package com.hotzi.net

import com.hotzi.net.AccessController.Activation
import java.io.InputStream
import java.io.OutputStream
import java.net.URLDecoder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Pages du portail, servies par le proxy lui-même. Aucune ressource externe :
 * le client n'a pas encore Internet quand il les ouvre.
 */
class Portal(
    private val access: AccessController,
    private val log: (String) -> Unit,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    fun isPortalHost(host: String, proxyHost: String): Boolean =
        host == HOST || host == "hotzi" || host == proxyHost

    /**
     * @param proxied vrai si la requête est passée par le proxy, faux si le
     *   client a tapé directement l'adresse du proxy dans son navigateur.
     */
    fun respond(
        request: HttpRequest,
        path: String,
        ip: String,
        proxied: Boolean,
        input: InputStream,
        output: OutputStream,
    ) {
        val base = if (proxied) "http://$HOST" else ""
        when {
            request.method == "POST" && path.startsWith("/activer") ->
                activate(readForm(request, input)["code"].orEmpty(), ip, base, output)
            path.startsWith("/favicon") ->
                Http.send(output, 404, "Not Found", "text/plain; charset=utf-8", ByteArray(0))
            else -> Http.sendHtml(output, page(ip, base, message = null, typed = ""))
        }
    }

    private fun activate(code: String, ip: String, base: String, output: OutputStream) {
        val message = when (val result = access.activate(code, ip)) {
            is Activation.Granted -> {
                log("Ticket ${result.ticket.displayCode} activé pour $ip (fin à ${hour(result.ticket.expiresAt)})")
                null
            }
            is Activation.AlreadyConnected -> null
            Activation.Unknown -> {
                log("Code inconnu essayé par $ip")
                UNKNOWN
            }
            Activation.Expired -> EXPIRED
            Activation.InUse -> {
                log("Ticket ${TicketCodes.format(TicketCodes.normalize(code))} déjà utilisé : refusé pour $ip")
                IN_USE
            }
            Activation.Revoked -> REVOKED
            Activation.TooManyAttempts -> {
                log("Trop d'essais depuis $ip : saisie bloquée 2 minutes")
                TOO_MANY
            }
        }
        if (message == null) Http.redirect(output, "$base/")
        else Http.sendHtml(output, page(ip, base, message, code))
    }

    private fun page(ip: String, base: String, message: Pair<String, String>?, typed: String): String {
        val now = clock()
        access.activeTicketFor(ip)?.let { return connectedPage(it, now) }
        val shown = message ?: access.lastTicketFor(ip)?.let { last ->
            val recent = now - (last.expiresAt ?: 0L) < RECENT_MS
            when {
                last.status == TicketStatus.EXPIRED && recent -> FINISHED
                last.status == TicketStatus.REVOKED -> REVOKED
                else -> null
            }
        }
        return formPage(base, shown, typed)
    }

    private fun formPage(base: String, message: Pair<String, String>?, typed: String): String {
        val error = message?.let { (title, text) ->
            """<div class="err" role="alert"><strong>${escape(title)}</strong>${escape(text)}</div>"""
        }.orEmpty()
        val inputClass = if (message != null) """ class="bad"""" else ""
        return layout(
            kicker = "Dernière étape",
            title = "Entre le code de ton ticket",
            body = """
<form method="post" action="$base/activer">
<label for="code">Code du ticket</label>
<input id="code" name="code"$inputClass value="${escape(typed)}" autocomplete="off" autocapitalize="characters" spellcheck="false" maxlength="12" placeholder="Ex. : K7QM-4XPA" required>
<p class="hint">8 lettres et chiffres, imprimés sous le QR code.</p>
$error
<button type="submit">Me connecter</button>
</form>
<p class="foot">Pas de ticket ? Achète-le au vendeur.<br>Un ticket marche sur un seul téléphone.</p>
""",
        )
    }

    private fun connectedPage(ticket: Ticket, now: Long): String {
        val remaining = ticket.remainingMs(now) / 1000
        val total = (ticket.durationMs / 1000).coerceAtLeast(1)
        val percent = (100 * remaining / total).coerceIn(0, 100)
        return layout(
            kicker = "C'est bon",
            title = "Tu es connecté",
            body = """
<p class="muted">Il te reste</p>
<p class="big" id="t">${countdown(remaining)}</p>
<div class="bar"><div id="b" style="width:$percent%"></div></div>
<p class="muted">Fin à ${hour(ticket.expiresAt)} · ${escape(ticket.label)}</p>
<p>Tu peux fermer cette page. Internet continue.</p>
<p class="muted">Pour revoir ton temps, tape <strong>$HOST</strong> dans le navigateur.</p>
<script>
(function(){var s=$remaining,d=$total,t=document.getElementById('t'),b=document.getElementById('b');
function p(n){return(n<10?'0':'')+n}
function f(){if(s<=0){location.reload();return}
var h=Math.floor(s/3600),m=Math.floor(s%3600/60),x=s%60;
t.textContent=(h>0?h+':'+p(m):p(m))+':'+p(x);b.style.width=Math.max(0,100*s/d)+'%';s--;setTimeout(f,1000)}
f()})();
</script>
""",
        )
    }

    private fun layout(kicker: String, title: String, body: String) = """<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Wi-Fi Hotzi</title>
<style>$CSS</style></head>
<body>
<header class="top">
<div class="brand">$LOGO<span>Wi-Fi Hotzi</span></div>
<p class="kicker">${escape(kicker)}</p>
<h1>${escape(title)}</h1>
</header>
<main>$body</main>
</body></html>"""

    private fun readForm(request: HttpRequest, input: InputStream): Map<String, String> {
        val length = request.header("Content-Length")?.toIntOrNull() ?: return emptyMap()
        if (length !in 0..MAX_FORM_BYTES) return emptyMap()
        val body = ByteArray(length)
        var read = 0
        while (read < length) {
            val n = input.read(body, read, length - read)
            if (n == -1) break
            read += n
        }
        return String(body, 0, read, Charsets.UTF_8).split('&').mapNotNull { pair ->
            val eq = pair.indexOf('=')
            if (eq <= 0) null else decode(pair.substring(0, eq)) to decode(pair.substring(eq + 1))
        }.toMap()
    }

    private fun decode(value: String) = runCatching { URLDecoder.decode(value, "UTF-8") }.getOrDefault("")

    private fun hour(time: Long?): String =
        if (time == null) "?" else SimpleDateFormat("HH:mm", Locale.FRANCE).format(Date(time))

    private fun countdown(seconds: Long): String {
        val h = seconds / 3600
        val m = seconds % 3600 / 60
        val s = seconds % 60
        return if (h > 0) "%d:%02d:%02d".format(Locale.ROOT, h, m, s) else "%02d:%02d".format(Locale.ROOT, m, s)
    }

    private fun escape(text: String) = buildString {
        text.forEach { c ->
            when (c) {
                '<' -> append("&lt;")
                '>' -> append("&gt;")
                '&' -> append("&amp;")
                '"' -> append("&quot;")
                '\'' -> append("&#39;")
                else -> append(c)
            }
        }
    }

    companion object {
        const val HOST = "hotzi.wifi"
        private const val MAX_FORM_BYTES = 4096
        private const val RECENT_MS = 6 * 60 * 60_000L

        private val UNKNOWN = "Ce code ne marche pas" to "Vérifie chaque lettre et chaque chiffre. Sinon, demande au vendeur."
        private val EXPIRED = "Ce ticket est terminé" to "Son temps est fini. Achète un nouveau ticket au vendeur."
        private val IN_USE = "Ce ticket est déjà utilisé" to "Il marche déjà sur un autre téléphone. Un ticket = un téléphone."
        private val REVOKED = "Ce ticket a été annulé" to "Le vendeur l'a annulé. Va le voir pour en parler."
        private val TOO_MANY = "Trop d'essais" to "Attends 2 minutes, puis réessaie."
        private val FINISHED = "Ton temps est fini" to "Internet est coupé sur ce téléphone. Entre le code d'un nouveau ticket pour continuer."

        private const val LOGO = """<svg width="36" height="36" viewBox="0 0 100 100" fill="none" stroke-linecap="round" aria-hidden="true"><path d="M12 62a38 38 0 0 1 76 0" stroke="#fff" stroke-width="9"/><path d="M26 62a24 24 0 0 1 48 0" stroke="#fff" stroke-width="9"/><path d="M36 62a14 14 0 0 1 28 0z" fill="#FF8A3D"/><path d="M16 76h68" stroke="#fff" stroke-width="9"/></svg>"""

        private const val CSS = """
*{box-sizing:border-box}
body{margin:0;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:#fff;color:#1C1236;font-size:16px;line-height:1.45}
.top{background:#2D1A7A;color:#fff;padding:18px 20px 26px;border-radius:0 0 28px 28px}
.brand{display:flex;align-items:center;gap:10px;font-weight:800;font-size:20px}
.kicker{margin:18px 0 4px;color:#FFC93C;font-weight:700;font-size:14px}
h1{margin:0;font-size:28px;line-height:1.15}
main{padding:22px 20px 28px;max-width:480px;margin:0 auto}
label{display:block;font-weight:700;margin-bottom:8px}
input{width:100%;height:64px;border:2px solid #E6E0F5;border-radius:16px;background:#F6F3FF;padding:0 16px;font:700 24px ui-monospace,Menlo,monospace;letter-spacing:.08em;text-transform:uppercase;color:#1C1236}
input.bad{border-color:#B42318}
input:focus{outline:3px solid #5B2EE5;outline-offset:2px}
.hint{margin:8px 0 0;color:#5E5776;font-size:14px}
.err{margin-top:14px;background:#FDE7E4;color:#7A1A12;border-radius:14px;padding:12px 14px}
.err strong{display:block}
button{margin-top:18px;width:100%;height:60px;border:0;border-radius:18px;background:#FF8A3D;color:#1C1236;font:800 18px system-ui,sans-serif}
.foot{margin-top:22px;text-align:center;color:#5E5776;font-size:14px}
.big{font-size:56px;font-weight:800;margin:4px 0 12px;font-variant-numeric:tabular-nums}
.bar{height:10px;background:#EDE7FF;border-radius:999px;overflow:hidden}
.bar div{height:10px;background:#5B2EE5;border-radius:999px}
.muted{color:#5E5776}
"""
    }
}
