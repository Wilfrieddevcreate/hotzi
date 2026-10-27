package com.hotzi.net

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WifiCredentialsTest {

    @Test
    fun `le Wi-Fi par défaut respecte les règles d'Android`() {
        assertTrue(WifiCredentials.DEFAULT.isValid)
    }

    @Test
    fun `le vendeur choisit la fin du nom`() {
        assertTrue(WifiCredentials.isValidEnding("Chez Awa"))
        assertTrue(WifiCredentials.isValidEnding("Boutique_2-Gare"))
        assertTrue(WifiCredentials.isValidEnding("A"))
        assertTrue(WifiCredentials.isValidEnding("a".repeat(22)))
    }

    @Test
    fun `les noms qu'Android refuserait ou que les clients liraient mal sont refusés`() {
        assertFalse(WifiCredentials.isValidEnding(""))
        assertFalse(WifiCredentials.isValidEnding("a".repeat(23)))
        assertFalse(WifiCredentials.isValidEnding("Chez Aïcha"))
        assertFalse(WifiCredentials.isValidEnding(" Awa"))
        assertFalse(WifiCredentials.isValidEnding("Awa "))
        assertFalse(WifiCredentials("Hotzi", "hotzi2026").isValid)
    }

    @Test
    fun `le mot de passe fait 8 à 63 caractères, sans espace ni accent`() {
        assertTrue(WifiCredentials.isValidPassphrase("12345678"))
        assertTrue(WifiCredentials.isValidPassphrase("Awa#2026!"))
        assertTrue(WifiCredentials.isValidPassphrase("x".repeat(63)))
        assertFalse(WifiCredentials.isValidPassphrase("1234567"))
        assertFalse(WifiCredentials.isValidPassphrase("x".repeat(64)))
        assertFalse(WifiCredentials.isValidPassphrase("mot de passe"))
        assertFalse(WifiCredentials.isValidPassphrase("événement"))
    }
}
