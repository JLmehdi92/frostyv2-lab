import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/base_api_client.dart' as api;
import 'package:onset/apis/twitch_community_highlights_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/community_highlight_event.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:onset/screens/channel/chat/incoming_raid.dart';
import 'package:onset/screens/channel/community_highlights/highlight_reducers.dart';
import 'package:onset/screens/channel/community_highlights/highlight_stack.dart';
import 'package:onset/screens/channel/community_highlights/highlight_timings.dart';
import 'package:onset/screens/channel/hype_train/hype_train_clock.dart';
import 'package:onset/services/realtime/twitch_realtime_client.dart';
import 'package:onset/services/telemetry.dart';

part 'community_highlights_store.g.dart';

typedef PollVoter =
    Future<ViewerActionOutcome> Function({
      required String pollId,
      required String choiceId,
    });

typedef PinRemover = Future<ViewerActionOutcome> Function(String pinId);

typedef RaidMembership =
    Future<ViewerActionOutcome> Function(String raidId, {required bool join});

typedef PollVote = ({String pollId, String choiceId});

class CommunityHighlightsStore = CommunityHighlightsStoreBase
    with _$CommunityHighlightsStore;

/// A channel's poll, prediction, pinned message, outgoing raid and gift bomb
/// banner, and the stack deciding which one shows above chat.
///
/// Snapshots come from anonymous GQL; changes from the four public Hermes
/// topics. Frequent updates (votes, points, raid viewers) are coalesced so
/// the screen changes at most twice a second; a new highlight or a status
/// change shows at once. Everything is read-only and anonymous: a failure
/// only hides the highlights.
abstract class CommunityHighlightsStoreBase with Store {
  CommunityHighlightsStoreBase({
    required this.channelId,
    this.channelLogin,
    this.channelName,
    required TwitchCommunityHighlightsService service,
    required TwitchRealtimeClient realtime,
    ServerClock? serverClock,
    this.expandNew = false,
    this.onGoAlong,
    this.isPinHidden,
    this.onHidePin,
    this.pollVoter,
    this.raidMembership,
    this.pinRemover,
    this.canRemovePins,
  }) : _service = service,
       serverClock = serverClock ?? ServerClock() {
    for (final topic in HighlightTopic.values) {
      try {
        final subscription = realtime.subscribe(topic.topicFor(channelId));
        _subscriptions.add(subscription);
        _topicEvents.add(
          subscription.events.listen((event) => _onTopicEvent(topic, event)),
        );
      } on Object catch (e) {
        _log('subscribe ${topic.prefix} failed: $e');
        _degraded.add(topic);
      }
    }
    unawaited(_fetchPoll());
    unawaited(_fetchPredictions());
    unawaited(_fetchPinned(initial: true));
    _updatePolling();
  }

  final String channelId;

  /// The channel's login, to vote or predict on its twitch.tv chat page.
  final String? channelLogin;

  /// The channel's display name ("X is raiding Y").
  final String? channelName;
  final TwitchCommunityHighlightsService _service;

  /// Twitch's time, learnt from notification timestamps.
  final ServerClock serverClock;

  /// New polls, predictions and raids arrive expanded (large screens); a
  /// pinned message never does, so it never holds a new one back.
  final bool expandNew;

  final bool Function(String pinId)? isPinHidden;

  final void Function(String pinId)? onHidePin;

  final PollVoter? pollVoter;

  final RaidMembership? raidMembership;

  final PinRemover? pinRemover;

  final bool Function()? canRemovePins;

  var _unpinning = false;

  bool get canUnpin =>
      pinRemover != null && _pinned != null && (canRemovePins?.call() ?? false);

  Future<ViewerActionOutcome?> unpin() async {
    final remover = pinRemover;
    final pin = _pinned;
    if (_unpinning || remover == null || pin == null || !canUnpin) return null;
    _unpinning = true;
    try {
      final outcome = await remover(pin.id);
      if (outcome == ViewerActionOutcome.done) unawaited(_fetchPinned());
      return outcome;
    } finally {
      _unpinning = false;
    }
  }

  final _newPins = StreamController<PinnedChatMessage>.broadcast();

  Stream<PinnedChatMessage> get newPins => _newPins.stream;

  bool _hidden(String? pinId) =>
      pinId != null && (isPinHidden?.call(pinId) ?? false);

  final _subscriptions = <RealtimeTopicSubscription>[];
  final _topicEvents = <StreamSubscription<RealtimeTopicEvent>>[];
  final _degraded = <HighlightTopic>{};
  final _deadlines = <HighlightKind, Timer>{};

