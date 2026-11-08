import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/channel_leaderboards.dart';
import 'package:onset/screens/channel/chat/widgets/leaderboards_sheet.dart';

import '../../../../fixtures/community_gql_payloads.dart';

void main() {
  Future<void> pump(WidgetTester tester, ChannelLeaderboards? boards) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LeaderboardsSheet(load: () async => boards)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the board the channel prefers', (tester) async {
    await pump(tester, ChannelLeaderboards.tryParse(leaderboardsResponse));

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('GifterOne'), findsOneWidget);
    expect(find.text('161 subs gifted'), findsOneWidget);
    expect(find.text('CheerOne'), findsNothing);
  });

  testWidgets('switches to the Bits board on a tap', (tester) async {
    await pump(tester, ChannelLeaderboards.tryParse(leaderboardsResponse));

    await tester.tap(
      find.byKey(LeaderboardsSheet.tabKey(LeaderboardKind.cheers)),
    );
    await tester.pumpAndSettle();

    expect(find.text('CheerOne'), findsOneWidget);
    expect(find.text('19,800 Bits cheered'), findsOneWidget);
    expect(find.text('GifterOne'), findsNothing);
  });

  testWidgets('shows the viewer rank and an empty board', (tester) async {
    await pump(
      tester,
      const ChannelLeaderboards(
        boards: {LeaderboardKind.cheers: []},
        mine: {
          LeaderboardKind.cheers: LeaderboardEntry(
            rank: 12,
            score: 300,
            userId: '9',
            displayName: 'Me',
          ),
        },
      ),
    );

    expect(find.text('No one is on this leaderboard yet.'), findsOneWidget);
    expect(find.text('Your rank: 12'), findsOneWidget);
    expect(
      find.byKey(LeaderboardsSheet.tabKey(LeaderboardKind.cheers)),
      findsNothing,
    );
  });

  testWidgets('a failure says so', (tester) async {
    await pump(tester, null);

    expect(find.byKey(LeaderboardsSheet.failedKey), findsOneWidget);
    expect(find.text('Couldn’t load the leaderboards.'), findsOneWidget);
  });
}
