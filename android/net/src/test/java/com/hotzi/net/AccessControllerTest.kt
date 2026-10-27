package com.hotzi.net

import com.hotzi.net.AccessController.Activation
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AccessControllerTest {
    private var now = 1_000_000L
    private val store = InMemoryPersistence()
    private val access = AccessController(store) { now }

    private fun granted(result: Activation): Ticket {
        assertTrue("attendu Granted, reçu $result", result is Activation.Granted)
        return (result as Activation.Granted).ticket
    }

    @Test
    fun `le chrono démarre à la première activation, pas à la création`() {
        val ticket = access.create("Standard", 60_000, 100)
        now += 10_000
        val active = granted(access.activate(ticket.code, "192.168.49.10"))
        assertEquals(now, active.activatedAt)
        assertEquals(now + 60_000, active.expiresAt)
        assertTrue(access.isAllowed("192.168.49.10"))
    }

    @Test
    fun `le code est accepté en minuscules et avec tiret`() {
        val ticket = access.create("Mini", 30_000, 50)
        granted(access.activate(ticket.displayCode.lowercase(), "192.168.49.10"))
    }

    @Test
    fun `un ticket en cours est refusé sur un deuxième téléphone`() {
        val ticket = access.create("Standard", 60_000, 100)
        granted(access.activate(ticket.code, "192.168.49.10"))
        assertEquals(Activation.InUse, access.activate(ticket.code, "192.168.49.11"))
        assertFalse(access.isAllowed("192.168.49.11"))
    }

    @Test
    fun `l'accès s'arrête à l'heure, pour ce client seulement`() {
        val short = access.create("Court", 60_000, 50)
        val long = access.create("Long", 120_000, 100)
        granted(access.activate(short.code, "192.168.49.10"))
        granted(access.activate(long.code, "192.168.49.11"))

        now += 60_000
        val expired = access.expireDue()

        assertEquals(listOf(short.code), expired.map { it.code })
        assertFalse(access.isAllowed("192.168.49.10"))
        assertTrue(access.isAllowed("192.168.49.11"))
    }

    @Test
    fun `un ticket terminé ne se réactive pas`() {
        val ticket = access.create("Mini", 30_000, 50)
        granted(access.activate(ticket.code, "192.168.49.10"))
        now += 30_000
        access.expireDue()
        assertEquals(Activation.Expired, access.activate(ticket.code, "192.168.49.10"))
        assertEquals(Activation.Expired, access.activate(ticket.code, "192.168.49.12"))
    }

    @Test
    fun `un ticket expiré est refusé même avant le passage du minuteur`() {
        val ticket = access.create("Mini", 30_000, 50)
        granted(access.activate(ticket.code, "192.168.49.10"))
        now += 30_000 + MOVE_DELAY
        assertEquals(Activation.Expired, access.activate(ticket.code, "192.168.49.11"))
    }

    @Test
    fun `un ticket annulé coupe l'accès et ne se réactive pas`() {
        val ticket = access.create("Standard", 60_000, 100)
        granted(access.activate(ticket.code, "192.168.49.10"))
        val revoked = access.revoke(ticket.displayCode)
        assertEquals(TicketStatus.REVOKED, revoked?.status)
        assertFalse(access.isAllowed("192.168.49.10"))
        assertEquals(Activation.Revoked, access.activate(ticket.code, "192.168.49.10"))
    }

    @Test
    fun `un client déjà connecté ne consomme pas un deuxième ticket`() {
        val first = access.create("Standard", 60_000, 100)
        val second = access.create("Standard", 60_000, 100)
        granted(access.activate(first.code, "192.168.49.10"))
        assertTrue(access.activate(second.code, "192.168.49.10") is Activation.AlreadyConnected)
        assertEquals(TicketStatus.AVAILABLE, access.all().first { it.code == second.code }.status)
    }

    @Test
    fun `les codes inconnus sont bloqués après cinq essais`() {
        repeat(AccessController.MAX_FAILURES) {
            assertEquals(Activation.Unknown, access.activate("AAAAAAAA", "192.168.49.10"))
        }
        val ticket = access.create("Mini", 30_000, 50)
        assertEquals(Activation.TooManyAttempts, access.activate(ticket.code, "192.168.49.10"))

        now += AccessController.FAILURE_WINDOW_MS
        granted(access.activate(ticket.code, "192.168.49.10"))
    }

    @Test
    fun `un ticket inutilisé peut passer sur une nouvelle adresse sans gagner de temps`() {
        val ticket = access.create("Confort", 6 * 3_600_000L, 300)
        val first = granted(access.activate(ticket.code, "192.168.49.10"))
        now += MOVE_DELAY
        val moved = granted(access.activate(ticket.code, "192.168.49.20"))
        assertEquals("192.168.49.20", moved.clientIp)
        assertEquals(first.expiresAt, moved.expiresAt)
        assertFalse(access.isAllowed("192.168.49.10"))
    }

    @Test
    fun `un ticket utilisé à l'instant ne change pas d'appareil`() {
        val ticket = access.create("Confort", 6 * 3_600_000L, 300)
        granted(access.activate(ticket.code, "192.168.49.10"))
        now += MOVE_DELAY - 1_000
        access.touch("192.168.49.10")
        now += 2_000
        assertEquals(Activation.InUse, access.activate(ticket.code, "192.168.49.20"))
    }

    @Test
    fun `après un changement de Wi-Fi, un ticket en cours suit le client sur sa nouvelle adresse`() {
        val ticket = access.create("Standard", 60_000, 100)
        granted(access.activate(ticket.code, "192.168.49.10"))
        access.touch("192.168.49.10")
        access.forgetActivity()
        val moved = granted(access.activate(ticket.code, "192.168.49.20"))
        assertEquals("192.168.49.20", moved.clientIp)
        assertFalse(access.isAllowed("192.168.49.10"))
    }

    @Test
    fun `les tickets et leurs heures survivent à un redémarrage`() {
        val ticket = access.create("Standard", 60_000, 100)
        val active = granted(access.activate(ticket.code, "192.168.49.10"))

        now += 20_000
        val restarted = AccessController(store) { now }
        assertTrue(restarted.isAllowed("192.168.49.10"))
        assertEquals(active.expiresAt, restarted.activeTicketFor("192.168.49.10")?.expiresAt)

        now += 40_000
        val restartedLate = AccessController(store) { now }
        assertFalse(restartedLate.isAllowed("192.168.49.10"))
        assertEquals(TicketStatus.EXPIRED, restartedLate.all().single().status)
    }

    @Test
    fun `l'app est prévenue à chaque changement de ticket, pas pour un simple refus`() {
        var changes = 0
        access.onChange = { changes++ }
        val ticket = access.create("Standard", 60_000, 100)
        assertEquals(1, changes)

        granted(access.activate(ticket.code, "192.168.49.10"))
        assertEquals(2, changes)

        assertEquals(Activation.InUse, access.activate(ticket.code, "192.168.49.11"))
        assertEquals(2, changes)

        now += 60_000
        access.expireDue()
        assertEquals(3, changes)
    }

    @Test
    fun `un ticket vendu depuis l'app est utilisable dès son enregistrement`() {
        val sold = store.insert(Ticket(TicketCodes.generate(), "Mini", 30 * 60_000L, 50, now, planId = 1))
        access.register(listOf(sold))
        granted(access.activate(sold.code, "192.168.49.10"))
        assertEquals(TicketStatus.ACTIVE, store.load().single().status)
    }

    private companion object {
        const val MOVE_DELAY = AccessController.MOVE_AFTER_IDLE_MS
    }
}
