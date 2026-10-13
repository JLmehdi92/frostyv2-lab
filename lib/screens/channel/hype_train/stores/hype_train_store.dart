import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_clock.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_math.dart' as htm;
import 'package:frosty/screens/channel/hype_train/hype_train_queue.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_reducer.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_sequence.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_timings.dart';
import 'package:frosty/services/realtime/twitch_realtime_client.dart';
import 'package:mobx/mobx.dart';

part 'hype_train_store.g.dart';

enum HtPhase { hidden, approaching, ongoing, ending, rewards, expired }

/// The banner's look, by priority (record approaching first).
enum HtStyle {
  regular,
  community,
  treasure,
  shared,
  mythic,
  goldenKappa,
  athReached,
  athApproaching,
}

/// What the end strip summarises.
@immutable
class HtEndSummary {
  const HtEndSummary({
    required this.reason,
    required this.level,
    required this.bits,
    required this.subs,
    this.rewards = const [],
    this.ath = false,
  });

  final HtEndReason reason;
  final int level;
  final int bits;
  final int subs;
  final List<HtReward> rewards;

  /// The train beat the channel's record.
  final bool ath;
}

class HypeTrainStore = HypeTrainStoreBase with _$HypeTrainStore;

/// One channel's hype train: the GQL snapshot on join (and on resubscribe,
/// app resume or while realtime is down), realtime events presented one at
/// a time with the official timings, and the approaching, end and expiry
/// flows. Everything is anonymous; nothing here can affect chat or video.
abstract class HypeTrainStoreBase with Store {
  HypeTrainStoreBase({
    required this.channelId,
    required TwitchHypeTrainService service,
    required TwitchRealtimeClient realtime,
    String? Function()? viewerId,
    ServerClock? serverClock,
  }) : _service = service,
       _viewerId = viewerId ?? (() => null),
       serverClock = serverClock ?? ServerClock() {
    try {
      final subscription = realtime.subscribe(
        'hype-train-events-v2.$channelId',
      );
      _subscription = subscription;
      _topicEvents = subscription.events.listen(_onTopicEvent);
    } on Object catch (e) {
      // A malformed channel id: GQL alone (it validates too).
      _log('subscribe failed: $e');
      _realtimeDegraded = true;
    }
    unawaited(_refetch());
  }

  final String channelId;
  final TwitchHypeTrainService _service;
  final String? Function() _viewerId;
  final ServerClock serverClock;

  static const _minRefetchGap = Duration(seconds: 2);
  static const _pollInterval = Duration(seconds: 20);
  static const _levelUpWait = Duration(seconds: 3);
  static const _approachingGrace = Duration(seconds: 5);
  static const _countdownTick = Duration(seconds: 1);

  final _queue = HtEventQueue();
  final _seenIds = <String>{};
  RealtimeTopicSubscription? _subscription;
  StreamSubscription<RealtimeTopicEvent>? _topicEvents;

  var _presenters = 0;
  var _compact = false;
  var _reduceMotion = false;

  var _busy = false;
  var _steps = const <HtStep>[];
  var _cursor = 0;
  Timer? _stepTimer;

  /// A next-level progression waiting for its level-up.
  HtProgressionEvent? _deferred;
  Timer? _deferredTimer;

  Timer? _countdown;
  Timer? _expiryTimer;
  Timer? _approachingTicker;
  Timer? _stripTicker;
  Timer? _pollTimer;

  var _fetching = false;
  DateTime? _lastFetch;
  var _failures = 0;

  var _deadlines = <int, DateTime>{};
  DateTime? _approachingSince;
  DateTime? _stripStart;
  var _disposed = false;

  /// Events that changed the train (tests).
  @visibleForTesting
  var appliedEvents = 0;

  @visibleForTesting
  int get queuedCount => _queue.length;

  /// GQL failures in a row (diagnostics).
  int get failures => _failures;

  // --- State ------------------------------------------------------------------

  @readonly
  HtPhase _phase = HtPhase.hidden;

  @readonly
  HypeTrainExecution? _train;

  @readonly
  HypeTrainApproaching? _approaching;

  /// The step on screen; null at rest.
  @readonly
  HtStep? _step;

  @readonly
  int _stepIndex = 0;

  /// The level on the pill: the old one until "level complete" is shown.
  @readonly
  int _shownLevel = 0;

