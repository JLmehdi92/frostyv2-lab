import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:frosty/apis/twitch_community_highlights_service.dart';
import 'package:frosty/models/community_highlight_event.dart';
import 'package:frosty/models/community_highlights.dart';
import 'package:frosty/screens/channel/community_highlights/highlight_reducers.dart';
import 'package:frosty/screens/channel/community_highlights/highlight_stack.dart';
import 'package:frosty/screens/channel/community_highlights/highlight_timings.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_clock.dart';
import 'package:frosty/services/realtime/twitch_realtime_client.dart';
import 'package:mobx/mobx.dart';

part 'community_highlights_store.g.dart';

class CommunityHighlightsStore = CommunityHighlightsStoreBase
    with _$CommunityHighlightsStore;

/// A channel's poll, prediction, pinned message and outgoing raid, and the
/// stack deciding which one shows above chat.
///
/// Snapshots come from anonymous GQL; changes from the four public Hermes
/// topics. Frequent updates (votes, points, raid viewers) are coalesced so
/// the screen changes at most twice a second; a new highlight or a status
/// change shows at once. Everything is read-only and anonymous: a failure
/// only hides the highlights.
abstract class CommunityHighlightsStoreBase with Store {
  CommunityHighlightsStoreBase({
    required this.channelId,
    required TwitchCommunityHighlightsService service,
    required TwitchRealtimeClient realtime,
    ServerClock? serverClock,
    this.expandNew = false,
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
  final TwitchCommunityHighlightsService _service;

  /// Twitch's time, learnt from notification timestamps.
  final ServerClock serverClock;

  /// New polls, predictions and raids arrive expanded (large screens); a
  /// pinned message never does, so it never holds a new one back.
  final bool expandNew;

  final _subscriptions = <RealtimeTopicSubscription>[];
  final _topicEvents = <StreamSubscription<RealtimeTopicEvent>>[];
  final _degraded = <HighlightTopic>{};
  final _deadlines = <HighlightKind, Timer>{};

  /// When the outgoing raid left (Twitch time).
  DateTime? _raidGoneAt;
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

  @readonly
  Poll? _poll;

  @readonly
  Prediction? _prediction;

  @readonly
  PinnedChatMessage? _pinned;

  @readonly
  RaidState? _raid;

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

  /// Hides the visible highlight for this session.
  @action
  void dismissCurrent() {
    final current = _stack.current;
    if (current != null) _stack = _stack.dismiss(current.kind, current.id);
  }

  // --- Realtime ------------------------------------------------------------------

  void _onTopicEvent(HighlightTopic topic, RealtimeTopicEvent event) {
    if (_disposed) return;
    switch (event) {
      case RealtimeMessage(:final payload, :final serverTime):
        if (serverTime != null) serverClock.observe(serverTime);
        _apply(ChEvent.parse(topic, payload));
      case RealtimeSubscribed(:final isResubscribe):
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
        if (!identical(next.pin, _nextPinned)) {
          _nextPinned = next.pin;
          _pinnedSticky = false;
          _changed(urgent: true);
        }
      case RaidEvent():
        final before = _nextRaid;
        _nextRaid = reduceRaid(before, event, channelId: channelId);
        if (identical(before, _nextRaid)) return;
        _changed(
          urgent:
              before == null ||
              _nextRaid == null ||
              before.gone != _nextRaid!.gone,
        );
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

    var stack = _stack;
    stack = _sync(stack, HighlightKind.poll, _poll?.id);
    stack = _sync(stack, HighlightKind.prediction, _prediction?.id);
    stack = _sync(
      stack,
      HighlightKind.pinned,
      _pinned?.id,
      sticky: _pinnedSticky,
    );
    stack = _sync(stack, HighlightKind.raid, _raid?.raid.id);
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
        expanded: expandNew && kind != HighlightKind.pinned,
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
          : (poll.endedAt ?? now).add(kPollResultLinger),
      () => _nextPoll = null,
    );
    final prediction = _nextPrediction;
    _deadline(HighlightKind.prediction, switch (prediction?.status) {
      PredictionStatus.resolved => (prediction!.endedAt ?? now).add(
        kPredictionResolvedLinger,
      ),
      PredictionStatus.canceled => (prediction!.endedAt ?? now).add(
        kPredictionCanceledLinger,
      ),
      _ => null,
    }, () => _nextPrediction = null);
    _deadline(
      HighlightKind.pinned,
      _nextPinned?.endsAt,
      () => _nextPinned = null,
    );
    final raid = _nextRaid;
    if (raid == null || !raid.gone) _raidGoneAt = null;
    _deadline(HighlightKind.raid, switch (raid) {
      null => null,
      // From the first "go" (it is sent several times).
      RaidState(gone: true) => (_raidGoneAt ??= now).add(kRaidAfterGoLinger),
      // A lost "go" or "cancel" must not leave it up forever.
      RaidState(:final raid) => raid.goAt?.add(
        kRaidAfterGoLinger + kRaidMissedGoMargin,
      ),
    }, () => _nextRaid = null);
  }

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
      } on Object catch (e) {
        final failures = (_failures[topic] ?? 0) + 1;
        _failures[topic] = failures;
        _log('${topic.prefix} fetch failed ($failures): $e');
        if (failures >= 3) {
          _gqlOff.add(topic);
          _updatePolling();
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
        _nextPrediction =
            predictions.active ??
            predictions.locked ??
            (recent ? resolved : null);
        _predictionTimestamp = null;
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
