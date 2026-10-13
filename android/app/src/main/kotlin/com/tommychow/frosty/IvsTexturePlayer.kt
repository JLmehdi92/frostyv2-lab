package com.tommychow.frosty

import android.content.Context
import com.amazonaws.ivs.player.Player
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Renders an IVS stream into a Flutter texture (via [TextureRegistry]) instead
 * of a SurfaceView. A texture can be moved/animated smoothly by Flutter's
 * compositor, which is what the in-app draggable mini player needs.
 *
 * The player is built and tuned from the [IvsTuning] sent by Dart (speed-up
 * live catch-up, initial buffer, optional low-latency buffer targets).
 */
class IvsTexturePlayer(
    context: Context,
    textureRegistry: TextureRegistry,
    messenger: BinaryMessenger,
    url: String,
    tuning: IvsTuning,
) {
    private val surfaceProducer = textureRegistry.createSurfaceProducer()
    val textureId: Long = surfaceProducer.id()
    private val player: Player = tuning.buildPlayer(context)
    private val channel = MethodChannel(messenger, "frosty/ivs-texture/$textureId")
    private val core = IvsPlayerCore(player, channel) { w, h ->
        if (w > 0 && h > 0) surfaceProducer.setSize(w, h)
    }

    init {
        surfaceProducer.setSize(1280, 720)
        player.setSurface(surfaceProducer.surface)
        core.start(url, tuning)
    }

    fun dispose() {
        core.dispose()
        surfaceProducer.release()
    }
}

/**
 * Creates and tracks [IvsTexturePlayer]s on demand from Dart over the
 * `frosty/ivs-texture-manager` channel: `create {url} -> textureId`,
 * `dispose {textureId}`.
 */
class IvsTextureManager(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
    private val messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "frosty/ivs-texture-manager")
    private val players = HashMap<Long, IvsTexturePlayer>()

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "create" -> {
                    val url = call.argument<String>("url") ?: ""
                    val tuning = IvsTuning.fromArgs(call.argument<Map<String, Any?>>("config"))
                    val player = IvsTexturePlayer(context, textureRegistry, messenger, url, tuning)
                    players[player.textureId] = player
                    result.success(player.textureId)
                }
                "dispose" -> {
                    val id = call.argument<Number>("textureId")?.toLong()
                    players.remove(id)?.dispose()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
