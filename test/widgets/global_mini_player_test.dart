import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:frosty/screens/channel/video/ivs_video.dart';
import 'package:frosty/screens/channel/video/stores/ivs_video_store.dart';
import 'package:frosty/stores/mini_player_store.dart';
import 'package:frosty/widgets/global_mini_player.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockIvsVideoStore extends Mock implements IvsVideoStore {}

class MockChatTabsStore extends Mock implements ChatTabsStore {}

void main() {
  const phone = MediaQueryData(size: Size(390, 844));

  test("under the shell's header and above its bar (board MiniLecteur)", () {
    // Home's header (100) and the floating bar (14 + 64).
    final area = MiniWindowArea.of(
      phone,
      chrome: const EdgeInsets.only(top: 100, bottom: 78),
    );
    expect(area.window.width, closeTo(164, 0.5));
    expect(area.window.height, closeTo(92, 0.5));
    expect(area.top, 112);
    expect(area.bottom, closeTo(662, 0.5));
    expect(area.initial.dx, closeTo(214, 0.5));
    expect(area.initial.dy, 112);

    // Dragged anywhere, it snaps to the nearest corner inside.
    expect(area.snap(const Offset(20, 700)), Offset(12, area.bottom));
    expect(area.snap(const Offset(300, 120)), Offset(area.initial.dx, 112));
    // Never over the header or the bar.
    expect(area.clamp(const Offset(100, 0)).dy, 112);
    expect(area.clamp(const Offset(100, 900)).dy, area.bottom);
  });

  test('on any other page: under a standard app bar', () {
    final area = MiniWindowArea.of(
      phone.copyWith(padding: const EdgeInsets.only(top: 24, bottom: 16)),
    );
    expect(area.top, 24 + kToolbarHeight + 12);
    expect(area.bottom, closeTo(844 - 92.1375 - 16 - 12, 0.01));
  });

  test('a screen too short for both: the header wins', () {
    final area = MiniWindowArea.of(
      const MediaQueryData(size: Size(844, 390)),
      chrome: const EdgeInsets.only(top: 100, bottom: 78),
    );
    expect(area.bottom, area.top);
    expect(area.clamp(const Offset(0, 500)).dy, area.top);
  });

  test('the chrome changing keeps a corner a corner', () {
    final home = MiniWindowArea.of(
      phone,
      chrome: const EdgeInsets.only(top: 100, bottom: 78),
    );
    final profile = MiniWindowArea.of(
      phone,
      chrome: const EdgeInsets.only(top: 56, bottom: 78),
    );
    // A corner is kept as a corner: under each header, above the bar.
    final corner = profile.nearest(const Offset(300, 70));
    expect(corner, MiniCorner.topRight);
    expect(profile.at(corner).dy, 68);
    expect(home.at(corner).dy, 112);
    final low = home.nearest(const Offset(10, 700));
    expect(low, MiniCorner.bottomLeft);
    final page = MiniWindowArea.of(phone);
    // On a page without the bar the window goes back down to the edge.
    expect(page.at(low).dy, greaterThan(home.at(low).dy));
  });

  group('the window', () {
    Widget placed(Offset offset, {required bool glide}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          MiniWindowPlacement(
            offset: offset,
            glide: glide,
            child: const SizedBox(
              key: ValueKey('window'),
              width: 10,
              height: 10,
            ),
          ),
        ],
      ),
    );

    Offset at(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(const ValueKey('window')));

    testWidgets('glides to its corner when the chrome changes height', (
      tester,
    ) async {
      await tester.pumpWidget(placed(const Offset(200, 112), glide: true));
      expect(at(tester), const Offset(200, 112));
      // Home's header (100) to Browse's (108).
      await tester.pumpWidget(placed(const Offset(200, 120), glide: true));
      await tester.pump(MiniWindowPlacement.glideDuration ~/ 3);
      expect(at(tester).dy, inExclusiveRange(112, 120));
      await tester.pumpAndSettle();
      expect(at(tester), const Offset(200, 120));
    });

    testWidgets('follows a drag directly', (tester) async {
      await tester.pumpWidget(placed(const Offset(200, 112), glide: false));
      await tester.pumpWidget(placed(const Offset(150, 300), glide: false));
      // At once, in the very frame.
      expect(at(tester), const Offset(150, 300));
    });

    testWidgets('reduce motion: no glide', (tester) async {
      Widget reduced(Offset offset) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: placed(offset, glide: true),
      );
      await tester.pumpWidget(reduced(const Offset(200, 112)));
      await tester.pumpWidget(reduced(const Offset(200, 120)));
      await tester.pump();
      expect(at(tester), const Offset(200, 120));
    });
  });

  testWidgets('grabbed mid-glide, the window starts from where it is drawn', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const channel = MethodChannel('puntito.simple_pip_mode');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => true,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final mini = MiniPlayerStore();
    final player = MockIvsVideoStore();
    when(player.dispose).thenAnswer((_) async {});
    final chat = MockChatTabsStore();
    when(chat.dispose).thenReturn(null);
    mini
      ..setShellChrome(const EdgeInsets.only(top: 100, bottom: 78))
      ..adopt(
        player: player,
        chatTabsStore: chat,
        userLogin: 'a',
        userId: '1',
        displayName: 'A',
      );
    await tester.pumpWidget(
      Provider<MiniPlayerStore>.value(
        value: mini,
        child: const MaterialApp(
          home: Stack(children: [Positioned.fill(child: GlobalMiniPlayer())]),
        ),
      ),
    );
    await tester.pump();
    final window = find.byType(IvsTextureVideo).first;
    expect(tester.getTopLeft(window).dy, 112);

    // Profile's shorter header: the window glides up to 68.
    mini.setShellChrome(const EdgeInsets.only(top: 56, bottom: 78));
    await tester.pump();
    await tester.pump(MiniWindowPlacement.glideDuration ~/ 3);
    final drawn = tester.getTopLeft(window).dy;
    expect(drawn, inExclusiveRange(68, 112));

    // Grabbed there: it stays under the finger.
    final gesture = await tester.startGesture(tester.getCenter(window));
    await tester.pump();
    expect(tester.getTopLeft(window).dy, closeTo(drawn, 0.5));
    // Past the touch slop the drag is the window's: it moves from where it
    // was drawn, not from the glide's end point (68).
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(tester.getTopLeft(window).dy, closeTo(drawn, 0.5));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(tester.getTopLeft(window).dy, closeTo(drawn + 20, 0.5));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    mini.close();
    await tester.pump();
  });

  testWidgets('a drag lifts the window and shows where it can land, '
      'and close works (board MiniLecteur)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const channel = MethodChannel('puntito.simple_pip_mode');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => true,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final mini = MiniPlayerStore();
    final player = MockIvsVideoStore();
    when(player.dispose).thenAnswer((_) async {});
    final chat = MockChatTabsStore();
    when(chat.dispose).thenReturn(null);
    mini
      ..setShellChrome(const EdgeInsets.only(top: 100, bottom: 78))
      ..adopt(
        player: player,
        chatTabsStore: chat,
        userLogin: 'a',
        userId: '1',
        displayName: 'A',
      );
    await tester.pumpWidget(
      Provider<MiniPlayerStore>.value(
        value: mini,
        child: const MaterialApp(
          home: Stack(children: [Positioned.fill(child: GlobalMiniPlayer())]),
        ),
      ),
    );
    await tester.pump();
    final scale = find.byType(AnimatedScale);
    double scaleNow() => tester.widget<AnimatedScale>(scale).scale;
    final targets = find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString().contains('CornerTargets'),
    );
    expect(scaleNow(), 1);
    expect(targets, findsNothing);

    final window = find.byType(IvsTextureVideo).first;
    final gesture = await tester.startGesture(tester.getCenter(window));
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(scaleNow(), 1.04);
    expect(targets, findsOneWidget);

    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(scaleNow(), 1);
    expect(targets, findsNothing);

    await tester.tap(find.byTooltip('Close mini player'));
    await tester.pump();
    expect(mini.visible, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('drag releases do not pile up curved animations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const channel = MethodChannel('puntito.simple_pip_mode');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => true,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    // Every CurvedAnimation made from here on, until it is disposed.
    final alive = <Object>{};
    void track(ObjectEvent event) {
      if (event.object is! CurvedAnimation) return;
      if (event is ObjectCreated) alive.add(event.object);
      if (event is ObjectDisposed) alive.remove(event.object);
    }

    FlutterMemoryAllocations.instance.addListener(track);
    addTearDown(() => FlutterMemoryAllocations.instance.removeListener(track));
    final mini = MiniPlayerStore();
    final player = MockIvsVideoStore();
    when(player.dispose).thenAnswer((_) async {});
    final chat = MockChatTabsStore();
    when(chat.dispose).thenReturn(null);
    mini.adopt(
      player: player,
      chatTabsStore: chat,
      userLogin: 'a',
      userId: '1',
      displayName: 'A',
    );
    await tester.pumpWidget(
      Provider<MiniPlayerStore>.value(
        value: mini,
        child: const MaterialApp(
          home: Stack(children: [Positioned.fill(child: GlobalMiniPlayer())]),
        ),
      ),
    );
    await tester.pump();
    final window = find.byType(IvsTextureVideo).first;
    for (final move in const [Offset(-200, 300), Offset(200, -300)]) {
      for (var i = 0; i < 2; i++) {
        final gesture = await tester.startGesture(tester.getCenter(window));
        await gesture.moveBy(move / 2);
        await gesture.moveBy(move / 2);
        await gesture.up();
        await tester.pump(const Duration(seconds: 1));
      }
    }
    final whileShown = alive.length;
    mini.close();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(alive, isEmpty, reason: '$whileShown alive while it was shown');
  });

  test('the landing corners read over a dark stream and a light page', () {
    /// The contrast of [over] laid on [ground].
    double contrast(Color over, Color ground) {
      final drawn = Color.alphaBlend(over, ground);
      final a = drawn.computeLuminance();
      final b = ground.computeLuminance();
      return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
    }

    for (final nearest in [false, true]) {
      final strokes = cornerTargetStrokes(
        nearest: nearest,
        accent: const Color(0xFFC8FF3D),
      );
      final best = [
        for (final ground in const [
          Color(0xFF000000),
          Color(0xFFFFFFFF),
          Color(0xFFF8F8F8),
          Color(0xFF0A0A0A),
        ])
          strokes.map((stroke) => contrast(stroke.$1, ground)).reduce(math.max),
      ];
      for (final ratio in best) {
        expect(ratio, greaterThanOrEqualTo(1.8), reason: 'nearest $nearest');
      }
    }
  });
}
