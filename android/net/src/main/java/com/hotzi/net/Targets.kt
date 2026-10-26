package com.hotzi.net

data class HostPort(val host: String, val port: Int)

/** Cible d'une requête envoyée à un proxy : « http://hote:port/chemin ». */
data class HttpTarget(val hostPort: HostPort, val path: String)

object Targets {

    fun parseAbsolute(target: String): HttpTarget? {
        if (!target.startsWith("http://", ignoreCase = true)) return null
        val rest = target.substring("http://".length)
        val slash = rest.indexOf('/')
        val authority = if (slash == -1) rest else rest.substring(0, slash)
        val path = if (slash == -1) "/" else rest.substring(slash)
        val hostPort = parseAuthority(authority, 80) ?: return null
        return HttpTarget(hostPort, path)
    }

    /** « exemple.com:443 », « [2001:db8::1]:443 » ou « exemple.com » (port par défaut). */
    fun parseAuthority(authority: String, defaultPort: Int): HostPort? {
        val value = authority.substringAfterLast('@')
        val host: String
        val portText: String?
        if (value.startsWith("[")) {
            val end = value.indexOf(']')
            if (end == -1) return null
            host = value.substring(1, end)
            portText = value.substring(end + 1).removePrefix(":").ifEmpty { null }
        } else {
            val colon = value.lastIndexOf(':')
            host = if (colon == -1) value else value.substring(0, colon)
            portText = if (colon == -1) null else value.substring(colon + 1)
        }
        val port = if (portText == null) defaultPort else portText.toIntOrNull() ?: return null
        if (host.isEmpty() || port !in 1..65535) return null
        return HostPort(host.lowercase(), port)
    }
}
