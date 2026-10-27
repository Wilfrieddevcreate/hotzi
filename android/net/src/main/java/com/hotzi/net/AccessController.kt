package com.hotzi.net

/**
 * Règles d'accès des tickets. Toute décision « ce client a-t-il Internet ? »
 * se prend ici ; le proxy ne fait qu'appliquer la réponse.
 *
 * Les heures sont des heures murales (et non le temps depuis le démarrage)
 * pour qu'un redémarrage du téléphone ne remette aucun chrono à zéro.
 */
class AccessController(
    private val persistence: TicketPersistence,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    sealed interface Activation {
        data class Granted(val ticket: Ticket) : Activation
        /** Le client a déjà un ticket en cours : on ne consomme pas le nouveau. */
        data class AlreadyConnected(val ticket: Ticket) : Activation
        data object Unknown : Activation
        data object Expired : Activation
        data object InUse : Activation
        data object Revoked : Activation
        data object TooManyAttempts : Activation
    }

    /** Appelé après chaque changement d'un ticket (création, activation, fin, annulation). */
    @Volatile
    var onChange: (() -> Unit)? = null

    private val lock = Any()
    private val tickets = LinkedHashMap<String, Ticket>()
    private val failures = HashMap<String, ArrayDeque<Long>>()
    private val lastSeen = HashMap<String, Long>()
    private var changed = false

    init {
        persistence.load().forEach { tickets[it.code] = it }
        expireDue()
    }

    fun create(label: String, durationMs: Long, priceFcfa: Int): Ticket = mutate {
        var code: String
        do {
            code = TicketCodes.generate()
        } while (tickets.containsKey(code))
        persistence.insert(Ticket(code, label, durationMs, priceFcfa, clock())).also {
            tickets[it.code] = it
            changed = true
        }
    }

    /** Ajoute des tickets déjà enregistrés ailleurs, par exemple vendus depuis l'app. */
    fun register(sold: List<Ticket>) = mutate {
        sold.forEach { tickets[it.code] = it }
        changed = sold.isNotEmpty()
    }

    fun all(): List<Ticket> = synchronized(lock) { tickets.values.toList() }

    fun activate(rawCode: String, ip: String): Activation = mutate { activateLocked(rawCode, ip) }

    fun isAllowed(ip: String): Boolean = synchronized(lock) { activeFor(ip, clock()) != null }

    fun activeTicketFor(ip: String): Ticket? = synchronized(lock) { activeFor(ip, clock()) }

    /** Dernier ticket utilisé depuis cette adresse, même terminé : le portail s'en sert pour expliquer la coupure. */
    fun lastTicketFor(ip: String): Ticket? = synchronized(lock) {
        tickets.values.filter { it.clientIp == ip }.maxByOrNull { it.activatedAt ?: 0L }
    }

    /** Annule un ticket. Renvoie le ticket annulé, ou null si le code est inconnu. */
    fun revoke(code: String): Ticket? = mutate {
        val ticket = tickets[TicketCodes.normalize(code)]
        when {
            ticket == null -> null
            ticket.status == TicketStatus.EXPIRED || ticket.status == TicketStatus.REVOKED -> ticket
            else -> update(ticket.copy(status = TicketStatus.REVOKED))
        }
    }

    /** Note qu'un client autorisé vient d'ouvrir une connexion. */
    fun touch(ip: String) {
        synchronized(lock) { lastSeen[ip] = clock() }
    }

    /** Passe en « terminé » les tickets dont l'heure est dépassée et les renvoie. */
    fun expireDue(): List<Ticket> = mutate {
        val now = clock()
        tickets.values
            .filter { it.status == TicketStatus.ACTIVE && (it.expiresAt ?: 0L) <= now }
            .map { update(it.copy(status = TicketStatus.EXPIRED)) }
    }

    private fun activateLocked(rawCode: String, ip: String): Activation {
        val now = clock()
        activeFor(ip, now)?.let { return Activation.AlreadyConnected(it) }
        if (isThrottled(ip, now)) return Activation.TooManyAttempts

        val ticket = tickets[TicketCodes.normalize(rawCode)]
        if (ticket == null) {
            failures.getOrPut(ip) { ArrayDeque() }.addLast(now)
            return Activation.Unknown
        }
        return when (ticket.status) {
            TicketStatus.REVOKED -> Activation.Revoked
            TicketStatus.EXPIRED -> Activation.Expired
            TicketStatus.ACTIVE -> when {
                (ticket.expiresAt ?: 0L) <= now -> {
                    update(ticket.copy(status = TicketStatus.EXPIRED))
                    Activation.Expired
                }
                canMove(ticket, now) -> {
                    lastSeen[ip] = now
                    Activation.Granted(update(ticket.copy(clientIp = ip)))
                }
                else -> Activation.InUse
            }
            TicketStatus.AVAILABLE -> {
                lastSeen[ip] = now
                Activation.Granted(
                    update(
                        ticket.copy(
                            status = TicketStatus.ACTIVE,
                            activatedAt = now,
                            expiresAt = now + ticket.durationMs,
                            clientIp = ip,
                        )
                    )
                )
            }
        }
    }

    private fun activeFor(ip: String, now: Long): Ticket? = tickets.values.firstOrNull {
        it.status == TicketStatus.ACTIVE && it.clientIp == ip && (it.expiresAt ?: 0L) > now
    }

    /**
     * Un ticket en cours peut passer sur une nouvelle adresse si l'ancienne ne
     * s'en sert plus (téléphone reconnecté, redémarrage de l'hôte). Jamais deux
     * appareils en même temps.
     */
    private fun canMove(ticket: Ticket, now: Long): Boolean {
        val previous = ticket.clientIp ?: return true
        return now - (lastSeen[previous] ?: 0L) >= MOVE_AFTER_IDLE_MS
    }

    private fun isThrottled(ip: String, now: Long): Boolean {
        val recent = failures[ip] ?: return false
        while (recent.isNotEmpty() && now - recent.first() >= FAILURE_WINDOW_MS) recent.removeFirst()
        return recent.size >= MAX_FAILURES
    }

    /** À appeler sous le verrou : enregistre le ticket et note qu'il faudra prévenir l'app. */
    private fun update(ticket: Ticket): Ticket {
        tickets[ticket.code] = ticket
        persistence.update(ticket)
        changed = true
        return ticket
    }

    /** Exécute [block] sous le verrou, puis prévient [onChange] hors du verrou si un ticket a changé. */
    private fun <T> mutate(block: () -> T): T {
        val (result, notify) = synchronized(lock) {
            changed = false
            block() to changed
        }
        if (notify) onChange?.invoke()
        return result
    }

    companion object {
        const val MAX_FAILURES = 5
        const val FAILURE_WINDOW_MS = 2 * 60_000L
        const val MOVE_AFTER_IDLE_MS = 3 * 60_000L
    }
}
