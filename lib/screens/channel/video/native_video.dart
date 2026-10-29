import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:onset/screens/channel/video/stores/native_video_store.dart';

/// Renders the native low-latency video surface for a [NativeVideoStore].
///
/// ONSET draws its own overlay on top, so the built-in media_kit controls are
/// disabled here ([NoVideoControls]).
class NativeVideo extends StatelessWidget {
  final NativeVideoStore videoStore;

  const NativeVideo({super.key, required this.videoStore});

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: videoStore.videoController,
      controls: NoVideoControls,
    );
  }
}
