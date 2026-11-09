import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/live_together.dart';
import 'package:onset/screens/channel/chat/widgets/live_together.dart';

import '../../../../fixtures/live_together_payloads.dart';
import '../../../../helpers/l10n.dart';

void main() {
  final english = lookupAppLocalizations(en);

  Future<void> pump(
    WidgetTester tester,
    LiveTogether? roster, {
    ValueChanged<LiveTogetherMember>? onOpen,
  }) => pumpLocalized(
    tester,
    Scaffold(
      body: LiveTogetherStrip(
        roster: roster,
        channelId: '1000',
        onOpen: onOpen ?? (_) {},
      ),
    ),
    locale: en,
  );

  testWidgets('names the co-streamers, the hidden ones and the total', (
    tester,
  ) async {
    await pump(tester, LiveTogether.fromCostream(costreamResponse()));

    expect(find.text('STREAMING TOGETHER'), findsOneWidget);
    expect(
      find.text('Streaming together with HostChannel, ThirdOne and 2 others'),
      findsOneWidget,
    );
    expect(find.text('48,210 viewers in total'), findsOneWidget);
  });

  testWidgets('lists the guests and opens one who is live', (tester) async {
    LiveTogetherMember? opened;
    await pump(
      tester,
      LiveTogether.fromGuestStar(guestStarResponse()),
      onOpen: (member) => opened = member,
    );

    expect(find.text('Live with GuestOne, GuestTwo'), findsOneWidget);
    await tester.tap(find.byKey(LiveTogetherStrip.rowKey));
    await tester.pumpAndSettle();

    expect(find.text(english.liveTogetherNotLive), findsOneWidget);
    expect(find.text('210 viewers'), findsOneWidget);
    await tester.tap(find.byKey(LiveTogetherSheet.memberKey('guestone')));
    await tester.pumpAndSettle();
    expect(opened, isNull);

    await tester.tap(find.byKey(LiveTogetherSheet.memberKey('guesttwo')));
    await tester.pumpAndSettle();
    expect(opened?.login, 'guesttwo');
    expect(find.byType(LiveTogetherSheet), findsNothing);
  });

  testWidgets('shows nothing when the streamer is alone', (tester) async {
    await pump(tester, null);
    expect(find.byKey(LiveTogetherStrip.rowKey), findsNothing);
  });

  test('the guest star call comes before the co-stream', () async {
    final guests = LiveTogether.fromGuestStar(guestStarResponse());
    final costream = LiveTogether.fromCostream(costreamResponse());

    expect(
      await loadLiveTogether(
        guestStar: () async => guests,
        costream: () async => costream,
      ),
      same(guests),
    );
    expect(
      await loadLiveTogether(
        guestStar: () async => null,
        costream: () async => costream,
      ),
      same(costream),
    );
  });
}
