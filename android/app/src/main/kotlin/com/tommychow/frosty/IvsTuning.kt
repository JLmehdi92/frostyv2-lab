package com.tommychow.frosty

import android.content.Context
import android.util.Log
import com.amazonaws.ivs.player.MediaPlayer
import com.amazonaws.ivs.player.Player
import com.amazonaws.ivs.player.SessionConfig

private const val TUNING_TAG = "FrostyIVS"

/**
 * Low-latency tuning for a native IVS player, sent from Dart as the `config`
 * map of `frosty/ivs-texture-manager.create` (see `IvsPlayerConfig`).
 *
 * Defaults match the official Twitch app: live catch-up by speeding playback
 * up (not by jumping to live), a 100 ms initial buffer and the IVS default
 * low-latency buffer targets.
 */
data class IvsTuning(
    val speedUpCatchUp: Boolean = true,
    val rebufferToLive: Boolean = false,
    val initialBufferMs: Long = 100,
    val llMinBufferSec: Double? = null,
    val llMinBufferCeilingSec: Double? = null,
    /** Past broadcast / highlight: no live low-latency or catch-up tuning. */
    val vod: Boolean = false,
) {
    /**
     * Builds the player with the session config, falling back to a plain
     * player if the SDK rejects it, so playback never fails because of tuning.
     */
    fun buildPlayer(context: Context): Player {
        if (vod) {
            val player = runCatching {
                val built: Player = MediaPlayer.Builder(context).build()
                built
            }.getOrElse { Player.Factory.create(context) }
            Log.i(TUNING_TAG, "vod player sdk=${runCatching { player.version }.getOrNull()}")
            return player
        }
        val player = runCatching {
            val session = SessionConfig().setLiveCatchUpSpeedUpEnabled(speedUpCatchUp)
            // Each buffer override is optional: an out-of-range value only
            // drops that value, never the speed-up catch-up.
            llMinBufferSec?.let { v ->
                runCatching { session.setLowLatencyMinBufferSeconds(v) }
                    .onFailure { Log.w(TUNING_TAG, "min buffer $v rejected: $it") }
            }
            llMinBufferCeilingSec?.let { v ->
                runCatching { session.setLowLatencyMinBufferCeilingSeconds(v) }
                    .onFailure { Log.w(TUNING_TAG, "buffer ceiling $v rejected: $it") }
            }
            val built: Player = MediaPlayer.Builder(context).sessionConfig(session).build()
            built
        }.getOrElse {
            Log.w(TUNING_TAG, "session config rejected, using defaults: $it")
            Player.Factory.create(context)
        }
        Log.i(TUNING_TAG, "tuning=$this sdk=${runCatching { player.version }.getOrNull()}")
        return player
    }

    /**
     * Settings applied on the player itself. Must run before the first
     * `load()`: changing the initial buffer swaps the native buffer strategy,
     * and the latency/catch-up modes are only (re)applied when a stream loads.
     */
    fun applyTo(player: Player) {
        if (vod) {
            // VODs keep the SDK's default buffering for smooth seeking.
            try {
                player.setLiveLowLatencyEnabled(false)
                player.setRebufferToLive(false)
            } catch (t: Throwable) {
                Log.w(TUNING_TAG, "vod config failed: $t")
            }
            return
        }
        try {
            player.setLiveLowLatencyEnabled(true)
            player.setRebufferToLive(rebufferToLive)
            player.setInitialBufferDuration(initialBufferMs)
        } catch (t: Throwable) {
            Log.w(TUNING_TAG, "low-latency config failed: $t")
        }
    }

    companion object {
        /** Parses the Dart `config` map, tolerating missing or mistyped keys. */
        fun fromArgs(args: Map<*, *>?): IvsTuning {
            if (args == null) return IvsTuning()
            val defaults = IvsTuning()
            return IvsTuning(
                speedUpCatchUp = args["speedUpCatchUp"] as? Boolean ?: defaults.speedUpCatchUp,
                rebufferToLive = args["rebufferToLive"] as? Boolean ?: defaults.rebufferToLive,
                initialBufferMs = (args["initialBufferMs"] as? Number)?.toLong()
                    ?: defaults.initialBufferMs,
                llMinBufferSec = (args["llMinBufferSec"] as? Number)?.toDouble(),
                llMinBufferCeilingSec = (args["llMinBufferCeilingSec"] as? Number)?.toDouble(),
                vod = args["vod"] as? Boolean ?: false,
            )
        }
    }
}
