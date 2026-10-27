package com.hotzi.net

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

class PortalTest {
    private val portal = Portal(AccessController(InMemoryPersistence()), log = {})

    private fun get(path: String): String {
        val input = ByteArrayInputStream("GET http://hotzi$path HTTP/1.1\r\nHost: hotzi\r\n\r\n".toByteArray())
        val request = HttpRequest.read(input)!!
        val output = ByteArrayOutputStream()
        portal.respond(request, path, "192.168.49.10", proxied = true, input, output)
        return output.toString(Charsets.UTF_8.name())
    }

    @Test
    fun `le portail répond à http-hotzi, à l'ancienne adresse et à l'adresse du proxy`() {
        assertTrue(portal.isPortalHost("hotzi", "192.168.49.1"))
        assertTrue(portal.isPortalHost("hotzi.wifi", "192.168.49.1"))
        assertTrue(portal.isPortalHost("192.168.49.1", "192.168.49.1"))
        assertFalse(portal.isPortalHost("hotzi.com", "192.168.49.1"))
    }

    @Test
    fun `la page du portail propose de scanner le ticket`() {
        val page = get("/")
        assertTrue(page.startsWith("HTTP/1.1 200"))
        assertTrue(page.contains("Scanner mon ticket"))
        assertTrue(page.contains("capture=\"environment\""))
        assertTrue(page.contains("'http://hotzi/qr.js'"))
    }

    @Test
    fun `le lecteur de QR code est servi par le téléphone, sans Internet`() {
        val script = get("/qr.js")
        assertTrue(script.startsWith("HTTP/1.1 200"))
        assertTrue(script.contains("Content-Type: text/javascript"))
        assertTrue(script.contains("jsQR"))
    }
}
