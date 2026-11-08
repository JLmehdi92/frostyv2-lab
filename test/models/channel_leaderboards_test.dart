import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/channel_leaderboards.dart';

import '../fixtures/community_gql_payloads.dart';

void main() {
  test('reads the cheer and gift boards with the channel settings', () {
    final boards = ChannelLeaderboards.tryParse(leaderboardsResponse)!;

    expect(boards.period, LeaderboardPeriod.week);
    expect(boards.preferred, LeaderboardKind.gifts);
    expect(boards.kinds, [LeaderboardKind.cheers, LeaderboardKind.gifts]);
    final cheers = boards.boards[LeaderboardKind.cheers]!;
    expect(cheers.map((e) => e.displayName), [
      'CheerOne',
      'CheerTwo',
      'cheer_three',
    ]);
    expect(cheers.first.score, 19800);
    expect(boards.boards[LeaderboardKind.gifts]!.first.rank, 1);
    expect(boards.mine, isEmpty);
  });

  test('a board the channel turned off is left out', () {
    final body = {
      'data': {
        'user': {
          'settings': {
            'leaderboard': {'isCheerEnabled': false, 'timePeriod': 'MONTH'},
          },
          'channel': (leaderboardsResponse['data']!['user']! as Map)['channel'],
        },
      },
    };

    final boards = ChannelLeaderboards.tryParse(body)!;

    expect(boards.kinds, [LeaderboardKind.gifts]);
    expect(boards.period, LeaderboardPeriod.month);
  });

  test('the viewer position is kept when Twitch gives it', () {
    final body = {
      'data': {
        'user': {
          'channel': {
            'leaderboardSet': {
              'bits': {
                'items': {'edges': []},
                'myPosition': {
                  'rank': 12,
                  'score': 300,
                  'user': {'id': '9', 'displayName': 'Me'},
                },
              },
            },
          },
        },
      },
    };

    final boards = ChannelLeaderboards.tryParse(body)!;

    expect(boards.mine[LeaderboardKind.cheers]!.rank, 12);
    expect(boards.isEmpty, isTrue);
  });

  test('an error or a changed shape gives nothing', () {
    expect(ChannelLeaderboards.tryParse({'errors': []}), isNull);
    expect(
      ChannelLeaderboards.tryParse({
        'data': {'user': null},
      }),
      isNull,
    );
    expect(ChannelLeaderboards.tryParse(42), isNull);
  });
}