  // When each highlight was first seen ended (Twitch time): a later commit
  // never pushes its removal back.
  final _pollEnded = _FirstSeen();
  final _predictionEnded = _FirstSeen();
  final _raidSeen = _FirstSeen();
  final _raidGone = _FirstSeen();
  final _raidCancelled = _FirstSeen();

  /// Raids called off this session (the latest few): a late event of one
  /// never brings it back.
  final _raidsCalledOff = <String>{};
  final _lastFetch = <HighlightTopic, DateTime>{};
  final _inFlight = <HighlightTopic, Future<void>>{};
  final _trailing = <HighlightTopic, Timer>{};

  /// A fetch asked for while one was out: it runs once that one ends.
  final _again = <HighlightTopic, Future<void> Function()>{};

  /// Realtime events applied, per topic: a GQL answer that started before
  /// one of them is older than what shows, and is dropped.
  final _events = <HighlightTopic, int>{};
  final _failures = <HighlightTopic, int>{};
  final _gqlOff = <HighlightTopic>{};
  Timer? _commitTimer;
  Timer? _pollTimer;
  DateTime? _lastCommit;
  var _disposed = false;

  // The latest state, applied to the observables by [_commit].
  Poll? _nextPoll;
  Prediction? _nextPrediction;
  DateTime? _predictionTimestamp;
  PinnedChatMessage? _nextPinned;
  var _pinnedSticky = false;
  RaidState? _nextRaid;
  GiftBombBanner? _nextGiftBomb;
  IncomingRaidBanner? _nextIncomingRaid;

  /// When each raider was last pinned (Twitch time), so one raid heard
  /// twice pins once.
  final _incomingPinned = <String, DateTime>{};
  var _incomingCount = 0;

  @readonly
  Poll? _poll;

  @readonly
  Prediction? _prediction;

  @readonly
  PinnedChatMessage? _pinned;

  @readonly
  RaidState? _raid;

  /// The gift bomb banner, fed from the channel's chat (see [showGiftBomb]).
  @readonly
  GiftBombBanner? _giftBomb;

  /// A channel raiding this one, pinned for a few seconds (see
  /// [showIncomingRaid]).
  @readonly
  IncomingRaidBanner? _incomingRaid;

  /// Takes the viewer to the raid's target when it leaves, as Twitch does,
  /// unless they chose to stay ([stayOnRaid]). Only a raid seen counting
  /// down: one first seen already gone does not move them.
  final void Function(OutgoingRaid raid)? onGoAlong;

  /// The raid the viewer chose not to go along with.
  @readonly
  String? _stayingFor;

  /// Whether the viewer stays here when the current raid leaves.
  @computed
  bool get stayingOnRaid {
    final raid = _raid;
    return raid != null && raid.raid.id == _stayingFor;
  }

  /// The raid the viewer is on their way to (the card shows them leaving).
  @readonly
  String? _departingFor;

  /// Whether the viewer is leaving with the current raid.
  @computed
  bool get departing {
    final raid = _raid;
    return raid != null && raid.raid.id == _departingFor;
  }

  /// The viewer is on their way to [raid]'s target (null: they stayed
  /// after all).
  @action
  void markDeparting(OutgoingRaid? raid) => _departingFor = raid?.id;

  /// Stays on this channel when the current raid leaves.
  @action
  Future<ViewerActionOutcome?> stayOnRaid() async {
    final raid = _nextRaid ?? _raid;
    if (raid == null) return null;
    final id = raid.raid.id;
    _stayingFor = id;
    final outcome = await raidMembership?.call(id, join: false);
    if (outcome != null &&
        outcome != ViewerActionOutcome.done &&
        _stayingFor == id) {
      runInAction(() => _stayingFor = null);
    }
    return outcome;
  }

  @action
  Future<ViewerActionOutcome?> joinRaidAgain() async {
    final raid = _nextRaid ?? _raid;
    if (raid == null ||
        raid.raid.id != _stayingFor ||
        raid.gone ||
        raid.cancelled) {
      return null;
    }
    _stayingFor = null;
    return raidMembership?.call(raid.raid.id, join: true);
  }

  @readonly
  PollVote? _pollVote;

  @readonly
  var _voting = false;

  @computed
  String? get votedChoiceId {
    final vote = _pollVote;
    return vote != null && vote.pollId == _poll?.id ? vote.choiceId : null;
  }

