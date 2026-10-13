import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/vod_overlay.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_vod_controller.dart';

final _vod = Vod(
  id: '1000000001',
  title: 'Morning stream',
  lengthSeconds: 3600,
  createdAt: DateTime.utc(2026, 10, 12),
  viewCount: 5,
  ownerId: '42',
  ownerLogin: '',
  ownerDisplayName: 'Streamer',
);

void main() {
  late FakeVodController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    controller = FakeVodController();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1600,
            height: 900,
            child: VodOverlay(
              controller: controller,
              vod: _vod,
              settings: SettingsStore.fromJson({}),
            ),
          ),
        ),
      ),
    );
  }

  test('share links carry the time in the Twitch format', () {
    expect(
      vodShareLink(_vod, const Duration(hours: 1, minutes: 2, seconds: 3)),
      'https://www.twitch.tv/videos/1000000001?t=1h2m3s',
    );
    expect(
      vodShareLink(_vod, Duration.zero),
      'https://www.twitch.tv/videos/1000000001',
    );
  });

  test('playback rates read like the official app', () {
    expect(formatPlaybackRate(1.25), '1.25×');
    expect(formatPlaybackRate(1.5), '1.5×');
    expect(formatPlaybackRate(2), '2×');
    expect(formatPlaybackRate(0.75), '0.75×');
  });

  testWidgets('shows the title and the elapsed time', (tester) async {
    await pump(tester);

    expect(find.text('Morning stream'), findsOneWidget);
    expect(find.text('10:00 / 1:00:00'), findsOneWidget);
  });

  testWidgets('centre buttons play and skip', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Play'));
    await tester.tap(find.byTooltip('Back 10 seconds'));
    await tester.tap(find.byTooltip('Forward 10 seconds'));

    expect(controller.calls, ['togglePlay', 'seekBy -10', 'seekBy 10']);
  });

  testWidgets('ended shows a replay button', (tester) async {
    controller.status = VodPlaybackStatus.ended;
    await pump(tester);

    expect(find.byTooltip('Replay'), findsOneWidget);
  });

  testWidgets('double tap on the sides skips with a badge', (tester) async {
    controller.overlayVisible = false;
    await pump(tester);

    await tester.tapAt(const Offset(100, 450));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(100, 450));
    await tester.pump();
    expect(controller.calls, contains('seekBy -10'));
    expect(find.text('−10 s'), findsOneWidget);

    await tester.tapAt(const Offset(1500, 450));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(1500, 450));
    await tester.pump();
    expect(controller.calls, contains('seekBy 10'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('+10 s'), findsNothing);
  });

  testWidgets('a single tap goes to the controller', (tester) async {
    controller.overlayVisible = false;
    await pump(tester);

    await tester.tapAt(const Offset(800, 450));
    await tester.pump(const Duration(milliseconds: 400));

    expect(controller.calls, ['tap']);
  });

  testWidgets('the speed chip appears off 1x', (tester) async {
    await pump(tester);
    expect(find.text('1.5×'), findsNothing);

    controller.setPlaybackRate(1.5);
    await tester.pump();

    expect(find.text('1.5×'), findsOneWidget);
  });

  testWidgets('settings set speed and quality and copy the link', (
    tester,
  ) async {
    final clipboard = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    await pump(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('1.25×'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('1.25×'));
    await tester.pumpAndSettle();
    expect(controller.calls, contains('rate 1.25'));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('720p60'));
    await tester.pumpAndSettle();
    expect(controller.calls, contains('quality 720p60'));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Copy link at current time'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Copy link at current time'));
    await tester.pumpAndSettle();
    expect(clipboard, ['https://www.twitch.tv/videos/1000000001?t=10m0s']);
  });
}
