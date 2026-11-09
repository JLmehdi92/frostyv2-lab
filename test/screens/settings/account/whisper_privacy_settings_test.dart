import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/whisper_history.dart';
import 'package:onset/screens/settings/account/whisper_privacy_settings.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';

import '../../../helpers/l10n.dart';

void main() {
  late List<bool> saved;
  late ViewerActionOutcome outcome;
  WhisperPrivacy? loaded;

  setUp(() {
    saved = [];
    outcome = ViewerActionOutcome.done;
    loaded = const WhisperPrivacy(blockStrangers: false);
  });

  Future<void> pump(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: ListView(
          children: [
            WhisperPrivacyGroup(
              load: () async => loaded,
              save: (block) async {
                saved.add(block);
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

  bool switchValue(WidgetTester tester) => tester
      .widget<SettingsListSwitch>(
        find.byKey(WhisperPrivacyGroup.blockStrangersKey),
      )
      .value;

  testWidgets('asks first, saves, and can be undone', (tester) async {
    await pump(tester);
    expect(find.text('Block whispers from strangers'), findsOneWidget);

    await tester.tap(find.byKey(WhisperPrivacyGroup.blockStrangersKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);

    await tester.tap(find.byKey(WhisperPrivacyGroup.blockStrangersKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(saved, [true]);
    expect(switchValue(tester), isTrue);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(saved, [true, false]);
    expect(switchValue(tester), isFalse);
  });

  testWidgets('a refused change keeps the switch', (tester) async {
    outcome = ViewerActionOutcome.integrityRefused;
    await pump(tester);
    await tester.tap(find.byKey(WhisperPrivacyGroup.blockStrangersKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(switchValue(tester), isFalse);
    expect(find.textContaining('anti-bot'), findsOneWidget);
  });

  testWidgets('unreadable settings show a note and no switch', (tester) async {
    loaded = null;
    await pump(tester);
    expect(find.byKey(WhisperPrivacyGroup.blockStrangersKey), findsNothing);
    expect(
      find.text(
        'Couldn’t load your whisper settings. Log in again, or try again later.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a parent’s lock is said and the switch is off limits', (
    tester,
  ) async {
    loaded = const WhisperPrivacy(blockStrangers: true, disabledByParent: true);
    await pump(tester);
    expect(
      find.text('A parent turned off whispers through Twitch’s parental tools.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(WhisperPrivacyGroup.blockStrangersKey));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
  });
}