  /// The % and bar: follow the `fillTo` steps, not the data.
  @readonly
  int _shownPercent = 0;

  @readonly
  Duration _remaining = Duration.zero;

  /// 0 → 1 from the approaching banner's arrival to its last deadline.
  @readonly
  double _approachingFraction = 0;

  /// Filled check circles (deadline keys 1 and 2 still ahead).
  @readonly
  int _approachingChecks = 0;

  /// Qualifying events still needed: the smallest deadline key ahead.
  @readonly
  int _approachingEventsLeft = 0;

  /// A train event arrived: the approaching bar is drawn full.
  @readonly
  bool _approachingCompleted = false;

  /// The viewer already took part: "N more" instead of "N".
  @readonly
  bool _approachingNMore = false;

  /// 0 → 1 over the 20 s end strip.
  @readonly
  double _stripFraction = 0;

  @readonly
  HtEndSummary? _endSummary;

  /// Emotes earned this session (level-ups, then the end).
  @readonly
  List<HtReward> _unlockedRewards = const [];

  @readonly
  bool _realtimeDegraded = false;

  @observable
  bool expanded = false;

  @observable
  bool collapsed = false;

  @computed
  int get percent => _train == null ? 0 : htm.percent(_train!.progress);

  @computed
  int get level => _train?.level ?? 0;

  @computed
  bool get visible => _phase != HtPhase.hidden;

  @computed
  bool get isFinalLevel => _train != null && htm.isFinalLevel(_train!);

  @computed
  ({int subs, int bits}) get levelTarget =>
      _train == null ? (subs: 0, bits: 0) : htm.levelTarget(_train!);

  @computed
  HtStyle get style {
    final train = _train;
    if (train == null) return HtStyle.regular;
    final ath = train.progress.athState;
    if (ath == HtAthState.approaching) return HtStyle.athApproaching;
    if (ath == HtAthState.reached || ath == HtAthState.justReached) {
      return HtStyle.athReached;
    }
    if (train.variant == HtVariant.goldenKappa) return HtStyle.goldenKappa;
    if (train.variant == HtVariant.mythic) return HtStyle.mythic;
    if (train.shared != null) return HtStyle.shared;
    if (train.variant == HtVariant.treasure) return HtStyle.treasure;
    if (train.variant == HtVariant.community) return HtStyle.community;
    return HtStyle.regular;
  }

  /// One line for screen readers.
  @computed
  String get semanticsSummary {
    switch (_phase) {
      case HtPhase.hidden:
        return '';
      case HtPhase.approaching:
        return 'Hype Train approaching';
      case HtPhase.ongoing:
        final seconds = _remaining.inSeconds;
        final time =
            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
        return 'Hype Train level $level, $percent percent, $time left';
      case HtPhase.ending || HtPhase.rewards:
        return 'Hype Train ended at level ${_endSummary?.level ?? level}';
      case HtPhase.expired:
        return 'Hype Train expired';
    }
  }

  // --- Presenter and lifecycle --------------------------------------------------

  /// A banner is on screen. Counted: each attach needs a detach.
  @action
  void attachPresenter() => _presenters++;

  /// [compact]: the collapsed pill or landscape; [reduceMotion]: the
  /// platform asks for fewer animations. Applies to the next sequence.
  void updatePresentation({bool compact = false, bool reduceMotion = false}) {
    _compact = compact;
    _reduceMotion = reduceMotion;
  }

  bool get reduceMotion => _reduceMotion;

  /// With no banner left, the running sequence finishes at once and later
  /// ones take no time, so the store never stalls in the background.
  @action
  void detachPresenter() {
    _presenters = max(0, _presenters - 1);
    if (_presenters == 0 && _busy) _finishSequenceNow();
  }

  @action
  void toggleExpanded() => expanded = !expanded;

  @action
  void setCollapsed(bool value) => collapsed = value;

  void handleAppResume() => unawaited(_refetch());

