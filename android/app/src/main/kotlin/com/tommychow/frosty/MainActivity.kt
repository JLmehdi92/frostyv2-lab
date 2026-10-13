package com.tommychow.frosty

import android.os.Build
import android.os.Bundle
import android.view.Display
import cl.puntito.simple_pip_mode.PipCallbackHelperActivityWrapper
import io.flutter.embedding.engine.FlutterEngine
import kotlin.math.abs
import kotlin.math.roundToInt

class MainActivity : PipCallbackHelperActivityWrapper() {
    private var textureManager: IvsTextureManager? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferSmoothRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Texture-backed IVS players (channel screen, mini player and PiP).
        textureManager = IvsTextureManager(this, flutterEngine.renderer, messenger)
    }

    /**
     * On a large screen (smallest width ≥ 600 dp), asks for a smoother refresh
     * rate at the current resolution: some OEM skins (HyperOS) keep apps they
     * do not list at 60 Hz. A multiple of 60 Hz (120 Hz) wins over a faster
     * odd rate (144 Hz), so 30 and 60 fps streams keep an even frame cadence.
     * Never lowers the current rate, and leaves phones to the system.
     */
    private fun preferSmoothRefreshRate() {
        if (resources.configuration.smallestScreenWidthDp < 600) return
        val display: Display = (
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay
            }
        ) ?: return
        val current = display.mode
        val sameSize = display.supportedModes.filter {
            it.physicalWidth == current.physicalWidth &&
                it.physicalHeight == current.physicalHeight
        }
        val evenCadence = sameSize.filter { mode ->
            val multiple = (mode.refreshRate / 60f).roundToInt()
            multiple >= 1 && abs(mode.refreshRate - multiple * 60f) < 1f
        }
        val best = (evenCadence.ifEmpty { sameSize }).maxByOrNull { it.refreshRate }
            ?: return
        if (best.refreshRate <= current.refreshRate + 1f) return
        window.attributes = window.attributes.apply {
            preferredDisplayModeId = best.modeId
        }
    }
}
