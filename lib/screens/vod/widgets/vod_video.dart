import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/screens/channel/video/captions.dart';
import 'package:onset/screens/vod/stores/ivs_vod_store.dart';
import 'package:onset/screens/vod/vod_player_controller.dart';

/// Renders the IVS VOD player's texture, 16:9, fitted or filling the box
/// (never distorted), with a spinner while loading or buffering.
class VodVideo extends StatelessWidget {
  const VodVideo({super.key, required this.store, this.fillScreen = false});

  final IvsVodStore store;

  /// Crop to fill the box instead of letterboxing (tablets, 2K screens).
  final bool fillScreen;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final id = store.textureId;
        final busy =
            store.status == VodPlaybackStatus.loading ||
            store.status == VodPlaybackStatus.buffering;
        if (id == null) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        // Sized explicitly in real pixels: a FittedBox around a Texture
        // renders black.
        final picture = ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const aspect = 16 / 9;
              final boxW = constraints.maxWidth;
              final boxH = constraints.maxHeight;
              final boxNarrowerThanVideo = boxW / boxH < aspect;
              final limitByWidth = fillScreen
                  ? !boxNarrowerThanVideo
                  : boxNarrowerThanVideo;
              // Minimums zeroed: the Stack below passes tight constraints,
              // which would otherwise stretch a fitted picture over the bars.
              return OverflowBox(
                minWidth: 0,
                minHeight: 0,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: SizedBox(
                  width: limitByWidth ? boxW : boxH * aspect,
                  height: limitByWidth ? boxW / aspect : boxH,
                  child: Texture(textureId: id),
                ),
              );
            },
          ),
        );
        return ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              picture,
              if (busy) const Center(child: CircularProgressIndicator()),
              if (store.captions.caption case final caption?)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: IgnorePointer(
                    child: Center(
                      child: CaptionText(
                        text: caption,
                        size: store.settingsStore.captionSize,
                        background: store.settingsStore.captionBackground,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
