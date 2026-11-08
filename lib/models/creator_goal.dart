enum CreatorGoalKind {
  subs,
  subPoints,
  newSubs,
  newSubPoints,
  followers,
  other,
}

enum CreatorGoalState { active, reached, ended }

class CreatorGoal {
  final String id;
  final CreatorGoalKind kind;
  final CreatorGoalState state;
  final String description;
  final int current;
  final int target;

  const CreatorGoal({
    required this.id,
    required this.kind,
    required this.state,
    required this.description,
    required this.current,
    required this.target,
  });

  double get progress => target <= 0 ? 0 : (current / target).clamp(0, 1);

  bool get isReached => state == CreatorGoalState.reached || current >= target;

  static CreatorGoal? tryParse(Object? raw, {String? eventType}) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final current = raw['currentContributions'];
    final target = raw['targetContributions'];
    if (id is! String || id.isEmpty) return null;
    if (current is! num || target is! num || target <= 0) return null;
    final description = raw['description'];
    return CreatorGoal(
      id: id,
      kind: _kindOf(raw['contributionType']),
      state: _stateOf(raw['state'], eventType),
      description: description is String ? description.trim() : '',
      current: current.toInt().clamp(0, 1 << 31),
      target: target.toInt(),
    );
  }

  static CreatorGoalKind _kindOf(Object? type) => switch (type) {
    'SUBS' => CreatorGoalKind.subs,
    'SUB_POINTS' => CreatorGoalKind.subPoints,
    'NEW_SUBS' => CreatorGoalKind.newSubs,
    'NEW_SUB_POINTS' => CreatorGoalKind.newSubPoints,
    'FOLLOWERS' => CreatorGoalKind.followers,
    _ => CreatorGoalKind.other,
  };

  static CreatorGoalState _stateOf(Object? state, String? eventType) {
    if (eventType == 'goal_ended' || state == 'ENDED') {
      return CreatorGoalState.ended;
    }
    if (eventType == 'goal_achieved' || state == 'ACHIEVED') {
      return CreatorGoalState.reached;
    }
    return CreatorGoalState.active;
  }
}

List<CreatorGoal> mergeCreatorGoal(List<CreatorGoal> goals, CreatorGoal goal) {
  final others = [
    for (final existing in goals)
      if (existing.id != goal.id) existing,
  ];
  if (goal.state == CreatorGoalState.ended) return others;
  final index = goals.indexWhere((existing) => existing.id == goal.id);
  if (index < 0) return [...others, goal];
  return [...others]..insert(index.clamp(0, others.length), goal);
}
