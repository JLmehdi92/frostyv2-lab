import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/third_party_cosmetics.dart';
import 'package:onset/screens/channel/chat/widgets/painted_name.dart';

class _FrameProvider extends ImageProvider<_FrameProvider> {
  _FrameProvider(this.completer);

  final _Completer completer;

  @override
  Future<_FrameProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _FrameProvider key,
    ImageDecoderCallback decode,
  ) => completer;
}

class _Completer extends ImageStreamCompleter {
  void frame(ui.Image image) => setImage(ImageInfo(image: image.clone()));
}

void main() {
  testWidgets('the paint image handles it gets are released', (tester) async {
    final image = await tester.runAsync(() => createTestImage());
    final completer = _Completer();
    int open() => image!.debugGetOpenHandleStackTraces()!.length;
    final before = open();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PaintedName(
          text: 'Fan',
          paint: const NamePaint(
            id: 'p',
            kind: NamePaintKind.image,
            imageUrl: 'https://example.com/paint.webp',
          ),
          style: const TextStyle(fontSize: 14),
          imageProviderFor: (_) => _FrameProvider(completer),
        ),
      ),
    );
    completer
      ..frame(image!)
      ..frame(image);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    imageCache
      ..clear()
      ..clearLiveImages();
    await tester.pump();

    expect(open(), before + 1);
  });
}
