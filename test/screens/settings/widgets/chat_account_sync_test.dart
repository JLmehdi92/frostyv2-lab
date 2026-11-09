import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/chat_ui_settings.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/chat_account_sync.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';

import '../../../helpers/l10n.dart';

ChatUiSettings _account({
  bool emoteAnimations = true,
  bool gifs = true,
  bool gifAnimations = true,
  bool readableColors = true,
}) => ChatUiSettings({
  ChatUiSetting.emoteAnimations: emoteAnimations,
  ChatUiSetting.gifs: gifs,
  ChatUiSetting.gifAnimations: gifAnimations,
  ChatUiSetting.readableColors: readableColors,
});

void main() {
  late SettingsStore store;
  late List<(ChatUiSetting, bool)> saved;
  ChatUiSettings? account;
  ViewerActionOutcome outcome = ViewerActionOutcome.done;

  setUp(() {
    store = SettingsStore.fromJson({});
    saved = [];
    account = _account();
    outcome = ViewerActionOutcome.done;
  });

  Future<void> pump(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: SettingsGroupsView(
          children: [
            ChatAccountSyncGroup(
              settingsStore: store,
              load: () async => account,
              save: (setting, enabled) async {
                saved.add((setting, enabled));
                if (outcome == ViewerActionOutcome.done) {
                  account = ChatUiSettings({
                    ...account!.values,
                    setting: enabled,
                  });
                }
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

  testWidgets('matching settings say so and offer nothing', (tester) async {
    await pump(tester);
    expect(
      find.text(
        'Animated emotes, GIFs, and readable colors match your Twitch account.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(ChatAccountSyncGroup.saveKey));
    await tester.pumpAndSettle();
    expect(find.text('Change your Twitch account?'), findsNothing);
  });

  testWidgets('the account settings can be used here, with an undo', (
    tester,
  ) async {
    account = _account(gifs: false, readableColors: false);
    await pump(tester);
    expect(
      find.text('2 chat settings differ from your Twitch account.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ChatAccountSyncGroup.useAccountKey));
    await tester.pumpAndSettle();
    expect(store.showGifs, isFalse);
    expect(store.readableNameColors, isFalse);
    expect(saved, isEmpty);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.showGifs, isTrue);
    expect(store.readableNameColors, isTrue);
  });

  testWidgets('saving to the account asks first and sends only changes', (
    tester,
  ) async {
    account = _account(emoteAnimations: false);
    await pump(tester);

    await tester.tap(find.byKey(ChatAccountSyncGroup.saveKey));
    await tester.pumpAndSettle();
    expect(find.text('Change your Twitch account?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);

    await tester.tap(find.byKey(ChatAccountSyncGroup.saveKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, [(ChatUiSetting.emoteAnimations, true)]);
    expect(find.text('Done.'), findsOneWidget);
    expect(
      find.text(
        'Animated emotes, GIFs, and readable colors match your Twitch account.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a refusal stops the save and says so', (tester) async {
    account = _account(gifs: false, gifAnimations: false);
    outcome = ViewerActionOutcome.integrityRefused;
    await pump(tester);

    await tester.tap(find.byKey(ChatAccountSyncGroup.saveKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(find.textContaining('anti-bot check'), findsOneWidget);
  });

  testWidgets('an unreadable account hides the sync', (tester) async {
    account = null;
    await pump(tester);
    expect(
      find.textContaining('Couldn’t load the chat settings'),
      findsOneWidget,
    );
    expect(find.byKey(ChatAccountSyncGroup.saveKey), findsNothing);
  });
}
