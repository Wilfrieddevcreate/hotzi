package com.hotzi.net

import java.io.Closeable

/** Connexions ouvertes par chaque client, pour pouvoir toutes les couper d'un coup. */
class ConnectionRegistry {
    private val byIp = HashMap<String, MutableSet<Closeable>>()

    /** Enregistre une connexion ; fermer le résultat la retire du registre. */
    fun track(ip: String, connection: Closeable): Closeable {
        synchronized(byIp) { byIp.getOrPut(ip) { HashSet() }.add(connection) }
        return Closeable { untrack(ip, connection) }
    }

    /** Ferme toutes les connexions de ce client et renvoie leur nombre. */
    fun closeAll(ip: String): Int {
        val connections = synchronized(byIp) { byIp.remove(ip)?.toList().orEmpty() }
        connections.forEach { runCatching { it.close() } }
        return connections.size
    }

    fun closeEverything() {
        synchronized(byIp) { byIp.keys.toList() }.forEach { closeAll(it) }
    }

    fun ips(): Set<String> = synchronized(byIp) { byIp.keys.toSet() }

    fun count(ip: String): Int = synchronized(byIp) { byIp[ip]?.size ?: 0 }

    private fun untrack(ip: String, connection: Closeable) {
        synchronized(byIp) {
            val connections = byIp[ip] ?: return
            connections.remove(connection)
            if (connections.isEmpty()) byIp.remove(ip)
        }
    }
}
