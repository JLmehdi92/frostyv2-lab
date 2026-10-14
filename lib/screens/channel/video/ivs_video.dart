import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/channel/video/captions.dart';
import 'package:frosty/screens/channel/video/quality_selection.dart';
import 'package:frosty/screens/channel/video/stores/ivs_video_store.dart';

/// Renders the IVS player into a Flutter [Texture] (instead of a SurfaceView)
/// so it can be dragged and animated smoothly. The texture is owned by the
/// [IvsVideoStore] (created as soon as the stream is opened), so the same live
/// player can move between the channel screen and the mini player without
/// reloading.
class IvsTextureVideo extends StatelessWidget {
  final IvsVideoStore videoStore;

  const IvsTextureVideo({super.key, required this.videoStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final id = videoStore.textureId;
        if (id == null) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        // Keep the 16:9 aspect ratio (never distort the picture) and either
        // fit it inside the box (letterbox bars) or fill the box (cropping a
        // little off the edges), per the fill-screen toggle. Sized explicitly
        // in real pixels — a FittedBox around a Texture renders black.
        final fill = videoStore.fillScreen;
        final busy =
            videoStore.status == IvsPlaybackStatus.loading ||
            videoStore.status == IvsPlaybackStatus.reconnecting;
        final picture = ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const aspect = 16 / 9;
              final boxW = constraints.maxWidth;
              final boxH = constraints.maxHeight;
              final boxNarrowerThanVideo = boxW / boxH < aspect;
              // contain → limited by the tighter side; cover → by the looser.
              final limitByWidth = fill
                  ? !boxNarrowerThanVideo
                  : boxNarrowerThanVideo;
              final width = limitByWidth ? boxW : boxH * aspect;
              final height = limitByWidth ? boxW / aspect : boxH;
              // OverflowBox lets the (centered) video exceed the box when
              // filling so the cropped edges aren't clamped away.
              return OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Texture(textureId: id),
                ),
              );
            },
          ),
        );
        // Always the same Stack so toggling the spinner never rebuilds the
        // Texture subtree.
        return Stack(
          fit: StackFit.expand,
          children: [
            picture,
            if (busy) const Center(child: CircularProgressIndicator()),
            if (videoStore.streamQuality == kAudioOnlyQuality)
              const Center(child: _AudioOnlyBadge()),
            if (videoStore.caption case final caption?)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: IgnorePointer(
                  child: Center(child: CaptionText(text: caption)),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Shown over the last picture while only the sound plays.
class _AudioOnlyBadge extends StatelessWidget {
  const _AudioOnlyBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Icon(Icons.headphones_rounded, color: Colors.white),
            Text('Audio only', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
