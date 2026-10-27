package com.hotzi.net

/** Où les règles d'accès enregistrent les tickets. */
interface TicketPersistence {
    fun load(): List<Ticket>

    /** Enregistre un nouveau ticket et le renvoie avec son identifiant (et un autre code si le sien était pris). */
    fun insert(ticket: Ticket): Ticket

    /** Enregistre l'état d'accès d'un ticket existant : statut, heures, téléphone client. */
    fun update(ticket: Ticket)
}

/** Tickets en mémoire, pour les tests. */
class InMemoryPersistence : TicketPersistence {
    private val rows = LinkedHashMap<String, Ticket>()
    private var lastId = 0L

    override fun load(): List<Ticket> = rows.values.toList()

    override fun insert(ticket: Ticket): Ticket = ticket.copy(id = ++lastId).also { rows[it.code] = it }

    override fun update(ticket: Ticket) {
        rows[ticket.code] = ticket
    }
}
