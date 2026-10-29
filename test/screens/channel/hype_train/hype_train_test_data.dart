import 'package:onset/models/hype_train.dart';

/// Small builders for hype train states in tests.
HtUser user(String id) => HtUser(id: id, login: id, displayName: id);

HtProgress progress({
  int level = 1,
  int value = 0,
  int goal = 100,
  int? total,
  HtAthState athState = HtAthState.none,
}) => HtProgress(
  level: HtLevel(value: level, cumulativeGoal: 0),
  goal: goal,
  value: value,
  total: total ?? value,
  athState: athState,
);

HypeTrainExecution train({
  String id = 'train',
  int level = 1,
  int value = 0,
  int goal = 100,
  int? total,
  int? maxLevel,
  Map<String, int> rates = const {},
  HtAthState athState = HtAthState.none,
  HtTreasure? treasure,
  HtCommunity? community,
  HtVariant? variant,
  List<HtConductor> conductors = const [],
  HtShared? shared,
}) => HypeTrainExecution(
  id: id,
  progress: progress(
    level: level,
    value: value,
    goal: goal,
    total: total,
    athState: athState,
  ),
  config: HtConfig(maxLevel: maxLevel, conversionRates: rates),
  treasure: treasure,
  community: community,
  variant:
      variant ??
      (treasure != null
          ? HtVariant.treasure
          : community != null
          ? HtVariant.community
          : HtVariant.regular),
  conductors: conductors,
  shared: shared,
);
