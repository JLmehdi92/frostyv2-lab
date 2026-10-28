package com.tommychow.frosty

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * The active network's cost, on the `frosty/network` channel: `isMetered`
 * answers true on mobile data (or a metered Wi-Fi), false on an unmetered
 * network, and null when Android cannot say.
 *
 * `frosty/network/metered` streams the same answer each time the network
 * changes (leaving Wi-Fi for mobile data), while someone listens: the
 * "Wi-Fi Only" previews stop at once instead of at the next check.
 */
class NetworkBridge(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "frosty/network")
    private val events = EventChannel(messenger, "frosty/network/metered")
    private val main = Handler(Looper.getMainLooper())
    private var callback: ConnectivityManager.NetworkCallback? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isMetered" -> result.success(isMetered())
                else -> result.notImplemented()
            }
        }
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                listen(sink)
            }

            override fun onCancel(arguments: Any?) {
                stopListening()
            }
        })
    }

    private fun manager(): ConnectivityManager? =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

    private fun isMetered(): Boolean? {
        val manager = manager() ?: return null
        return try {
            if (manager.activeNetwork == null) null else manager.isActiveNetworkMetered
        } catch (e: SecurityException) {
            null
        }
    }

    private fun listen(sink: EventChannel.EventSink) {
        stopListening()
        val manager = manager() ?: return
        // Callbacks come on a connectivity thread: answered on the main one.
        val next = object : ConnectivityManager.NetworkCallback() {
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                main.post { sink.success(isMetered()) }
            }

            override fun onLost(network: Network) {
                main.post { sink.success(isMetered()) }
            }
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                manager.registerDefaultNetworkCallback(next)
            } else {
                manager.registerNetworkCallback(NetworkRequest.Builder().build(), next)
            }
            callback = next
        } catch (e: RuntimeException) {
            // No updates (SecurityException, too many callbacks): the
            // previews keep the answer read when they started.
        }
    }

    private fun stopListening() {
        val current = callback ?: return
        callback = null
        try {
            manager()?.unregisterNetworkCallback(current)
        } catch (e: IllegalArgumentException) {
            // Already gone.
        }
    }

    /** Stops listening (the activity is going). */
    fun dispose() {
        stopListening()
        events.setStreamHandler(null)
        channel.setMethodCallHandler(null)
    }
}
