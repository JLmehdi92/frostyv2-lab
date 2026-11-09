import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/unban_request.dart';
import 'package:onset/screens/channel/chat/widgets/unban_request_sheet.dart';

import '../../../../fixtures/unban_request_payloads.dart';
import '../../../../helpers/l10n.dart';

void main() {
  late List<String> sent;

  Future<void> pump(
    WidgetTester tester,
    List<Map<String, Object?>> reads, {
    UnbanRequestOutcome outcome = const UnbanRequestOutcome(
      UnbanRequestResult.sent,
    ),
  }) {
    var index = 0;
    return pumpLocalized(
      tester,
      Scaffold(
        body: UnbanRequestSheet(
          load: () async => UnbanRequestState.fromBody(
            reads[index < reads.length ? index++ : reads.length - 1],
          ),
          send: (message) async {
            sent.add(message);
            return outcome;
          },
        ),
      ),
      locale: en,
    );
  }

  setUp(() => sent = []);

  testWidgets('sends a reason, then shows the pending request', (tester) async {
    await pump(tester, [unbanResponse(), unbanResponse(status: 'PENDING')]);
    await tester.pumpAndSettle();

    final send = find.byKey(UnbanRequestSheet.sendKey);
    await tester.enterText(find.byKey(UnbanRequestSheet.fieldKey), 'Sorry.');
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Send your unban request?'), findsOneWidget);
    expect(sent, isEmpty);
    await tester.tap(find.byKey(UnbanRequestSheet.confirmKey));
    await tester.pumpAndSettle();

    expect(sent, ['Sorry.']);
    expect(find.text('Your unban request will be reviewed.'), findsOneWidget);
    expect(
      find.textContaining('The moderators haven’t answered yet.'),
      findsOneWidget,
    );
    expect(find.byKey(UnbanRequestSheet.sendKey), findsNothing);
  });

  testWidgets('shows the moderators’ note on a denied request', (tester) async {
    await pump(tester, [
      unbanResponse(canRequest: false, status: 'DENIED', note: 'Not now.'),
    ]);
    await tester.pumpAndSettle();

    expect(find.textContaining('was denied'), findsOneWidget);
    expect(find.text('Note from the channel moderators:'), findsOneWidget);
    expect(find.text('Not now.'), findsOneWidget);
    expect(
      find.text('You can’t send an unban request right now.'),
      findsOneWidget,
    );
  });

  testWidgets('a refusal says why and keeps the text', (tester) async {
    await pump(
      tester,
      [unbanResponse()],
      outcome: const UnbanRequestOutcome(
        UnbanRequestResult.refused,
        code: 'TOO_SOON_SINCE_BAN',
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(UnbanRequestSheet.fieldKey), 'Please.');
    await tester.pump();
    await tester.tap(find.byKey(UnbanRequestSheet.sendKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(UnbanRequestSheet.confirmKey));
    await tester.pumpAndSettle();

    expect(
      find.text('It’s too soon after your ban. Try again later.'),
      findsOneWidget,
    );
    expect(find.text('Please.'), findsOneWidget);
  });

  testWidgets('a channel without unban requests says so', (tester) async {
    await pump(tester, [unbanResponse(enabled: false)]);
    await tester.pumpAndSettle();
    expect(
      find.text('This channel doesn’t take unban requests.'),
      findsOneWidget,
    );
  });
}
