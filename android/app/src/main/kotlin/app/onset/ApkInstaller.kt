package app.onset

import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/**
 * Installs ONSET updates downloaded by the Dart side (`onset_installer.dart`).
 *
 * The APK is copied into a [PackageInstaller] session rather than shared
 * through a content URI: no other app (an "APK viewer" answering a VIEW
 * intent) can read it, and it embeds build-time secrets. Only an APK directly
 * inside the app's own cache `updates/` directory is accepted, so the channel
 * cannot install anything else, and the session only takes an update of this
 * very package. Android itself refuses an update signed with another key.
 *
 * `install` answers once the installer has: success, `install_aborted` when
 * the viewer dismissed it, `install_failed` otherwise. A successful update
 * usually stops this process before the answer.
 */
class ApkInstaller(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> result.success(canInstall())
                "openInstallSettings" -> {
                    openInstallSettings()
                    result.success(null)
                }
                "install" -> {
                    val file = call.argument<String>("path")?.let(::updateFile)
                    if (file == null) {
                        result.error("outside_updates", "only a downloaded update can be installed", null)
                    } else {
                        install(file, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canInstall(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${context.packageName}"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            // Some skins have no such page; the Dart side explains what to do.
        }
    }

    /** The APK at [path] when it sits directly in the cache `updates/` dir. */
    private fun updateFile(path: String): File? = try {
        val updates = File(context.cacheDir, UPDATES_DIR).canonicalFile
        val file = File(path).canonicalFile
        file.takeIf { it.parentFile == updates && it.isFile && it.name.endsWith(".apk") }
    } catch (e: IOException) {
        null
    }

    private fun install(file: File, result: MethodChannel.Result) {
        finish { it.error("superseded", "another install started", null) }
        pending = result
        // Copying tens of megabytes stays off the main thread.
        io.execute {
            // Any exception: one left uncaught on this thread would kill the app.
            val failed = try {
                commitSession(file)
                false
            } catch (e: Exception) {
                true
            }
            if (failed) {
                main.post {
                    finish { it.error(FAILED, "the update could not be handed to Android", null) }
                }
            }
        }
    }

    private fun commitSession(file: File) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        // The session only accepts an update of this app.
        params.setAppPackageName(context.packageName)
        val sessionId = installer.createSession(params)
        try {
            installer.openSession(sessionId).use { session ->
                session.openWrite("onset.apk", 0, file.length()).use { out ->
                    file.inputStream().use { it.copyTo(out) }
                    session.fsync(out)
                }
                // Explicit, to our own non-exported receiver. Mutable on API 31+
                // because the installer fills in the status extras.
                val intent = Intent(context, InstallResultReceiver::class.java)
                val mutable =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or mutable
                val callback = PendingIntent.getBroadcast(context, sessionId, intent, flags)
                session.commit(callback.intentSender)
            }
        } catch (e: Exception) {
            try {
                installer.abandonSession(sessionId)
            } catch (ignored: SecurityException) {
                // Already committed or gone.
            }
            throw e
        }
    }

    companion object {
        const val CHANNEL = "onset/updates"
        const val ABORTED = "install_aborted"
        const val FAILED = "install_failed"
        private const val UPDATES_DIR = "updates"

        /** The Dart call waiting for the installer's answer (main thread only). */
        private var pending: MethodChannel.Result? = null

        /** Answers the waiting Dart call, if any, once. */
        fun finish(answer: (MethodChannel.Result) -> Unit) {
            val result = pending ?: return
            pending = null
            answer(result)
        }
    }
}

/**
 * Receives the install session's status. Not exported: only the system,
 * through the session's PendingIntent, can reach it.
 */
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                // The viewer confirms in the system's own installer screen; the
                // final status arrives here afterwards.
                val confirm = confirmation(intent)?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    if (confirm == null) throw ActivityNotFoundException()
                    context.startActivity(confirm)
                } catch (e: ActivityNotFoundException) {
                    ApkInstaller.finish {
                        it.error(ApkInstaller.FAILED, "no installer to confirm the update", null)
                    }
                }
            }
            PackageInstaller.STATUS_SUCCESS -> ApkInstaller.finish { it.success(null) }
            PackageInstaller.STATUS_FAILURE_ABORTED -> ApkInstaller.finish {
                it.error(ApkInstaller.ABORTED, "the update was dismissed", null)
            }
            else -> ApkInstaller.finish {
                it.error(ApkInstaller.FAILED, "Android refused the update", null)
            }
        }
    }

    private fun confirmation(intent: Intent): Intent? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_INTENT)
        }
}
