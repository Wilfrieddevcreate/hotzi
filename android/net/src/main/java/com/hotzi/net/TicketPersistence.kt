package com.hotzi.net

import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.io.File

interface TicketPersistence {
    fun load(): List<Ticket>
    fun save(tickets: List<Ticket>)
}

class InMemoryPersistence(initial: List<Ticket> = emptyList()) : TicketPersistence {
    var saved: List<Ticket> = initial
        private set

    override fun load(): List<Ticket> = saved

    override fun save(tickets: List<Ticket>) {
        saved = tickets.toList()
    }
}

/**
 * Tickets enregistrés dans un fichier JSON, écrit d'un bloc (fichier temporaire
 * puis renommage) : un redémarrage brutal ne laisse jamais un fichier à moitié écrit.
 */
class JsonFilePersistence(private val file: File) : TicketPersistence {

    override fun load(): List<Ticket> {
        if (!file.exists()) return emptyList()
        return try {
            val array = JSONArray(file.readText())
            (0 until array.length()).map { fromJson(array.getJSONObject(it)) }
        } catch (e: JSONException) {
            // On garde le fichier illisible de côté plutôt que de l'écraser.
            file.renameTo(File(file.parentFile, "${file.name}.illisible-${System.currentTimeMillis()}"))
            emptyList()
        }
    }

    override fun save(tickets: List<Ticket>) {
        val array = JSONArray()
        tickets.forEach { array.put(toJson(it)) }
        val tmp = File(file.parentFile, "${file.name}.tmp")
        tmp.writeText(array.toString())
        if (!tmp.renameTo(file)) {
            file.delete()
            tmp.renameTo(file)
        }
    }

    private fun toJson(ticket: Ticket) = JSONObject().apply {
        put("code", ticket.code)
        put("label", ticket.label)
        put("durationMs", ticket.durationMs)
        put("priceFcfa", ticket.priceFcfa)
        put("createdAt", ticket.createdAt)
        put("status", ticket.status.name)
        ticket.activatedAt?.let { put("activatedAt", it) }
        ticket.expiresAt?.let { put("expiresAt", it) }
        ticket.clientIp?.let { put("clientIp", it) }
    }

    private fun fromJson(json: JSONObject) = Ticket(
        code = json.getString("code"),
        label = json.getString("label"),
        durationMs = json.getLong("durationMs"),
        priceFcfa = json.getInt("priceFcfa"),
        createdAt = json.getLong("createdAt"),
        status = TicketStatus.valueOf(json.getString("status")),
        activatedAt = if (json.has("activatedAt")) json.getLong("activatedAt") else null,
        expiresAt = if (json.has("expiresAt")) json.getLong("expiresAt") else null,
        clientIp = if (json.has("clientIp")) json.getString("clientIp") else null,
    )
}
