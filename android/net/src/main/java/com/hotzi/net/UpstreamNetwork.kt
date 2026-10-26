package com.hotzi.net

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest

/** Connexion Internet du téléphone hôte, celle que les clients utilisent à travers le proxy. */
class UpstreamNetwork(context: Context, private val onChange: () -> Unit) {
    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    private var callback: ConnectivityManager.NetworkCallback? = null

    @Volatile
    private var cellular: Network? = null

    fun start() {
        if (callback != null) return
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        val networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                cellular = network
                onChange()
            }

            override fun onLost(network: Network) {
                if (cellular == network) {
                    cellular = null
                    onChange()
                }
            }
        }
        connectivity.requestNetwork(request, networkCallback)
        callback = networkCallback
    }

    fun stop() {
        callback?.let { runCatching { connectivity.unregisterNetworkCallback(it) } }
        callback = null
        cellular = null
    }

    /** Les données mobiles d'abord ; sinon le réseau par défaut, pratique pour tester sans forfait. */
    fun current(): Network? = cellular ?: connectivity.activeNetwork

    fun describe(): String = when {
        cellular != null -> "données mobiles"
        connectivity.activeNetwork != null -> "autre réseau (pas les données mobiles)"
        else -> "aucune connexion Internet"
    }
}
