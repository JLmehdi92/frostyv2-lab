// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hype_train_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$HypeTrainStore on HypeTrainStoreBase, Store {
  Computed<int>? _$percentComputed;

  @override
  int get percent => (_$percentComputed ??= Computed<int>(
    () => super.percent,
    name: 'HypeTrainStoreBase.percent',
  )).value;
  Computed<int>? _$levelComputed;

  @override
  int get level => (_$levelComputed ??= Computed<int>(
    () => super.level,
    name: 'HypeTrainStoreBase.level',
  )).value;
  Computed<bool>? _$visibleComputed;

  @override
  bool get visible => (_$visibleComputed ??= Computed<bool>(
    () => super.visible,
    name: 'HypeTrainStoreBase.visible',
  )).value;
  Computed<bool>? _$isFinalLevelComputed;

  @override
  bool get isFinalLevel => (_$isFinalLevelComputed ??= Computed<bool>(
    () => super.isFinalLevel,
    name: 'HypeTrainStoreBase.isFinalLevel',
  )).value;
  Computed<({int bits, int subs})>? _$levelTargetComputed;

  @override
  ({int bits, int subs}) get levelTarget =>
      (_$levelTargetComputed ??= Computed<({int bits, int subs})>(
        () => super.levelTarget,
        name: 'HypeTrainStoreBase.levelTarget',
      )).value;
  Computed<HtStyle>? _$styleComputed;

  @override
  HtStyle get style => (_$styleComputed ??= Computed<HtStyle>(
    () => super.style,
    name: 'HypeTrainStoreBase.style',
  )).value;

  late final _$_phaseAtom = Atom(
    name: 'HypeTrainStoreBase._phase',
    context: context,
  );

  HtPhase get phase {
    _$_phaseAtom.reportRead();
    return super._phase;
  }

  @override
  HtPhase get _phase => phase;

  @override
  set _phase(HtPhase value) {
    _$_phaseAtom.reportWrite(value, super._phase, () {
      super._phase = value;
    });
  }

  late final _$_trainAtom = Atom(
    name: 'HypeTrainStoreBase._train',
    context: context,
  );

  HypeTrainExecution? get train {
    _$_trainAtom.reportRead();
    return super._train;
  }

  @override
  HypeTrainExecution? get _train => train;

  @override
  set _train(HypeTrainExecution? value) {
    _$_trainAtom.reportWrite(value, super._train, () {
      super._train = value;
    });
  }

  late final _$_approachingAtom = Atom(
    name: 'HypeTrainStoreBase._approaching',
    context: context,
  );

  HypeTrainApproaching? get approaching {
    _$_approachingAtom.reportRead();
    return super._approaching;
  }

  @override
  HypeTrainApproaching? get _approaching => approaching;

  @override
  set _approaching(HypeTrainApproaching? value) {
    _$_approachingAtom.reportWrite(value, super._approaching, () {
      super._approaching = value;
    });
  }

  late final _$_stepAtom = Atom(
    name: 'HypeTrainStoreBase._step',
    context: context,
  );

  HtStep? get step {
    _$_stepAtom.reportRead();
    return super._step;
  }

  @override
  HtStep? get _step => step;

  @override
  set _step(HtStep? value) {
    _$_stepAtom.reportWrite(value, super._step, () {
      super._step = value;
    });
  }

  late final _$_stepIndexAtom = Atom(
    name: 'HypeTrainStoreBase._stepIndex',
    context: context,
  );

  int get stepIndex {
    _$_stepIndexAtom.reportRead();
    return super._stepIndex;
  }

  @override
  int get _stepIndex => stepIndex;

  @override
  set _stepIndex(int value) {
    _$_stepIndexAtom.reportWrite(value, super._stepIndex, () {
      super._stepIndex = value;
    });
  }

  late final _$_shownLevelAtom = Atom(
    name: 'HypeTrainStoreBase._shownLevel',
    context: context,
  );

  int get shownLevel {
    _$_shownLevelAtom.reportRead();
    return super._shownLevel;
  }

  @override
  int get _shownLevel => shownLevel;

  @override
  set _shownLevel(int value) {
    _$_shownLevelAtom.reportWrite(value, super._shownLevel, () {
      super._shownLevel = value;
    });
  }

  late final _$_shownPercentAtom = Atom(
    name: 'HypeTrainStoreBase._shownPercent',
    context: context,
  );

  int get shownPercent {
    _$_shownPercentAtom.reportRead();
    return super._shownPercent;
  }

  @override
  int get _shownPercent => shownPercent;

  @override
  set _shownPercent(int value) {
    _$_shownPercentAtom.reportWrite(value, super._shownPercent, () {
      super._shownPercent = value;
    });
  }

  late final _$_remainingAtom = Atom(
    name: 'HypeTrainStoreBase._remaining',
    context: context,
  );

  Duration get remaining {
    _$_remainingAtom.reportRead();
    return super._remaining;
  }

  @override
  Duration get _remaining => remaining;

  @override
  set _remaining(Duration value) {
    _$_remainingAtom.reportWrite(value, super._remaining, () {
      super._remaining = value;
    });
  }

  late final _$_approachingFractionAtom = Atom(
    name: 'HypeTrainStoreBase._approachingFraction',
    context: context,
  );

  double get approachingFraction {
    _$_approachingFractionAtom.reportRead();
    return super._approachingFraction;
  }

  @override
  double get _approachingFraction => approachingFraction;

  @override
  set _approachingFraction(double value) {
    _$_approachingFractionAtom.reportWrite(
      value,
      super._approachingFraction,
      () {
        super._approachingFraction = value;
      },
    );
  }

  late final _$_approachingChecksAtom = Atom(
    name: 'HypeTrainStoreBase._approachingChecks',
    context: context,
  );

  int get approachingChecks {
    _$_approachingChecksAtom.reportRead();
    return super._approachingChecks;
  }

  @override
  int get _approachingChecks => approachingChecks;

  @override
  set _approachingChecks(int value) {
    _$_approachingChecksAtom.reportWrite(value, super._approachingChecks, () {
      super._approachingChecks = value;
    });
  }

  late final _$_approachingEventsLeftAtom = Atom(
    name: 'HypeTrainStoreBase._approachingEventsLeft',
    context: context,
  );

  int get approachingEventsLeft {
    _$_approachingEventsLeftAtom.reportRead();
    return super._approachingEventsLeft;
  }

  @override
  int get _approachingEventsLeft => approachingEventsLeft;

  @override
  set _approachingEventsLeft(int value) {
    _$_approachingEventsLeftAtom.reportWrite(
      value,
      super._approachingEventsLeft,
      () {
        super._approachingEventsLeft = value;
      },
    );
  }

  late final _$_approachingCompletedAtom = Atom(
    name: 'HypeTrainStoreBase._approachingCompleted',
    context: context,
  );

  bool get approachingCompleted {
    _$_approachingCompletedAtom.reportRead();
    return super._approachingCompleted;
  }

  @override
  bool get _approachingCompleted => approachingCompleted;

  @override
  set _approachingCompleted(bool value) {
    _$_approachingCompletedAtom.reportWrite(
      value,
      super._approachingCompleted,
      () {
        super._approachingCompleted = value;
      },
    );
  }

  late final _$_approachingNMoreAtom = Atom(
    name: 'HypeTrainStoreBase._approachingNMore',
    context: context,
  );

  bool get approachingNMore {
    _$_approachingNMoreAtom.reportRead();
    return super._approachingNMore;
  }

  @override
  bool get _approachingNMore => approachingNMore;

  @override
  set _approachingNMore(bool value) {
    _$_approachingNMoreAtom.reportWrite(value, super._approachingNMore, () {
      super._approachingNMore = value;
    });
  }

  late final _$_stripFractionAtom = Atom(
    name: 'HypeTrainStoreBase._stripFraction',
    context: context,
  );

  double get stripFraction {
    _$_stripFractionAtom.reportRead();
    return super._stripFraction;
  }

  @override
  double get _stripFraction => stripFraction;

  @override
  set _stripFraction(double value) {
    _$_stripFractionAtom.reportWrite(value, super._stripFraction, () {
      super._stripFraction = value;
    });
  }

  late final _$_endSummaryAtom = Atom(
    name: 'HypeTrainStoreBase._endSummary',
    context: context,
  );

  HtEndSummary? get endSummary {
    _$_endSummaryAtom.reportRead();
    return super._endSummary;
  }

  @override
  HtEndSummary? get _endSummary => endSummary;

  @override
  set _endSummary(HtEndSummary? value) {
    _$_endSummaryAtom.reportWrite(value, super._endSummary, () {
      super._endSummary = value;
    });
  }

  late final _$_unlockedRewardsAtom = Atom(
    name: 'HypeTrainStoreBase._unlockedRewards',
    context: context,
  );

  List<HtReward> get unlockedRewards {
    _$_unlockedRewardsAtom.reportRead();
    return super._unlockedRewards;
  }

  @override
  List<HtReward> get _unlockedRewards => unlockedRewards;

  @override
  set _unlockedRewards(List<HtReward> value) {
    _$_unlockedRewardsAtom.reportWrite(value, super._unlockedRewards, () {
      super._unlockedRewards = value;
    });
  }

  late final _$_realtimeDegradedAtom = Atom(
    name: 'HypeTrainStoreBase._realtimeDegraded',
    context: context,
  );

  bool get realtimeDegraded {
    _$_realtimeDegradedAtom.reportRead();
    return super._realtimeDegraded;
  }

  @override
  bool get _realtimeDegraded => realtimeDegraded;

  @override
  set _realtimeDegraded(bool value) {
    _$_realtimeDegradedAtom.reportWrite(value, super._realtimeDegraded, () {
      super._realtimeDegraded = value;
    });
  }

  late final _$expandedAtom = Atom(
    name: 'HypeTrainStoreBase.expanded',
    context: context,
  );

  @override
  bool get expanded {
    _$expandedAtom.reportRead();
    return super.expanded;
  }

  @override
  set expanded(bool value) {
    _$expandedAtom.reportWrite(value, super.expanded, () {
      super.expanded = value;
    });
  }

  late final _$collapsedAtom = Atom(
    name: 'HypeTrainStoreBase.collapsed',
    context: context,
  );

  @override
  bool get collapsed {
    _$collapsedAtom.reportRead();
    return super.collapsed;
  }

  @override
  set collapsed(bool value) {
    _$collapsedAtom.reportWrite(value, super.collapsed, () {
      super.collapsed = value;
    });
  }

  late final _$HypeTrainStoreBaseActionController = ActionController(
    name: 'HypeTrainStoreBase',
    context: context,
  );

  @override
  void attachPresenter() {
    final _$actionInfo = _$HypeTrainStoreBaseActionController.startAction(
      name: 'HypeTrainStoreBase.attachPresenter',
    );
    try {
      return super.attachPresenter();
    } finally {
      _$HypeTrainStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void detachPresenter() {
    final _$actionInfo = _$HypeTrainStoreBaseActionController.startAction(
      name: 'HypeTrainStoreBase.detachPresenter',
    );
    try {
      return super.detachPresenter();
    } finally {
      _$HypeTrainStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleExpanded() {
    final _$actionInfo = _$HypeTrainStoreBaseActionController.startAction(
      name: 'HypeTrainStoreBase.toggleExpanded',
    );
    try {
      return super.toggleExpanded();
    } finally {
      _$HypeTrainStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setCollapsed(bool value) {
    final _$actionInfo = _$HypeTrainStoreBaseActionController.startAction(
      name: 'HypeTrainStoreBase.setCollapsed',
    );
    try {
      return super.setCollapsed(value);
    } finally {
      _$HypeTrainStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onEvent(HypeTrainEvent event) {
    final _$actionInfo = _$HypeTrainStoreBaseActionController.startAction(
      name: 'HypeTrainStoreBase._onEvent',
    );
    try {
      return super._onEvent(event);
    } finally {
      _$HypeTrainStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _present(HypeTrainEvent event) {
    final _$actionInfo = _$HypeTrainStoreBaseActionController.startAction(
      name: 'HypeTrainStoreBase._present',
    );
    try {
      return super._present(event);
    } finally {
      _$HypeTrainStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _advance() {
    final _$actionInfo = _$HypeTrainStoreBaseActionController.startAction(
      name: 'HypeTrainStoreBase._advance',
    );
    try {
      return super._advance();
    } finally {
      _$HypeTrainStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _tick() {
    final _$actionInfo = _$HypeTrainStoreBaseActionController.startAction(
      name: 'HypeTrainStoreBase._tick',
    );
    try {
      return super._tick();
    } finally {
      _$HypeTrainStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _beginEnd(HtEndEvent end) {
    final _$actionInfo = _$HypeTrainStoreBaseActionController.startAction(
      name: 'HypeTrainStoreBase._beginEnd',
    );
    try {
      return super._beginEnd(end);
    } finally {
      _$HypeTrainStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _toHidden() {
    final _$actionInfo = _$HypeTrainStoreBaseActionController.startAction(
      name: 'HypeTrainStoreBase._toHidden',
    );
    try {
      return super._toHidden();
    } finally {
      _$HypeTrainStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _showApproaching(HypeTrainApproaching approaching) {
    final _$actionInfo = _$HypeTrainStoreBaseActionController.startAction(
      name: 'HypeTrainStoreBase._showApproaching',
    );
    try {
      return super._showApproaching(approaching);
    } finally {
      _$HypeTrainStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _approachingTick() {
    final _$actionInfo = _$HypeTrainStoreBaseActionController.startAction(
      name: 'HypeTrainStoreBase._approachingTick',
    );
    try {
      return super._approachingTick();
    } finally {
      _$HypeTrainStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _applySnapshot(HypeTrainSnapshot snapshot) {
    final _$actionInfo = _$HypeTrainStoreBaseActionController.startAction(
      name: 'HypeTrainStoreBase._applySnapshot',
    );
    try {
      return super._applySnapshot(snapshot);
    } finally {
      _$HypeTrainStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
expanded: ${expanded},
collapsed: ${collapsed},
percent: ${percent},
level: ${level},
visible: ${visible},
isFinalLevel: ${isFinalLevel},
levelTarget: ${levelTarget},
style: ${style}
    ''';
  }
}
