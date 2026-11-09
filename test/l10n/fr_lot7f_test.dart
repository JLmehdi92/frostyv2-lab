import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/chat_identity.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/live_together.dart';
import 'package:onset/models/unban_request.dart';
import 'package:onset/screens/channel/chat/widgets/chat_badge_sheet.dart';
import 'package:onset/screens/channel/chat/widgets/chat_message.dart';
import 'package:onset/screens/channel/chat/widgets/live_together.dart';
import 'package:onset/screens/channel/chat/widgets/unban_request_sheet.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_sheet.dart';

import '../fixtures/chat_identity_payloads.dart';
import '../fixtures/live_together_payloads.dart';
import '../fixtures/unban_request_payloads.dart';
import '../helpers/chat_message_harness.dart';
import '../helpers/l10n.dart';
import '../screens/channel/hype_train/widgets/hype_train_widget_harness.dart';

void main() {
  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';

      testWidgets('the co-stream line, $at', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            body: LiveTogetherStrip(
              roster: LiveTogether.fromCostream(costreamResponse()),
              channelId: '1000',
              onOpen: (_) {},
            ),
          ),
          size: size,
          textScale: scale,
        );
        await expectFrenchThroughout(
          tester,
          'co-stream line, $at',
          content: const ['HostChannel', 'ThirdOne'],
        );
      });

      testWidgets('the guest list, $at', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            body: LiveTogetherSheet(
              roster: LiveTogether.fromGuestStar(guestStarResponse())!,
              channelId: '1000',
              onOpen: (_) {},
            ),
          ),
          size: size,
          textScale: scale,
        );
        await expectFrenchThroughout(
          tester,
          'guest list, $at',
          content: const ['GuestOne', 'GuestTwo'],
        );
      });
      testWidgets('the chat badge sheet, $at', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            body: ChatBadgeSheet(
              load: () async => ChatIdentity.fromBody(chatIdentityResponse()),
              select: (_, _) async => ViewerActionOutcome.done,
              setFlairHidden: (_) async => ViewerActionOutcome.done,
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pumpAndSettle();
        await expectFrenchThroughout(
          tester,
          'chat badge sheet, $at',
          content: const [
            'Subscriber',
            '5 Gift Subs',
            'Prime Gaming',
            'GLHF Pledge',
          ],
        );
        await tester.tap(
          find.byKey(
            ChatBadgeSheet.choiceKey(ChatBadgeScope.channel, 'sub-gifter/5'),
          ),
        );
        await tester.pumpAndSettle();
        await expectFrenchThroughout(
          tester,
          'chat badge confirm, $at',
          content: const ['5 Gift Subs'],
        );
      });
      for (final status in [null, 'DENIED']) {
        testWidgets('the unban request, $status, $at', (tester) async {
          await pumpLocalized(
            tester,
            Scaffold(
              body: UnbanRequestSheet(
                load: () async => UnbanRequestState.fromBody(
                  unbanResponse(
                    canRequest: status == null,
                    status: status,
                    note: status == null ? null : 'Pas maintenant.',
                  ),
                ),
                send: (_) async =>
                    const UnbanRequestOutcome(UnbanRequestResult.sent),
              ),
            ),
            size: size,
            textScale: scale,
          );
          await tester.pumpAndSettle();
          await expectFrenchThroughout(
            tester,
            'unban request $status, $at',
            content: const ['Pas maintenant.'],
          );
        });
      }
      testWidgets('the chosen mythic emote, $at', (tester) async {
        final h = HtHarness(
          snapshot: HtOngoingSnapshot(
            liveTrain(level: 2).copyWith(
              variant: HtVariant.mythic,
              mythic: const HtMythic(
                selectedEmote: HtReward(
                  type: HtRewardType.emote,
                  id: '25',
                  token: 'Kappa',
                ),
              ),
            ),
            fetchedAt: DateTime.utc(2026),
          ),
        );
        await pumpLocalized(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: HypeTrainSheet(store: h.store, onLearnMore: () {}),
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const ValueKey('ht-mythic-chosen')), findsOneWidget);
        await expectFrenchThroughout(
          tester,
          'mythic chosen, $at',
          content: const ['Kappa'],
        );
        await h.close(tester);
      });

      testWidgets('the emote effect line, $at', (tester) async {
        await pumpLocalized(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => IRCMessage.showEmoteDetailsBottomSheet(
                    context,
                    emote: const Emote(
                      name: 'kaicFire_BW',
                      zeroWidth: false,
                      url:
                          'https://static-cdn.jtvnw.net/emoticons/v2/25_BW/default/dark/3.0',
                      type: EmoteType.twitchSub,
                    ),
                    launchExternal: false,
                  ),
                  child: const Text('▶'),
                ),
              ),
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.tap(find.text('▶'));
        await tester.pumpAndSettle();
        final french = lookupAppLocalizations(fr);
        expect(find.text(french.emoteModifierLine(code: 'BW')), findsOneWidget);
        await expectFrenchThroughout(
          tester,
          'emote effect, $at',
          content: const ['kaicFire_BW'],
        );
      });

      testWidgets('a private callout line, $at', (tester) async {
        final french = lookupAppLocalizations(fr);
        await pumpLocalized(
          tester,
          Scaffold(
            body: ListView(
              children: [
                ChatMessage(
                  ircMessage: IRCMessage.createNotice(
                    message: french.privateCalloutLine(
                      body: 'Regardez encore pour gagner vos récompenses.',
                    ),
                    actionLabel: french.privateCalloutOpen,
                    actionCallback: () {},
                  ),
                  chatStore: fakeChatStore(),
                ),
              ],
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        await expectFrenchThroughout(
          tester,
          'callout line, $at',
          content: const ['Regardez encore pour gagner vos récompenses.'],
        );
      });

      testWidgets('the prediction win banner, $at', (tester) async {
        await pumpLocalized(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.predictionWon(count: 12500)),
                    ),
                  ),
                  child: const Text('▶'),
                ),
              ),
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.tap(find.text('▶'));
        await tester.pumpAndSettle();
        await expectFrenchThroughout(tester, 'prediction win, $at');
      });
    }
  }
}
