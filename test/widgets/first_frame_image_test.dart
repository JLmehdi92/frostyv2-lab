import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/widgets/first_frame_image.dart';

/// A 4x2 GIF of two frames, red then blue, 20 ms each, looping.
final _twoFrames = MemoryImage(
  base64Decode(
    'R0lGODlhBAACAIEAAP8AAAAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQAAgAAACwA'
    'AAAABAACAAAIBwABCBwoMCAAIfkEAQIAAQAsAAAAAAQAAgCBAAD/AAAAAAAAAAAACAcAAQgc'
    'KDAgADs=',
  ),
);

/// The top-left pixel of [image] as 0xRRGGBBAA.
Future<int> _firstPixel(ui.Image image) async {
  final bytes = (await image.toByteData())!;
  return bytes.getUint32(0);
}

void main() {
  /// The frames [provider] gives while the clock runs for about [time].
  Future<List<ImageInfo>> framesOf(
    WidgetTester tester,
    ImageProvider provider, {
    Duration time = const Duration(milliseconds: 600),
  }) async {
    // Each test decodes the GIF afresh, from its first frame.
    imageCache
      ..clear()
      ..clearLiveImages();
    final frames = <ImageInfo>[];
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) => frames.add(info));
    stream.addListener(listener);
    // Decoding runs on real time; an animation moves on scheduler frames.
    const step = Duration(milliseconds: 20);
    for (var spent = Duration.zero; spent < time; spent += step) {
      await tester.runAsync(() => Future<void>.delayed(step));
      await tester.pump(step);
    }
    stream.removeListener(listener);
    return frames;
  }

  testWidgets('the GIF itself moves on to its second frame', (tester) async {
    final frames = await framesOf(tester, _twoFrames);

    expect(frames.length, greaterThan(1));
  });

  testWidgets('gives the first frame once and nothing after', (tester) async {
    final frames = await framesOf(tester, FirstFrameImage(_twoFrames));

    expect(frames, hasLength(1));
    expect(frames.single.image.width, 4);
    final pixel = await tester.runAsync(() => _firstPixel(frames.single.image));
    expect(pixel, 0xFF0000FF);
  });

  testWidgets('reports a decoding error', (tester) async {
    await tester.runAsync(() async {
      Object? error;
      final stream = FirstFrameImage(
        MemoryImage(base64Decode('AAAA')),
      ).resolve(ImageConfiguration.empty);
      stream.addListener(
        ImageStreamListener((_, _) {}, onError: (e, _) => error = e),
      );

      for (var i = 0; i < 50 && error == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(error, isNotNull);
    });
  });

  test('two wrappers of the same image are equal', () {
    expect(FirstFrameImage(_twoFrames), FirstFrameImage(_twoFrames));
    expect(
      FirstFrameImage(_twoFrames).hashCode,
      FirstFrameImage(_twoFrames).hashCode,
    );
  });
}
