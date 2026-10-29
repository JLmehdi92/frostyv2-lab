import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

/// The soft shadow under the live player's chrome (the boards'
/// `drop-shadow(0 1px 2px rgba(0,0,0,.6))`), so its text and glyphs read
/// over a bright picture where the scrim is thin.
const kPlayerChromeShadow = [
  Shadow(offset: Offset(0, 1), blurRadius: 2, color: Color(0x99000000)),
];

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
/// physically tilted (falls back to allowing both).
Future<void> enterLandscape() async {
  final physicalOrientation = await NativeDeviceOrientationCommunicator()
      .orientation(useSensor: true);
  final needsSwap = Platform.isIOS;
  if (physicalOrientation == NativeDeviceOrientation.landscapeLeft) {
    SystemChrome.setPreferredOrientations([
      needsSwap
          ? DeviceOrientation.landscapeRight
          : DeviceOrientation.landscapeLeft,
    ]);
  } else if (physicalOrientation == NativeDeviceOrientation.landscapeRight) {
    SystemChrome.setPreferredOrientations([
      needsSwap
          ? DeviceOrientation.landscapeLeft
          : DeviceOrientation.landscapeRight,
    ]);
  } else {
    // Sensor can't tell which way (e.g. tablet flat on a desk): force a
    // specific landscape so the rotation actually happens (a "both
    // landscape" hint is ignored by some OEMs when auto-rotate is locked).
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
  }
}

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
