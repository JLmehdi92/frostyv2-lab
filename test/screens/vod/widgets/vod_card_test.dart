import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';

Vod _vod({
  bool recording = false,
  bool restricted = false,
  String? thumbnail,
}) => Vod(
  id: '1',
  title: 'Speedrun attempts',
  lengthSeconds: 3725,
  createdAt: DateTime.now().subtract(const Duration(days: 2)),
  viewCount: 1500,
  ownerId: '42',
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
  gameName: 'Celeste',
  previewThumbnailUrl: thumbnail,
  isRecording: recording,
  isRestricted: restricted,
);

void main() {
  Future<void> pump(WidgetTester tester, Widget card) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));

  testWidgets('shows length, title, category and details', (tester) async {
    await pump(tester, VodCard(vod: _vod(), onTap: () {}));

    expect(find.text('1:02:05'), findsOneWidget);
    expect(find.text('Speedrun attempts'), findsOneWidget);
    expect(find.text('Celeste'), findsOneWidget);
    expect(find.text('2 days ago · 1,500 views'), findsOneWidget);
    expect(
      find.byIcon(Icons.video_library_outlined),
      findsOneWidget,
      reason: 'no thumbnail yet',
    );
  });

  testWidgets('in a category list it names the channel instead', (
    tester,
  ) async {
    await pump(tester, VodCard(vod: _vod(), showChannel: true, onTap: () {}));
    expect(find.text('Streamer'), findsOneWidget);
    expect(find.text('Celeste'), findsNothing);
  });

  testWidgets('flags a recording and a subscriber-only video', (tester) async {
    await pump(
      tester,
      VodCard(vod: _vod(recording: true, restricted: true), onTap: () {}),
    );

    expect(find.text('Recording'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.text('Subscribers only'), findsOneWidget);
  });

  testWidgets('a processing thumbnail shows the placeholder', (tester) async {
    await pump(
      tester,
      VodCard(
        vod: _vod(
          thumbnail:
              'https://vod-secure.twitch.tv/_404/404_processing_320x180.png',
        ),
        onTap: () {},
      ),
    );

    expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);
  });

  testWidgets('shows resume progress and watched', (tester) async {
    await pump(
      tester,
      VodCard(vod: _vod(), progress: 0.25, watched: true, onTap: () {}),
    );

    expect(find.text('Watched'), findsOneWidget);
    final bar = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(bar.widthFactor, 0.25);
  });

  testWidgets('tapping opens the video', (tester) async {
    var taps = 0;
    await pump(tester, VodCard(vod: _vod(), onTap: () => taps++));

    await tester.tap(find.text('Speedrun attempts'));

    expect(taps, 1);
  });

  testWidgets('fits a tablet grid column with large text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1600 / 3,
                child: VodCard(vod: _vod(), onTap: () {}),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
