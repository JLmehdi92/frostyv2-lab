import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/chat/widgets/points_intro.dart';
import 'package:onset/screens/settings/chat_settings.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';
import 'package:onset/widgets/new_feature_pill.dart';

import '../../../helpers/l10n.dart';
import '../../settings/settings_harness.dart';

void main() {
  testWidgets('the intro dismisses and points to the explainer', (
    tester,
  ) async {
    var dismissed = false;
    var learned = false;
    await pumpLocalized(
      tester,
      locale: en,
      Scaffold(
        body: PointsIntroCard(
          onDismiss: () => dismissed = true,
          onLearnMore: () => learned = true,
        ),
      ),
    );
    await tester.tap(find.text('How to earn points'));
    await tester.tap(find.text('Got it'));
    expect(learned, isTrue);
    expect(dismissed, isTrue);
  });

  testWidgets('the explainer lists the ways to earn points', (tester) async {
    await pumpLocalized(
      tester,
      locale: en,
      const Scaffold(body: PointsEarnSheet()),
    );
    expect(find.textContaining('Watch the stream'), findsOneWidget);
    expect(find.textContaining('Collect the bonus'), findsOneWidget);
    expect(find.textContaining('watch streak'), findsOneWidget);
  });

  testWidgets('the explainer reads in French', (tester) async {
    await pumpLocalized(tester, const Scaffold(body: PointsEarnSheet()));
    expect(find.text('COMMENT GAGNER DES POINTS'), findsOneWidget);
    expect(englishLeaks(tester), isEmpty);
  });

  testWidgets('Chat settings bring the intro back', (tester) async {
    final settings = SettingsStore()..pointsIntroSeen = true;
    await pumpSettings(
      tester,
      Scaffold(body: ChatSettings(settingsStore: settings)),
      settings: settings,
      auth: FakeAuthStore(),
    );
    await tapVisible(tester, find.text('Show the channel points intro again'));
    expect(settings.pointsIntroSeen, isFalse);
    expect(find.text('The intro will show again.'), findsOneWidget);
  });

  testWidgets('a new setting carries the pill until it is used', (
    tester,
  ) async {
    final settings = SettingsStore();
    expect(settings.isNewFeature(NewFeature.landscapeAlerts.name), isTrue);
    await pumpSettings(
      tester,
      Scaffold(body: ChatSettings(settingsStore: settings)),
      settings: settings,
      auth: FakeAuthStore(),
    );
    final row = find.widgetWithText(
      SettingsListSwitch,
      'Alerts over the video in landscape',
    );
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(of: row, matching: find.byType(NewFeaturePill)),
      findsOneWidget,
    );
    await tapVisible(tester, find.text('Alerts over the video in landscape'));
    expect(settings.alertsOverLandscapeVideo, isFalse);
    expect(settings.isNewFeature(NewFeature.landscapeAlerts.name), isFalse);
    expect(
      SettingsStore.fromJson(settings.toJson()).seenNewFeatures,
      contains(NewFeature.landscapeAlerts.name),
    );
  });
}
