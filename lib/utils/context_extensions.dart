import 'package:flutter/material.dart';
import 'package:onset/apis/bttv_api.dart';
import 'package:onset/apis/ffz_api.dart';
import 'package:onset/apis/seventv_api.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_channel_profile_service.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/apis/twitch_community_highlights_service.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/realtime/twitch_realtime_client.dart';
import 'package:onset/stores/global_assets_store.dart';
import 'package:onset/stores/mini_player_store.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

/// Shortest window side, in dp, from which a layout is a tablet's (Android's
/// own large-screen threshold, Material's medium window class).
const kLargeScreenShortestSide = 600.0;

/// Whether a window of [size] gets the large-screen layouts.
bool isLargeScreenSize(Size size) =>
    size.shortestSide >= kLargeScreenShortestSide;

/// Says whether its subtree gets the large-screen layouts, whatever its
/// window: a panel of a tablet layout (Browse's category pane) narrower
/// than [kLargeScreenShortestSide] is still a tablet's.
class LargeScreenScope extends InheritedWidget {
  const LargeScreenScope({
    super.key,
    required this.large,
    required super.child,
  });

  final bool large;

  static bool? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LargeScreenScope>()?.large;

  @override
  bool updateShouldNotify(LargeScreenScope oldWidget) =>
      large != oldWidget.large;
}

/// Static utility class for orientation-related operations
class OrientationUtils {
  /// Gets the current orientation from the given context
  static Orientation getCurrentOrientation(BuildContext context) {
    return MediaQuery.of(context).orientation;
  }

  /// Returns true if the current orientation is portrait
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Returns true if the current orientation is landscape
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }
}

/// Comprehensive context extensions for common Flutter patterns
extension ContextExtensions on BuildContext {
  // ===== THEME & STYLING =====

  /// Gets the current theme
  ThemeData get theme => Theme.of(this);

  /// Gets the current color scheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Gets the current text theme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Gets the scaffold background color
  Color get scaffoldColor => Theme.of(this).scaffoldBackgroundColor;

  /// Gets body small text color (commonly used for secondary text)
  Color? get bodySmallColor => Theme.of(this).textTheme.bodySmall?.color;

  /// Gets the app's custom semantic colors. A theme built without them (a
  /// bare MaterialApp, a test) gets the ONSET palette for its brightness
  /// instead of a crash.
  FrostyColors get frostyColors {
    final theme = Theme.of(this);
    return theme.extension<FrostyColors>() ??
        (theme.brightness == Brightness.dark
            ? FrostyColors.dark
            : FrostyColors.light);
  }

  /// Gets the app's monospace metadata and wide-tracked label styles, with
  /// the same fallback as [frostyColors].
  FrostyTextStyles get frostyText =>
      Theme.of(this).extension<FrostyTextStyles>() ??
      FrostyTextStyles.resolve(frostyColors.metadata);

  /// Gets the default text style
  TextStyle get defaultTextStyle => DefaultTextStyle.of(this).style;

  // ===== SCREEN & LAYOUT =====

  /// Gets the screen width
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Gets the screen height
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Tablet-sized window (both sides at least 600 dp). A split-screen half
  /// narrower than that keeps the phone layouts.
  bool get isLargeScreen =>
      LargeScreenScope.maybeOf(this) ??
      isLargeScreenSize(MediaQuery.sizeOf(this));

  /// Gets the safe area padding top (commonly used)
  double get safePaddingTop => MediaQuery.of(this).padding.top;

  /// Gets the safe area padding bottom (commonly used)
  double get safePaddingBottom => MediaQuery.of(this).padding.bottom;

  // ===== PROVIDER ACCESS =====

  /// Gets TwitchApi from provider
  TwitchApi get twitchApi => read<TwitchApi>();

  /// Gets AuthStore from provider
  AuthStore get authStore => read<AuthStore>();

  /// Gets SettingsStore from provider
  SettingsStore get settingsStore => read<SettingsStore>();

  /// Gets FFZApi from provider
  FFZApi get ffzApi => read<FFZApi>();

  /// Gets BTTVApi from provider
  BTTVApi get bttvApi => read<BTTVApi>();

  /// Gets SevenTVApi from provider
  SevenTVApi get sevenTVApi => read<SevenTVApi>();

  /// Gets TwitchVodService from provider
  TwitchVodService get twitchVodService => read<TwitchVodService>();

  /// Clips from anonymous GQL.
  TwitchClipService get twitchClipService => read<TwitchClipService>();

  /// Channel profiles and schedules from anonymous GQL.
  TwitchChannelProfileService get twitchChannelProfileService =>
      read<TwitchChannelProfileService>();

  /// Sorted and tagged directories from anonymous GQL.
  TwitchDirectoryService get twitchDirectoryService =>
      read<TwitchDirectoryService>();

  /// Polls, predictions and pinned messages from anonymous GQL.
  TwitchCommunityHighlightsService get twitchCommunityHighlightsService =>
      read<TwitchCommunityHighlightsService>();

  /// Hype train snapshots from anonymous GQL.
  TwitchHypeTrainService get twitchHypeTrainService =>
      read<TwitchHypeTrainService>();

  /// The shared anonymous realtime connection (Hermes).
  TwitchRealtimeClient get realtimeClient => read<TwitchRealtimeClient>();

  /// Gets GlobalAssetsStore from provider
  GlobalAssetsStore get globalAssetsStore => read<GlobalAssetsStore>();

  /// Gets the global in-app MiniPlayerStore from provider
  MiniPlayerStore get miniPlayerStore => read<MiniPlayerStore>();

  // ===== ORIENTATION =====

  /// Returns true if currently in portrait orientation
  bool get isPortrait => OrientationUtils.isPortrait(this);

  /// Returns true if currently in landscape orientation
  bool get isLandscape => OrientationUtils.isLandscape(this);
}

/// TextScaler extensions for common scaling operations
extension TextScalerExtensions on double {
  /// Creates a linear text scaler with this scale factor
  TextScaler get textScaler => TextScaler.linear(this);
}
