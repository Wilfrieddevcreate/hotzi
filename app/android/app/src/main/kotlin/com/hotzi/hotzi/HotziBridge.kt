package com.hotzi.hotzi

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import com.hotzi.net.HotziDatabase
import com.hotzi.net.HotziEngine
import com.hotzi.net.HotziPermissions
import com.hotzi.net.HotziService
import com.hotzi.net.Ticket
import com.hotzi.net.WifiCredentials
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Pont entre l'app Flutter et la bibliothèque réseau :
 * - « hotzi/data » : forfaits, tickets, ventes, réglages, code secret (la base est côté Kotlin) ;
 * - « hotzi/network » : allumer, éteindre, nom du Wi-Fi, annuler un ticket, autorisations ;
 * - « hotzi/network/state » : l'état du Wi-Fi, envoyé à chaque changement.
 *
 * Les clés des données sont celles des colonnes de la base, comme côté Dart.
 */
class HotziBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val engine = HotziEngine.get(activity)
    private val database = engine.database
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var pendingPermissions: MethodChannel.Result? = null
    private val pushState: () -> Unit = { sink?.success(state()) }

    init {
        MethodChannel(messenger, "hotzi/data").setMethodCallHandler(::onData)
        MethodChannel(messenger, "hotzi/network").setMethodCallHandler(::onNetwork)
        EventChannel(messenger, "hotzi/network/state").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                sink = events
                engine.addListener(pushState)
                events.success(state())
            }

            override fun onCancel(arguments: Any?) {
                engine.removeListener(pushState)
                sink = null
            }
        })
    }

    fun dispose() {
        engine.removeListener(pushState)
        sink = null
        io.shutdown()
    }

    fun onPermissionsResult(requestCode: Int) {
        if (requestCode != REQUEST_PERMISSIONS) return
        pendingPermissions?.success(HotziPermissions.missing(activity, includeOptional = false).isEmpty())
        pendingPermissions = null
    }

    /** Les lectures et écritures de la base se font hors du fil de l'interface. */
    private fun onData(call: MethodCall, result: MethodChannel.Result) {
        io.execute {
            val reply = runCatching {
                when (call.method) {
                    "plans" -> database.plans().map(::planMap)
                    "savePlan" -> planMap(database.savePlan(plan(call.arguments as Map<*, *>)))
                    "tickets" -> database.tickets().map(::ticketMap)
                    "sales" -> database.sales().map(::saleMap)
                    "sell" -> engine.sell(
                        planId = call.long("plan_id"),
                        quantity = call.long("quantity").toInt(),
                        payment = call.argument<String>("payment")!!,
                        at = call.long("at"),
                    ).map(::ticketMap)
                    "setting" -> database.setting(call.argument<String>("key")!!)
                    "saveSetting" -> database.saveSetting(call.argument("key")!!, call.argument("value")!!).let { null }
                    "hasPin" -> database.hasPin()
                    "savePin" -> database.savePin(call.argument("pin")!!).let { null }
                    "checkPin" -> database.checkPin(call.argument("pin")!!)
                    else -> NOT_IMPLEMENTED
                }
            }
            main.post {
                reply.fold(
                    onSuccess = { if (it === NOT_IMPLEMENTED) result.notImplemented() else result.success(it) },
                    onFailure = { result.error("hotzi", it.message, null) },
                )
            }
        }
    }

    @SuppressLint("BatteryLife") // App installée directement chez le vendeur ; le réglage évite que le Wi-Fi soit coupé.
    private fun onNetwork(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                HotziService.start(activity)
                result.success(null)
            }
            "stop" -> {
                HotziService.stop(activity)
                result.success(null)
            }
            "revoke" -> {
                engine.revoke(call.argument<String>("code")!!)
                result.success(null)
            }
            "changeWifi" -> try {
                engine.changeWifi(WifiCredentials(call.argument("name")!!, call.argument("passphrase")!!))
                result.success(null)
            } catch (e: IllegalArgumentException) {
                result.error("hotzi", e.message, null)
            }
            "hasPermissions" -> result.success(HotziPermissions.missing(activity, includeOptional = false).isEmpty())
            "requestPermissions" -> {
                val missing = HotziPermissions.missing(activity, includeOptional = true)
                if (missing.isEmpty()) {
                    result.success(true)
                } else {
                    pendingPermissions?.success(false)
                    pendingPermissions = result
                    activity.requestPermissions(missing.toTypedArray(), REQUEST_PERMISSIONS)
                }
            }
            "wifiEnabled" -> result.success(activity.applicationContext.getSystemService(WifiManager::class.java).isWifiEnabled)
            "openWifiSettings" -> {
                activity.startActivity(Intent(Settings.Panel.ACTION_WIFI))
                result.success(null)
            }
            "batteryExempt" -> result.success(
                activity.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(activity.packageName)
            )
            "askBatteryExemption" -> {
                activity.startActivity(
                    Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${activity.packageName}"))
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun state(): Map<String, Any?> {
        val state = engine.state
        return mapOf(
            "running" to state.running,
            "runningSince" to state.runningSince,
            "controlActive" to state.controlActive,
            "networkName" to (state.group?.networkName ?: engine.credentials.name),
            "passphrase" to (state.group?.passphrase?.ifEmpty { null } ?: engine.credentials.passphrase),
            "proxyHost" to state.group?.ownerAddress?.hostAddress,
            "proxyPort" to HotziEngine.PROXY_PORT,
            "upstream" to state.upstream,
            "upstreamAvailable" to state.upstreamAvailable,
            "error" to state.error,
            "ticketsVersion" to engine.ticketsVersion,
            "sessions" to engine.sessions().map {
                mapOf(
                    "code" to it.code,
                    "planName" to it.label,
                    "clientIp" to it.clientIp,
                    "remainingMs" to it.remainingMs,
                    "connections" to it.connections,
                )
            },
        )
    }

    private fun planMap(plan: HotziDatabase.Plan) = mapOf(
        "id" to plan.id,
        "name" to plan.name,
        "duration_minutes" to plan.durationMinutes,
        "price_fcfa" to plan.priceFcfa,
        "active" to if (plan.active) 1 else 0,
        "description" to plan.description,
        "created_at" to plan.createdAt,
    )

    private fun plan(row: Map<*, *>) = HotziDatabase.Plan(
        id = (row["id"] as Number?)?.toLong(),
        name = row["name"] as String,
        durationMinutes = (row["duration_minutes"] as Number).toInt(),
        priceFcfa = (row["price_fcfa"] as Number).toInt(),
        active = (row["active"] as Number).toInt() == 1,
        description = row["description"] as String? ?: "",
        createdAt = (row["created_at"] as Number).toLong(),
    )

    private fun ticketMap(ticket: Ticket) = mapOf(
        "id" to ticket.id,
        "code" to ticket.code,
        "plan_id" to ticket.planId,
        "plan_name" to ticket.label,
        "duration_minutes" to ticket.durationMs / 60_000L,
        "price_fcfa" to ticket.priceFcfa,
        "status" to ticket.status.name.lowercase(),
        "created_at" to ticket.createdAt,
        "activated_at" to ticket.activatedAt,
        "expires_at" to ticket.expiresAt,
        "client_id" to ticket.clientIp,
    )

    private fun saleMap(sale: HotziDatabase.Sale) = mapOf(
        "id" to sale.id,
        "ticket_id" to sale.ticketId,
        "sold_at" to sale.soldAt,
        "amount_fcfa" to sale.amountFcfa,
        "payment_method" to sale.payment,
    )

    private fun MethodCall.long(key: String): Long = (argument<Any>(key) as Number).toLong()

    private companion object {
        const val REQUEST_PERMISSIONS = 42
        val NOT_IMPLEMENTED = Any()
    }
}
