package com.hotzi.net

/**
 * Nom et mot de passe du Wi-Fi Hotzi, choisis par le vendeur.
 *
 * Android impose que le nom d'un Wi-Fi Direct commence par « DIRECT-xy » :
 * le vendeur ne choisit que la fin, après [PREFIX]. Les mêmes règles sont
 * vérifiées côté Flutter pour expliquer le refus avant l'envoi.
 */
data class WifiCredentials(val name: String, val passphrase: String) {

    val isValid: Boolean
        get() = name.startsWith(PREFIX) && isValidEnding(name.removePrefix(PREFIX)) && isValidPassphrase(passphrase)

    companion object {
        const val PREFIX = "DIRECT-hz-"
        val DEFAULT = WifiCredentials("${PREFIX}Hotzi", "hotzi2026")

        /**
         * Lettres sans accents, chiffres, espaces, tirets, sans espace au début ni à la fin.
         * 22 caractères au plus : un nom de Wi-Fi tient en 32 octets, préfixe compris.
         */
        private val ENDING = Regex("[A-Za-z0-9_-]([A-Za-z0-9 _-]{0,20}[A-Za-z0-9_-])?")

        /** La règle du WPA2 : 8 à 63 caractères ; sans espace ni accent pour que le client le tape sans erreur. */
        private val PASSPHRASE = Regex("[!-~]{8,63}")

        fun isValidEnding(ending: String): Boolean = ENDING.matches(ending)

        fun isValidPassphrase(passphrase: String): Boolean = PASSPHRASE.matches(passphrase)
    }
}
