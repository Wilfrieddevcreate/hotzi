package com.hotzi.net

import android.net.Network
import java.io.BufferedInputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.Inet6Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * Le seul chemin entre le Wi-Fi Hotzi et Internet. Chaque connexion est
 * vérifiée par [AccessController] ; si le proxy s'arrête, plus personne ne sort.
 *
 * Il écoute uniquement sur l'adresse du Wi-Fi Hotzi, jamais côté données mobiles.
 */
class AccessProxy(
    val address: InetAddress,
    val port: Int,
    private val access: AccessController,
    private val portal: Portal,
    private val registry: ConnectionRegistry,
    private val upstream: () -> Network?,
    private val log: (String) -> Unit,
) {
    private val pool: ExecutorService = Executors.newCachedThreadPool()
    private val lastRefusalLog = HashMap<String, Long>()

    @Volatile
    private var server: ServerSocket? = null

    val isListening: Boolean get() = server?.isClosed == false

    @Throws(IOException::class)
    fun start() {
        val socket = ServerSocket()
        socket.reuseAddress = true
        socket.bind(InetSocketAddress(address, port), BACKLOG)
        server = socket
        pool.execute { acceptLoop(socket) }
    }

    fun stop() {
        runCatching { server?.close() }
        server = null
        registry.closeEverything()
        pool.shutdownNow()
    }

    private fun acceptLoop(socket: ServerSocket) {
        while (!socket.isClosed) {
            val client = try {
                socket.accept()
            } catch (e: IOException) {
                break
            }
            try {
                pool.execute { serve(client) }
            } catch (e: RejectedExecutionException) {
                runCatching { client.close() }
            }
        }
    }

    private fun serve(client: Socket) {
        val ip = client.inetAddress?.hostAddress
        if (ip == null) {
            runCatching { client.close() }
            return
        }
        try {
            client.soTimeout = HEAD_TIMEOUT_MS
            val input = BufferedInputStream(client.getInputStream())
            val output = client.getOutputStream()
            val request = HttpRequest.read(input) ?: return
            when {
                request.method == "CONNECT" -> connect(request, ip, client, input, output)
                // Le client a tapé l'adresse du proxy lui-même, sans le configurer.
                request.target.startsWith("/") ->
                    portal.respond(request, request.target, ip, proxied = false, input, output)
                else -> {
                    val target = Targets.parseAbsolute(request.target)
                    when {
                        target == null ->
                            Http.sendText(output, 400, "Bad Request", "Requête non prise en charge.")
                        portal.isPortalHost(target.hostPort.host, address.hostAddress.orEmpty()) ->
                            portal.respond(request, target.path, ip, proxied = true, input, output)
                        access.isAllowed(ip) -> forward(request, target, ip, client, input, output)
                        // Sans ticket, toute page web mène au portail.
                        else -> portal.respond(request, target.path, ip, proxied = true, input, output)
                    }
                }
            }
        } catch (e: IOException) {
            // Client parti, ou connexion coupée à l'expiration de son ticket.
        } finally {
            runCatching { client.close() }
        }
    }

    private fun connect(request: HttpRequest, ip: String, client: Socket, input: InputStream, output: OutputStream) {
        val target = Targets.parseAuthority(request.target, 443)
        if (target == null) {
            Http.sendText(output, 400, "Bad Request", "Cible invalide.")
            return
        }
        // Le portail n'existe qu'en http : on ne laisse jamais « https://hotzi.wifi » partir sur Internet.
        if (portal.isPortalHost(target.host, address.hostAddress.orEmpty())) {
            Http.sendText(output, 502, "Bad Gateway", "Ouvre http://${Portal.HOST}")
            return
        }
        if (!access.isAllowed(ip)) {
            logRefusal(ip, "${target.host}:${target.port}")
            Http.sendText(output, 403, "Forbidden", "Pas de ticket actif. Ouvre http://${Portal.HOST} pour entrer ton code.")
            return
        }
        access.touch(ip)
        val remote = openUpstream(target, output) ?: return
        output.write("HTTP/1.1 200 Connection Established\r\n\r\n".toByteArray(Charsets.ISO_8859_1))
        output.flush()
        relay(ip, client, input, remote)
    }

    private fun forward(
        request: HttpRequest,
        target: HttpTarget,
        ip: String,
        client: Socket,
        input: InputStream,
        output: OutputStream,
    ) {
        access.touch(ip)
        val remote = openUpstream(target.hostPort, output) ?: return
        val head = buildString {
            append(request.method).append(' ').append(target.path).append(' ').append(request.version).append("\r\n")
            var hasHost = false
            for ((name, value) in request.headers) {
                if (name.lowercase() in HOP_BY_HOP) continue
                if (name.equals("Host", ignoreCase = true)) hasHost = true
                append(name).append(": ").append(value).append("\r\n")
            }
            if (!hasHost) {
                append("Host: ").append(target.hostPort.host)
                if (target.hostPort.port != 80) append(':').append(target.hostPort.port)
                append("\r\n")
            }
            // Une requête par connexion : impossible de glisser une 2e requête vers un autre site.
            append("Connection: close\r\n\r\n")
        }
        try {
            remote.getOutputStream().apply {
                write(head.toByteArray(Charsets.ISO_8859_1))
                flush()
            }
        } catch (e: IOException) {
            runCatching { remote.close() }
            throw e
        }
        relay(ip, client, input, remote)
    }

    /** Copie dans les deux sens jusqu'à ce qu'un côté ferme, ou que le ticket expire. */
    private fun relay(ip: String, client: Socket, clientInput: InputStream, remote: Socket) {
        val trackedClient = registry.track(ip, client)
        val trackedRemote = registry.track(ip, remote)
        try {
            client.soTimeout = 0
            val toClient = pool.submit(Runnable {
                copy(remote.getInputStream(), client.getOutputStream())
                closeBoth(client, remote)
            })
            copy(clientInput, remote.getOutputStream())
            closeBoth(client, remote)
            runCatching { toClient.get() }
        } catch (e: RejectedExecutionException) {
            closeBoth(client, remote)
        } finally {
            trackedClient.close()
            trackedRemote.close()
        }
    }

    private fun openUpstream(target: HostPort, output: OutputStream): Socket? {
        val network = upstream()
        if (network == null) {
            Http.sendText(output, 503, "Service Unavailable", "Le téléphone Hotzi n'a pas Internet pour le moment.")
            return null
        }
        val addresses = try {
            network.getAllByName(target.host).filterNot(::isLocal)
        } catch (e: IOException) {
            Http.sendText(output, 502, "Bad Gateway", "Adresse introuvable : ${target.host}")
            return null
        }
        if (addresses.isEmpty()) {
            Http.sendText(output, 403, "Forbidden", "Destination interdite.")
            return null
        }
        for (candidate in addresses) {
            val socket = network.socketFactory.createSocket()
            try {
                socket.connect(InetSocketAddress(candidate, target.port), CONNECT_TIMEOUT_MS)
                socket.tcpNoDelay = true
                return socket
            } catch (e: IOException) {
                runCatching { socket.close() }
            }
        }
        Http.sendText(output, 502, "Bad Gateway", "Impossible de joindre ${target.host}.")
        return null
    }

    /** Interdit d'utiliser le proxy pour atteindre le téléphone hôte ou des réseaux privés. */
    private fun isLocal(candidate: InetAddress): Boolean =
        candidate.isLoopbackAddress || candidate.isAnyLocalAddress || candidate.isLinkLocalAddress ||
            candidate.isSiteLocalAddress || candidate.isMulticastAddress || candidate == address ||
            (candidate is Inet6Address && (candidate.address[0].toInt() and 0xfe) == 0xfc)

    private fun logRefusal(ip: String, destination: String) {
        val now = System.currentTimeMillis()
        val shouldLog = synchronized(lastRefusalLog) {
            val last = lastRefusalLog[ip]
            if (last == null || now - last > REFUSAL_LOG_INTERVAL_MS) {
                lastRefusalLog[ip] = now
                true
            } else {
                false
            }
        }
        if (shouldLog) log("Refusé : $ip → $destination (pas de ticket actif)")
    }

    private fun copy(from: InputStream, to: OutputStream) {
        val buffer = ByteArray(BUFFER_BYTES)
        try {
            while (true) {
                val n = from.read(buffer)
                if (n == -1) break
                to.write(buffer, 0, n)
            }
        } catch (e: IOException) {
            // Un côté a fermé.
        }
    }

    private fun closeBoth(a: Socket, b: Socket) {
        runCatching { a.close() }
        runCatching { b.close() }
    }

    private companion object {
        const val BACKLOG = 64
        const val HEAD_TIMEOUT_MS = 15_000
        const val CONNECT_TIMEOUT_MS = 15_000
        const val BUFFER_BYTES = 16 * 1024
        const val REFUSAL_LOG_INTERVAL_MS = 30_000L
        val HOP_BY_HOP = setOf(
            "connection", "proxy-connection", "keep-alive", "proxy-authorization",
            "proxy-authenticate", "te", "trailer", "upgrade",
        )
    }
}
