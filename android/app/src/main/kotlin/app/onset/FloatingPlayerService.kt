package app.onset

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageButton
import com.amazonaws.ivs.player.Player
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.roundToInt

private const val FLOATING_TAG = "OnsetFloating"

class FloatingPlayerService : Service() {
    private var windowManager: WindowManager? = null
    private var window: FrameLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var player: Player? = null
    private var surface: SurfaceHolder? = null
    private var closing = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            close(returned = false)
            return START_NOT_STICKY
        }
        val url = intent.getStringExtra(EXTRA_URL)
        if (intent.action == ACTION_STOP || url == null) {
            close(returned = false)
            return START_NOT_STICKY
        }
        running = true
        closing = false
        promote(intent)
        if (!Settings.canDrawOverlays(this)) {
            close(returned = false)
            return START_NOT_STICKY
        }
        show(url, intent.getStringExtra(EXTRA_CLOSE_LABEL) ?: "")
        return START_NOT_STICKY
    }

    private fun promote(intent: Intent) {
        val title = intent.getStringExtra(EXTRA_TITLE) ?: ""
        val channelName = intent.getStringExtra(EXTRA_CHANNEL_LABEL) ?: title
        val closeLabel = intent.getStringExtra(EXTRA_CLOSE_LABEL) ?: ""
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, channelName, NotificationManager.IMPORTANCE_LOW),
            )
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, FloatingPlayerService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_playback)
            .setContentTitle(title)
            .setContentIntent(open)
            .setOngoing(true)
            .addAction(action(closeLabel, stop))
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun action(label: String, intent: PendingIntent) =
        Notification.Action.Builder(
            Icon.createWithResource(this, android.R.drawable.ic_menu_close_clear_cancel),
            label,
            intent,
        ).build()

    private fun show(url: String, closeLabel: String) {
        val active = player
        if (active != null) {
            active.load(Uri.parse(url))
            active.play()
            return
        }
        val manager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager = manager
        val metrics = resources.displayMetrics
        val density = metrics.density
        val width = (minOf(metrics.widthPixels, metrics.heightPixels) * 0.6f).roundToInt()
        val height = width * 9 / 16
        val layout = WindowManager.LayoutParams(
            width,
            height,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = metrics.widthPixels - width - (16 * density).roundToInt()
            y = (96 * density).roundToInt()
        }
        params = layout

        val root = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                setColor(Color.BLACK)
                cornerRadius = 14 * density
            }
            clipToOutline = true
            elevation = 8 * density
        }
        val video = SurfaceView(this)
        video.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                surface = holder
                player?.setSurface(holder.surface)
            }

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}

            override fun surfaceDestroyed(holder: SurfaceHolder) {
                surface = null
                player?.setSurface(null)
            }
        })
        root.addView(video, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))

        val closeSize = (36 * density).roundToInt()
        val close = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setColorFilter(Color.WHITE)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0x8C000000.toInt())
            }
            contentDescription = closeLabel
            setOnClickListener { close(returned = false) }
        }
        root.addView(
            close,
            FrameLayout.LayoutParams(closeSize, closeSize, Gravity.TOP or Gravity.END).apply {
                val margin = (6 * density).roundToInt()
                setMargins(margin, margin, margin, margin)
            },
        )
        root.setOnTouchListener(DragToMove(layout, manager, root, (8 * density)) { returnToApp() })

        try {
            manager.addView(root, layout)
        } catch (t: Throwable) {
            Log.w(FLOATING_TAG, "overlay refused: ${t.message}")
            close(returned = false)
            return
        }
        window = root

        val created = IvsTuning().buildPlayer(this)
        player = created
        surface?.let { created.setSurface(it.surface) }
        created.load(Uri.parse(url))
        created.play()
    }

    private fun returnToApp() {
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            try {
                startActivity(it)
            } catch (t: Throwable) {
                Log.w(FLOATING_TAG, "could not return to the app: ${t.message}")
            }
        }
        close(returned = true)
    }

    private fun close(returned: Boolean) {
        if (closing) return
        closing = true
        running = false
        window?.let { view ->
            try {
                windowManager?.removeView(view)
            } catch (_: Throwable) {
            }
        }
        window = null
        player?.release()
        player = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
        Handler(Looper.getMainLooper()).post { onClosed?.invoke(returned) }
    }

    override fun onDestroy() {
        close(returned = false)
        super.onDestroy()
    }

    private class DragToMove(
        private val layout: WindowManager.LayoutParams,
        private val manager: WindowManager,
        private val view: View,
        private val slop: Float,
        private val onTap: () -> Unit,
    ) : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var downX = 0f
        private var downY = 0f
        private var moved = false

        override fun onTouch(v: View, event: MotionEvent): Boolean {
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = layout.x
                    startY = layout.y
                    downX = event.rawX
                    downY = event.rawY
                    moved = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downX
                    val dy = event.rawY - downY
                    if (abs(dx) > slop || abs(dy) > slop) moved = true
                    if (moved) {
                        layout.x = startX + dx.roundToInt()
                        layout.y = startY + dy.roundToInt()
                        try {
                            manager.updateViewLayout(view, layout)
                        } catch (_: Throwable) {
                        }
                    }
                }
                MotionEvent.ACTION_UP -> if (!moved) {
                    v.performClick()
                    onTap()
                }
            }
            return true
        }
    }

    companion object {
        private const val CHANNEL_ID = "onset_floating_player"
        private const val NOTIFICATION_ID = 4207
        private const val ACTION_STOP = "app.onset.floating.STOP"
        const val EXTRA_URL = "url"
        const val EXTRA_TITLE = "title"
        const val EXTRA_CHANNEL_LABEL = "channelLabel"
        const val EXTRA_CLOSE_LABEL = "closeLabel"

        var onClosed: ((Boolean) -> Unit)? = null

        @Volatile
        var running = false

        fun stop(context: Context) {
            if (!running) return
            try {
                context.startService(
                    Intent(context, FloatingPlayerService::class.java).setAction(ACTION_STOP),
                )
            } catch (t: Throwable) {
                Log.w(FLOATING_TAG, "could not stop: ${t.message}")
            }
        }
    }
}

class FloatingPlayerBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "onset/floating-player")

    init {
        FloatingPlayerService.onClosed = { returned ->
            try {
                channel.invokeMethod("closed", mapOf("returned" to returned))
            } catch (_: Throwable) {
            }
        }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "canDrawOverlays" -> result.success(Settings.canDrawOverlays(activity))
                "openPermissionSettings" -> result.success(openPermissionSettings())
                "start" -> result.success(start(call.arguments as? Map<*, *>))
                "stop" -> {
                    FloatingPlayerService.stop(activity)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openPermissionSettings(): Boolean = try {
        activity.startActivity(
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}"),
            ),
        )
        true
    } catch (t: Throwable) {
        Log.w(FLOATING_TAG, "no overlay settings: ${t.message}")
        false
    }

    private fun start(args: Map<*, *>?): Boolean {
        val url = args?.get("url") as? String ?: return false
        if (!Settings.canDrawOverlays(activity)) return false
        val intent = Intent(activity, FloatingPlayerService::class.java)
            .putExtra(FloatingPlayerService.EXTRA_URL, url)
            .putExtra(FloatingPlayerService.EXTRA_TITLE, args["title"] as? String ?: "")
            .putExtra(FloatingPlayerService.EXTRA_CHANNEL_LABEL, args["channelLabel"] as? String ?: "")
            .putExtra(FloatingPlayerService.EXTRA_CLOSE_LABEL, args["closeLabel"] as? String ?: "")
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                activity.startForegroundService(intent)
            } else {
                activity.startService(intent)
            }
            activity.moveTaskToBack(true)
            true
        } catch (t: Throwable) {
            Log.w(FLOATING_TAG, "could not start: ${t.message}")
            false
        }
    }

    fun dispose() {
        FloatingPlayerService.onClosed = null
        channel.setMethodCallHandler(null)
    }
}
