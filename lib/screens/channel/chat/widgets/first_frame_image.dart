import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The first frame [inner] gives, and nothing after it: an animated GIF
/// drawn through it stays still.
///
/// That is the GIF's first frame, unless the same image is already playing
/// elsewhere in the app (the image cache shares it): then it is the frame
/// showing at that moment. Once that frame is in, it stops listening to
/// [inner], so the frames that follow are not decoded for this image.
@immutable
class FirstFrameImage extends ImageProvider<FirstFrameImage> {
  const FirstFrameImage(this.inner);

  final ImageProvider inner;

  @override
  Future<FirstFrameImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<FirstFrameImage>(this);

  @override
  ImageStreamCompleter loadImage(
    FirstFrameImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    _firstFrame(),
    informationCollector: () => [
      DiagnosticsProperty<ImageProvider>('Still image of', inner),
    ],
  );

  Future<ImageInfo> _firstFrame() {
    final frame = Completer<ImageInfo>();
    final stream = inner.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, _) {
        stream.removeListener(listener);
        if (frame.isCompleted) {
          image.dispose();
        } else {
          // The completer that draws it now owns the image.
          frame.complete(image);
        }
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        if (!frame.isCompleted) frame.completeError(error, stackTrace);
      },
    );
    stream.addListener(listener);
    return frame.future;
  }

  @override
  bool operator ==(Object other) =>
      other is FirstFrameImage && other.inner == inner;

  @override
  int get hashCode => Object.hash(FirstFrameImage, inner);

  @override
  String toString() => 'FirstFrameImage($inner)';
}
