package com.hotzi.net

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log

import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * Assemble le Wi-Fi Hotzi, le proxy et les règles d'accès. Un seul moteur par
 * application : le service le fait tourner, l'interface le lit.
 */
class HotziEngine private constructor(context: Context) {

    data class State(
        val running: Boolean = false,
        /** Heure du dernier démarrage, pour afficher « allumé depuis 08:02 ». */
        val runningSince: Long? = null,
        val group: WifiDirectHotspot.Group? = null,
        val proxyAddress: String? = null,
        val upstream: String = "",
        val upstreamAvailable: Boolean = false,
        val error: String? = null,
    ) {
        /** Vrai seulement si le Wi-Fi et le proxy tournent : sans eux, on n'affiche jamais « protégé ». */
        val controlActive: Boolean get() = running && group != null && proxyAddress != null
    }

    /** Un client qui a Internet en ce moment. */
    data class Session(
        val code: String,
        val label: String,
        val clientIp: String,
        val remainingMs: Long,
        val connections: Int,
    )

    private val appContext = context.applicationContext
    private val prefs = appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val main = Handler(Looper.getMainLooper())
    private val worker: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor()
    private val logLines = ArrayDeque<String>()
    private val listeners = LinkedHashSet<() -> Unit>()
    private val ticketChanges = AtomicInteger()

    val database = HotziDatabase.get(appContext)
    val access = AccessController(database).also {
        it.onChange = {
            ticketChanges.incrementAndGet()
            publish()
        }
    }
    val registry = ConnectionRegistry()

    /** Augmente à chaque changement de ticket : l'app sait alors qu'elle doit relire la liste. */
    val ticketsVersion: Int get() = ticketChanges.get()
    private val portal = Portal(access, ::log)
    private val upstream = UpstreamNetwork(appContext) { publish() }
    private val hotspot = WifiDirectHotspot(appContext, object : WifiDirectHotspot.Listener {
        override fun onGroupUp(group: WifiDirectHotspot.Group) = worker.execute { groupUp(group) }
        override fun onGroupDown() = worker.execute { groupDown() }
        override fun onError(message: String) {
            log(message)
            update { it.copy(error = message) }
        }
    })

    @Volatile
    private var proxy: AccessProxy? = null
    private var ticker: ScheduledFuture<*>? = null
    private var retry: ScheduledFuture<*>? = null

    @Volatile
    var state = State()
        private set

    /** À appeler depuis le thread principal. */
    fun start() {
        if (state.running) return
        prefs.edit().putBoolean(KEY_SHOULD_RUN, true).apply()
        update { State(running = true, runningSince = System.currentTimeMillis(), upstream = upstream.describe()) }
        log("Démarrage du Wi-Fi Hotzi")
        upstream.start()
        hotspot.start(NETWORK_NAME, PASSPHRASE)
        ticker = worker.scheduleWithFixedDelay(::tick, 1, 1, TimeUnit.SECONDS)
    }

    /**
     * À appeler depuis le thread principal.
     * @param forget vrai si le vendeur l'arrête lui-même : Hotzi ne redémarrera pas avec le téléphone.
     */
    fun stop(forget: Boolean) {
        if (!state.running) return
        if (forget) prefs.edit().putBoolean(KEY_SHOULD_RUN, false).apply()
        ticker?.cancel(false)
        retry?.cancel(false)
        hotspot.stop()
        upstream.stop()
        worker.execute { stopProxy() }
        update { State(running = false) }
        log("Wi-Fi Hotzi arrêté")
    }

    /** Ticket de test, sans forfait ni vente (app de test réseau). */
    fun createTicket(label: String, durationMs: Long, priceFcfa: Int): Ticket =
        access.create(label, durationMs, priceFcfa).also {
            log("Ticket ${it.displayCode} créé : $label")
        }

    /** Vente depuis l'app : les tickets sont aussitôt utilisables sur le portail. */
    fun sell(planId: Long, quantity: Int, payment: String, at: Long): List<Ticket> =
        database.sell(planId, quantity, payment, at).also { sold ->
            access.register(sold)
            log("${sold.size} ticket(s) vendu(s) : ${sold.joinToString { it.displayCode }}")
        }

    /** Clients qui ont Internet en ce moment, le plus ancien d'abord. */
    fun sessions(now: Long = System.currentTimeMillis()): List<Session> =
        access.all()
            .filter { it.status == TicketStatus.ACTIVE && it.clientIp != null && it.remainingMs(now) > 0 }
            .sortedBy { it.activatedAt }
            .map { Session(it.code, it.label, it.clientIp!!, it.remainingMs(now), registry.count(it.clientIp)) }

