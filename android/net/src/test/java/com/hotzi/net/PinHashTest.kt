package com.hotzi.net

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PinHashTest {

    @Test
    fun `le code n'est jamais enregistré tel quel`() {
        val stored = PinHash.create("2580")
        assertTrue(PinHash.isHash(stored))
        assertFalse(stored.contains("2580"))
        assertNotEquals(stored, PinHash.create("2580"))
    }

    @Test
    fun `seul le bon code correspond`() {
        val stored = PinHash.create("2580")
        assertTrue(PinHash.matches("2580", stored))
        assertFalse(PinHash.matches("2581", stored))
        assertFalse(PinHash.matches("", stored))
    }

    @Test
    fun `un ancien code gardé en clair marche encore, pour être converti`() {
        assertFalse(PinHash.isHash("2580"))
        assertTrue(PinHash.matches("2580", "2580"))
        assertFalse(PinHash.matches("1111", "2580"))
    }

    @Test
    fun `une empreinte abîmée ne laisse jamais entrer`() {
        assertFalse(PinHash.matches("2580", "pbkdf2-sha256\$abc\$\$"))
        assertFalse(PinHash.matches("2580", "pbkdf2-sha256\$1000\$!!!\$!!!"))
    }
}
