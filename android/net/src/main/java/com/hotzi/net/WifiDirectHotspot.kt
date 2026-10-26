package com.hotzi.net

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pGroup
import android.net.wifi.p2p.WifiP2pInfo
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.os.Looper
import android.os.Parcelable
import java.net.Inet4Address
import java.net.InetAddress
import java.net.NetworkInterface

/**
 * Le Wi-Fi Hotzi : un groupe Wi-Fi Direct dont le téléphone est propriétaire.
 * Les clients s'y connectent comme à un Wi-Fi ordinaire, mais ce réseau n'a
 * aucune route vers Internet : seul le proxy en a une.
 *
 * À appeler depuis le thread principal.
 */
class WifiDirectHotspot(private val context: Context, private val listener: Listener) {

    data class Group(
        val networkName: String,
        val passphrase: String,
        val ownerAddress: InetAddress,
        val clientCount: Int,
    )

    interface Listener {
        fun onGroupUp(group: Group)
        fun onGroupDown()
        fun onError(message: String)
    }

    private val manager: WifiP2pManager? = context.getSystemService(WifiP2pManager::class.java)
    private var channel: WifiP2pManager.Channel? = null
    private var registered = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION -> {
                    val state = intent.getIntExtra(WifiP2pManager.EXTRA_WIFI_STATE, -1)
                    if (state == WifiP2pManager.WIFI_P2P_STATE_DISABLED) {
                        listener.onError("Le Wi-Fi est éteint. Allume-le, sans te connecter à un réseau.")
                    }
                }
                WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> onConnectionChanged(intent)
            }
        }
    }

    @SuppressLint("MissingPermission") // L'app vérifie les autorisations avant de démarrer.
    fun start(networkName: String, passphrase: String) {
        val manager = manager ?: return listener.onError("Ce téléphone ne permet pas le Wi-Fi Direct.")
        val channel = channel ?: manager.initialize(context, Looper.getMainLooper()) {
            this.channel = null
            listener.onGroupDown()
        }.also { this.channel = it }
        registerReceiver()

        val config = try {
            WifiP2pConfig.Builder()
                .setNetworkName(networkName)
                .setPassphrase(passphrase)
                .setGroupOperatingBand(WifiP2pConfig.GROUP_OWNER_BAND_2GHZ)
                .enablePersistentMode(false)
                .build()
        } catch (e: IllegalArgumentException) {
            return listener.onError("Nom ou mot de passe du Wi-Fi invalide : ${e.message}")
        }

        // Un ancien groupe resté ouvert ferait échouer la création : on le retire d'abord.
        manager.removeGroup(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() = create(manager, channel, config)
            override fun onFailure(reason: Int) = create(manager, channel, config)
        })
    }

    fun stop() {
        channel?.let { manager?.removeGroup(it, null) }
        if (registered) {
            runCatching { context.unregisterReceiver(receiver) }
            registered = false
        }
        channel?.close()
        channel = null
    }

    @SuppressLint("MissingPermission")
    private fun create(manager: WifiP2pManager, channel: WifiP2pManager.Channel, config: WifiP2pConfig) {
        manager.createGroup(channel, config, object : WifiP2pManager.ActionListener {
            // Le groupe est annoncé ensuite par WIFI_P2P_CONNECTION_CHANGED_ACTION.
            override fun onSuccess() = Unit

            override fun onFailure(reason: Int) =
                listener.onError("Impossible de créer le Wi-Fi Hotzi (${reasonText(reason)}).")
        })
    }

    private fun onConnectionChanged(intent: Intent) {
        val info = intent.parcelable<WifiP2pInfo>(WifiP2pManager.EXTRA_WIFI_P2P_INFO)
        val group = intent.parcelable<WifiP2pGroup>(WifiP2pManager.EXTRA_WIFI_P2P_GROUP)
        if (info?.groupFormed != true || !info.isGroupOwner || group == null) {
            listener.onGroupDown()
            return
        }
        val address = info.groupOwnerAddress ?: ipv4Of(group.`interface`)
        if (address == null) {
            listener.onError("Adresse du Wi-Fi Hotzi introuvable.")
            return
        }
        listener.onGroupUp(Group(group.networkName, group.passphrase.orEmpty(), address, group.clientList.size))
    }

    private fun registerReceiver() {
        if (registered) return
        val filter = IntentFilter().apply {
            addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
        registered = true
    }

    private fun ipv4Of(interfaceName: String?): InetAddress? {
        val nic = interfaceName?.let { runCatching { NetworkInterface.getByName(it) }.getOrNull() } ?: return null
        return nic.inetAddresses.toList().firstOrNull { it is Inet4Address }
    }

    private fun reasonText(reason: Int) = when (reason) {
        WifiP2pManager.P2P_UNSUPPORTED -> "Wi-Fi Direct non pris en charge"
        WifiP2pManager.BUSY -> "Wi-Fi occupé, nouvel essai bientôt"
        WifiP2pManager.ERROR -> "erreur interne d'Android"
        else -> "code $reason"
    }

    private inline fun <reified T : Parcelable> Intent.parcelable(key: String): T? =
        if (Build.VERSION.SDK_INT >= 33) {
            getParcelableExtra(key, T::class.java)
        } else {
            @Suppress("DEPRECATION")
            getParcelableExtra(key)
        }
}
