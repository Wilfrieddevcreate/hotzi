package com.hotzi.net

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.IOException

class ParsingTest {

    private fun read(raw: String) = HttpRequest.read(ByteArrayInputStream(raw.toByteArray(Charsets.ISO_8859_1)))

    @Test
    fun `lit une requête CONNECT`() {
        val request = read("CONNECT www.google.com:443 HTTP/1.1\r\nHost: www.google.com:443\r\n\r\n")!!
        assertEquals("CONNECT", request.method)
        assertEquals("www.google.com:443", request.target)
        assertEquals("www.google.com:443", request.header("host"))
    }

    @Test
    fun `laisse le corps dans le flux`() {
        val input = ByteArrayInputStream("POST /activer HTTP/1.1\r\nContent-Length: 4\r\n\r\ncode".toByteArray())
        val request = HttpRequest.read(input)!!
        assertEquals("4", request.header("Content-Length"))
        assertEquals("code", String(input.readBytes()))
    }

    @Test
    fun `renvoie null si le client ferme sans rien envoyer`() {
        assertNull(read(""))
    }

    @Test(expected = IOException::class)
    fun `refuse des en-têtes trop longs`() {
        read("GET / HTTP/1.1\r\nX: " + "a".repeat(HttpRequest.MAX_HEAD_BYTES) + "\r\n\r\n")
    }

    @Test
    fun `découpe une URL de proxy`() {
        val target = Targets.parseAbsolute("http://Exemple.com:8080/a/b?c=1")!!
        assertEquals(HostPort("exemple.com", 8080), target.hostPort)
        assertEquals("/a/b?c=1", target.path)
        assertEquals("/", Targets.parseAbsolute("http://hotzi.wifi")!!.path)
        assertNull(Targets.parseAbsolute("https://exemple.com/"))
    }

    @Test
    fun `lit les cibles CONNECT, IPv6 compris`() {
        assertEquals(HostPort("exemple.com", 443), Targets.parseAuthority("exemple.com", 443))
        assertEquals(HostPort("2001:db8::1", 8443), Targets.parseAuthority("[2001:db8::1]:8443", 443))
        assertNull(Targets.parseAuthority("exemple.com:99999", 443))
        assertNull(Targets.parseAuthority("exemple.com:abc", 443))
    }

    @Test
    fun `les codes générés n'ont pas de caractères ambigus`() {
        repeat(200) {
            val code = TicketCodes.generate()
            assertEquals(TicketCodes.LENGTH, code.length)
            assertTrue(code.all { it in TicketCodes.ALPHABET })
            assertTrue(code.none { it in "01OI" })
        }
    }

    @Test
    fun `normalise et met en forme les codes`() {
        assertEquals("K7QM4XPA", TicketCodes.normalize(" k7qm-4xpa "))
        assertEquals("K7QM-4XPA", TicketCodes.format("K7QM4XPA"))
    }
}
