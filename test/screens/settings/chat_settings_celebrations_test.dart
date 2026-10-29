import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/settings/chat_settings.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';

void main() {
  test('celebrations play over the video by default, also for old saves', () {
    expect(
      SettingsStore.fromJson({}).celebrationsOnVideo,
      CelebrationsOnVideo.full,
    );
    // A value this build does not know reads as the default.
    expect(
      SettingsStore.fromJson({
        'celebrationsOnVideo': 'sparkly',
      }).celebrationsOnVideo,
      CelebrationsOnVideo.full,
    );
    final store = SettingsStore.fromJson({})
      ..celebrationsOnVideo = CelebrationsOnVideo.subtle;
    expect(
      SettingsStore.fromJson(store.toJson()).celebrationsOnVideo,
      CelebrationsOnVideo.subtle,
    );
    store.resetChatSettings();
    expect(store.celebrationsOnVideo, CelebrationsOnVideo.full);
  });

  testWidgets('"Celebrations on video" sits under the celebrations switch', (
    tester,
  ) async {
    final store = SettingsStore.fromJson({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatSettings(settingsStore: store)),
      ),
    );

    final title = find.text('Celebrations on video');
    await tester.scrollUntilVisible(
      title,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.getTopLeft(title).dy,
      greaterThan(tester.getTopLeft(find.text('Show celebrations')).dy),
    );

    await tester.tap(find.text('Subtle'));
    await tester.pumpAndSettle();
    expect(store.celebrationsOnVideo, CelebrationsOnVideo.subtle);

    await tester.tap(find.text('Full'));
    await tester.pumpAndSettle();
    expect(store.celebrationsOnVideo, CelebrationsOnVideo.full);

    // Nothing to choose while celebrations are off.
    store.showCelebrations = false;
    await tester.pumpAndSettle();
    expect(title, findsNothing);
  });
}
