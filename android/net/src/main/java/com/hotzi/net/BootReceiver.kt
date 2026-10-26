package com.hotzi.net

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Relance Hotzi après un redémarrage du téléphone, s'il tournait avant. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED && HotziEngine.shouldRun(context)) {
            HotziService.start(context)
        }
    }
}
