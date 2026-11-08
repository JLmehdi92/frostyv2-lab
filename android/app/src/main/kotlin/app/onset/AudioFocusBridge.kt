package app.onset

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Android audio focus for the live player, on the `onset/audio-focus`
 * channel: `request` takes the focus (and listens for headphones being
 * unplugged), `abandon` lets it go, and changes come back as
 * `change {state: loss | lossTransient | gain | noisy}`. Ducking is left
 * to the system (Android 8+ lowers the volume itself).
 */
class AudioFocusBridge(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "onset/audio-focus")
    private val main = Handler(Looper.getMainLooper())
    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var request: AudioFocusRequest? = null
    private var held = false

    private val listener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS -> send("loss")
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> send("lossTransient")
            AudioManager.AUDIOFOCUS_GAIN -> send("gain")
            // LOSS_TRANSIENT_CAN_DUCK: the system lowers the volume.
        }
    }

    private val noisy = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) send("noisy")
        }
    }
    private var noisyRegistered = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "request" -> result.success(request())
                "abandon" -> {
                    abandon()
                    result.success(null)
                }
                "headphonesConnected" -> result.success(headphonesConnected())
                else -> result.notImplemented()
            }
        }
    }

    private fun headphonesConnected(): Boolean {
        val headphoneTypes = mutableSetOf(
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            headphoneTypes.add(AudioDeviceInfo.TYPE_USB_HEADSET)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            headphoneTypes.add(AudioDeviceInfo.TYPE_BLE_HEADSET)
        }
        return audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .any { it.type in headphoneTypes }
    }

    private fun send(state: String) {
        main.post { channel.invokeMethod("change", mapOf("state" to state)) }
    }

    /** True when granted; false when refused or delayed (GAIN follows). */
    private fun request(): Boolean {
        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val focusRequest = request ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                        .build(),
                )
                .setWillPauseWhenDucked(false)
                // Refused during a call: GAIN comes once it ends.
                .setAcceptsDelayedFocusGain(true)
                .setOnAudioFocusChangeListener(listener, main)
                .build()
                .also { request = it }
            audioManager.requestAudioFocus(focusRequest)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                listener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN,
            )
        }
        val granted = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        // A delayed request is still pending: it must be abandoned too.
        held = granted || result == AudioManager.AUDIOFOCUS_REQUEST_DELAYED
        if (held && !noisyRegistered) {
            val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // A system broadcast still arrives; other apps cannot send it.
                context.registerReceiver(noisy, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(noisy, filter)
            }
            noisyRegistered = true
        }
        return granted
    }

    private fun abandon() {
        if (held) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                request?.let { audioManager.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager.abandonAudioFocus(listener)
            }
            held = false
        }
        if (noisyRegistered) {
            context.unregisterReceiver(noisy)
            noisyRegistered = false
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        abandon()
    }
}
