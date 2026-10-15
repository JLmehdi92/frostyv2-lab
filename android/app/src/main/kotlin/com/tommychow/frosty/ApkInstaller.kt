package com.tommychow.frosty

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/**
 * The FileProvider that hands a downloaded update to the system installer.
 *
 * Its own subclass, so that it never clashes in the merged manifest with the
 * FileProviders of plugins. It only exposes the cache `updates/` directory
 * (`res/xml/update_paths.xml`).
 */
class UpdateFileProvider : FileProvider()

/**
 * Installs ONSET updates downloaded by the Dart side (`onset_installer.dart`).
 *
 * Only an APK directly inside the app's own cache `updates/` directory is
 * accepted, so the channel cannot be used to install anything else. Android
 * itself refuses an update signed with another key than the installed app.
 */
class ApkInstaller(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, CHANNEL)

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
                        try {
                            install(file)
                            result.success(null)
                        } catch (e: ActivityNotFoundException) {
                            result.error("no_installer", "no installer available", null)
                        } catch (e: IllegalArgumentException) {
                            result.error("outside_updates", "the update is not shareable", null)
                        }
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

    private fun install(file: File) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.updates", file)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    companion object {
        const val CHANNEL = "onset/updates"
        private const val UPDATES_DIR = "updates"
    }
}