  @computed
  bool get canVote {
    final poll = _poll;
    return pollVoter != null &&
        poll != null &&
        poll.isActive &&
        votedChoiceId == null;
  }

  @action
  Future<ViewerActionOutcome?> voteInPoll(String choiceId) async {
    final poll = _poll;
    final voter = pollVoter;
    if (_voting || voter == null || poll == null || !canVote) return null;
    if (!poll.choices.any((choice) => choice.id == choiceId)) return null;
    _voting = true;
    try {
      final outcome = await voter(pollId: poll.id, choiceId: choiceId);
      if (outcome == ViewerActionOutcome.done) {
        runInAction(() => _pollVote = (pollId: poll.id, choiceId: choiceId));
      }
      return outcome;
    } finally {
      runInAction(() => _voting = false);
    }
  }

  @readonly
  var _stack = const HighlightStack();

  /// The highlight on screen.
  @computed
  HighlightItem? get current => _stack.current;

  @computed
  bool get visible => _stack.items.isNotEmpty;

  /// Twitch's current time, for countdowns.
  DateTime serverNow() => serverClock.now();

  // --- Viewer actions ------------------------------------------------------------

  @action
  void select(int index) => _stack = _stack.select(index);

  @action
  void toggleExpanded() => _stack = _stack.toggleExpanded();

  /// Hides the visible highlight for this session; a pinned message stays
  /// hidden for good.
  @action
  void dismissCurrent() {
    final current = _stack.current;
    if (current == null) return;
    if (current.kind == HighlightKind.pinned) onHidePin?.call(current.id);
    _stack = _stack.dismiss(current.kind, current.id);
  }

  // --- Chat ----------------------------------------------------------------------

  /// Pins [bomb]'s banner from now for as long as Twitch would (see
  /// [bannerDuration]); a bomb too small for one is ignored. A newer bomb
  /// replaces the one up. [live] follows its gifts as they arrive.
  @action
  void showGiftBomb(GiftBomb bomb, {ValueListenable<GiftBomb>? live}) {
    final duration = bannerDuration(bomb.count);
    if (_disposed || duration == null) return;
    final startedAt = serverNow();
    _nextGiftBomb = GiftBombBanner(
      bomb: bomb,
      startedAt: startedAt,
      endsAt: startedAt.add(duration),
      live: live,
    );
    _changed(urgent: true);
  }

  /// Pins [raid] for [kIncomingRaidPin] from now; the same raider again
  /// within [kIncomingRaidRepeat] is the same raid, and pins nothing.
  @action
  void showIncomingRaid(IncomingRaid raid) {
    if (_disposed) return;
    final now = serverNow();
    _incomingPinned.removeWhere(
      (_, at) => now.difference(at) >= kIncomingRaidRepeat,
    );
    final key = raid.raiderKey;
    if (_incomingPinned.containsKey(key)) return;
    _incomingPinned[key] = now;
    _nextIncomingRaid = IncomingRaidBanner(
      raid: raid,
      id: 'raid-${++_incomingCount}',
      endsAt: now.add(kIncomingRaidPin),
    );
    _changed(urgent: true);
  }

  // --- Realtime ------------------------------------------------------------------

  void _onTopicEvent(HighlightTopic topic, RealtimeTopicEvent event) {
    if (_disposed) return;
    switch (event) {
      case RealtimeMessage(:final payload, :final serverTime):
        if (serverTime != null) serverClock.observe(serverTime);
        _apply(ChEvent.parse(topic, payload));
      case RealtimeSubscribed(:final isResubscribe):
        if (isResubscribe) {
          // A new connection: give the snapshot another chance.
          _gqlOff.remove(topic);
          _failures.remove(topic);
        }
        _degraded.remove(topic);
        _updatePolling();
        if (isResubscribe) unawaited(_fetch(topic));
      case RealtimeUnavailable():
        _degraded.add(topic);
        _updatePolling();
    }
  }

