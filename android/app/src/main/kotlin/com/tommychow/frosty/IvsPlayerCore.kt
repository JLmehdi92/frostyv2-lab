package com.tommychow.frosty

import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.amazonaws.ivs.player.Cue
import com.amazonaws.ivs.player.Player
import com.amazonaws.ivs.player.PlayerException
import com.amazonaws.ivs.player.Quality
import io.flutter.plugin.common.MethodChannel

private const val CORE_TAG = "FrostyIVS"

/**
 * Shared Amazon IVS control/event wiring used by both the full-screen
 * SurfaceView player ([IvsPlayerView]) and the texture-backed mini player
 * ([IvsTexturePlayer]).
 *
 * Given an IVS [Player] and a per-instance [MethodChannel], it bridges
 * play/pause/quality/load from Dart, forwards player events back, and ticks
 * the live latency once per second. [onVideoSize] lets a texture target resize
 * its buffer to the source resolution.
 */
class IvsPlayerCore(
    private val player: Player,
    private val channel: MethodChannel,
    private val onVideoSize: ((Int, Int) -> Unit)? = null,
) {
    private val main = Handler(Looper.getMainLooper())
    private var latencyTicker: Runnable? = null
    private var qualitiesSent = false

    fun start(url: String) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> { player.play(); result.success(null) }
                "pause" -> { player.pause(); result.success(null) }
                "setAutoQuality" -> { player.setAutoQualityMode(true); result.success(null) }
                "setQuality" -> {
                    val name = call.argument<String>("name")
                    val q = player.qualities.firstOrNull { it.name == name }
                    if (q != null) player.setQuality(q, true)
                    result.success(null)
                }
                "load" -> {
                    val newUrl = call.argument<String>("url")
                    qualitiesSent = false
                    if (newUrl != null) player.load(Uri.parse(newUrl))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        player.addListener(object : Player.Listener() {
            override fun onStateChanged(state: Player.State) {
                send(mapOf("type" to "state", "state" to state.name))
                if (state == Player.State.READY) player.play()
                if (state == Player.State.PLAYING && !qualitiesSent) {
                    qualitiesSent = true
                    send(mapOf("type" to "qualities", "list" to player.qualities.map { it.name }))
                }
            }

            override fun onError(e: PlayerException) {
                Log.e(CORE_TAG, "onError code=${e.code} msg=${e.errorMessage}")
                send(mapOf("type" to "error", "code" to e.code, "msg" to e.errorMessage))
            }

            override fun onRebuffering() { send(mapOf("type" to "rebuffering")) }
            override fun onQualityChanged(quality: Quality) {
                send(mapOf("type" to "quality", "name" to quality.name))
            }
            override fun onVideoSizeChanged(w: Int, h: Int) { onVideoSize?.invoke(w, h) }
            override fun onCue(cue: Cue) {}
            override fun onDurationChanged(duration: Long) {}
            override fun onSeekCompleted(position: Long) {}
        })

        try {
            player.setLiveLowLatencyEnabled(true)
            player.setRebufferToLive(true)
        } catch (t: Throwable) {
            Log.w(CORE_TAG, "low-latency config failed: $t")
        }

        player.load(Uri.parse(url))
        startLatencyTicker()
    }

    private fun startLatencyTicker() {
        latencyTicker = object : Runnable {
            override fun run() {
                try { send(mapOf("type" to "latency", "ms" to player.liveLatency)) } catch (_: Throwable) {}
                main.postDelayed(this, 1000)
            }
        }
        main.postDelayed(latencyTicker!!, 1000)
    }

    private fun send(data: Map<String, Any?>) {
        main.post {
            try { channel.invokeMethod("onEvent", data) } catch (_: Throwable) {}
        }
    }

    fun dispose() {
        latencyTicker?.let { main.removeCallbacks(it) }
        channel.setMethodCallHandler(null)
        player.release()
    }
}
