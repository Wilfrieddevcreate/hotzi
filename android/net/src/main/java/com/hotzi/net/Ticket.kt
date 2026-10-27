package com.hotzi.net

/** Vie d'un ticket : disponible, puis en cours, puis terminé (ou annulé par le vendeur). */
enum class TicketStatus { AVAILABLE, ACTIVE, EXPIRED, REVOKED }

data class Ticket(
    /** Code normalisé, sans tiret : « K7QM4XPA ». */
    val code: String,
    /** Nom du forfait au moment de la vente. */
    val label: String,
    val durationMs: Long,
    /** Prix figé au moment de la vente, même si le forfait change ensuite. */
    val priceFcfa: Int,
    val createdAt: Long,
    val status: TicketStatus = TicketStatus.AVAILABLE,
    val activatedAt: Long? = null,
    val expiresAt: Long? = null,
    /** Adresse du téléphone client qui utilise le ticket. */
    val clientIp: String? = null,
    val id: Long? = null,
    val planId: Long? = null,
) {
    val displayCode: String get() = TicketCodes.format(code)

    fun remainingMs(now: Long): Long =
        if (status == TicketStatus.ACTIVE && expiresAt != null) (expiresAt - now).coerceAtLeast(0) else 0
}
