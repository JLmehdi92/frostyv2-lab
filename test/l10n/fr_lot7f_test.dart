import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/chat_identity.dart';
import 'package:onset/models/live_together.dart';
import 'package:onset/models/unban_request.dart';
import 'package:onset/screens/channel/chat/widgets/chat_badge_sheet.dart';
import 'package:onset/screens/channel/chat/widgets/live_together.dart';
import 'package:onset/screens/channel/chat/widgets/unban_request_sheet.dart';

import '../fixtures/chat_identity_payloads.dart';
import '../fixtures/live_together_payloads.dart';
import '../fixtures/unban_request_payloads.dart';
import '../helpers/l10n.dart';

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
    }
  }
}
