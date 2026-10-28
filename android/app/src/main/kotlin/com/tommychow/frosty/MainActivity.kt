package com.tommychow.frosty

import android.annotation.TargetApi
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.Display
import android.view.View
import android.window.SplashScreenView
import cl.puntito.simple_pip_mode.PipCallbackHelperActivityWrapper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.roundToInt

class MainActivity : PipCallbackHelperActivityWrapper() {
    private var textureManager: IvsTextureManager? = null
    private var backgroundAudio: BackgroundAudioBridge? = null
    private var audioFocus: AudioFocusBridge? = null
    private var twitchCookies: TwitchCookies? = null
    private var apkInstaller: ApkInstaller? = null
    private var network: NetworkBridge? = null

    /** Whether this activity is the first of a fresh process (read by the
     * launch intro): set before the Flutter engine is configured. */
    private var coldStart = false

    /** Opened from the launcher, not from a notification or a link. */
    private var fromLauncher = false

    private var launchChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // A kept process (warm start) or a restored state does not replay
        // the launch intro.
        coldStart = !processStarted && savedInstanceState == null
        processStarted = true
        fromLauncher = intent?.action == Intent.ACTION_MAIN &&
            intent?.hasCategory(Intent.CATEGORY_LAUNCHER) == true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // The Flutter intro starts from the splash's own frame (the launch
            // tile on the ONSET ground): no system exit fade, and the splash
            // stays until Flutter has drawn its tile in the same place.
            splashScreen.setOnExitAnimationListener { handOverSplash(it) }
        }
        super.onCreate(savedInstanceState)
        preferSmoothRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Reads the twitch.tv session cookie left behind by the login WebView.
        twitchCookies = TwitchCookies(messenger)

        // Texture-backed IVS players (channel screen, mini player and PiP).
        textureManager = IvsTextureManager(this, flutterEngine.renderer, messenger)

        // The media notification that keeps a stream's sound in the background.
        backgroundAudio = BackgroundAudioBridge(applicationContext, messenger)

        // Calls and other apps pause the stream; unplugged headphones too.
        audioFocus = AudioFocusBridge(applicationContext, messenger)

        // In-app updates: hands a downloaded build to the system installer.
        apkInstaller = ApkInstaller(applicationContext, messenger)

        // Whether the network costs data (the "Wi-Fi Only" autoplay setting).
        network = NetworkBridge(applicationContext, messenger)

        // How this launch started, for the launch intro. The splash (before
        // and from Android 12) shows the launch tile.
        launchChannel = MethodChannel(messenger, "onset/launch").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "info") {
                    result.success(
                        mapOf(
                            "coldStart" to coldStart,
                            "nativeTile" to true,
                            "fromLauncher" to fromLauncher,
                        ),
                    )
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Tells Flutter where the splash drew its tile (relative to the Flutter
     * view, in dp), then removes the splash once Flutter answers that its own
     * tile is drawn there — or after 300 ms whatever happens. Measured rather
     * than assumed: the splash is centred on the whole window, which a Flutter
     * view stopping above a navigation bar does not cover, and the system
     * picks the icon's size.
     */
    @TargetApi(Build.VERSION_CODES.S)
    private fun handOverSplash(splash: SplashScreenView) {
        var removed = false
        val remove = {
            if (!removed) {
                removed = true
                splash.remove()
            }
        }
        val icon = splash.iconView
        val flutterView = findViewById<View>(FLUTTER_VIEW_ID)
        val channel = launchChannel
        if (icon == null || flutterView == null || channel == null || icon.width == 0) {
            remove()
            return
        }
        val iconAt = IntArray(2).also { icon.getLocationOnScreen(it) }
        val viewAt = IntArray(2).also { flutterView.getLocationOnScreen(it) }
        val density = resources.displayMetrics.density
        // The tile is 72 dp in the middle of the icon's 288 dp canvas
        // (res/drawable/splash_icon.xml).
        val tile = icon.width * 72f / 288f
        channel.invokeMethod(
            "splashTile",
            mapOf(
                "x" to (iconAt[0] - viewAt[0] + icon.width / 2f) / density,
                "y" to (iconAt[1] - viewAt[1] + icon.height / 2f) / density,
                "size" to tile / density,
            ),
            object : MethodChannel.Result {
                override fun success(result: Any?) = remove()

                override fun error(code: String, message: String?, details: Any?) = remove()

                override fun notImplemented() = remove()
            },
        )
        splash.postDelayed({ remove() }, 300)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        backgroundAudio?.dispose()
        backgroundAudio = null
        audioFocus?.dispose()
        audioFocus = null
        super.cleanUpFlutterEngine(flutterEngine)
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

    private companion object {
        /** Lives as long as the process: a second activity is a warm start. */
        var processStarted = false
    }
}
