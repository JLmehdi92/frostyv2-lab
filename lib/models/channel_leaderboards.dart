enum LeaderboardKind { cheers, gifts }

enum LeaderboardPeriod { day, week, month, allTime, unknown }

class LeaderboardEntry {
  final int rank;
  final int score;
  final String userId;
  final String displayName;

  const LeaderboardEntry({
    required this.rank,
    required this.score,
    required this.userId,
    required this.displayName,
  });

  static LeaderboardEntry? tryParse(Object? node) {
    if (node is! Map) return null;
    final rank = node['rank'];
    final score = node['score'];
    final user = node['user'];
    if (rank is! int || score is! int || user is! Map) return null;
    final id = user['id'];
    final name = user['displayName'];
    if (id is! String || name is! String || name.isEmpty) return null;
    return LeaderboardEntry(
      rank: rank,
      score: score,
      userId: id,
      displayName: name,
    );
  }
}

class ChannelLeaderboards {
  final LeaderboardPeriod period;
  final LeaderboardKind? preferred;
  final Map<LeaderboardKind, List<LeaderboardEntry>> boards;
  final Map<LeaderboardKind, LeaderboardEntry> mine;

  const ChannelLeaderboards({
    this.period = LeaderboardPeriod.unknown,
    this.preferred,
    this.boards = const {},
    this.mine = const {},
  });

  List<LeaderboardKind> get kinds => [
    for (final kind in LeaderboardKind.values)
      if (boards.containsKey(kind)) kind,
  ];

  bool get isEmpty => boards.values.every((entries) => entries.isEmpty);

  static ChannelLeaderboards? tryParse(Object? body) {
    if (body is! Map || body['errors'] != null) return null;
    final user = (body['data'] as Map?)?['user'];
    if (user is! Map) return null;
    final set = (user['channel'] as Map?)?['leaderboardSet'];
    if (set is! Map) return null;
    final settings = (user['settings'] as Map?)?['leaderboard'];
    final config = settings is Map ? settings : const {};
    final enabled = {
      LeaderboardKind.cheers: config['isCheerEnabled'] != false,
      LeaderboardKind.gifts: config['isSubGiftEnabled'] != false,
    };
    final fields = {
      LeaderboardKind.cheers: 'bits',
      LeaderboardKind.gifts: 'subGift',
    };
    final boards = <LeaderboardKind, List<LeaderboardEntry>>{};
    final mine = <LeaderboardKind, LeaderboardEntry>{};
    for (final kind in LeaderboardKind.values) {
      final board = set[fields[kind]];
      if (!enabled[kind]! || board is! Map) continue;
      final edges = (board['items'] as Map?)?['edges'];
      boards[kind] = [
        if (edges is List)
          for (final edge in edges)
            ?LeaderboardEntry.tryParse((edge as Map?)?['node']),
      ];
      if (LeaderboardEntry.tryParse(board['myPosition']) case final entry?) {
        mine[kind] = entry;
      }
    }
    return ChannelLeaderboards(
      period: switch (config['timePeriod']) {
        'DAY' => LeaderboardPeriod.day,
        'WEEK' => LeaderboardPeriod.week,
        'MONTH' => LeaderboardPeriod.month,
        'ALLTIME' => LeaderboardPeriod.allTime,
        _ => LeaderboardPeriod.unknown,
      },
      preferred: switch (config['defaultLeaderboard']) {
        'BITS' => LeaderboardKind.cheers,
        'SUBGIFT' => LeaderboardKind.gifts,
        _ => null,
      },
      boards: boards,
      mine: mine,
    );
  }
}
