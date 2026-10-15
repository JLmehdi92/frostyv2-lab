import 'package:flutter/services.dart';

/// Hands a downloaded update to the Android system installer
/// (`ApkInstaller.kt`).
///
/// The native side only installs files from the app's own cache `updates/`
/// directory, and Android itself refuses an update signed with another key.
class OnsetInstaller {
  static const channel = MethodChannel('onset/updates');

  const OnsetInstaller();

  /// Whether ONSET may install apps ("Install unknown apps", Android 8+).
  /// False when the native side is missing.
  Future<bool> canInstall() async {
    try {
      return await channel.invokeMethod<bool>('canInstall') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the system page that lets ONSET install apps.
  Future<void> openInstallSettings() async {
    try {
      await channel.invokeMethod<void>('openInstallSettings');
    } on PlatformException {
      // Nothing to open: the update flow says so.
    } on MissingPluginException {
      // Not on Android.
    }
  }

  /// Opens the system installer for the APK at [path].
  Future<void> install(String path) =>
      channel.invokeMethod<void>('install', {'path': path});
}
