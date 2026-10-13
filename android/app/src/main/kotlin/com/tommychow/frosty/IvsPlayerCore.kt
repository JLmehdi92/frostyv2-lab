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
    private var statsEnabled = false

    fun start(url: String, tuning: IvsTuning = IvsTuning()) {
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
                "setStatsEnabled" -> {
                    statsEnabled = call.argument<Boolean>("enabled") == true
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
                val errorType = runCatching { e.errorType.name }.getOrNull()
                val source = runCatching { e.source }.getOrNull()
                Log.e(CORE_TAG, "onError type=$errorType code=${e.code} source=$source msg=${e.errorMessage}")
                send(
                    mapOf(
                        "type" to "error",
                        "code" to e.code,
                        "msg" to e.errorMessage,
                        "errorType" to errorType,
                        "source" to source,
                    ),
                )
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

        tuning.applyTo(player)

        // The player can be created before the usher URL is known; Dart then
        // sends it with "load" as soon as it resolves.
        if (url.isNotEmpty()) player.load(Uri.parse(url))
        startLatencyTicker()
    }

    private fun startLatencyTicker() {
        latencyTicker = object : Runnable {
            override fun run() {
                // Reschedule first so a failing getter can never stop the
                // latency ticker (dispose() removes it on this same thread).
                main.postDelayed(this, 1000)
                try { send(mapOf("type" to "latency", "ms" to player.liveLatency)) } catch (_: Throwable) {}
                if (statsEnabled) {
                    try { send(collectStats()) } catch (t: Throwable) { Log.w(CORE_TAG, "stats failed: $t") }
                }
            }
        }
        main.postDelayed(latencyTicker!!, 1000)
    }

    /**
     * Snapshot of the player statistics for the Dart stats panel. Every getter
     * is guarded so a value the SDK cannot provide is sent as null instead of
     * breaking the ticker.
     */
    private fun collectStats(): Map<String, Any?> {
        val stats = runCatching { player.statistics }.getOrNull()
        val quality = runCatching { player.quality }.getOrNull()
        val position = runCatching { player.position }.getOrNull()
        val buffered = runCatching { player.bufferedPosition }.getOrNull()
        return mapOf(
            "type" to "stats",
            "bitrate" to stats?.videoBitRate,
            "fps" to stats?.frameRate,
            "dropped" to stats?.droppedFrames,
            "decoded" to stats?.decodedFrames,
            "rendered" to stats?.renderedFrames,
            "bufferedMs" to if (position != null && buffered != null) {
                (buffered - position).coerceAtLeast(0L)
            } else {
                null
            },
            "lowLatency" to runCatching { player.isLiveLowLatency }.getOrNull(),
            "playbackRate" to runCatching { player.playbackRate.toDouble() }.getOrNull(),
            "bandwidth" to runCatching { player.bandwidthEstimate }.getOrNull(),
            "quality" to quality?.let {
                mapOf(
                    "name" to it.name,
                    "width" to it.width,
                    "height" to it.height,
                    "codecs" to it.codecs,
                    "framerate" to it.framerate.toDouble(),
                    "bitrate" to it.bitrate,
                )
            },
        )
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
