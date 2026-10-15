import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/player_media.dart';
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

String _clipLink(Duration _) => 'https://clips.twitch.tv/Slug';

void main() {
  late FakeVodController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    controller = FakeVodController();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1600, 900),
    VoidCallback? onCycleChatMode,
    SettingsStore? settings,
    bool isLandscape = false,
    PlayerMedia? media,
    bool skipButtons = true,
    bool? looping,
    VoidCallback? onToggleLoop,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: VodOverlay(
              controller: controller,
              media: media ?? PlayerMedia.vod(_vod),
              settings: settings ?? SettingsStore.fromJson({}),
              skipButtons: skipButtons,
              looping: looping,
              onToggleLoop: onToggleLoop,
              onCycleChatMode: onCycleChatMode,
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

  group('other media (clips)', () {
    const clipMedia = PlayerMedia(
      title: 'breakup advice',
      ownerId: '1',
      ownerLogin: 'xqc',
      ownerDisplayName: 'xQc',
      shareLabel: 'Copy clip link',
      shareLink: _clipLink,
    );

    testWidgets('without skip buttons, a side double tap plays/pauses', (
      tester,
    ) async {
      controller.overlayVisible = false;
      await pump(tester, media: clipMedia, skipButtons: false);

      expect(find.text('breakup advice'), findsOneWidget);
      expect(find.byTooltip('Back 10 seconds'), findsNothing);
      expect(find.byTooltip('Forward 10 seconds'), findsNothing);

      await tester.tapAt(const Offset(100, 450));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(100, 450));
      await tester.pump();
      expect(controller.calls, isNot(contains('seekBy -10')));
      expect(controller.calls, contains('togglePlay'));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('the loop button shows its state and toggles', (tester) async {
      var toggles = 0;
      await pump(
        tester,
        media: clipMedia,
        skipButtons: false,
        looping: false,
        onToggleLoop: () => toggles++,
      );

      await tester.tap(find.byTooltip('Loop'));
      expect(toggles, 1);

      await pump(
        tester,
        media: clipMedia,
        skipButtons: false,
        looping: true,
        onToggleLoop: () {},
      );
      expect(find.byTooltip('Stop looping'), findsOneWidget);
    });

    testWidgets('a VOD has no loop button', (tester) async {
      await pump(tester);
      expect(find.byTooltip('Loop'), findsNothing);
    });

    testWidgets('settings copy the media link', (tester) async {
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
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pump(tester, media: clipMedia, skipButtons: false);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Copy clip link'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Copy clip link'));
      await tester.pumpAndSettle();

      expect(clipboard, ['https://clips.twitch.tv/Slug']);
    });
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

  group('small screens', () {
    const phone = Size(360, 203);

    testWidgets('a long video at 1.5x fits a 360 wide player', (tester) async {
      controller
        ..duration = const Duration(hours: 4)
        ..position = const Duration(hours: 1, minutes: 23, seconds: 45);
      controller.setPlaybackRate(1.5);
      await pump(tester, size: phone);

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Full screen'), findsOneWidget);
    });

    testWidgets('the play button is not covered by the seek bar', (
      tester,
    ) async {
      await pump(tester, size: phone);
      final play = tester.getRect(find.byTooltip('Play'));

      await tester.tapAt(play.bottomCenter - const Offset(0, 6));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(play.topCenter + const Offset(0, 6));
      await tester.pump(const Duration(milliseconds: 400));

      expect(controller.calls, ['togglePlay', 'togglePlay']);
    });

    testWidgets('a tap on the gradient band reaches the video', (tester) async {
      await pump(tester, size: phone);

      // The top band, right of the title, where no button is.
      await tester.tapAt(const Offset(250, 30));
      await tester.pump(const Duration(milliseconds: 400));

      expect(controller.calls, contains('tap'));
    });
  });

  testWidgets('in landscape the middle double tap cycles the chat mode', (
    tester,
  ) async {
    var cycles = 0;
    controller.overlayVisible = false;
    await pump(tester, onCycleChatMode: () => cycles++);

    // The middle third, above the centre buttons.
    await tester.tapAt(const Offset(800, 250));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(800, 250));
    await tester.pump();

    expect(cycles, 1);
    expect(controller.calls, isNot(contains('togglePlay')));
    await tester.pump(const Duration(seconds: 1));
  });
}
