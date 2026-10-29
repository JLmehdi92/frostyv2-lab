import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/overlay_common.dart';

void main() {
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
