import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/captions.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/caption_style_setting.dart';

void main() {
  testWidgets('captions on, then their size and background', (tester) async {
    final store = SettingsStore.fromJson({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(children: [CaptionStyleSetting(settingsStore: store)]),
        ),
      ),
    );

    await tester.tap(find.text('Closed Captions'));
    await tester.pump();
    expect(store.showCaptions, isTrue);

    expect(find.text('Caption size'), findsOneWidget);
    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    expect(store.captionSize, CaptionSize.large);

    expect(find.text('Caption background'), findsOneWidget);
    await tester.tap(find.text('Translucent'));
    await tester.pumpAndSettle();
    expect(store.captionBackground, CaptionBackground.translucent);

    // A sample line shows the chosen style.
    final sample = tester.widget<CaptionText>(find.byType(CaptionText));
    expect(sample.size, CaptionSize.large);
    expect(sample.background, CaptionBackground.translucent);
  });

  test('resetting video settings restores the caption style', () {
    final store = SettingsStore.fromJson({})
      ..captionSize = CaptionSize.small
      ..captionBackground = CaptionBackground.none
      ..captionLanguage = 'es';
    store.resetVideoSettings();
    expect(store.captionSize, CaptionSize.medium);
    expect(store.captionBackground, CaptionBackground.black);
    expect(store.captionLanguage, '');
  });

  test('the style survives a restart', () {
    final store = SettingsStore.fromJson({})
      ..captionSize = CaptionSize.extraLarge
      ..captionBackground = CaptionBackground.none;
    final again = SettingsStore.fromJson(store.toJson());
    expect(again.captionSize, CaptionSize.extraLarge);
    expect(again.captionBackground, CaptionBackground.none);
  });
}
