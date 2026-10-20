package com.tommychow.frosty

import android.content.Context
import android.net.ConnectivityManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The active network's cost, on the `frosty/network` channel: `isMetered`
 * answers true on mobile data (or a metered Wi-Fi), false on an unmetered
 * network, and null when Android cannot say.
 */
class NetworkBridge(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "frosty/network")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isMetered" -> result.success(isMetered())
                else -> result.notImplemented()
            }
        }
    }

    private fun isMetered(): Boolean? {
        val manager =
            context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return null
        return try {
            if (manager.activeNetwork == null) null else manager.isActiveNetworkMetered
        } catch (e: SecurityException) {
            null
        }
    }
}
