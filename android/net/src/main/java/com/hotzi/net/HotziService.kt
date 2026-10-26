package com.hotzi.net

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/** Garde Hotzi en vie écran éteint : service au premier plan, verrous Wi-Fi et processeur. */
class HotziService : Service() {
    private lateinit var engine: HotziEngine
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var shownText = ""
    private val refresh: () -> Unit = { showState() }

    override fun onCreate() {
        super.onCreate()
        engine = HotziEngine.get(this)
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Wi-Fi Hotzi", NotificationManager.IMPORTANCE_LOW)
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            engine.stop(forget = true)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        shownText = text()
        startForeground(NOTIFICATION_ID, notification(shownText), ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        acquireLocks()
        engine.addListener(refresh)
        engine.start()
        return START_STICKY
    }

    override fun onDestroy() {
        engine.removeListener(refresh)
        engine.stop(forget = false)
        wakeLock?.release()
        wifiLock?.release()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun showState() {
        val text = text()
        if (text == shownText) return
        shownText = text
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification(text))
    }

    private fun text(): String {
        val state = engine.state
        return when {
            state.controlActive -> "Wi-Fi allumé · ${state.group?.clientCount ?: 0} appareil(s) · tickets protégés"
            state.running && state.error != null -> "Attention : ${state.error}"
            state.running -> "Démarrage du Wi-Fi Hotzi…"
            else -> "Wi-Fi Hotzi arrêté"
        }
    }

    private fun notification(text: String): Notification {
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }
        val stop = PendingIntent.getService(
            this, 1, Intent(this, HotziService::class.java).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.hotzi_ic_stat)
            .setContentTitle("Hotzi")
            .setContentText(text)
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, "Arrêter", stop).build())
            .build()
    }

    private fun acquireLocks() {
        if (wakeLock == null) {
            wakeLock = getSystemService(PowerManager::class.java)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "hotzi:reseau")
                .apply { setReferenceCounted(false); acquire() }
        }
        if (wifiLock == null) {
            val mode = if (Build.VERSION.SDK_INT >= 34) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                @Suppress("DEPRECATION")
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }
            wifiLock = applicationContext.getSystemService(WifiManager::class.java)
                .createWifiLock(mode, "hotzi:reseau")
                .apply { setReferenceCounted(false); acquire() }
        }
    }

    companion object {
        private const val CHANNEL_ID = "hotzi_reseau"
        private const val NOTIFICATION_ID = 1
        private const val ACTION_STOP = "com.hotzi.net.STOP"

        fun start(context: Context) {
            context.startForegroundService(Intent(context, HotziService::class.java))
        }

        fun stop(context: Context) {
            context.startService(Intent(context, HotziService::class.java).setAction(ACTION_STOP))
        }
    }
}
