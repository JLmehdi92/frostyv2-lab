import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/video_settings.dart';

void main() {
  testWidgets('Video Autoplaying offers Twitch\'s three choices', (
    tester,
  ) async {
    final store = SettingsStore.fromJson({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VideoSettings(settingsStore: store)),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Video Autoplaying'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Choose when videos should play automatically'),
      findsOneWidget,
    );
    for (final option in VodAutoplay.values) {
      expect(find.text(option.label), findsOneWidget);
    }

    await tester.tap(find.text('Wi-Fi Only'));
    await tester.pumpAndSettle();
    expect(store.vodAutoplay, VodAutoplay.wifiOnly);

    await tester.tap(find.text('Never'));
    await tester.pumpAndSettle();
    expect(store.vodAutoplay, VodAutoplay.never);
  });
}
