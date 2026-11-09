import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/chat_identity.dart';
import 'package:onset/screens/channel/chat/widgets/chat_badge_sheet.dart';

import '../../../../fixtures/chat_identity_payloads.dart';
import '../../../../helpers/l10n.dart';

void main() {
  late List<String> calls;
  late bool flair;

  Future<void> pump(
    WidgetTester tester, {
    ViewerActionOutcome outcome = ViewerActionOutcome.done,
  }) => pumpLocalized(
    tester,
    Scaffold(
      body: ChatBadgeSheet(
        load: () async =>
            ChatIdentity.fromBody(chatIdentityResponse(flairHidden: flair)),
        select: (scope, badge) async {
          calls.add('${scope.name}:${badge?.key ?? 'none'}');
          return outcome;
        },
        setFlairHidden: (hidden) async {
          calls.add('flair:$hidden');
          if (outcome == ViewerActionOutcome.done) flair = hidden;
          return outcome;
        },
      ),
    ),
    locale: en,
  );

  setUp(() {
    calls = [];
    flair = false;
  });

  testWidgets('a pick is confirmed first, then can be undone', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        ChatBadgeSheet.choiceKey(ChatBadgeScope.channel, 'sub-gifter/5'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Show “5 Gift Subs” next to your name?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(
      find.byKey(
        ChatBadgeSheet.choiceKey(ChatBadgeScope.channel, 'sub-gifter/5'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ChatBadgeSheet.confirmKey));
    await tester.pumpAndSettle();
    expect(calls, ['channel:sub-gifter/5']);
    expect(find.text('Badge changed.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(calls, ['channel:sub-gifter/5', 'channel:subscriber/3012']);
  });

  testWidgets('no badge everywhere asks before clearing', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ChatBadgeSheet.choiceKey(ChatBadgeScope.global, 'none')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Show no badge next to your name?'), findsOneWidget);
    await tester.tap(find.byKey(ChatBadgeSheet.confirmKey));
    await tester.pumpAndSettle();
    expect(calls, ['global:none']);
  });

  testWidgets('the flair switch is confirmed, and a failure says so', (
    tester,
  ) async {
    await pump(tester, outcome: ViewerActionOutcome.failed);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ChatBadgeSheet.flairKey));
    await tester.pumpAndSettle();
    expect(find.text('Hide your sub badge flair?'), findsOneWidget);
    await tester.tap(find.byKey(ChatBadgeSheet.confirmKey));
    await tester.pumpAndSettle();
    expect(calls, ['flair:true']);
    expect(find.text('Couldn’t change your badge. Try again.'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('picking the current badge does nothing', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        ChatBadgeSheet.choiceKey(ChatBadgeScope.channel, 'subscriber/3012'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ChatBadgeSheet.confirmKey), findsNothing);
  });
}
