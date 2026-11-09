// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel_events_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ChannelEventsStore on ChannelEventsStoreBase, Store {
  Computed<bool>? _$canShareWatchStreakComputed;

  @override
  bool get canShareWatchStreak =>
      (_$canShareWatchStreakComputed ??= Computed<bool>(
        () => super.canShareWatchStreak,
        name: 'ChannelEventsStoreBase.canShareWatchStreak',
      )).value;
  Computed<bool>? _$canShareResubComputed;

  @override
  bool get canShareResub => (_$canShareResubComputed ??= Computed<bool>(
    () => super.canShareResub,
    name: 'ChannelEventsStoreBase.canShareResub',
  )).value;

  late final _$_sharingWatchStreakAtom = Atom(
    name: 'ChannelEventsStoreBase._sharingWatchStreak',
    context: context,
  );

  bool get sharingWatchStreak {
    _$_sharingWatchStreakAtom.reportRead();
    return super._sharingWatchStreak;
  }

  @override
  bool get _sharingWatchStreak => sharingWatchStreak;

  @override
  set _sharingWatchStreak(bool value) {
    _$_sharingWatchStreakAtom.reportWrite(value, super._sharingWatchStreak, () {
      super._sharingWatchStreak = value;
    });
  }

  late final _$_resubNotificationAtom = Atom(
    name: 'ChannelEventsStoreBase._resubNotification',
    context: context,
  );

  ResubNotification? get resubNotification {
    _$_resubNotificationAtom.reportRead();
    return super._resubNotification;
  }

  @override
  ResubNotification? get _resubNotification => resubNotification;

  @override
  set _resubNotification(ResubNotification? value) {
    _$_resubNotificationAtom.reportWrite(value, super._resubNotification, () {
      super._resubNotification = value;
    });
  }

  late final _$_sharingResubAtom = Atom(
    name: 'ChannelEventsStoreBase._sharingResub',
    context: context,
  );

  bool get sharingResub {
    _$_sharingResubAtom.reportRead();
    return super._sharingResub;
  }

  @override
  bool get _sharingResub => sharingResub;

  @override
  set _sharingResub(bool value) {
    _$_sharingResubAtom.reportWrite(value, super._sharingResub, () {
      super._sharingResub = value;
    });
  }

  late final _$_dropCampaignsAtom = Atom(
    name: 'ChannelEventsStoreBase._dropCampaigns',
    context: context,
  );

  List<DropCampaign> get dropCampaigns {
    _$_dropCampaignsAtom.reportRead();
    return super._dropCampaigns;
  }

  @override
  List<DropCampaign> get _dropCampaigns => dropCampaigns;

  @override
  set _dropCampaigns(List<DropCampaign> value) {
    _$_dropCampaignsAtom.reportWrite(value, super._dropCampaigns, () {
      super._dropCampaigns = value;
    });
  }

  late final _$_claimingDropIdAtom = Atom(
    name: 'ChannelEventsStoreBase._claimingDropId',
    context: context,
  );

  String? get claimingDropId {
    _$_claimingDropIdAtom.reportRead();
    return super._claimingDropId;
  }

  @override
  String? get _claimingDropId => claimingDropId;

  @override
  set _claimingDropId(String? value) {
    _$_claimingDropIdAtom.reportWrite(value, super._claimingDropId, () {
      super._claimingDropId = value;
    });
  }

  late final _$_weeklyRewardsAtom = Atom(
    name: 'ChannelEventsStoreBase._weeklyRewards',
    context: context,
  );

  WeeklyRewards? get weeklyRewards {
    _$_weeklyRewardsAtom.reportRead();
    return super._weeklyRewards;
  }

  @override
  WeeklyRewards? get _weeklyRewards => weeklyRewards;

  @override
  set _weeklyRewards(WeeklyRewards? value) {
    _$_weeklyRewardsAtom.reportWrite(value, super._weeklyRewards, () {
      super._weeklyRewards = value;
    });
  }

  late final _$_momentAtom = Atom(
    name: 'ChannelEventsStoreBase._moment',
    context: context,
  );

  CommunityMoment? get moment {
    _$_momentAtom.reportRead();
    return super._moment;
  }

  @override
  CommunityMoment? get _moment => moment;

  @override
  set _moment(CommunityMoment? value) {
    _$_momentAtom.reportWrite(value, super._moment, () {
      super._moment = value;
    });
  }

  late final _$_claimingMomentAtom = Atom(
    name: 'ChannelEventsStoreBase._claimingMoment',
    context: context,
  );

  bool get claimingMoment {
    _$_claimingMomentAtom.reportRead();
    return super._claimingMoment;
  }

  @override
  bool get _claimingMoment => claimingMoment;

  @override
  set _claimingMoment(bool value) {
    _$_claimingMomentAtom.reportWrite(value, super._claimingMoment, () {
      super._claimingMoment = value;
    });
  }

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

  late final _$_watchStreakAtom = Atom(
    name: 'ChannelEventsStoreBase._watchStreak',
    context: context,
  );

  WatchStreak? get watchStreak {
    _$_watchStreakAtom.reportRead();
    return super._watchStreak;
  }

  @override
  WatchStreak? get _watchStreak => watchStreak;

  @override
  set _watchStreak(WatchStreak? value) {
    _$_watchStreakAtom.reportWrite(value, super._watchStreak, () {
      super._watchStreak = value;
    });
  }

  late final _$_contentLabelsAtom = Atom(
    name: 'ChannelEventsStoreBase._contentLabels',
    context: context,
  );

  List<String>? get contentLabels {
    _$_contentLabelsAtom.reportRead();
    return super._contentLabels;
  }

  @override
  List<String>? get _contentLabels => contentLabels;

  @override
  set _contentLabels(List<String>? value) {
    _$_contentLabelsAtom.reportWrite(value, super._contentLabels, () {
      super._contentLabels = value;
    });
  }

  late final _$_paidPromotionAtom = Atom(
    name: 'ChannelEventsStoreBase._paidPromotion',
    context: context,
  );

  bool get paidPromotion {
    _$_paidPromotionAtom.reportRead();
    return super._paidPromotion;
  }

  @override
  bool get _paidPromotion => paidPromotion;

  @override
  set _paidPromotion(bool value) {
    _$_paidPromotionAtom.reportWrite(value, super._paidPromotion, () {
      super._paidPromotion = value;
    });
  }

  late final _$_bitsBalanceAtom = Atom(
    name: 'ChannelEventsStoreBase._bitsBalance',
    context: context,
  );

  int? get bitsBalance {
    _$_bitsBalanceAtom.reportRead();
    return super._bitsBalance;
  }

  @override
  int? get _bitsBalance => bitsBalance;

  @override
  set _bitsBalance(int? value) {
    _$_bitsBalanceAtom.reportWrite(value, super._bitsBalance, () {
      super._bitsBalance = value;
    });
  }

  late final _$_giftedSinceJoiningAtom = Atom(
    name: 'ChannelEventsStoreBase._giftedSinceJoining',
    context: context,
  );

  int get giftedSinceJoining {
    _$_giftedSinceJoiningAtom.reportRead();
    return super._giftedSinceJoining;
  }

  @override
  int get _giftedSinceJoining => giftedSinceJoining;

  @override
  set _giftedSinceJoining(int value) {
    _$_giftedSinceJoiningAtom.reportWrite(value, super._giftedSinceJoining, () {
      super._giftedSinceJoining = value;
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

  late final _$_goalsAtom = Atom(
    name: 'ChannelEventsStoreBase._goals',
    context: context,
  );

  List<CreatorGoal> get goals {
    _$_goalsAtom.reportRead();
    return super._goals;
  }

  @override
  List<CreatorGoal> get _goals => goals;

  @override
  set _goals(List<CreatorGoal> value) {
    _$_goalsAtom.reportWrite(value, super._goals, () {
      super._goals = value;
    });
  }

  late final _$shareWatchStreakAsyncAction = AsyncAction(
    'ChannelEventsStoreBase.shareWatchStreak',
    context: context,
  );

  @override
  Future<ViewerActionOutcome?> shareWatchStreak() {
    return _$shareWatchStreakAsyncAction.run(() => super.shareWatchStreak());
  }

  late final _$claimDropAsyncAction = AsyncAction(
    'ChannelEventsStoreBase.claimDrop',
    context: context,
  );

  @override
  Future<DropClaimResult?> claimDrop(TimedDrop drop) {
    return _$claimDropAsyncAction.run(() => super.claimDrop(drop));
  }

  late final _$claimMomentAsyncAction = AsyncAction(
    'ChannelEventsStoreBase.claimMoment',
    context: context,
  );

  @override
  Future<MomentClaimResult?> claimMoment() {
    return _$claimMomentAsyncAction.run(() => super.claimMoment());
  }

  late final _$unlockChosenEmoteAsyncAction = AsyncAction(
    'ChannelEventsStoreBase.unlockChosenEmote',
    context: context,
  );

  @override
  Future<PointsActionResult> unlockChosenEmote(
    PointsReward reward,
    String emoteId,
  ) {
    return _$unlockChosenEmoteAsyncAction.run(
      () => super.unlockChosenEmote(reward, emoteId),
    );
  }

  late final _$shareResubAsyncAction = AsyncAction(
    'ChannelEventsStoreBase.shareResub',
    context: context,
  );

  @override
  Future<ViewerActionOutcome?> shareResub({String? message}) {
    return _$shareResubAsyncAction.run(
      () => super.shareResub(message: message),
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

  late final _$redeemRewardAsyncAction = AsyncAction(
    'ChannelEventsStoreBase.redeemReward',
    context: context,
  );

  @override
  Future<PointsActionResult> redeemReward(
    PointsReward reward, {
    String? userInput,
  }) {
    return _$redeemRewardAsyncAction.run(
      () => super.redeemReward(reward, userInput: userInput),
    );
  }

  late final _$ChannelEventsStoreBaseActionController = ActionController(
    name: 'ChannelEventsStoreBase',
    context: context,
  );

  @override
  void _applyContentLabels(HermesEvent event) {
    final _$actionInfo = _$ChannelEventsStoreBaseActionController.startAction(
      name: 'ChannelEventsStoreBase._applyContentLabels',
    );
    try {
      return super._applyContentLabels(event);
    } finally {
      _$ChannelEventsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _applyBitsBalance(HermesEvent event) {
    final _$actionInfo = _$ChannelEventsStoreBaseActionController.startAction(
      name: 'ChannelEventsStoreBase._applyBitsBalance',
    );
    try {
      return super._applyBitsBalance(event);
    } finally {
      _$ChannelEventsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _applySubGifts(HermesEvent event) {
    final _$actionInfo = _$ChannelEventsStoreBaseActionController.startAction(
      name: 'ChannelEventsStoreBase._applySubGifts',
    );
    try {
      return super._applySubGifts(event);
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
canShareWatchStreak: ${canShareWatchStreak},
canShareResub: ${canShareResub}
    ''';
  }
}
