import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/screens/settings/account/gift_settings.dart';

import '../../../helpers/l10n.dart';

void main() {
  late List<GiftSettings> saved;
  late ViewerActionOutcome outcome;
  GiftSettings? loaded;

  setUp(() {
    saved = [];
    outcome = ViewerActionOutcome.done;
    loaded = const GiftSettings(followedChannelsOnly: false, countHidden: true);
  });

  Future<void> pump(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: ListView(
          children: [
            GiftSettingsGroup(
              load: () async => loaded,
              save: (settings) async {
                saved.add(settings);
                return outcome;
              },
            ),
          ],
        ),
      ),
      locale: en,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the account’s two switches', (tester) async {
    await pump(tester);
    expect(
      find.text('Block gifted subs in channels you don’t follow'),
      findsOneWidget,
    );
    expect(find.text('Hide your gift count'), findsOneWidget);
  });

  testWidgets('a change asks first, then saves, and can be undone', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(GiftSettingsGroup.followedOnlyKey));
    await tester.pumpAndSettle();
    expect(find.text('Change this Twitch setting?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);

    await tester.tap(find.byKey(GiftSettingsGroup.followedOnlyKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(saved, [
      const GiftSettings(followedChannelsOnly: true, countHidden: true),
    ]);
    expect(find.text('Done.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(saved.last, loaded);
  });

  testWidgets('a refused change keeps the switch where it was', (tester) async {
    outcome = ViewerActionOutcome.failed;
    await pump(tester);
    await tester.tap(find.byKey(GiftSettingsGroup.hideCountKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t reach Twitch. Try again.'), findsOneWidget);
    await tester.tap(find.byKey(GiftSettingsGroup.hideCountKey));
    await tester.pumpAndSettle();
    expect(find.text('Change this Twitch setting?'), findsOneWidget);
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(saved.last.countHidden, isFalse);
  });

  testWidgets('settings Twitch doesn’t give are said, with no switch', (
    tester,
  ) async {
    loaded = null;
    await pump(tester);
    expect(find.byKey(GiftSettingsGroup.followedOnlyKey), findsNothing);
    expect(
      find.text(
        'Couldn’t load your gifted sub settings. Log in again, or try again '
        'later.',
      ),
      findsOneWidget,
    );
  });
}
