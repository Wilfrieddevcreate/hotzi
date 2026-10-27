package com.hotzi.net

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

/** Autorisations à demander avant d'allumer le Wi-Fi Hotzi. */
object HotziPermissions {

    /**
     * Jusqu'à Android 12, le Wi-Fi Direct exige la localisation précise ; ensuite,
     * « appareils à proximité ». Les notifications sont facultatives : sans elles,
     * Hotzi marche mais le vendeur ne voit pas son état dans la barre du haut.
     */
    fun missing(context: Context, includeOptional: Boolean): List<String> {
        val needed = buildList {
            if (Build.VERSION.SDK_INT >= 33) {
                add(Manifest.permission.NEARBY_WIFI_DEVICES)
                if (includeOptional) add(Manifest.permission.POST_NOTIFICATIONS)
            } else {
                add(Manifest.permission.ACCESS_COARSE_LOCATION)
                add(Manifest.permission.ACCESS_FINE_LOCATION)
            }
        }
        return needed.filter { context.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
    }
}
