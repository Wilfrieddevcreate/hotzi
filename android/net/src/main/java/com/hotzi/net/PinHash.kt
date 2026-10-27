package com.hotzi.net

import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

/**
 * Empreinte du code secret du vendeur : la base ne garde jamais le code lui-même.
 * Format enregistré : « pbkdf2-sha256$itérations$sel$empreinte », en Base64.
 *
 * Un code à 4 chiffres n'a que 10 000 possibilités : quelqu'un qui aurait copié
 * la base pourrait encore le retrouver. L'empreinte empêche de le lire tel quel,
 * et son calcul volontairement lent freine les essais.
 */
object PinHash {
    private const val SCHEME = "pbkdf2-sha256"
    private const val ITERATIONS = 50_000
    private const val SALT_BYTES = 16
    private const val HASH_BITS = 256

    fun create(pin: String, random: SecureRandom = SecureRandom()): String {
        val salt = ByteArray(SALT_BYTES).also(random::nextBytes)
        val encoder = Base64.getEncoder()
        return listOf(SCHEME, ITERATIONS, encoder.encodeToString(salt), encoder.encodeToString(derive(pin, salt, ITERATIONS)))
            .joinToString("$")
    }

    /** Vrai si [pin] correspond à [stored]. Accepte aussi un ancien code gardé en clair, à convertir. */
    fun matches(pin: String, stored: String): Boolean {
        if (!isHash(stored)) return MessageDigest.isEqual(pin.toByteArray(), stored.toByteArray())
        val parts = stored.split('$')
        if (parts.size != 4) return false
        val iterations = parts[1].toIntOrNull() ?: return false
        val decoder = Base64.getDecoder()
        val salt = runCatching { decoder.decode(parts[2]) }.getOrNull() ?: return false
        val expected = runCatching { decoder.decode(parts[3]) }.getOrNull() ?: return false
        return MessageDigest.isEqual(derive(pin, salt, iterations), expected)
    }

    fun isHash(stored: String): Boolean = stored.startsWith("$SCHEME$")

    private fun derive(pin: String, salt: ByteArray, iterations: Int): ByteArray {
        val spec = PBEKeySpec(pin.toCharArray(), salt, iterations, HASH_BITS)
        try {
            return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
        } finally {
            spec.clearPassword()
        }
    }
}
