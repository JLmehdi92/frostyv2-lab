import 'package:flutter/services.dart';

/// Hands a downloaded update to the Android package installer
/// (`ApkInstaller.kt`).
///
/// The native side copies the APK into a PackageInstaller session, so no
/// other app ever gets to read it, and only accepts files from the app's own
/// cache `updates/` directory. Android itself refuses an update signed with
/// another key.
class OnsetInstaller {
  static const channel = MethodChannel('onset/updates');

  /// The [PlatformException] code of an install the viewer dismissed.
  static const abortedCode = 'install_aborted';

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

  /// Installs the APK at [path] and completes with the installer's answer:
  /// a [PlatformException] coded [abortedCode] when the viewer dismissed it,
  /// any other code when Android refused the update.
  Future<void> install(String path) =>
      channel.invokeMethod<void>('install', {'path': path});
}