  void _apply(ChEvent event) {
    switch (event) {
      case PollEvent(:final poll):
        if (poll.channelId != null && poll.channelId != channelId) return;
        _saw(HighlightTopic.polls);
        final before = _nextPoll;
        _nextPoll = reducePoll(before, event);
        _changed(urgent: _isUrgent(before, _nextPoll));
      case PredictionEvent(:final prediction):
        if (prediction.channelId != null && prediction.channelId != channelId) {
          return;
        }
        _saw(HighlightTopic.predictions);
        final before = _nextPrediction;
        final next = reducePrediction(
          before,
          event,
          lastTimestamp: _predictionTimestamp,
        );
        _nextPrediction = next.prediction;
        _predictionTimestamp = next.timestamp;
        _changed(urgent: _isUrgent(before, _nextPrediction));
      case PinEvent() || UnpinEvent() || PinUpdateEvent():
        // An update carries no details: the refetch it asks for is newer.
        if (event is! PinUpdateEvent) _saw(HighlightTopic.pinned);
        final next = reducePinned(_nextPinned, event);
        if (next.refetch) unawaited(_fetchPinned());
        final pin = next.pin;
        if (event is PinEvent &&
            pin != null &&
            pin.id != _nextPinned?.id &&
            !_hidden(pin.id)) {
          _newPins.add(pin);
        }
        if (!identical(next.pin, _nextPinned)) {
          _nextPinned = next.pin;
          _pinnedSticky = false;
          _changed(urgent: true);
        }
      case RaidEvent(:final raid):
        // A raid called off stays so, even once its card is gone.
        if (_raidsCalledOff.contains(raid.id)) return;
        final before = _nextRaid;
        _nextRaid = reduceRaid(before, event, channelId: channelId);
        if (identical(before, _nextRaid)) return;
        _changed(
          urgent:
              before == null ||
              _nextRaid == null ||
              before.gone != _nextRaid!.gone ||
              before.cancelled != _nextRaid!.cancelled,
        );
        final next = _nextRaid;
        if (next != null && next.cancelled) {
          _raidsCalledOff.add(next.raid.id);
          if (_raidsCalledOff.length > 8) {
            _raidsCalledOff.remove(_raidsCalledOff.first);
          }
        }
        if (before != null &&
            !before.gone &&
            !before.cancelled &&
            next != null &&
            next.gone &&
            next.raid.id == before.raid.id &&
            next.raid.id != _stayingFor) {
          onGoAlong?.call(next.raid);
        }
      case ChUnknown():
        break;
    }
  }

  void _saw(HighlightTopic topic) => _events[topic] = (_events[topic] ?? 0) + 1;

  /// A new or gone highlight, or a new status, shows at once; the rest is
  /// coalesced.
  static bool _isUrgent(Object? before, Object? after) =>
      switch ((before, after)) {
        (final Poll a, final Poll b) => a.id != b.id || a.status != b.status,
        (final Prediction a, final Prediction b) =>
          a.id != b.id || a.status != b.status,
        (null, null) => false,
        _ => true,
      };

  void _changed({required bool urgent}) {
    if (_disposed) return;
    final last = _lastCommit;
    final now = clock.now();
    if (urgent ||
        last == null ||
        now.difference(last) >= kHighlightCommitInterval) {
      _commitTimer?.cancel();
      _commitTimer = null;
      _commit();
      return;
    }
    _commitTimer ??= Timer(kHighlightCommitInterval - now.difference(last), () {
      _commitTimer = null;
      _commit();
    });
  }

  @action
  void _commit() {
    if (_disposed) return;
    _lastCommit = clock.now();
    _poll = _nextPoll;
    _prediction = _nextPrediction;
    _pinned = _nextPinned;
    _raid = _nextRaid;
    _giftBomb = _nextGiftBomb;
    _incomingRaid = _nextIncomingRaid;

    var stack = _stack;
    stack = _sync(stack, HighlightKind.poll, _poll?.id);
    stack = _sync(stack, HighlightKind.prediction, _prediction?.id);
    final pinId = _pinned?.id;
    stack = _sync(
      stack,
      HighlightKind.pinned,
      _hidden(pinId) ? null : pinId,
      sticky: _pinnedSticky,
    );
    stack = _sync(stack, HighlightKind.raid, _raid?.raid.id);
    stack = _sync(stack, HighlightKind.giftBomb, _giftBomb?.id);
    stack = _sync(stack, HighlightKind.incomingRaid, _incomingRaid?.id);
    _stack = stack;
    _scheduleDeadlines();
  }

  HighlightStack _sync(
    HighlightStack stack,
    HighlightKind kind,
    String? id, {
    bool sticky = false,
  }) {
    if (id == null) return stack.remove(kind);
    final existing = stack.items.where((i) => i.kind == kind).firstOrNull;
    if (existing?.id == id) return stack;
    return stack.upsert(
      HighlightItem(
        kind: kind,
        id: id,
        sticky: sticky,
        // A pinned message, a raid (its card has no collapsed form) and
        // the short-lived pins never arrive expanded, so none holds a new
        // highlight back.
        expanded:
            expandNew &&
            kind != HighlightKind.pinned &&
            kind != HighlightKind.raid &&
            !kind.shortLived,
      ),
    );
  }

