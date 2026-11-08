import 'dart:math';

enum CommunityGoalStatus {
  unstarted,
  started,
  ended,
  fulfilled,
  archived,
  unknown,
}

enum GoalContributionResult {
  contributed,
  notEnoughPoints,
  maxPerStream,
  notOpen,
  refused,
  integrityRefused,
  signedOut,
  failed;

  static GoalContributionResult fromBody(Object? body) {
    if (body is! Map) return failed;
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final text = errors
          .map((e) => e is Map ? '${e['message']}' : '$e')
          .join(' ')
          .toLowerCase();
      return text.contains('integrity') ? integrityRefused : failed;
    }
    final data = body['data'];
    final payload = data is Map
        ? data['contributeCommunityPointsCommunityGoal']
        : null;
    if (payload is! Map) return failed;
    final error = payload['error'];
    if (error is! Map) return contributed;
    return switch (error['code']) {
      'NOT_ENOUGH_POINTS' => notEnoughPoints,
      'MAX_PER_STREAM' => maxPerStream,
      'NOT_CURRENTLY_REDEEMABLE' || 'NOT_FOUND' => notOpen,
      _ => refused,
    };
  }
}

class CommunityGoal {
  final String id;
  final String title;
  final String description;
  final CommunityGoalStatus status;
  final int amountNeeded;
  final int pointsContributed;
  final int smallContribution;
  final int perStreamMaximum;
  final bool isInStock;
  final Uri? imageUrl;
  final int? color;
  final int contributedThisStream;

  const CommunityGoal({
    required this.id,
    required this.title,
    this.description = '',
    this.status = CommunityGoalStatus.unknown,
    required this.amountNeeded,
    this.pointsContributed = 0,
    this.smallContribution = 0,
    this.perStreamMaximum = 0,
    this.isInStock = false,
    this.imageUrl,
    this.color,
    this.contributedThisStream = 0,
  });

  int get remaining => max(0, amountNeeded - pointsContributed);

  int get percentRaised => amountNeeded <= 0
      ? 0
      : (pointsContributed * 100 ~/ amountNeeded).clamp(0, 100);

  double get progress =>
      amountNeeded <= 0 ? 0 : (pointsContributed / amountNeeded).clamp(0, 1);

  bool get isOpen =>
      status == CommunityGoalStatus.started && isInStock && remaining > 0;

  bool get isMaxedThisStream =>
      perStreamMaximum > 0 && contributedThisStream >= perStreamMaximum;

  int maxContribution({required int balance}) {
    final streamLeft = perStreamMaximum > 0
        ? perStreamMaximum - contributedThisStream
        : remaining;
    return max(0, [balance, streamLeft, remaining].reduce(min));
  }

  CommunityGoal withContributedThisStream(int points) => CommunityGoal(
    id: id,
    title: title,
    description: description,
    status: status,
    amountNeeded: amountNeeded,
    pointsContributed: pointsContributed,
    smallContribution: smallContribution,
    perStreamMaximum: perStreamMaximum,
    isInStock: isInStock,
    imageUrl: imageUrl,
    color: color,
    contributedThisStream: points,
  );

  static List<CommunityGoal>? listFrom(Object? body) {
    if (body is! Map) return null;
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) return null;
    final data = body['data'];
    if (data is! Map) return null;
    final user = data['user'];
    final channel = user is Map ? user['channel'] : data['channel'];
    final settings = channel is Map ? channel['communityPointsSettings'] : null;
    final goals = settings is Map ? settings['goals'] : null;
    if (goals is! List) return null;
    return [
      for (final raw in goals)
        if (tryParse(raw) case final goal?)
          if (goal.status != CommunityGoalStatus.unstarted &&
              goal.status != CommunityGoalStatus.archived)
            goal,
    ];
  }

  static Map<String, int> contributionsFrom(Object? body) {
    if (body is! Map) return const {};
    final data = body['data'];
    final user = data is Map ? data['user'] : null;
    final channel = user is Map ? user['channel'] : null;
    final self = channel is Map ? channel['self'] : null;
    final points = self is Map ? self['communityPoints'] : null;
    final list = points is Map ? points['goalContributions'] : null;
    if (list is! List) return const {};
    return {
      for (final entry in list)
        if (entry is Map &&
            entry['goal'] is Map &&
            (entry['goal'] as Map)['id'] is String &&
            entry['userPointsContributedThisStream'] is num)
          (entry['goal'] as Map)['id'] as String:
              (entry['userPointsContributedThisStream'] as num).toInt(),
    };
  }

  static CommunityGoal? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final needed = raw['amountNeeded'];
    if (id is! String || id.isEmpty || needed is! num || needed <= 0) {
      return null;
    }
    final title = raw['title'];
    final description = raw['description'];
    return CommunityGoal(
      id: id,
      title: title is String ? title.trim() : '',
      description: description is String ? description.trim() : '',
      status: _statusOf(raw['status']),
      amountNeeded: needed.toInt(),
      pointsContributed: _count(raw['pointsContributed']),
      smallContribution: _count(raw['smallContribution']),
      perStreamMaximum: _count(raw['perStreamUserMaximumContribution']),
      isInStock: raw['isInStock'] == true,
      imageUrl: _image(raw['image']) ?? _image(raw['defaultImage']),
      color: _color(raw['backgroundColor']),
    );
  }

  static CommunityGoalStatus _statusOf(Object? status) => switch (status) {
    'UNSTARTED' => CommunityGoalStatus.unstarted,
    'STARTED' => CommunityGoalStatus.started,
    'ENDED' => CommunityGoalStatus.ended,
    'FULFILLED' => CommunityGoalStatus.fulfilled,
    'ARCHIVED' => CommunityGoalStatus.archived,
    _ => CommunityGoalStatus.unknown,
  };

  static Uri? _image(Object? image) {
    if (image is! Map) return null;
    final url = image['url2x'] ?? image['url'];
    if (url is! String) return null;
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' ? uri : null;
  }

  static int? _color(Object? hex) {
    if (hex is! String) return null;
    final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(hex);
    if (match == null) return null;
    return 0xFF000000 | int.parse(match.group(1)!, radix: 16);
  }

  static int _count(Object? value) =>
      value is num && value > 0 ? value.toInt() : 0;
}
