import 'package:frosty/screens/settings/stores/settings_store.dart';

/// Picks the player engine that can actually run on this platform.
///
/// The Amazon IVS engine only has a native implementation on Android, so any
/// other platform (iOS) uses the Twitch web player instead of spinning
/// forever. [forceWeb] is set after a runtime fallback.
PlayerEngine resolvePlayerEngine({
  required PlayerEngine setting,
  required bool isAndroid,
  required bool forceWeb,
}) {
  if (forceWeb) return PlayerEngine.twitchWeb;
  if (setting == PlayerEngine.ivs && !isAndroid) return PlayerEngine.twitchWeb;
  return setting;
}
