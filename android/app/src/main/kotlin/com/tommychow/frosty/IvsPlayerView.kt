package com.tommychow.frosty

import android.content.Context
import android.view.View
import com.amazonaws.ivs.player.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class IvsPlayerViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        return IvsPlayerView(context, viewId, args as? Map<String, Any?>, messenger)
    }
}

/**
 * Hosts the Amazon IVS player (the same engine the official Twitch app uses)
 * on a full-screen SurfaceView for exact-parity low latency. Control/event
 * wiring is shared with the mini player via [IvsPlayerCore].
 */
class IvsPlayerView(
    context: Context,
    viewId: Int,
    params: Map<String, Any?>?,
    messenger: BinaryMessenger,
) : PlatformView {
    private val playerView = PlayerView(context)
    private val channel = MethodChannel(messenger, "frosty/ivs/$viewId")
    private val core = IvsPlayerCore(playerView.player, channel)

    init {
        // Hide the IVS player's built-in controls (play/pause bar) — Frosty
        // draws its own overlay on top.
        playerView.setControlsEnabled(false)
        core.start(params?.get("url") as? String ?: "")
    }

    override fun getView(): View = playerView

    override fun dispose() = core.dispose()
}
