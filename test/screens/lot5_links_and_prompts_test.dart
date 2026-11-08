import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/video/video_overlay.dart';
import 'package:onset/screens/home/feedback_prompt.dart';
import 'package:onset/screens/settings/account/account_settings.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/utils/twitch_report.dart';

import '../helpers/l10n.dart';

void main() {
  group('feedback prompt', () {
    test('asks after a dozen opens, later pushes it back, done stops it', () {
      final settings = SettingsStore();
      for (var i = 0; i < FeedbackPrompt.firstAskAfterOpens - 1; i++) {
        FeedbackPrompt.countOpen(settings);
      }
      expect(FeedbackPrompt.due(settings), isFalse);
      FeedbackPrompt.countOpen(settings);
      expect(FeedbackPrompt.due(settings), isTrue);

      FeedbackPrompt.later(settings);
      expect(FeedbackPrompt.due(settings), isFalse);
      for (var i = 0; i < FeedbackPrompt.askAgainAfterOpens; i++) {
        FeedbackPrompt.countOpen(settings);
      }
      expect(FeedbackPrompt.due(settings), isTrue);

      FeedbackPrompt.done(settings);
      expect(FeedbackPrompt.due(settings), isFalse);
      final restored = SettingsStore.fromJson(settings.toJson());
      expect(restored.feedbackPromptDone, isTrue);
      expect(restored.appOpens, settings.appOpens);
    });

    Future<SettingsStore> ask(WidgetTester tester, String button) async {
      final settings = SettingsStore()
        ..appOpens = 20
        ..feedbackPromptAtOpen = 12;
      final opened = <String>[];
      await pumpLocalized(
        tester,
        locale: en,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => askForFeedbackIfDue(
                context,
                settings,
                openUrl: (url) async => opened.add(url),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Enjoying ONSET?'), findsOneWidget);
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      if (button == 'Send feedback') {
        expect(opened, [onsetFeedbackUrl]);
      } else {
        expect(opened, isEmpty);
      }
      return settings;
    }

    testWidgets('send opens the project page and stops asking', (tester) async {
      final settings = await ask(tester, 'Send feedback');
      expect(settings.feedbackPromptDone, isTrue);
    });

    testWidgets('later asks again much later', (tester) async {
      final settings = await ask(tester, 'Later');
      expect(settings.feedbackPromptDone, isFalse);
      expect(
        settings.feedbackPromptAtOpen,
        20 + FeedbackPrompt.askAgainAfterOpens,
      );
    });

    testWidgets('never stops asking', (tester) async {
      final settings = await ask(tester, 'Don’t ask again');
      expect(settings.feedbackPromptDone, isTrue);
    });

    testWidgets('the prompt reads in French', (tester) async {
      await pumpLocalized(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showFeedbackPrompt(context),
            child: const Text('▶'),
          ),
        ),
      );
      await tester.tap(find.text('▶'));
      await tester.pumpAndSettle();
      expect(find.text('ONSET vous plaît ?'), findsOneWidget);
      expect(englishLeaks(tester), isEmpty);
    });
  });

  test('every twitch.tv page is named and described in both languages', () {
    for (final l in [L10n.english, lookupAppLocalizations(fr)]) {
      for (final page in TwitchAccountPage.values) {
        expect(page.title(l), isNotEmpty);
        expect(page.detail(l), contains('twitch.tv'));
        expect(Uri.https('www.twitch.tv', page.path).path, startsWith('/'));
      }
    }
    expect(
      TwitchAccountPage.values.map((p) => p.path),
      containsAll([
        '/settings/profile',
        '/settings/family-center',
        '/drops/inventory',
        '/subscriptions',
        '/user/delete-account',
      ]),
    );
  });

  test('report and Mod View links only for real logins', () {
    expect(
      twitchReportUri('Streamer').toString(),
      'https://www.twitch.tv/streamer/report',
    );
    expect(twitchReportUri('../x'), isNull);
    expect(
      twitchModViewUri('streamer').toString(),
      'https://www.twitch.tv/moderator/streamer',
    );
  });

  testWidgets('an offline channel says to check back, a failure offers retry', (
    tester,
  ) async {
    var retried = 0;
    Widget message({required bool failed, String? name}) => Scaffold(
      body: OfflineChannelMessage(
        key: ValueKey('$failed$name'),
        name: name,
        failed: failed,
        onRetry: () async => retried++,
        action: const Text('▶'),
      ),
    );
    await pumpLocalized(
      tester,
      locale: en,
      message(failed: false, name: 'Ninja'),
    );
    expect(find.text('Ninja is offline. Check back soon!'), findsOneWidget);
    expect(find.text('▶'), findsOneWidget);

    await pumpLocalized(tester, locale: en, message(failed: true));
    expect(find.text('Couldn’t load this channel.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, 1);

    await pumpLocalized(tester, message(failed: false, name: 'Ninja'));
    expect(
      find.text('Ninja est hors ligne. Revenez bientôt !'),
      findsOneWidget,
    );
    expect(englishLeaks(tester, content: ['Ninja']), isEmpty);
  });
}
