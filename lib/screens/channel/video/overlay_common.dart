import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

/// Scrim behind the top or bottom controls of a video overlay (live and
/// VOD), dark at the edge and clear towards the middle of the video.
BoxDecoration overlayGradient({required bool fromTop}) => BoxDecoration(
  gradient: LinearGradient(
    begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
    end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
    colors: const [
      Colors.black,
      Color.fromRGBO(0, 0, 0, 0.78),
      Color.fromRGBO(0, 0, 0, 0.48),
      Color.fromRGBO(0, 0, 0, 0.12),
      Colors.transparent,
    ],
    stops: const [0.0, 0.25, 0.5, 0.8, 1.0],
  ),
);

/// Rotates to landscape, picking the side that matches how the device is
/// physically tilted. On a [largeScreen] both sides stay allowed, so a
/// tablet turned over (or lying flat) is never upside down.
Future<void> enterLandscape({bool largeScreen = false}) async {
  final physicalOrientation = await NativeDeviceOrientationCommunicator()
      .orientation(useSensor: true);
  await SystemChrome.setPreferredOrientations(
    landscapeOrientations(
      physicalOrientation,
      largeScreen: largeScreen,
      isIOS: Platform.isIOS,
    ),
  );
}

/// The orientations [enterLandscape] locks for a physical tilt.
@visibleForTesting
List<DeviceOrientation> landscapeOrientations(
  NativeDeviceOrientation physical, {
  required bool largeScreen,
  required bool isIOS,
}) {
  const left = DeviceOrientation.landscapeLeft;
  const right = DeviceOrientation.landscapeRight;
  if (largeScreen) return const [left, right];
  return switch (physical) {
    NativeDeviceOrientation.landscapeLeft => [isIOS ? right : left],
    NativeDeviceOrientation.landscapeRight => [isIOS ? left : right],
    // Sensor can't tell which way (e.g. flat on a desk): force a specific
    // landscape so the rotation actually happens (a "both landscape" hint is
    // ignored by some OEMs when auto-rotate is locked).
    _ => const [left],
  };
}

/// The full-screen button on a large screen in landscape: switches between
/// the side chat and the video alone, without rotating. A tablet is turned
/// by hand, and Android 16 ignores orientation requests on large screens.
void toggleLargeScreenFullScreen(SettingsStore settings) {
  if (settings.fullScreen) {
    settings.fullScreen = false;
    releaseOrientationLock();
  } else {
    settings
      ..fullScreen = true
      ..fullScreenChatOverlay = false;
  }
}

/// Gives back the rotation a full-screen tap may have locked to landscape.
/// On a large screen, called whenever full screen is left (button or
/// double-tap), so the tablet can be turned back to portrait.
void releaseOrientationLock() => SystemChrome.setPreferredOrientations([]);

/// After a portrait full-screen tap on a large screen: Android 16 ignores
/// rotation requests there (targetSdk 36), and a split-screen window cannot
/// rotate. When the window is still portrait after [wait], runs [undo],
/// releases the lock and asks the viewer to turn the tablet, so the button
/// never looks stuck.
Future<void> undoIfStillPortrait(
  BuildContext context, {
  required VoidCallback undo,
  Duration wait = const Duration(milliseconds: 1500),
}) async {
  await Future<void>.delayed(wait);
  if (!context.mounted ||
      MediaQuery.orientationOf(context) != Orientation.portrait) {
    return;
  }
  undo();
  releaseOrientationLock();
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(
      content: Text('Turn your tablet to landscape for full screen'),
    ),
  );
}

/// Which of the rotate and full-screen buttons a live overlay shows. A large
/// screen drops rotate (turned by hand) and keeps full screen in portrait
/// too; an iPad cannot be rotated by the app at all.
({bool rotate, bool fullScreen}) liveScreenButtons({
  required bool landscape,
  required bool largeScreen,
  required bool iPad,
}) => (rotate: !iPad && !largeScreen, fullScreen: landscape || largeScreen);

/// Returns to portrait and then releases the orientation lock.
void exitToPortrait() {
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setPreferredOrientations([]);
}

/// Mute button and volume slider of the player settings sheet.
class VolumeRow extends StatelessWidget {
  const VolumeRow({
    super.key,
    required this.muted,
    required this.volume,
    required this.onToggleMute,
    required this.onVolumeChanged,
  });

  final bool muted;
  final double volume;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      children: [
        IconButton(
          tooltip: muted ? 'Unmute' : 'Mute',
          icon: Icon(
            muted || volume == 0
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
          ),
          onPressed: onToggleMute,
        ),
        Expanded(
          child: Slider.adaptive(
            value: volume,
            divisions: 20,
            onChanged: onVolumeChanged,
          ),
        ),
      ],
    ),
  );
}

/// Names the tap surface over a player for screen readers: what a tap
/// does, and the double-tap gestures (named by [actions]) as actions they
/// can pick, since a double tap is how a screen reader activates.
class VideoSurfaceSemantics extends StatelessWidget {
  const VideoSurfaceSemantics({
    super.key,
    required this.controlsVisible,
    this.actions = const {},
    required this.child,
  });

  /// Whether a tap would hide the controls rather than show them.
  final bool controlsVisible;

  final Map<String, VoidCallback> actions;

  /// The gesture surface; its tap is the one described.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Video player',
      onTapHint: controlsVisible ? 'hide controls' : 'show controls',
      customSemanticsActions: {
        for (final MapEntry(key: label, value: run) in actions.entries)
          CustomSemanticsAction(label: label): run,
      },
      child: child,
    );
  }
}
