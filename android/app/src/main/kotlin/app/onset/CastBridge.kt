package app.onset

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.SessionProvider
import com.google.android.gms.common.images.WebImage
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

private const val CAST_TAG = "OnsetCast"

class CastOptionsProvider : OptionsProvider {
    override fun getCastOptions(context: Context): CastOptions =
        CastOptions.Builder()
            .setReceiverApplicationId(CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID)
            .setStopReceiverApplicationWhenEndingSession(true)
            .build()

    override fun getAdditionalSessionProviders(context: Context): List<SessionProvider>? = null
}

class CastBridge(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "onset/cast")
    private val selector = MediaRouteSelector.Builder()
        .addControlCategory(
            CastMediaControlIntent.categoryForCast(
                CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID,
            ),
        )
        .build()
    private val castExecutor by lazy { Executors.newSingleThreadExecutor() }
    private var castContext: CastContext? = null
    private var unavailable = false
    private var discovering = false
    private var connecting = false

    private val routerCallback = object : MediaRouter.Callback() {
        override fun onRouteAdded(router: MediaRouter, route: MediaRouter.RouteInfo) = sendDevices()

        override fun onRouteRemoved(router: MediaRouter, route: MediaRouter.RouteInfo) = sendDevices()

        override fun onRouteChanged(router: MediaRouter, route: MediaRouter.RouteInfo) = sendDevices()
    }

    private val sessionListener = object : SessionManagerListener<CastSession> {
        override fun onSessionStarting(session: CastSession) = setConnecting(true)

        override fun onSessionStarted(session: CastSession, sessionId: String) = setConnecting(false)

        override fun onSessionStartFailed(session: CastSession, error: Int) = setConnecting(false)

        override fun onSessionEnding(session: CastSession) = sendState()

        override fun onSessionEnded(session: CastSession, error: Int) = setConnecting(false)

        override fun onSessionResuming(session: CastSession, sessionId: String) = setConnecting(true)

        override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) = setConnecting(false)

        override fun onSessionResumeFailed(session: CastSession, error: Int) = setConnecting(false)

        override fun onSessionSuspended(session: CastSession, reason: Int) = sendState()
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> withCastContext { available ->
                    if (available) startDiscovery()
                    result.success(available)
                }
                "stop" -> {
                    stopDiscovery()
                    result.success(null)
                }
                "state" -> result.success(stateMap())
                "connect" -> {
                    val id = call.argument<String>("id")
                    val route = router().routes.firstOrNull { it.id == id && isCastRoute(it) }
                    if (route == null) {
                        result.success(false)
                    } else {
                        setConnecting(true)
                        route.select()
                        result.success(true)
                    }
                }
                "disconnect" -> {
                    castContext?.sessionManager?.endCurrentSession(true)
                    connecting = false
                    sendState()
                    result.success(null)
                }
                "load" -> result.success(load(call.arguments as? Map<*, *>))
                else -> result.notImplemented()
            }
        }
    }

    private fun router(): MediaRouter = MediaRouter.getInstance(context)

    private fun withCastContext(then: (Boolean) -> Unit) {
        castContext?.let { return then(true) }
        if (unavailable) return then(false)
        try {
            CastContext.getSharedInstance(context, castExecutor)
                .addOnSuccessListener { shared ->
                    castContext = shared
                    shared.sessionManager.addSessionManagerListener(
                        sessionListener,
                        CastSession::class.java,
                    )
                    then(true)
                }
                .addOnFailureListener {
                    Log.w(CAST_TAG, "cast unavailable: ${it.message}")
                    unavailable = true
                    then(false)
                }
        } catch (t: Throwable) {
            Log.w(CAST_TAG, "cast unavailable: ${t.message}")
            unavailable = true
            then(false)
        }
    }

    private fun startDiscovery() {
        if (!discovering) {
            discovering = true
            router().addCallback(
                selector,
                routerCallback,
                MediaRouter.CALLBACK_FLAG_PERFORM_ACTIVE_SCAN,
            )
        }
        sendDevices()
        sendState()
    }

    private fun stopDiscovery() {
        if (!discovering) return
        discovering = false
        router().removeCallback(routerCallback)
    }

    private fun isCastRoute(route: MediaRouter.RouteInfo): Boolean =
        !route.isDefault && route.isEnabled && route.matchesSelector(selector)

    private fun sendDevices() {
        val devices = router().routes.filter { isCastRoute(it) }.map {
            mapOf("id" to it.id, "name" to it.name)
        }
        send("devices", devices)
    }

    private fun setConnecting(value: Boolean) {
        connecting = value
        sendState()
    }

    private fun currentSession(): CastSession? = castContext?.sessionManager?.currentCastSession

    private fun stateMap(): Map<String, Any?> {
        val session = currentSession()
        val state = when {
            session?.isConnected == true -> "connected"
            connecting || session?.isConnecting == true -> "connecting"
            else -> "disconnected"
        }
        val routeId = router().selectedRoute.takeIf { isCastRoute(it) }?.id
        return mapOf(
            "state" to state,
            "device" to session?.castDevice?.friendlyName,
            "deviceId" to routeId,
        )
    }

    private fun sendState() = send("state", stateMap())

    private fun load(args: Map<*, *>?): Boolean {
        val url = args?.get("url") as? String ?: return false
        val client = currentSession()?.remoteMediaClient ?: return false
        val live = args["live"] as? Boolean ?: true
        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE).apply {
            (args["title"] as? String)?.let { putString(MediaMetadata.KEY_TITLE, it) }
            (args["subtitle"] as? String)?.let { putString(MediaMetadata.KEY_SUBTITLE, it) }
            (args["imageUrl"] as? String)?.let { addImage(WebImage(Uri.parse(it))) }
        }
        val info = MediaInfo.Builder(url)
            .setContentType("application/x-mpegURL")
            .setStreamType(if (live) MediaInfo.STREAM_TYPE_LIVE else MediaInfo.STREAM_TYPE_BUFFERED)
            .setMetadata(metadata)
            .build()
        val request = MediaLoadRequestData.Builder()
            .setMediaInfo(info)
            .setAutoplay(true)
            .setCurrentTime((args["startMs"] as? Number)?.toLong() ?: 0L)
            .build()
        return try {
            client.load(request)
            true
        } catch (t: Throwable) {
            Log.w(CAST_TAG, "load failed: ${t.message}")
            false
        }
    }

    private fun send(method: String, arguments: Any?) {
        try {
            channel.invokeMethod(method, arguments)
        } catch (_: Throwable) {
        }
    }

    fun dispose() {
        stopDiscovery()
        castContext?.sessionManager?.removeSessionManagerListener(
            sessionListener,
            CastSession::class.java,
        )
        channel.setMethodCallHandler(null)
        castExecutor.shutdown()
    }
}
