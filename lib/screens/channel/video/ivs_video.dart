import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/channel/video/stores/ivs_video_store.dart';

/// Renders the native Amazon IVS player for an [IvsVideoStore]. Waits for the
/// usher URL to resolve, then hosts the native `PlayerView` via Hybrid
/// Composition (required because IVS renders into a SurfaceView).
class IvsVideo extends StatelessWidget {
  final IvsVideoStore videoStore;

  const IvsVideo({super.key, required this.videoStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final url = videoStore.url;
        if (url == null) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _IvsPlatformView(
          url: url,
          onCreated: videoStore.attachPlatformView,
        );
      },
    );
  }
}

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
          ],
        );
      },
    );
  }
}

class _IvsPlatformView extends StatelessWidget {
  final String url;
  final void Function(int id) onCreated;

  const _IvsPlatformView({required this.url, required this.onCreated});

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{'url': url};
    return PlatformViewLink(
      viewType: 'frosty/ivs-player',
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        return PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: 'frosty/ivs-player',
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () => params.onFocusChanged(true),
          )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..addOnPlatformViewCreatedListener(onCreated)
          ..create();
      },
    );
  }
}