    /** Annule un ticket et coupe tout de suite Internet au client qui l'utilise. */
    fun revoke(code: String) {
        worker.execute {
            val ticket = access.revoke(code) ?: return@execute
            val closed = ticket.clientIp?.let(registry::closeAll) ?: 0
            log("Ticket ${ticket.displayCode} annulé ($closed connexion(s) fermée(s))")
        }
    }

    fun logs(): List<String> = synchronized(logLines) { logLines.toList() }

    fun addListener(listener: () -> Unit) {
        synchronized(listeners) { listeners.add(listener) }
    }

    fun removeListener(listener: () -> Unit) {
        synchronized(listeners) { listeners.remove(listener) }
    }

    private fun groupUp(group: WifiDirectHotspot.Group) {
        if (!state.running) return
        retry?.cancel(false)
        val current = proxy
        if (current == null || current.address != group.ownerAddress || !current.isListening) {
            current?.stop()
            val next = AccessProxy(group.ownerAddress, PROXY_PORT, access, portal, registry, upstream::current, ::log)
            try {
                next.start()
            } catch (e: IOException) {
                proxy = null
                log("Le proxy n'a pas pu démarrer : ${e.message}")
                update { it.copy(group = group, proxyAddress = null, error = "Le proxy n'a pas pu démarrer.") }
                return
            }
            proxy = next
            log("Wi-Fi « ${group.networkName} » prêt, proxy sur ${group.ownerAddress.hostAddress}:$PROXY_PORT")
        }
        update { it.copy(group = group, proxyAddress = "${group.ownerAddress.hostAddress}:$PROXY_PORT", error = null) }
    }

    private fun groupDown() {
        val wasUp = state.group != null
        stopProxy()
        update { it.copy(group = null, proxyAddress = null) }
        if (!state.running) return
        if (wasUp) log("Le Wi-Fi Hotzi s'est arrêté. Personne n'a Internet. Nouvel essai dans $RETRY_SECONDS s.")
        scheduleRetry()
    }

    private fun scheduleRetry() {
        if (retry?.isDone == false) return
        retry = worker.schedule(Runnable {
            if (state.running && state.group == null) main.post { hotspot.start(NETWORK_NAME, PASSPHRASE) }
        }, RETRY_SECONDS, TimeUnit.SECONDS)
    }

    private fun stopProxy() {
        proxy?.stop()
        proxy = null
    }

    private fun tick() {
        for (ticket in access.expireDue()) {
            val closed = ticket.clientIp?.let(registry::closeAll) ?: 0
            log("Ticket ${ticket.displayCode} terminé : Internet coupé pour ${ticket.clientIp} ($closed connexion(s) fermée(s))")
        }
        // Filet de sécurité : aucune connexion ne survit sans ticket valide.
        for (ip in registry.ips()) {
            if (!access.isAllowed(ip)) registry.closeAll(ip)
        }
        // Le proxy est mort alors que le Wi-Fi tourne : on le signale et on le relance.
        val group = state.group
        if (group != null && proxy?.isListening != true) {
            log("Le proxy ne répond plus. Personne n'a Internet. Relance.")
            update { it.copy(proxyAddress = null, error = "Le proxy s'est arrêté.") }
            groupUp(group)
        }
        update { it.copy(upstream = upstream.describe(), upstreamAvailable = upstream.current() != null) }
    }

    fun log(message: String) {
        Log.i(TAG, message)
        val line = SimpleDateFormat("HH:mm:ss", Locale.FRANCE).format(Date()) + "  " + message
        synchronized(logLines) {
            logLines.addLast(line)
            while (logLines.size > MAX_LOGS) logLines.removeFirst()
        }
        publish()
    }

    @Synchronized
    private fun update(change: (State) -> State) {
        state = change(state)
        publish()
    }

    private fun publish() {
        val snapshot = synchronized(listeners) { listeners.toList() }
        main.post { snapshot.forEach { it() } }
    }

    companion object {
        const val NETWORK_NAME = "DIRECT-hz-Hotzi"
        const val PASSPHRASE = "hotzi2026"
        const val PROXY_PORT = 8282

        private const val TAG = "Hotzi"
        private const val RETRY_SECONDS = 10L
        private const val MAX_LOGS = 200
        private const val PREFS = "hotzi_engine"
        private const val KEY_SHOULD_RUN = "should_run"

        @Volatile
        private var instance: HotziEngine? = null

        fun get(context: Context): HotziEngine =
            instance ?: synchronized(this) { instance ?: HotziEngine(context).also { instance = it } }

        /** Vrai si Hotzi tournait quand le téléphone s'est éteint. */
        fun shouldRun(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_SHOULD_RUN, false)
    }
}
