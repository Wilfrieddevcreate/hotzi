package com.hotzi.net

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream

/** Juste ce qu'il faut de HTTP/1.x pour un proxy : la ligne de requête et les en-têtes. */
class HttpRequest(
    val method: String,
    val target: String,
    val version: String,
    val headers: List<Pair<String, String>>,
) {
    fun header(name: String): String? =
        headers.firstOrNull { it.first.equals(name, ignoreCase = true) }?.second

    companion object {
        const val MAX_HEAD_BYTES = 16 * 1024

        /**
         * Lit jusqu'à la ligne vide qui termine les en-têtes. Le corps éventuel
         * reste dans [input]. Renvoie null si le client ferme sans rien envoyer.
         */
        fun read(input: InputStream): HttpRequest? {
            val head = ByteArrayOutputStream()
            var matched = 0 // octets de « \r\n\r\n » déjà vus
            while (matched < 4) {
                val b = input.read()
                if (b == -1) {
                    if (head.size() == 0) return null
                    throw IOException("requête incomplète")
                }
                head.write(b)
                if (head.size() > MAX_HEAD_BYTES) throw IOException("en-têtes trop longs")
                matched = when (b) {
                    '\r'.code -> if (matched == 2) 3 else 1
                    '\n'.code -> if (matched == 1 || matched == 3) matched + 1 else 0
                    else -> 0
                }
            }
            val lines = head.toString(Charsets.ISO_8859_1.name()).split("\r\n")
            val parts = lines.first().split(' ')
            if (parts.size != 3) throw IOException("ligne de requête invalide")
            val headers = lines.drop(1).mapNotNull { line ->
                val colon = line.indexOf(':')
                if (colon <= 0) null else line.substring(0, colon).trim() to line.substring(colon + 1).trim()
            }
            return HttpRequest(parts[0].uppercase(), parts[1], parts[2], headers)
        }
    }
}
