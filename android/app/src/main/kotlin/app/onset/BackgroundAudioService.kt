package app.onset

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

private const val AUDIO_TAG = "OnsetAudio"

/**
 * Keeps a live stream's sound going with the app in the background: a
 * `mediaPlayback` foreground service (so Android does not freeze the
 * process playing it) with a media session (lock screen, headphones and
 * Bluetooth buttons) and a media notification (play/pause, stop).
 *
 * The IVS player itself stays where it is; this only keeps the process
 * alive and forwards the media buttons to Dart ([onCommand]).
 */
class BackgroundAudioService : Service() {
    companion object {
        const val ACTION_SHOW = "app.onset.audio.SHOW"
        const val ACTION_PLAY = "app.onset.audio.PLAY"
        const val ACTION_PAUSE = "app.onset.audio.PAUSE"
        const val ACTION_STOP = "app.onset.audio.STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_SUBTITLE = "subtitle"
        const val EXTRA_PLAYING = "playing"

        private const val CHANNEL_ID = "playback"
        private const val NOTIFICATION_ID = 7301

        /** The running service, to update without starting it again. */
        var instance: BackgroundAudioService? = null
            private set

        /** Media buttons ("play", "pause", "stop") go to Dart through this. */
        var onCommand: ((String) -> Unit)? = null

        /**
         * The notification's words in the language the app shows, sent by
         * Dart with each show and whenever the language changes (Dart's ARB
         * files hold them: `mediaChannel`, `mediaPlay`, `mediaPause`,
         * `mediaStop`). Empty only until Dart's first show, which carries
         * them: the notification is never posted before it.
         */
        var labels = MediaLabels()

        /**
         * A start asked for but not yet handled, and whether a hide came in
         * meanwhile: stopping a service started in the foreground before it
         * called startForeground crashes the app, so it stops itself after.
         */
        internal var startPending = false
        internal var hideRequested = false
    }

    private var session: MediaSession? = null
    private var title = ""
    private var subtitle = ""
    private var playing = true

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        session = MediaSession(this, "ONSET").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() { onCommand?.invoke("play") }
                override fun onPause() { onCommand?.invoke("pause") }
                override fun onStop() { onCommand?.invoke("stop") }
            })
            isActive = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> {
                startPending = false
                update(
                    intent.getStringExtra(EXTRA_TITLE) ?: "",
                    intent.getStringExtra(EXTRA_SUBTITLE) ?: "",
                    intent.getBooleanExtra(EXTRA_PLAYING, true),
                    promote = true,
                )
                if (hideRequested) {
                    hideRequested = false
                    stopSelf()
                }
            }
            ACTION_PLAY -> onCommand?.invoke("play")
            ACTION_PAUSE -> onCommand?.invoke("pause")
            ACTION_STOP -> onCommand?.invoke("stop")
        }
        // Not restarted by Android: without the app there is nothing to play.
        return START_NOT_STICKY
    }

    /**
     * Shows [title] and [subtitle] as playing or paused. Only a start
     * ([promote]) calls startForeground: Android 12+ refuses it again from
     * the background, so later changes just repost the notification.
     */
    fun update(title: String, subtitle: String, playing: Boolean, promote: Boolean = false) {
        this.title = title
        this.subtitle = subtitle
        this.playing = playing
        session?.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, title)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, subtitle)
                .build(),
        )
        session?.setPlaybackState(
            PlaybackState.Builder()
                .setActions(
                    PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or
                        PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_STOP,
                )
                .setState(
                    if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                    PlaybackState.PLAYBACK_POSITION_UNKNOWN,
                    1f,
                )
                .build(),
        )
        val notification = buildNotification()
        if (!promote) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, notification)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, labels.channel, NotificationManager.IMPORTANCE_LOW),
            )
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val toggle = if (playing) {
            action(android.R.drawable.ic_media_pause, labels.pause, ACTION_PAUSE)
        } else {
            action(android.R.drawable.ic_media_play, labels.play, ACTION_PLAY)
        }
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE)
        }
        return builder
            .setSmallIcon(R.drawable.ic_stat_playback)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setContentIntent(open)
            .setDeleteIntent(pending(ACTION_STOP))
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(playing)
            .addAction(toggle)
            .addAction(action(android.R.drawable.ic_menu_close_clear_cancel, labels.stop, ACTION_STOP))
            .setStyle(
                Notification.MediaStyle()
                    .setMediaSession(session?.sessionToken)
                    .setShowActionsInCompactView(0, 1),
            )
            .build()
    }

    private fun action(icon: Int, label: String, intentAction: String) =
        Notification.Action.Builder(Icon.createWithResource(this, icon), label, pending(intentAction))
            .build()

    private fun pending(intentAction: String): PendingIntent = PendingIntent.getService(
        this,
        intentAction.hashCode(),
        Intent(this, BackgroundAudioService::class.java).setAction(intentAction),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    /** Posts the notification again in the [labels] just received. */
    fun refreshLabels() {
        update(title, subtitle, playing)
    }

    /** Leaves at once: later shows start a new service instead of this one. */
    fun dismiss() {
        if (instance === this) instance = null
        stopSelf()
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        session?.isActive = false
        session?.release()
        session = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }
}