  @visibleForTesting
  void injectEvent(HypeTrainEvent event) => _onEvent(event);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelAll();
    unawaited(_topicEvents?.cancel());
    _subscription?.cancel();
  }

  void _cancelAll() {
    for (final timer in [
      _stepTimer,
      _deferredTimer,
      _countdown,
      _expiryTimer,
      _approachingTicker,
      _stripTicker,
      _pollTimer,
    ]) {
      timer?.cancel();
    }
  }

  // --- Realtime -------------------------------------------------------------------

  void _onTopicEvent(RealtimeTopicEvent event) {
    if (_disposed) return;
    switch (event) {
      case RealtimeMessage(:final payload, :final serverTime):
        if (serverTime != null) serverClock.observe(serverTime);
        _onEvent(HypeTrainEvent.parse(payload));
      case RealtimeSubscribed(:final isResubscribe):
        runInAction(() => _realtimeDegraded = false);
        _updatePolling();
        if (isResubscribe) unawaited(_refetch());
      case RealtimeUnavailable():
        runInAction(() => _realtimeDegraded = true);
        _updatePolling();
    }
  }

  @action
  void _onEvent(HypeTrainEvent event) {
    if (_disposed) return;
    switch (_phase) {
      case HtPhase.ending:
        // Only a new train interrupts the end sequence.
        if (event is! HtStartEvent) return;
        _toHidden();
      case HtPhase.rewards || HtPhase.expired:
        if (event is! HtStartEvent && event is! HtApproachingEvent) return;
        _toHidden();
      case HtPhase.hidden || HtPhase.approaching || HtPhase.ongoing:
        break;
    }

    if (event is HtEndEvent) {
      if (_train != null && _phase == HtPhase.ongoing) _beginEnd(event);
      return;
    }

    if (_phase == HtPhase.ongoing) {
      if (event is HtApproachingEvent) return;
      _queue.enqueue(event);
      _pump();
      return;
    }

    // Hidden or approaching: no train yet.
    final isTrainEvent = switch (event) {
      HtStartEvent() ||
      HtProgressionEvent() ||
      HtLevelUpEvent() ||
      HtConductorEvent() ||
      HtMergeEvent() => true,
      _ => false,
    };
    if (_phase == HtPhase.approaching && isTrainEvent) {
      _approachingCompleted = true;
      _approachingFraction = 1;
    }
    switch (event) {
      case HtApproachingEvent(:final approaching):
        _showApproaching(approaching);
      case HtStartEvent() || HtMergeEvent():
        // The full approaching bar stays readable while the banner fades
        // into the start sequence; it is cleared when the train ends.
        _approachingTicker?.cancel();
        _phase = HtPhase.ongoing;
        _queue.enqueue(event);
        _pump();
      case HtLevelUpEvent(train: final fresh?):
        // The level-up carries the whole train: show it as it is now.
        final result = applyEvent(
          fresh,
          event,
          seenIds: _seenIds,
          channelId: channelId,
        );
        _clearApproaching();
        _phase = HtPhase.ongoing;
        _setTrain(result.train);
      case HtProgressionEvent() ||
          HtLevelUpEvent() ||
          HtConductorEvent() ||
          HtChannelLeftEvent():
        // We missed the start.
        unawaited(_refetch());
      case HtEndEvent() || HtIgnoredEvent() || HtUnknownEvent():
        break;
    }
  }

  // --- Presentation -------------------------------------------------------------

  void _pump() {
    while (!_busy && !_disposed) {
      final event = _takeDeferredIfReady() ?? _queue.pop();
      if (event == null) return;
      _present(event);
    }
  }

  /// The deferred progression, once its level-up has been applied.
  HtProgressionEvent? _takeDeferredIfReady() {
    final deferred = _deferred;
    final train = _train;
    if (deferred == null || train == null) return null;
    if (deferred.progress.level.value != train.level) return null;
    _deferred = null;
    _deferredTimer?.cancel();
    return deferred;
  }

  @action
  void _present(HypeTrainEvent event) {
    final before = _train;
    final HtApplyResult result;
    if (before == null) {
      switch (event) {
        case HtStartEvent(:final train) || HtMergeEvent(:final train):
          result = HtApplyResult(train);
        case _:
          return;
      }
    } else {
      result = applyEvent(
        before,
        event,
        seenIds: _seenIds,
        channelId: channelId,
      );
    }
    if (result.deferredNextLevel && event is HtProgressionEvent) {
      _deferred = event;
      _deferredTimer?.cancel();
      _deferredTimer = Timer(_levelUpWait, () {
        _deferred = null;
        unawaited(_refetch());
      });
      return;
    }
    if (!result.applied) return;
    appliedEvents++;

    if (result.levelChangedFrom != null && before != null) {
      _unlockedRewards = [
        ..._unlockedRewards,
        ...before.progress.level.rewards.where(
          (r) => r.type == HtRewardType.emote,
        ),
      ];
    }
    _setTrain(result.train, animated: true);
    // Its level-up is in: the deferred progression follows this sequence.
    if (_deferred?.progress.level.value == result.train.level) {
      _deferredTimer?.cancel();
    }
    if (result.train.endReason == HtEndReason.completed &&
        event is HtChannelLeftEvent) {
      _beginEnd(const HtEndEvent(reason: HtEndReason.completed));
      return;
    }
    final steps = planSequence(
      HtPlanInput(
        event: event,
        before: before,
        after: result.train,
        result: result,
        channelId: channelId,
        compact: _compact,
        reduceMotion: _reduceMotion,
        presenterVisible: _presenters > 0,
      ),
    );
    final from = result.levelChangedFrom;
    _shownLevel =
        from != null && steps.any((s) => s.kind == HtStepKind.levelComplete)
        ? from
        : result.train.level;
    if (before == null) _shownPercent = htm.percent(result.train.progress);
    _runSteps(steps);
  }

  void _runSteps(List<HtStep> steps, {VoidCallback? onDone}) {
    _stepTimer?.cancel();
    _busy = true;
    _steps = steps;
    _cursor = 0;
    _onSequenceDone = onDone;
    _advance();
  }

  VoidCallback? _onSequenceDone;

  @action
  void _advance() {
    while (!_disposed) {
      if (_cursor >= _steps.length) {
        _step = null;
        _busy = false;
        if (_phase == HtPhase.ongoing) _showTrainAsIs();
        final done = _onSequenceDone;
        _onSequenceDone = null;
        done?.call();
        _pump();
        return;
      }
      final step = _steps[_cursor];
      _step = step;
      _stepIndex = _cursor;
      if (_cursor > 0 && _steps[_cursor - 1].kind == HtStepKind.levelComplete) {
        _shownLevel = _train?.level ?? _shownLevel;
      }
      switch (step.kind) {
        case HtStepKind.fillTo:
          if (step.data['percent'] case final int value) _shownPercent = value;
        case HtStepKind.flash100:
          _shownPercent = 100;
        case _:
          break;
      }
      if (step.isStrip) _startStrip(step);
      if (step.duration == Duration.zero) {
        _cursor++;
        continue;
      }
      _stepTimer = Timer(step.duration, () {
        _cursor++;
        _advance();
      });
      return;
    }
  }

  void _finishSequenceNow() {
    _stepTimer?.cancel();
    // Strips need a presenter; the rest is state the train already has.
    _steps = [
      for (final step in _steps.skip(_cursor))
        if (!step.isStrip) step.copyWith(duration: Duration.zero),
    ];
    _cursor = 0;
    _stripTicker?.cancel();
    _advance();
  }

  // --- Train, countdown and expiry --------------------------------------------

  void _setTrain(HypeTrainExecution train, {bool animated = false}) {
    _train = train;
    if (!animated) _showTrainAsIs();
    _updateCountdown();
    _scheduleExpiry();
    _updatePolling();
  }

  void _showTrainAsIs() {
    final train = _train;
    _shownLevel = train?.level ?? 0;
    _shownPercent = train == null ? 0 : htm.percent(train.progress);
  }

  void _updateCountdown() {
    final expiresAt = _train?.expiresAt;
    if (_phase != HtPhase.ongoing || expiresAt == null) {
      _countdown?.cancel();
      _countdown = null;
      _remaining = Duration.zero;
      return;
    }
    _tick();
    _countdown ??= Timer.periodic(_countdownTick, (_) => _tick());
  }

  @action
  void _tick() {
    final expiresAt = _train?.expiresAt;
    if (expiresAt == null) return;
    final left = expiresAt.difference(serverClock.now());
    // Whole seconds, rounded up, like the official countdown.
    final seconds = (left.inMilliseconds / 1000).ceil();
    _remaining = Duration(seconds: max(0, seconds));
  }

  /// Twitch sometimes never sends the end: close it ourselves (D5).
  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final expiresAt = _train?.expiresAt;
    if (_phase != HtPhase.ongoing || expiresAt == null) return;
    final due = expiresAt
        .add(HtTimings.expiryGrace)
        .difference(serverClock.now());
    _expiryTimer = Timer(due.isNegative ? Duration.zero : due, () {
      final train = _train;
      if (train == null || _phase != HtPhase.ongoing) return;
      _onEvent(
        HtEndEvent(
          reason: train.level >= 2
              ? HtEndReason.completed
              : HtEndReason.expired,
        ),
      );
    });
  }

  // --- End ------------------------------------------------------------------------

  @action
  void _beginEnd(HtEndEvent end) {
    _stepTimer?.cancel();
    _busy = false;
    _onSequenceDone = null;
    _deferred = null;
    _deferredTimer?.cancel();
    // Whatever is still queued already happened: apply it silently.
    var train = _train!;
    for (final event in _queue.drainForEnd()) {
      final result = applyEvent(
        train,
        event,
        seenIds: _seenIds,
        channelId: channelId,
        force: true,
      );
      if (result.applied) {
        appliedEvents++;
        train = result.train;
      }
    }
    final before = train;
    final result = applyEvent(train, end, seenIds: _seenIds);
    _train = result.train;
    _countdown?.cancel();
    _countdown = null;
    _expiryTimer?.cancel();
    final totals = htm.endTotals(result.endTotals);
    final ath =
        result.train.progress.athState == HtAthState.reached ||
        result.train.progress.athState == HtAthState.justReached;
    _endSummary = HtEndSummary(
      reason: end.reason,
      level: result.train.level,
      bits: totals.bits,
      subs: totals.subs,
      rewards: result.endRewards,
      ath: ath,
    );
    if (result.endRewards.isNotEmpty) _unlockedRewards = result.endRewards;
    final steps = planSequence(
      HtPlanInput(
        event: end,
        before: before,
        after: result.train,
        result: result,
        channelId: channelId,
        compact: _compact,
        reduceMotion: _reduceMotion,
        presenterVisible: _presenters > 0,
      ),
    );
    _phase = end.reason == HtEndReason.completed
        ? HtPhase.ending
        : HtPhase.expired;
    _remaining = Duration.zero;
    _runSteps(steps, onDone: _toHidden);
  }

  void _startStrip(HtStep step) {
    _phase = step.kind == HtStepKind.rewardsStrip
        ? HtPhase.rewards
        : HtPhase.expired;
    _stripStart = clock.now();
    _stripFraction = 0;
    _stripTicker?.cancel();
    _stripTicker = Timer.periodic(HtTimings.stripTick, (_) {
      runInAction(() {
        final start = _stripStart;
        if (start == null) return;
        final elapsed = clock.now().difference(start).inMilliseconds;
        _stripFraction = min(1, elapsed / step.duration.inMilliseconds);
      });
    });
  }

  @action
  void _toHidden() {
    _stepTimer?.cancel();
    _stripTicker?.cancel();
    _countdown?.cancel();
    _countdown = null;
    _expiryTimer?.cancel();
    _deferredTimer?.cancel();
    _deferred = null;
    _busy = false;
    _onSequenceDone = null;
    _steps = const [];
    _queue.clear();
    _phase = HtPhase.hidden;
    _train = null;
    _step = null;
    _stripStart = null;
    _stripFraction = 0;
    _remaining = Duration.zero;
    _unlockedRewards = const [];
    _clearApproaching();
    _updatePolling();
  }

  // --- Approaching ----------------------------------------------------------------

  @action
  void _showApproaching(HypeTrainApproaching approaching) {
    final now = serverClock.now();
    final deadlines = {
      for (final MapEntry(:key, :value) in approaching.deadlines.entries)
        key: now.add(Duration(seconds: value)),
    };
    if (deadlines.isEmpty) return;
    final first = deadlines[1] ?? deadlines.values.reduce(_later);
    // Too late to be worth showing (notes: the 20 s rule).
    if (first.difference(now) <= HtTimings.approachingMinWindow) return;
    final arriving = _phase != HtPhase.approaching;
    _approaching = approaching;
    _deadlines = deadlines;
    if (arriving) {
      _approachingSince = now;
      _approachingCompleted = false;
      _approachingFraction = 0;
    }
    final viewer = _viewerId();
    _approachingNMore =
        viewer != null && approaching.participants.contains(viewer);
    _phase = HtPhase.approaching;
    _approachingTick();
    _approachingTicker?.cancel();
    _approachingTicker = Timer.periodic(
      HtTimings.approachingTick,
      (_) => _approachingTick(),
    );
    _updatePolling();
  }

  static DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  @action
  void _approachingTick() {
    if (_phase != HtPhase.approaching) {
      _approachingTicker?.cancel();
      return;
    }
    final now = serverClock.now();
    _approachingChecks = [
      1,
      2,
    ].where((key) => _deadlines[key]?.isAfter(now) ?? false).length;
    final ahead = [
      for (final MapEntry(:key, :value) in _deadlines.entries)
        if (value.isAfter(now)) key,
    ];
    _approachingEventsLeft = ahead.isEmpty
        ? (_approaching?.goal ?? 0)
        : ahead.reduce(min);
    final last = _deadlines.values.reduce(_later);
    final since = _approachingSince ?? now;
    final span = last.difference(since).inMilliseconds;
    if (!_approachingCompleted && span > 0) {
      _approachingFraction = (now.difference(since).inMilliseconds / span)
          .clamp(0.0, 1.0);
    }
    if (now.isAfter(last.add(_approachingGrace))) {
      // No start came: confirm with GQL, which may bring it back.
      _toHidden();
      unawaited(_refetch());
    }
  }

  void _clearApproaching() {
    _approachingTicker?.cancel();
    _approaching = null;
    _deadlines = {};
    _approachingSince = null;
    _approachingChecks = 0;
    _approachingEventsLeft = 0;
    _approachingFraction = 0;
    _approachingCompleted = false;
    _approachingNMore = false;
  }

  // --- GQL --------------------------------------------------------------------------

  /// Single-flight, at most every 2 s.
  Future<void> _refetch() async {
    if (_disposed || _fetching) return;
    final last = _lastFetch;
    final now = clock.now();
    if (last != null && now.difference(last) < _minRefetchGap) return;
    _fetching = true;
    _lastFetch = now;
    try {
      final snapshot = await _service.getHypeTrain(channelId);
      if (_disposed) return;
      _failures = 0;
      _applySnapshot(snapshot);
    } on Object catch (e) {
      // Keep what we show; realtime or the next fetch will correct it.
      _failures++;
      _log('fetch failed: $e');
    } finally {
      _fetching = false;
    }
  }

  @action
  void _applySnapshot(HypeTrainSnapshot snapshot) {
    switch (snapshot) {
      case HtOngoingSnapshot(train: final fetched):
        if (_phase case HtPhase.ending || HtPhase.rewards || HtPhase.expired) {
          if (fetched.id == _train?.id) return;
          _toHidden();
        }
        final current = _train;
        if (current != null &&
            current.id == fetched.id &&
            fetched.progress.total < current.progress.total) {
          return;
        }
        final seconds = fetched.progress.remainingSeconds;
        final train = seconds != null && seconds >= 0
            ? fetched.copyWith(
                expiresAt: serverClock.now().add(Duration(seconds: seconds)),
              )
            : fetched;
        // Shown as it is now: no start animation (the notes' progress
        // marker), and queued events are older than the snapshot.
        _stepTimer?.cancel();
        _busy = false;
        _onSequenceDone = null;
        _step = null;
        _queue.clear();
        _clearApproaching();
        _phase = HtPhase.ongoing;
        _setTrain(train);
        _pump();
      case HtApproachingSnapshot(:final approaching):
        if (_phase == HtPhase.hidden || _phase == HtPhase.approaching) {
          _showApproaching(approaching);
        }
      case HtNoTrain():
        if (_phase != HtPhase.ongoing) return;
        final expiresAt = _train?.expiresAt;
        final fallbackPending =
            expiresAt != null &&
            expiresAt.add(HtTimings.expiryGrace).isAfter(serverClock.now());
        // The end is on its way (or our fallback will present it).
        if (!fallbackPending) _toHidden();
    }
  }

  /// While realtime is down and something is showing, poll GQL (D12).
  void _updatePolling() {
    final active = _phase == HtPhase.ongoing || _phase == HtPhase.approaching;
    if (_realtimeDegraded && active && !_disposed) {
      _pollTimer ??= Timer.periodic(
        _pollInterval,
        (_) => unawaited(_refetch()),
      );
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('HypeTrainStore($channelId) $message');
  }
}