  // --- Deadlines -------------------------------------------------------------------

  void _scheduleDeadlines() {
    final now = serverNow();
    final poll = _nextPoll;
    _deadline(
      HighlightKind.poll,
      poll == null || poll.isActive
          ? null
          : _earliest(
              poll.endedAt,
              _pollEnded.of(poll.id, now),
            ).add(kPollResultLinger),
      () => _nextPoll = null,
    );
    final prediction = _nextPrediction;
    final linger = switch (prediction?.status) {
      PredictionStatus.resolved => kPredictionResolvedLinger,
      PredictionStatus.canceled => kPredictionCanceledLinger,
      _ => null,
    };
    _deadline(
      HighlightKind.prediction,
      prediction == null || linger == null
          ? null
          : _earliest(
              prediction.endedAt,
              _predictionEnded.of(prediction.id, now),
            ).add(linger),
      () => _nextPrediction = null,
    );
    _deadline(
      HighlightKind.pinned,
      _nextPinned?.endsAt,
      () => _nextPinned = null,
    );
    final raid = _nextRaid;
    _deadline(HighlightKind.raid, switch (raid) {
      null => null,
      // Says so for a moment, from the first cancel seen.
      RaidState(cancelled: true, :final raid) =>
        _raidCancelled.of(raid.id, now).add(kRaidCancelledLinger),
      // From the first "go" (it is sent several times).
      RaidState(gone: true, :final raid) =>
        _raidGone.of(raid.id, now).add(kRaidAfterGoLinger),
      // A lost "go" or "cancel" must not leave it up forever, nor a
      // missing or absurd departure time.
      RaidState(:final raid) => _earliest(
        raid.goAt,
        _raidSeen
            .of(raid.id, now)
            .add(Duration(seconds: raid.forceRaidNowSeconds)),
      ).add(kRaidAfterGoLinger + kRaidMissedGoMargin),
    }, () => _nextRaid = null);
    _deadline(
      HighlightKind.giftBomb,
      _nextGiftBomb?.endsAt,
      () => _nextGiftBomb = null,
    );
    _deadline(
      HighlightKind.incomingRaid,
      _nextIncomingRaid?.endsAt,
      () => _nextIncomingRaid = null,
    );
  }

  static DateTime _earliest(DateTime? a, DateTime b) =>
      a != null && a.isBefore(b) ? a : b;

  /// Removes the [kind] highlight at [at] (Twitch time), with [clear].
  void _deadline(HighlightKind kind, DateTime? at, void Function() clear) {
    if (at == null) {
      _deadlines.remove(kind)?.cancel();
      return;
    }
    _deadlines.remove(kind)?.cancel();
    final wait = at.difference(serverNow());
    _deadlines[kind] = Timer(wait.isNegative ? Duration.zero : wait, () {
      _deadlines.remove(kind);
      if (_disposed) return;
      clear();
      _commit();
    });
  }

  // --- GQL ---------------------------------------------------------------------------

  Future<void> _fetch(HighlightTopic topic) => switch (topic) {
    HighlightTopic.polls => _fetchPoll(),
    HighlightTopic.predictions => _fetchPredictions(),
    HighlightTopic.pinned => _fetchPinned(),
    HighlightTopic.raid => Future.value(),
  };

  /// Runs [fetch] for [topic]: one at a time, at most every 2 s, never
  /// after dispose, and off for the session after 3 failures in a row.
  Future<void> _guarded(HighlightTopic topic, Future<void> Function() fetch) {
    if (_disposed || _gqlOff.contains(topic)) return Future.value();
    final running = _inFlight[topic];
    if (running != null) {
      // It may have been sent before the change that asks for this one.
      _again[topic] = fetch;
      return running;
    }
    final last = _lastFetch[topic];
    final since = last == null ? null : clock.now().difference(last);
    if (since != null && since < kHighlightRefetchGap) {
      // Too soon: once, at the end of the gap (a change must not be lost).
      _trailing[topic] ??= Timer(kHighlightRefetchGap - since, () {
        _trailing.remove(topic);
        unawaited(_guarded(topic, fetch));
      });
      return Future.value();
    }
    _lastFetch[topic] = clock.now();
    return _inFlight[topic] = () async {
      try {
        await fetch();
        _failures[topic] = 0;
      } on api.NetworkException catch (e) {
        // Offline is not a broken API: the next try may work.
        _log('${topic.prefix} fetch failed (network): $e');
      } on api.TimeoutException catch (e) {
        _log('${topic.prefix} fetch failed (timeout): $e');
      } on TimeoutException catch (e) {
        _log('${topic.prefix} fetch failed (timeout): $e');
      } on Object catch (e) {
        final failures = (_failures[topic] ?? 0) + 1;
        _failures[topic] = failures;
        _log('${topic.prefix} fetch failed ($failures): $e');
        if (failures >= 3) {
          _gqlOff.add(topic);
          _updatePolling();
          // Seen in release too: Twitch probably changed the query.
          Telemetry.log(
            'community highlights: ${topic.prefix} snapshot off: $e',
          );
        }
      } finally {
        _inFlight.remove(topic);
        final again = _again.remove(topic);
        if (again != null) unawaited(_guarded(topic, again));
      }
    }();
  }

