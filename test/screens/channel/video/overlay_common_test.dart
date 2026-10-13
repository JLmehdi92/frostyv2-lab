import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/overlay_common.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('landscapeOrientations', () {
    const left = DeviceOrientation.landscapeLeft;
    const right = DeviceOrientation.landscapeRight;

    test('a phone locks the side it is tilted to', () {
      expect(
        landscapeOrientations(
          NativeDeviceOrientation.landscapeLeft,
          largeScreen: false,
          isIOS: false,
        ),
        [left],
      );
      expect(
        landscapeOrientations(
          NativeDeviceOrientation.landscapeRight,
          largeScreen: false,
          isIOS: true,
        ),
        [left],
      );
      expect(
        landscapeOrientations(
          NativeDeviceOrientation.portraitUp,
          largeScreen: false,
          isIOS: false,
        ),
        [left],
      );
    });

    test('a large screen allows both sides, so turning it over works', () {
      for (final tilt in NativeDeviceOrientation.values) {
        expect(landscapeOrientations(tilt, largeScreen: true, isIOS: false), [
          left,
          right,
        ], reason: '$tilt');
      }
    });
  });

  group('live screen buttons', () {
    test('a phone rotates in portrait and exits in landscape', () {
      expect(
        liveScreenButtons(landscape: false, largeScreen: false, iPad: false),
        (rotate: true, fullScreen: false),
      );
      expect(
        liveScreenButtons(landscape: true, largeScreen: false, iPad: false),
        (rotate: true, fullScreen: true),
      );
    });

    test('a large screen never shows the rotate button', () {
      for (final landscape in [false, true]) {
        expect(
          liveScreenButtons(
            landscape: landscape,
            largeScreen: true,
            iPad: false,
          ),
          (rotate: false, fullScreen: true),
        );
      }
    });

    test('an iPad keeps hiding rotate', () {
      expect(
        liveScreenButtons(landscape: false, largeScreen: false, iPad: true),
        (rotate: false, fullScreen: false),
      );
    });
  });

  group('toggleLargeScreenFullScreen', () {
    late List<MethodCall> calls;

    setUp(() => SharedPreferences.setMockInitialValues({}));

    void recordPlatform(WidgetTester tester) {
      calls = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    Iterable<Object?> orientationRequests() => calls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .map((c) => c.arguments);

    testWidgets('hides the chat, then brings the side column back', (
      tester,
    ) async {
      recordPlatform(tester);
      final settings = SettingsStore.fromJson({})
        ..fullScreen = false
        ..fullScreenChatOverlay = true;

      toggleLargeScreenFullScreen(settings);
      expect(settings.fullScreen, isTrue);
      expect(settings.fullScreenChatOverlay, isFalse);

      toggleLargeScreenFullScreen(settings);
      expect(settings.fullScreen, isFalse);
    });

    testWidgets('never asks for portrait; leaving releases the lock', (
      tester,
    ) async {
      recordPlatform(tester);
      final settings = SettingsStore.fromJson({})..fullScreen = false;

      toggleLargeScreenFullScreen(settings);
      toggleLargeScreenFullScreen(settings);
      await tester.pump();

      expect(orientationRequests(), [<String>[]]);
    });
  });

  group('overlayGradient', () {
    test('fades from black to transparent with the live stops', () {
      final gradient =
          overlayGradient(fromTop: true).gradient! as LinearGradient;

      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
      expect(gradient.stops, [0.0, 0.25, 0.5, 0.8, 1.0]);
      expect(gradient.colors, const [
        Colors.black,
        Color.fromRGBO(0, 0, 0, 0.78),
        Color.fromRGBO(0, 0, 0, 0.48),
        Color.fromRGBO(0, 0, 0, 0.12),
        Colors.transparent,
      ]);
    });

    test('the bottom gradient starts at the bottom', () {
      final gradient =
          overlayGradient(fromTop: false).gradient! as LinearGradient;

      expect(gradient.begin, Alignment.bottomCenter);
      expect(gradient.end, Alignment.topCenter);
    });
  });

  group('VolumeRow', () {
    Future<void> pump(
      WidgetTester tester, {
      required bool muted,
      required double volume,
      VoidCallback? onToggleMute,
      ValueChanged<double>? onVolumeChanged,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VolumeRow(
            muted: muted,
            volume: volume,
            onToggleMute: onToggleMute ?? () {},
            onVolumeChanged: onVolumeChanged ?? (_) {},
          ),
        ),
      ),
    );

    testWidgets('shows the silent icon when muted or at zero', (tester) async {
      await pump(tester, muted: true, volume: 1);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.byTooltip('Unmute'), findsOneWidget);

      await pump(tester, muted: false, volume: 0);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.byTooltip('Mute'), findsOneWidget);

      await pump(tester, muted: false, volume: 0.5);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('calls back on tap and slide', (tester) async {
      var toggles = 0;
      double? volume;
      await pump(
        tester,
        muted: false,
        volume: 0.5,
        onToggleMute: () => toggles++,
        onVolumeChanged: (v) => volume = v,
      );

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.drag(find.byType(Slider), const Offset(-1000, 0));

      expect(toggles, 1);
      expect(volume, 0);
    });
  });
}
