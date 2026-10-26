package com.hotzi.banc

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.WindowInsets
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import com.hotzi.net.HotziEngine
import com.hotzi.net.HotziService
import com.hotzi.net.Ticket
import com.hotzi.net.TicketStatus
import java.util.Locale

/**
 * Banc de test du prototype réseau : démarre le Wi-Fi Hotzi, crée des tickets
 * de test et montre en direct qui a Internet. Ce n'est pas l'app finale.
 */
class MainActivity : Activity() {
    private lateinit var engine: HotziEngine
    private lateinit var status: TextView
    private lateinit var toggle: Button
    private lateinit var batteryButton: Button
    private lateinit var ticketList: LinearLayout
    private lateinit var logView: TextView
    private val ticketLabels = HashMap<String, TextView>()
    private var shownTickets = ""
    private val refresh: () -> Unit = { render() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        engine = HotziEngine.get(this)
        setContentView(buildLayout())
        val missing = missingPermissions(includeOptional = true)
        if (missing.isNotEmpty()) requestPermissions(missing.toTypedArray(), REQUEST_PERMISSIONS)
    }

    override fun onStart() {
        super.onStart()
        engine.addListener(refresh)
        render()
    }

    override fun onStop() {
        engine.removeListener(refresh)
        super.onStop()
    }

    private fun onToggle() {
        if (engine.state.running) {
            HotziService.stop(this)
            return
        }
        val missing = missingPermissions(includeOptional = false)
        if (missing.isNotEmpty()) {
            requestPermissions(missing.toTypedArray(), REQUEST_PERMISSIONS)
            toast("Autorise Hotzi, puis appuie de nouveau sur Démarrer.")
            return
        }
        if (!getSystemService(WifiManager::class.java).isWifiEnabled) {
            toast("Allume le Wi-Fi, sans te connecter à un réseau.")
            startActivity(Intent(Settings.Panel.ACTION_WIFI))
            return
        }
        HotziService.start(this)
    }

    private fun createTestTicket(minutes: Int) {
        engine.createTicket("Test $minutes min", minutes * 60_000L, if (minutes <= 2) 50 else 100)
        render()
    }

    private fun render() {
        val state = engine.state
        status.text = buildString {
            append(
                when {
                    state.controlActive -> "CONTRÔLE ACTIF : les tickets sont protégés"
                    state.running -> "CONTRÔLE INACTIF : personne n'a Internet"
                    else -> "Wi-Fi Hotzi arrêté"
                }
            )
            append("\n\nWi-Fi : ")
            append(
                state.group?.let { "${it.networkName}  ·  mot de passe ${it.passphrase}  ·  ${it.clientCount} appareil(s)" }
                    ?: "pas de réseau"
            )
            append("\nProxy : ").append(state.proxyAddress ?: "arrêté")
            append("\nInternet du téléphone : ").append(if (state.running) state.upstream else "—")
            state.error?.let { append("\n\nAttention : ").append(it) }
        }
        status.setBackgroundColor(Color.parseColor(if (state.controlActive) "#2D1A7A" else "#4E4766"))
        toggle.text = if (state.running) "Arrêter le Wi-Fi Hotzi" else "Démarrer le Wi-Fi Hotzi"
        batteryButton.visibility = if (isBatteryExempt()) View.GONE else View.VISIBLE
        renderTickets()
        logView.text = engine.logs().takeLast(40).reversed().joinToString("\n")
    }

