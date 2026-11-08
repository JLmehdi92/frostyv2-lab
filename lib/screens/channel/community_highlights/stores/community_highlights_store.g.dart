// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_highlights_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CommunityHighlightsStore on CommunityHighlightsStoreBase, Store {
  Computed<bool>? _$stayingOnRaidComputed;

  @override
  bool get stayingOnRaid => (_$stayingOnRaidComputed ??= Computed<bool>(
    () => super.stayingOnRaid,
    name: 'CommunityHighlightsStoreBase.stayingOnRaid',
  )).value;
  Computed<bool>? _$departingComputed;

  @override
  bool get departing => (_$departingComputed ??= Computed<bool>(
    () => super.departing,
    name: 'CommunityHighlightsStoreBase.departing',
  )).value;
  Computed<String?>? _$votedChoiceIdComputed;

  @override
  String? get votedChoiceId => (_$votedChoiceIdComputed ??= Computed<String?>(
    () => super.votedChoiceId,
    name: 'CommunityHighlightsStoreBase.votedChoiceId',
  )).value;
  Computed<bool>? _$canVoteComputed;

  @override
  bool get canVote => (_$canVoteComputed ??= Computed<bool>(
    () => super.canVote,
    name: 'CommunityHighlightsStoreBase.canVote',
  )).value;
  Computed<HighlightItem?>? _$currentComputed;

  @override
  HighlightItem? get current => (_$currentComputed ??= Computed<HighlightItem?>(
    () => super.current,
    name: 'CommunityHighlightsStoreBase.current',
  )).value;
  Computed<bool>? _$visibleComputed;

  @override
  bool get visible => (_$visibleComputed ??= Computed<bool>(
    () => super.visible,
    name: 'CommunityHighlightsStoreBase.visible',
  )).value;

  late final _$_pollAtom = Atom(
    name: 'CommunityHighlightsStoreBase._poll',
    context: context,
  );

  Poll? get poll {
    _$_pollAtom.reportRead();
    return super._poll;
  }

  @override
  Poll? get _poll => poll;

  @override
  set _poll(Poll? value) {
    _$_pollAtom.reportWrite(value, super._poll, () {
      super._poll = value;
    });
  }

  late final _$_predictionAtom = Atom(
    name: 'CommunityHighlightsStoreBase._prediction',
    context: context,
  );

  Prediction? get prediction {
    _$_predictionAtom.reportRead();
    return super._prediction;
  }

  @override
  Prediction? get _prediction => prediction;

  @override
  set _prediction(Prediction? value) {
    _$_predictionAtom.reportWrite(value, super._prediction, () {
      super._prediction = value;
    });
  }

  late final _$_pinnedAtom = Atom(
    name: 'CommunityHighlightsStoreBase._pinned',
    context: context,
  );

  PinnedChatMessage? get pinned {
    _$_pinnedAtom.reportRead();
    return super._pinned;
  }

  @override
  PinnedChatMessage? get _pinned => pinned;

  @override
  set _pinned(PinnedChatMessage? value) {
    _$_pinnedAtom.reportWrite(value, super._pinned, () {
      super._pinned = value;
    });
  }

  late final _$_raidAtom = Atom(
    name: 'CommunityHighlightsStoreBase._raid',
    context: context,
  );

  RaidState? get raid {
    _$_raidAtom.reportRead();
    return super._raid;
  }

  @override
  RaidState? get _raid => raid;

  @override
  set _raid(RaidState? value) {
    _$_raidAtom.reportWrite(value, super._raid, () {
      super._raid = value;
    });
  }

  late final _$_giftBombAtom = Atom(
    name: 'CommunityHighlightsStoreBase._giftBomb',
    context: context,
  );

  GiftBombBanner? get giftBomb {
    _$_giftBombAtom.reportRead();
    return super._giftBomb;
  }

  @override
  GiftBombBanner? get _giftBomb => giftBomb;

  @override
  set _giftBomb(GiftBombBanner? value) {
    _$_giftBombAtom.reportWrite(value, super._giftBomb, () {
      super._giftBomb = value;
    });
  }

  late final _$_incomingRaidAtom = Atom(
    name: 'CommunityHighlightsStoreBase._incomingRaid',
    context: context,
  );

  IncomingRaidBanner? get incomingRaid {
    _$_incomingRaidAtom.reportRead();
    return super._incomingRaid;
  }

  @override
  IncomingRaidBanner? get _incomingRaid => incomingRaid;

  @override
  set _incomingRaid(IncomingRaidBanner? value) {
    _$_incomingRaidAtom.reportWrite(value, super._incomingRaid, () {
      super._incomingRaid = value;
    });
  }

  late final _$_stayingForAtom = Atom(
    name: 'CommunityHighlightsStoreBase._stayingFor',
    context: context,
  );

  String? get stayingFor {
    _$_stayingForAtom.reportRead();
    return super._stayingFor;
  }

  @override
  String? get _stayingFor => stayingFor;

  @override
  set _stayingFor(String? value) {
    _$_stayingForAtom.reportWrite(value, super._stayingFor, () {
      super._stayingFor = value;
    });
  }

  late final _$_departingForAtom = Atom(
    name: 'CommunityHighlightsStoreBase._departingFor',
    context: context,
  );

  String? get departingFor {
    _$_departingForAtom.reportRead();
    return super._departingFor;
  }

  @override
  String? get _departingFor => departingFor;

  @override
  set _departingFor(String? value) {
    _$_departingForAtom.reportWrite(value, super._departingFor, () {
      super._departingFor = value;
    });
  }

  late final _$_pollVoteAtom = Atom(
    name: 'CommunityHighlightsStoreBase._pollVote',
    context: context,
  );

  ({String choiceId, String pollId})? get pollVote {
    _$_pollVoteAtom.reportRead();
    return super._pollVote;
  }

  @override
  ({String choiceId, String pollId})? get _pollVote => pollVote;

  @override
  set _pollVote(({String choiceId, String pollId})? value) {
    _$_pollVoteAtom.reportWrite(value, super._pollVote, () {
      super._pollVote = value;
    });
  }

  late final _$_votingAtom = Atom(
    name: 'CommunityHighlightsStoreBase._voting',
    context: context,
  );

  bool get voting {
    _$_votingAtom.reportRead();
    return super._voting;
  }

  @override
  bool get _voting => voting;

  @override
  set _voting(bool value) {
    _$_votingAtom.reportWrite(value, super._voting, () {
      super._voting = value;
    });
  }

  late final _$_stackAtom = Atom(
    name: 'CommunityHighlightsStoreBase._stack',
    context: context,
  );

  HighlightStack get stack {
    _$_stackAtom.reportRead();
    return super._stack;
  }

  @override
  HighlightStack get _stack => stack;

  @override
  set _stack(HighlightStack value) {
    _$_stackAtom.reportWrite(value, super._stack, () {
      super._stack = value;
    });
  }

  late final _$stayOnRaidAsyncAction = AsyncAction(
    'CommunityHighlightsStoreBase.stayOnRaid',
    context: context,
  );

  @override
  Future<ViewerActionOutcome?> stayOnRaid() {
    return _$stayOnRaidAsyncAction.run(() => super.stayOnRaid());
  }

  late final _$joinRaidAgainAsyncAction = AsyncAction(
    'CommunityHighlightsStoreBase.joinRaidAgain',
    context: context,
  );

  @override
  Future<ViewerActionOutcome?> joinRaidAgain() {
    return _$joinRaidAgainAsyncAction.run(() => super.joinRaidAgain());
  }

  late final _$voteInPollAsyncAction = AsyncAction(
    'CommunityHighlightsStoreBase.voteInPoll',
    context: context,
  );

  @override
  Future<ViewerActionOutcome?> voteInPoll(String choiceId) {
    return _$voteInPollAsyncAction.run(() => super.voteInPoll(choiceId));
  }

  late final _$CommunityHighlightsStoreBaseActionController = ActionController(
    name: 'CommunityHighlightsStoreBase',
    context: context,
  );

  @override
  void markDeparting(OutgoingRaid? raid) {
    final _$actionInfo = _$CommunityHighlightsStoreBaseActionController
        .startAction(name: 'CommunityHighlightsStoreBase.markDeparting');
    try {
      return super.markDeparting(raid);
    } finally {
      _$CommunityHighlightsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void select(int index) {
    final _$actionInfo = _$CommunityHighlightsStoreBaseActionController
        .startAction(name: 'CommunityHighlightsStoreBase.select');
    try {
      return super.select(index);
    } finally {
      _$CommunityHighlightsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleExpanded() {
    final _$actionInfo = _$CommunityHighlightsStoreBaseActionController
        .startAction(name: 'CommunityHighlightsStoreBase.toggleExpanded');
    try {
      return super.toggleExpanded();
    } finally {
      _$CommunityHighlightsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void dismissCurrent() {
    final _$actionInfo = _$CommunityHighlightsStoreBaseActionController
        .startAction(name: 'CommunityHighlightsStoreBase.dismissCurrent');
    try {
      return super.dismissCurrent();
    } finally {
      _$CommunityHighlightsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void showGiftBomb(GiftBomb bomb, {ValueListenable<GiftBomb>? live}) {
    final _$actionInfo = _$CommunityHighlightsStoreBaseActionController
        .startAction(name: 'CommunityHighlightsStoreBase.showGiftBomb');
    try {
      return super.showGiftBomb(bomb, live: live);
    } finally {
      _$CommunityHighlightsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void showIncomingRaid(IncomingRaid raid) {
    final _$actionInfo = _$CommunityHighlightsStoreBaseActionController
        .startAction(name: 'CommunityHighlightsStoreBase.showIncomingRaid');
    try {
      return super.showIncomingRaid(raid);
    } finally {
      _$CommunityHighlightsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _commit() {
    final _$actionInfo = _$CommunityHighlightsStoreBaseActionController
        .startAction(name: 'CommunityHighlightsStoreBase._commit');
    try {
      return super._commit();
    } finally {
      _$CommunityHighlightsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
stayingOnRaid: ${stayingOnRaid},
departing: ${departing},
votedChoiceId: ${votedChoiceId},
canVote: ${canVote},
current: ${current},
visible: ${visible}
    ''';
  }
}
