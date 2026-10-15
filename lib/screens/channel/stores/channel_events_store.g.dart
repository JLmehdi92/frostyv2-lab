// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel_events_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ChannelEventsStore on ChannelEventsStoreBase, Store {
  late final _$_pointsAtom = Atom(
    name: 'ChannelEventsStoreBase._points',
    context: context,
  );

  CommunityPointsContext get points {
    _$_pointsAtom.reportRead();
    return super._points;
  }

  @override
  CommunityPointsContext get _points => points;

  @override
  set _points(CommunityPointsContext value) {
    _$_pointsAtom.reportWrite(value, super._points, () {
      super._points = value;
    });
  }

  late final _$_celebrationAtom = Atom(
    name: 'ChannelEventsStoreBase._celebration',
    context: context,
  );

  Celebration? get celebration {
    _$_celebrationAtom.reportRead();
    return super._celebration;
  }

  @override
  Celebration? get _celebration => celebration;

  @override
  set _celebration(Celebration? value) {
    _$_celebrationAtom.reportWrite(value, super._celebration, () {
      super._celebration = value;
    });
  }

  late final _$_creatorGoalAtom = Atom(
    name: 'ChannelEventsStoreBase._creatorGoal',
    context: context,
  );

  Map<String, dynamic>? get creatorGoal {
    _$_creatorGoalAtom.reportRead();
    return super._creatorGoal;
  }

  @override
  Map<String, dynamic>? get _creatorGoal => creatorGoal;

  @override
  set _creatorGoal(Map<String, dynamic>? value) {
    _$_creatorGoalAtom.reportWrite(value, super._creatorGoal, () {
      super._creatorGoal = value;
    });
  }

  late final _$_pointsActionInFlightAtom = Atom(
    name: 'ChannelEventsStoreBase._pointsActionInFlight',
    context: context,
  );

  bool get pointsActionInFlight {
    _$_pointsActionInFlightAtom.reportRead();
    return super._pointsActionInFlight;
  }

  @override
  bool get _pointsActionInFlight => pointsActionInFlight;

  @override
  set _pointsActionInFlight(bool value) {
    _$_pointsActionInFlightAtom.reportWrite(
      value,
      super._pointsActionInFlight,
      () {
        super._pointsActionInFlight = value;
      },
    );
  }

  late final _$refreshPointsAsyncAction = AsyncAction(
    'ChannelEventsStoreBase.refreshPoints',
    context: context,
  );

  @override
  Future<void> refreshPoints() {
    return _$refreshPointsAsyncAction.run(() => super.refreshPoints());
  }

  late final _$ChannelEventsStoreBaseActionController = ActionController(
    name: 'ChannelEventsStoreBase',
    context: context,
  );

  @override
  Future<PointsActionResult> redeemReward(
    PointsReward reward, {
    String? userInput,
  }) {
    final _$actionInfo = _$ChannelEventsStoreBaseActionController.startAction(
      name: 'ChannelEventsStoreBase.redeemReward',
    );
    try {
      return super.redeemReward(reward, userInput: userInput);
    } finally {
      _$ChannelEventsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  Future<PointsActionResult> claimBonus() {
    final _$actionInfo = _$ChannelEventsStoreBaseActionController.startAction(
      name: 'ChannelEventsStoreBase.claimBonus',
    );
    try {
      return super.claimBonus();
    } finally {
      _$ChannelEventsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  Future<PointsActionResult> placePrediction({
    required String eventId,
    required String outcomeId,
    required int points,
  }) {
    final _$actionInfo = _$ChannelEventsStoreBaseActionController.startAction(
      name: 'ChannelEventsStoreBase.placePrediction',
    );
    try {
      return super.placePrediction(
        eventId: eventId,
        outcomeId: outcomeId,
        points: points,
      );
    } finally {
      _$ChannelEventsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _applyCelebration(HermesEvent event) {
    final _$actionInfo = _$ChannelEventsStoreBaseActionController.startAction(
      name: 'ChannelEventsStoreBase._applyCelebration',
    );
    try {
      return super._applyCelebration(event);
    } finally {
      _$ChannelEventsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _applyGoal(HermesEvent event) {
    final _$actionInfo = _$ChannelEventsStoreBaseActionController.startAction(
      name: 'ChannelEventsStoreBase._applyGoal',
    );
    try {
      return super._applyGoal(event);
    } finally {
      _$ChannelEventsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearCelebration() {
    final _$actionInfo = _$ChannelEventsStoreBaseActionController.startAction(
      name: 'ChannelEventsStoreBase.clearCelebration',
    );
    try {
      return super.clearCelebration();
    } finally {
      _$ChannelEventsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void playPreviewCelebration() {
    final _$actionInfo = _$ChannelEventsStoreBaseActionController.startAction(
      name: 'ChannelEventsStoreBase.playPreviewCelebration',
    );
    try {
      return super.playPreviewCelebration();
    } finally {
      _$ChannelEventsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
