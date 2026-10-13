import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/home/stream_list/large_stream_card.dart';
import 'package:frosty/screens/home/stream_list/stream_card.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/adaptive_sliver_list.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';

StreamTwitch _stream(int i) => StreamTwitch(
  '$i',
  'login$i',
  'Name $i',
  '1',
  'Game',
  'A fairly long stream title that wraps on narrow cards $i',
  10,
  '2026-10-13T15:00:00Z',
  'https://static-cdn.jtvnw.net/previews-ttv/live_user_login-{width}x{height}.jpg',
);

void main() {
  Future<void> pumpGrid(
    WidgetTester tester,
    Size size,
    double maxItemWidth,
    Widget Function(StreamTwitch) card, {
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [FrostyColors.light]),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  AdaptiveSliverList(
                    maxItemWidth: maxItemWidth,
                    itemCount: 7,
                    itemBuilder: (_, i) => card(_stream(i)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final size in const [Size(1600, 1067), Size(1067, 1600)]) {
    testWidgets('row cards share a row at $size', (tester) async {
      await pumpGrid(
        tester,
        size,
        AdaptiveSliverList.rowCardWidth,
        (s) => StreamCard(streamInfo: s, showThumbnail: true),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      final first = tester.getTopLeft(find.text('Name 0'));
      final second = tester.getTopLeft(find.text('Name 1'));
      expect(second.dy, first.dy);
      expect(second.dx, greaterThan(first.dx));
    });

    testWidgets('large cards share a row at $size', (tester) async {
      await pumpGrid(
        tester,
        size,
        AdaptiveSliverList.tileCardWidth,
        (s) => LargeStreamCard(streamInfo: s, showThumbnail: true),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('Name 1')).dy,
        tester.getTopLeft(find.text('Name 0')).dy,
      );
    });
  }

  int requestedWidth(WidgetTester tester) {
    final image = tester.widget<FrostyCachedNetworkImage>(
      find.byType(FrostyCachedNetworkImage).first,
    );
    final size = RegExp(r'-(\d+)x(\d+)\.jpg').firstMatch(image.imageUrl)!;
    expect(image.memCacheWidth, int.parse(size[1]!));
    expect(image.cacheKey, endsWith('-${size[1]}'));
    return int.parse(size[1]!);
  }

  testWidgets('grid thumbnails are fetched at their drawn size', (
    tester,
  ) async {
    await pumpGrid(
      tester,
      const Size(1600, 1067),
      AdaptiveSliverList.rowCardWidth,
      (s) => StreamCard(streamInfo: s, showThumbnail: true),
    );
    // A third of a 533 dp card, not a third of the 1600 dp screen.
    expect(requestedWidth(tester), lessThanOrEqualTo(320));

    await pumpGrid(
      tester,
      const Size(1600, 1067),
      AdaptiveSliverList.tileCardWidth,
      (s) => LargeStreamCard(streamInfo: s, showThumbnail: true),
    );
    expect(requestedWidth(tester), lessThanOrEqualTo(480));
  });
}
