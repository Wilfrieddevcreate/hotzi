package com.hotzi.net

import java.io.OutputStream

/** Réponses HTTP courtes ; la connexion est toujours fermée après. */
internal object Http {

    fun send(
        output: OutputStream,
        code: Int,
        reason: String,
        contentType: String,
        body: ByteArray,
        extraHeaders: List<String> = emptyList(),
    ) {
        val head = buildString {
            append("HTTP/1.1 ").append(code).append(' ').append(reason).append("\r\n")
            append("Content-Type: ").append(contentType).append("\r\n")
            append("Content-Length: ").append(body.size).append("\r\n")
            append("Cache-Control: no-store\r\n")
            append("Connection: close\r\n")
            extraHeaders.forEach { append(it).append("\r\n") }
            append("\r\n")
        }
        output.write(head.toByteArray(Charsets.ISO_8859_1))
        output.write(body)
        output.flush()
    }

    fun sendHtml(output: OutputStream, html: String) =
        send(output, 200, "OK", "text/html; charset=utf-8", html.toByteArray(Charsets.UTF_8))

    fun sendText(output: OutputStream, code: Int, reason: String, text: String) =
        send(output, code, reason, "text/plain; charset=utf-8", text.toByteArray(Charsets.UTF_8))

    fun redirect(output: OutputStream, location: String) =
        send(output, 303, "See Other", "text/plain; charset=utf-8", ByteArray(0), listOf("Location: $location"))
}
