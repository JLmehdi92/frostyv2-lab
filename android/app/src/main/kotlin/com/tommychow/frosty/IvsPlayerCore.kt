package com.tommychow.frosty

import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.amazonaws.ivs.player.Cue
import com.amazonaws.ivs.player.Player
import com.amazonaws.ivs.player.PlayerException
import com.amazonaws.ivs.player.Quality
import com.amazonaws.ivs.player.TextCue
import com.amazonaws.ivs.player.TextTrack
import io.flutter.plugin.common.MethodChannel

private const val CORE_TAG = "FrostyIVS"

/**
 * Amazon IVS control/event wiring for a texture-backed player
 * ([IvsTexturePlayer]), live or VOD ([IvsTuning.vod]).
 *
 * Given an IVS [Player] and a per-instance [MethodChannel], it bridges
 * play/pause/quality/sound/load (and, for VODs, seek/rate/position) from
 * Dart, forwards player events back, and ticks either the live latency (plus
 * optional stats) once per second or the VOD progress four times a second.
 * [onVideoSize] lets the texture resize its buffer to the source resolution.
 */
class IvsPlayerCore(
    private val player: Player,
    private val channel: MethodChannel,
    private val onVideoSize: ((Int, Int) -> Unit)? = null,
) {
    private val main = Handler(Looper.getMainLooper())
    private var latencyTicker: Runnable? = null
    private var progressTicker: Runnable? = null
    private var tuning = IvsTuning()

    /**
     * VOD only: position to seek to on the first READY after a load (0 too:
     * a still-recording VOD would otherwise start at its live edge).
     */
    private var pendingStartMs: Long? = null

    /** VOD only: auto-play once per load, so later READYs keep a pause. */
    private var autoPlayPending = false
    private var qualitiesSent = false

    /**
     * Names last sent to Dart. Twitch can add renditions after playback
     * starts (the enhanced-broadcast 1440p HEVC/AV1 ones are negotiated
     * later), so the ladder is watched and a change re-sent.
     */
    private var sentQualityNames: List<String>? = null
    private var statsEnabled = false

    /** Closed captions asked for by Dart (off by default). */
    private var captionsEnabled = false

    fun start(url: String, tuning: IvsTuning = IvsTuning()) {
        this.tuning = tuning
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
                "setMuted" -> {
                    player.isMuted = call.argument<Boolean>("muted") == true
                    result.success(null)
                }
                "setVolume" -> {
                    val volume = call.argument<Number>("volume")?.toFloat() ?: 1f
                    player.volume = volume.coerceIn(0f, 1f)
                    result.success(null)
                }
                "setCaptions" -> {
                    captionsEnabled = call.argument<Boolean>("enabled") == true
                    applyCaptions()
                    result.success(null)
                }
                "setStatsEnabled" -> {
                    statsEnabled = call.argument<Boolean>("enabled") == true
                    result.success(null)
                }
                "load" -> {
                    val newUrl = call.argument<String>("url")
                    qualitiesSent = false
                    sentQualityNames = null
                    if (tuning.vod) {
                        pendingStartMs = call.argument<Number>("startMs")?.toLong()
                        autoPlayPending = true
                    }
                    if (newUrl != null) player.load(Uri.parse(newUrl))
                    result.success(null)
                }
                // VOD-only controls: a live player has no seek and its speed is
                // owned by the live catch-up.
                "seekTo" -> if (tuning.vod) {
                    val ms = call.argument<Number>("ms")?.toLong() ?: 0L
                    if (autoPlayPending) {
                        // Not READY yet: the start seek on READY would undo
                        // this one, so it becomes the start position.
                        pendingStartMs = ms
                    } else {
                        player.seekTo(ms.coerceAtLeast(0L))
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
                "setPlaybackRate" -> if (tuning.vod) {
                    val raw = call.argument<Number>("rate")?.toFloat() ?: 1f
                    val rate = if (raw.isNaN()) 1f else raw
                    player.playbackRate = rate.coerceIn(0.5f, 2f)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
                "getPosition" -> if (tuning.vod) {
                    result.success(runCatching { player.position }.getOrNull())
                } else {
                    result.notImplemented()
                }
                else -> result.notImplemented()
            }
        }

        player.addListener(object : Player.Listener() {
            override fun onStateChanged(state: Player.State) {
                send(mapOf("type" to "state", "state" to state.name))
                if (state == Player.State.READY) {
                    if (!tuning.vod) {
                        player.play()
                    } else if (autoPlayPending) {
                        autoPlayPending = false
                        pendingStartMs?.let { player.seekTo(it.coerceAtLeast(0L)) }
                        pendingStartMs = null
                        player.play()
                    }
                }
                // Text tracks are known once the stream plays.
                if (state == Player.State.PLAYING) applyCaptions()
                if (state == Player.State.PLAYING && !qualitiesSent) {
                    qualitiesSent = true
                    val names = sortedQualityNames()
                    sentQualityNames = names
                    send(mapOf("type" to "qualities", "list" to names))
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
            override fun onCue(cue: Cue) {
                if (!captionsEnabled || cue !is TextCue) return
                send(
                    mapOf(
                        "type" to "caption",
                        "text" to cue.text,
                        "startMs" to cue.startTime,
                        "endMs" to cue.endTime,
                    ),
                )
            }
            // A stream can announce its caption tracks after it starts.
            override fun onTextTracksChanged(tracks: List<TextTrack>) {
                applyCaptions()
            }
            override fun onDurationChanged(duration: Long) {
                if (tuning.vod) send(mapOf("type" to "duration", "ms" to duration))
            }
            override fun onSeekCompleted(position: Long) {
                if (tuning.vod) send(mapOf("type" to "seeked", "ms" to position))
            }
        })

        tuning.applyTo(player)

        // The player can be created before the usher URL is known; Dart then
        // sends it with "load" as soon as it resolves.
        if (url.isNotEmpty()) {
            // A VOD created with its URL must auto-play like one sent with "load".
            if (tuning.vod) autoPlayPending = true
            player.load(Uri.parse(url))
        }
        if (tuning.vod) startProgressTicker() else startLatencyTicker()
    }

    /**
     * Selects the stream's first caption track when captions are on (a stream
     * without one has nothing to select). Never throws: captions must not
     * disturb playback.
     */
    private fun applyCaptions() {
        if (!captionsEnabled) return
        runCatching {
            if (player.textTrack == null) {
                player.textTracks.firstOrNull()?.let { player.setTextTrack(it) }
            }
        }.onFailure { Log.w(CORE_TAG, "captions: ${it.message}") }
    }

    /**
     * VOD only: position, buffer and duration four times a second for the seek
     * bar and chat replay (no latency: a VOD has no live edge).
     */
    private fun startProgressTicker() {
        progressTicker = object : Runnable {
            override fun run() {
                main.postDelayed(this, 250)
                try {
                    val position = runCatching { player.position }.getOrNull()
                    val buffered = runCatching { player.bufferedPosition }.getOrNull()
                    send(
                        mapOf(
                            "type" to "progress",
                            "positionMs" to position,
                            "bufferedMs" to buffered,
                            "durationMs" to runCatching { player.duration }.getOrNull(),
                        ),
                    )
                } catch (t: Throwable) {
                    Log.w(CORE_TAG, "progress failed: $t")
                }
            }
        }
        main.postDelayed(progressTicker!!, 250)
    }

    /**
     * Best first (resolution, then frame rate, then bitrate) so "highest
     * quality" is the first entry, e.g. 1440p HEVC/AV1 even if it uses less
     * bitrate than a 1080p H.264 source.
     */
    private fun sortedQualityNames(): List<String> =
        player.qualities.sortedWith(
            compareByDescending<Quality> { it.height }
                .thenByDescending { it.framerate }
                .thenByDescending { it.bitrate },
        ).map { it.name }

    /** Re-sends the ladder when it changed since the first report. */
    private fun sendQualitiesIfChanged() {
        val sent = sentQualityNames ?: return
        val names = sortedQualityNames()
        if (names.isEmpty() || names == sent) return
        sentQualityNames = names
        send(mapOf("type" to "qualitiesChanged", "list" to names))
    }

    private fun startLatencyTicker() {
        latencyTicker = object : Runnable {
            override fun run() {
                // Reschedule first so a failing getter can never stop the
                // latency ticker (dispose() removes it on this same thread).
                main.postDelayed(this, 1000)
                try { send(mapOf("type" to "latency", "ms" to player.liveLatency)) } catch (_: Throwable) {}
                try { sendQualitiesIfChanged() } catch (t: Throwable) { Log.w(CORE_TAG, "qualities failed: $t") }
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
        progressTicker?.let { main.removeCallbacks(it) }
        channel.setMethodCallHandler(null)
        player.release()
    }
}
