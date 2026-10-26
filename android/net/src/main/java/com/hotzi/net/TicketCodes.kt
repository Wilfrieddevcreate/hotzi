package com.hotzi.net

import java.security.SecureRandom

/**
 * Codes d'accès : 8 caractères pris dans un alphabet sans caractères ambigus
 * (ni 0/O, ni 1/I), soit 32^8 ≈ 10^12 combinaisons.
 */
object TicketCodes {
    const val ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    const val LENGTH = 8

    private val random = SecureRandom()

    fun generate(): String = buildString(LENGTH) {
        repeat(LENGTH) { append(ALPHABET[random.nextInt(ALPHABET.length)]) }
    }

    /** « k7qm-4xpa » ou « K7QM 4XPA » deviennent « K7QM4XPA ». */
    fun normalize(input: String): String =
        input.uppercase().filterNot { it == '-' || it == ' ' || it == '.' || it == '\t' }

    fun format(code: String): String =
        if (code.length == LENGTH) code.substring(0, 4) + "-" + code.substring(4) else code
}
