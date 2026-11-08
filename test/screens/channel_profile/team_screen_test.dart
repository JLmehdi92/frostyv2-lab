import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/team.dart';
import 'package:onset/screens/channel_profile/team_screen.dart';

import '../../helpers/l10n.dart';

const _team = Team(
  id: '1',
  name: 'staff',
  displayName: 'Twitch Staff',
  info: 'The people behind Twitch.',
  members: [
    TeamMember(id: '1', login: 'quiet', displayName: 'Quiet'),
    TeamMember(id: '2', login: 'small', displayName: 'Small'),
    TeamMember(id: '3', login: 'big', displayName: 'Big'),
  ],
);

StreamTwitch _stream(String id, String name, int viewers) => StreamTwitch(
  id,
  name.toLowerCase(),
  name,
  '509658',
  'Just Chatting',
  'Hello',
  viewers,
  '2026-11-08T10:00:00Z',
  '',
);

void main() {
  testWidgets('live members come first, most watched first, then the rest', (
    tester,
  ) async {
    List<String>? asked;
    await pumpLocalized(
      tester,
      locale: en,
      TeamScreen(
        name: 'staff',
        loadTeam: (_) async => _team,
        loadLive: (ids) async {
          asked = ids;
          return [_stream('2', 'Small', 10), _stream('3', 'Big', 900)];
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(asked, ['1', '2', '3']);
    expect(find.text('Twitch Staff'), findsWidgets);
    expect(find.text('3 members'), findsOneWidget);
    expect(find.text('The people behind Twitch.'), findsOneWidget);
    expect(find.text('Live now'), findsOneWidget);
    expect(find.text('900 viewers'), findsOneWidget);
    final big = tester.getTopLeft(find.text('Big')).dy;
    final small = tester.getTopLeft(find.text('Small')).dy;
    final quiet = tester.getTopLeft(find.text('Quiet')).dy;
    expect(big < small && small < quiet, isTrue);
  });

  testWidgets('a team that cannot load offers to try again', (tester) async {
    var fail = true;
    await pumpLocalized(
      tester,
      locale: en,
      TeamScreen(
        name: 'staff',
        loadTeam: (_) async => fail ? throw Exception('down') : _team,
        loadLive: (_) async => const [],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load this team.'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Quiet'), findsOneWidget);
  });

  testWidgets('live members still show when their streams cannot load', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      locale: en,
      TeamScreen(
        name: 'staff',
        loadTeam: (_) async => _team,
        loadLive: (_) async => throw Exception('helix'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Live now'), findsNothing);
    expect(find.text('Big'), findsOneWidget);
  });
}