    private fun renderTickets() {
        val tickets = engine.access.all().sortedByDescending { it.createdAt }
        val signature = tickets.joinToString { it.code + it.status }
        if (signature != shownTickets) {
            shownTickets = signature
            ticketList.removeAllViews()
            ticketLabels.clear()
            if (tickets.isEmpty()) ticketList.addView(text(14f).apply { text = "Aucun ticket. Crée un ticket de test." })
            for (ticket in tickets) {
                val label = text(14f)
                ticketLabels[ticket.code] = label
                val line = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    setPadding(0, dp(6), 0, dp(6))
                }
                line.addView(label, LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f))
                if (ticket.status == TicketStatus.AVAILABLE || ticket.status == TicketStatus.ACTIVE) {
                    line.addView(button("Annuler") { engine.revoke(ticket.code) })
                }
                ticketList.addView(line)
            }
        }
        val now = System.currentTimeMillis()
        tickets.forEach { ticketLabels[it.code]?.text = describe(it, now) }
    }

    private fun describe(ticket: Ticket, now: Long): String {
        val detail = when (ticket.status) {
            TicketStatus.AVAILABLE -> "Disponible, pas encore utilisé"
            TicketStatus.ACTIVE ->
                "En cours · reste ${minutes(ticket.remainingMs(now))} · ${ticket.clientIp} · " +
                    "${engine.registry.count(ticket.clientIp.orEmpty())} connexion(s)"
            TicketStatus.EXPIRED -> "Terminé · ${ticket.clientIp.orEmpty()}"
            TicketStatus.REVOKED -> "Annulé"
        }
        return "${ticket.displayCode}  ·  ${ticket.label}\n$detail"
    }

    private fun minutes(ms: Long): String {
        val seconds = ms / 1000
        return String.format(Locale.ROOT, "%d:%02d", seconds / 60, seconds % 60)
    }

    /** Jusqu'à Android 12, le Wi-Fi Direct exige la localisation précise (pas seulement approximative). */
    private fun missingPermissions(includeOptional: Boolean): List<String> {
        val needed = buildList {
            if (Build.VERSION.SDK_INT >= 33) {
                add(Manifest.permission.NEARBY_WIFI_DEVICES)
                if (includeOptional) add(Manifest.permission.POST_NOTIFICATIONS)
            } else {
                add(Manifest.permission.ACCESS_COARSE_LOCATION)
                add(Manifest.permission.ACCESS_FINE_LOCATION)
            }
        }
        return needed.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
    }

    private fun isBatteryExempt() = getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName)

    @SuppressLint("BatteryLife") // Banc de test installé à la main, pas publié sur le Play Store.
    private fun askBatteryExemption() {
        startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
    }

    private fun buildLayout(): View {
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(24))
        }
        column.addView(text(22f).apply {
            text = "Hotzi · banc de test réseau"
            setTypeface(typeface, Typeface.BOLD)
        })
        status = text(15f).apply {
            setTextColor(Color.WHITE)
            setPadding(dp(14), dp(12), dp(14), dp(12))
        }
        column.addView(status, spaced(12))
        toggle = button("") { onToggle() }
        column.addView(toggle, spaced(12))
        column.addView(pair(button("Ticket test 2 min") { createTestTicket(2) }, button("Ticket test 5 min") { createTestTicket(5) }), spaced(8))
        batteryButton = button("Ne pas couper Hotzi") { askBatteryExemption() }
        column.addView(pair(button("Réglages Wi-Fi") { startActivity(Intent(Settings.Panel.ACTION_WIFI)) }, batteryButton), spaced(8))
        column.addView(heading("Tickets"), spaced(20))
        ticketList = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        column.addView(ticketList, spaced(4))
        column.addView(heading("Journal (le plus récent en haut)"), spaced(20))
        logView = text(12f).apply {
            typeface = Typeface.MONOSPACE
            setTextIsSelectable(true)
        }
        column.addView(logView, spaced(4))

        return ScrollView(this).apply {
            clipToPadding = false
            addView(column)
            setOnApplyWindowInsetsListener { view, insets ->
                val (top, bottom) = systemBars(insets)
                view.setPadding(0, top, 0, bottom)
                insets
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun systemBars(insets: WindowInsets): Pair<Int, Int> =
        if (Build.VERSION.SDK_INT >= 30) {
            insets.getInsets(WindowInsets.Type.systemBars()).let { it.top to it.bottom }
        } else {
            insets.systemWindowInsetTop to insets.systemWindowInsetBottom
        }

    private fun text(size: Float) = TextView(this).apply {
        textSize = size
        setTextColor(Color.parseColor("#1C1236"))
    }

    private fun heading(title: String) = text(17f).apply {
        text = title
        setTypeface(typeface, Typeface.BOLD)
    }

    private fun button(label: String, onClick: () -> Unit) = Button(this).apply {
        text = label
        isAllCaps = false
        setOnClickListener { onClick() }
    }

    private fun pair(left: View, right: View) = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        addView(left, LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f).apply { marginEnd = dp(4) })
        addView(right, LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f).apply { marginStart = dp(4) })
    }

    private fun spaced(top: Int) = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = dp(top) }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    private fun toast(message: String) = Toast.makeText(this, message, Toast.LENGTH_LONG).show()

    private companion object {
        const val REQUEST_PERMISSIONS = 1
    }
}