/** The media notification's words, in the language the app shows. */
data class MediaLabels(
    val channel: String = "",
    val play: String = "",
    val pause: String = "",
    val stop: String = "",
) {
    companion object {
        /** Read from a `labels` map sent by Dart; null when it has none. */
        fun from(map: Map<*, *>?): MediaLabels? {
            if (map == null) return null
            fun text(key: String) = map[key] as? String ?: ""
            return MediaLabels(text("channel"), text("play"), text("pause"), text("stop"))
        }
    }
}

/**
 * The `onset/background-audio` channel: `show {title, subtitle, playing,
 * labels}` starts or updates [BackgroundAudioService], `labels {channel,
 * play, pause, stop}` changes the notification's words (the app's language
 * changed), `hide` stops it, and media buttons come back as `command
 * {action}`.
 */
class BackgroundAudioBridge(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "onset/background-audio")
    private val main = Handler(Looper.getMainLooper())

    init {
        BackgroundAudioService.onCommand = { action ->
            main.post { channel.invokeMethod("command", mapOf("action" to action)) }
        }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "labels" -> {
                    MediaLabels.from(call.arguments as? Map<*, *>)?.let {
                        BackgroundAudioService.labels = it
                        BackgroundAudioService.instance?.refreshLabels()
                    }
                    result.success(null)
                }
                "show" -> {
                    MediaLabels.from(call.argument<Map<*, *>>("labels"))?.let {
                        BackgroundAudioService.labels = it
                    }
                    val title = call.argument<String>("title") ?: ""
                    val subtitle = call.argument<String>("subtitle") ?: ""
                    val playing = call.argument<Boolean>("playing") ?: true
                    val running = BackgroundAudioService.instance
                    if (running != null) {
                        BackgroundAudioService.hideRequested = false
                        running.update(title, subtitle, playing)
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(context, BackgroundAudioService::class.java)
                        .setAction(BackgroundAudioService.ACTION_SHOW)
                        .putExtra(BackgroundAudioService.EXTRA_TITLE, title)
                        .putExtra(BackgroundAudioService.EXTRA_SUBTITLE, subtitle)
                        .putExtra(BackgroundAudioService.EXTRA_PLAYING, playing)
                    BackgroundAudioService.hideRequested = false
                    try {
                        BackgroundAudioService.startPending = true
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(intent)
                        } else {
                            context.startService(intent)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        // E.g. Android 12+ refusing a start from the background.
                        BackgroundAudioService.startPending = false
                        Log.w(AUDIO_TAG, "background audio not started", e)
                        result.error("start_failed", e.message, null)
                    }
                }
                "hide" -> {
                    hide()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Stops the service, or has it stop itself once started. */
    private fun hide() {
        if (BackgroundAudioService.startPending) {
            BackgroundAudioService.hideRequested = true
            return
        }
        val running = BackgroundAudioService.instance
        if (running != null) {
            running.dismiss()
        } else {
            context.stopService(Intent(context, BackgroundAudioService::class.java))
        }
    }

    fun dispose() {
        BackgroundAudioService.onCommand = null
        channel.setMethodCallHandler(null)
        hide()
    }
}