  /// [request]'s answer, or null when the store is gone or a realtime event
  /// of [topic] arrived meanwhile (it is newer than the answer).
  Future<({T value})?> _fresh<T>(
    HighlightTopic topic,
    Future<T> Function() request,
  ) async {
    final seen = _events[topic] ?? 0;
    final value = await request();
    if (_disposed || (_events[topic] ?? 0) != seen) return null;
    return (value: value);
  }

  Future<void> _fetchPoll() => _guarded(HighlightTopic.polls, () async {
    final poll = await _fresh(
      HighlightTopic.polls,
      () => _service.getPoll(channelId),
    );
    if (poll == null) return;
    final answer = poll.value;
    _nextPoll = answer == null
        ? null
        : reducePoll(
            _nextPoll,
            PollEvent(
              answer.isActive ? PollEventKind.update : PollEventKind.complete,
              answer,
            ),
          );
    _changed(urgent: true);
  });

  Future<void> _fetchPredictions() =>
      _guarded(HighlightTopic.predictions, () async {
        final answer = await _fresh(
          HighlightTopic.predictions,
          () => _service.getPredictions(channelId),
        );
        if (answer == null) return;
        final predictions = answer.value;
        final resolved = predictions.lastResolved;
        final ended = resolved?.endedAt;
        final recent =
            ended != null &&
            serverNow().difference(ended) <= kPredictionResolvedMaxAge;
        final snapshot =
            predictions.active ??
            predictions.locked ??
            (recent ? resolved : null);
        final before = _nextPrediction;
        if (snapshot != null && snapshot.id == before?.id) {
          // A lagging read never moves the status back.
          final next = reducePrediction(
            before,
            PredictionEvent(snapshot),
            lastTimestamp: _predictionTimestamp,
          );
          _nextPrediction = next.prediction;
          _predictionTimestamp = next.timestamp;
        } else {
          _nextPrediction = snapshot;
          _predictionTimestamp = null;
        }
        _changed(urgent: true);
      });

  Future<void> _fetchPinned({bool initial = false}) =>
      _guarded(HighlightTopic.pinned, () async {
        final answer = await _fresh(
          HighlightTopic.pinned,
          () => _service.getPinned(channelId),
        );
        if (answer == null) return;
        final pin = answer.value;
        final expired = pin != null && pinExpired(pin, serverNow());
        _nextPinned = expired ? null : pin;
        _pinnedSticky = initial;
        _changed(urgent: true);
      });

  /// GQL every 30 s for the kinds whose topic is unavailable.
  void _updatePolling() {
    final topics = {
      for (final topic in _degraded)
        if (topic != HighlightTopic.raid && !_gqlOff.contains(topic)) topic,
    };
    if (_disposed || topics.isEmpty) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    _pollTimer ??= Timer.periodic(kHighlightPollFallback, (_) {
      for (final topic in {..._degraded}) {
        if (topic != HighlightTopic.raid) unawaited(_fetch(topic));
      }
    });
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('CommunityHighlightsStore($channelId) $message');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_newPins.close());
    for (final events in _topicEvents) {
      unawaited(events.cancel());
    }
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    for (final timer in _deadlines.values) {
      timer.cancel();
    }
    _deadlines.clear();
    for (final timer in _trailing.values) {
      timer.cancel();
    }
    _commitTimer?.cancel();
    _pollTimer?.cancel();
  }
}

/// When an id was first seen, kept while that id stays.
class _FirstSeen {
  String? _id;
  DateTime? _at;

  DateTime of(String id, DateTime now) {
    if (_id != id || _at == null) {
      _id = id;
      _at = now;
    }
    return _at!;
  }
}
