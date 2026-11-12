import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/overlay_common.dart';

void main() {
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
