import 'package:clock/clock.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/video/latency_stats.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

/// What the auto latency controller is doing, as shown in the stats panel.
enum AutoLatencyPhase {
  /// The setting is off for this stream: the player is left as it was.
  off,

  /// Gave up for this stream (the player refused or did not keep the rate,
  /// or catching up kept causing stalls) until a manual refresh.
  stopped,

  /// Not allowed to catch up now: paused, ad, reconnecting, no buffer or
  /// latency reading, not a low-latency stream...
  held,

  /// Stopped (after stalls) or on a stream without low latency: drains a
  /// clearly excessive buffer at [LatencyController.drainRate], like the SDK
  /// speed-up this replaces.
  draining,

  /// Waiting for the connection to have been calm long enough.
  settling,

  /// Close enough to live: plays at 1.0x.
  steady,

  /// Plays at [LatencyController.catchUpRate] to get back to the target.
  catchingUp,
}

/// Why auto latency is held or stopped, worded by [autoLatencyReasonText].
enum AutoLatencyReason {
  /// An ad plays.
  ad,

  /// The player gave no buffer length.
  noBufferReading,

  /// A tick came without a latency.
  noLatencyReading,

  /// The latency ticks stopped coming during a catch-up.
  noLatencyTicks,

  /// The stream has no low latency.
  notLowLatency,

  /// The viewer paused (or a page covers the player).
  paused,

  /// The player reconnects (or jumps to live, or is not playing yet).
  reconnecting,

  /// The player waits for data.
  buffering,

  /// The player refused a faster rate.
  rateRefused,

  /// The player did not keep the rate asked for.
  rateNotKept,

  /// Catching up kept causing stalls.
  stallsAfterCatchUp,

  /// The player stayed fast after 1.0x was asked for
  /// ([AutoLatencyStatus.reasonRate] says how fast).
  stuckFast,

  /// The player refused to go back to 1.0x.
  notBackToNormal,
}

/// A snapshot of the controller for the stats panel. Compares by value so a
/// store only notifies observers when something they show changed.
class AutoLatencyStatus {
  const AutoLatencyStatus({
    required this.phase,
    required this.rate,
    this.targetMs,
    this.reason,
    this.reasonRate,
    this.calmLeftSeconds,
  });

  final AutoLatencyPhase phase;

  /// The playback rate the controller wants.
  final double rate;

  /// The latency aimed at (with any back-off); null when off.
  final int? targetMs;

  /// Why it is held or stopped.
  final AutoLatencyReason? reason;

  /// The rate the player stayed at, for [AutoLatencyReason.stuckFast].
  final double? reasonRate;

  /// Seconds of calm still needed before it may act (while settling).
  final int? calmLeftSeconds;

  @override
  bool operator ==(Object other) =>
      other is AutoLatencyStatus &&
      other.phase == phase &&
      other.rate == rate &&
      other.targetMs == targetMs &&
      other.reason == reason &&
      other.reasonRate == reasonRate &&
      other.calmLeftSeconds == calmLeftSeconds;

  @override
  int get hashCode =>
      Object.hash(phase, rate, targetMs, reason, reasonRate, calmLeftSeconds);
}

/// Keeps a live stream close to live without ever reloading it, by playing
/// it very slightly faster while it sits behind its target.
///
/// Why a playback rate and not the SDK: the IVS speed-up catch-up only
/// drains buffer above the low-latency buffer target, at 1.03x, and that
/// target grows after stalls (a 1 s rebuffer penalty, up to the ceiling) and
/// never shrinks back. A stream that settled 2.2 s behind after a network
/// burst therefore stays there. Playing at [catchUpRate] drains that buffer
/// over a few seconds instead, invisibly: the picture never stops and the
/// audio keeps its pitch (the SDK sets the rate through `PlaybackParams`
/// speed, like its own catch-up).
///
/// The controller is deliberately timid:
/// - it only acts once the connection has been calm for a while (no stall,
///   no gap in the latency ticks, a buffer reading) — a few seconds after a
///   load, longer after a stall;
/// - it starts [startAboveMs] above the target and stops [stopAboveMs] above
///   it, on the median of the last [smoothing] samples, so it cannot
///   oscillate on noise;
/// - it never eats the buffer below [bufferFloorMs]: past that, what is left
///   of the delay is the network's and playing faster would only stall;
/// - any stall stops it at once; a stall (or an ABR switch) during or right
///   after a catch-up is a strike that raises the target, and after
///   [maxStrikes] it stops for the stream;
/// - it never acts while held (paused, ad, reconnecting, a missing reading)
///   and never above [maxLiveRate]; picture-in-picture and the mini player
///   are not holds: the rate is invisible there too, and every check keeps
///   running;
/// - a tick gap, or no tick at all ([checkTicks]), ends a catch-up at once.
///
/// With auto latency on, the player is created without the SDK speed-up
/// (it would reset any other rate). Where the catch-up does not run for long
/// (stopped after stalls, a stream without low latency) a timid drain takes
/// the SDK's place: [drainRate] only when the latency is [drainAboveMs] past
/// the target with buffer above the floor, never after a stall in the last
/// [calmAfterStall], never after the player refused or did not keep a rate,
/// and never during an ad (the SDK leaves its own speed-up alone during ads
/// too: `MediaPlayer::checkBufferSpeedUp` skips while its ad flag is set).
///
/// Pure Dart with an injectable clock: the store feeds it the native ticks
/// and applies [rate].
class LatencyController {
  LatencyController({
    required this.enabled,
    required this.targetMs,
    required this.bufferFloorMs,
    DateTime Function()? now,
  }) : _now = now ?? clock.now {
    _phase = enabled ? AutoLatencyPhase.settling : AutoLatencyPhase.off;
  }

  /// The targets for a buffer profile.
  ///
  /// Ultra was measured holding 1.1–1.2 s on a calm connection, so it aims
  /// at 1.3 s; its SDK minimum buffer is 0.5 s, so the floor keeps 0.2 s
  /// above it. Standard lands at 1.8–2.0 s after a refresh (a fresh load
  /// starts at the edge), so it aims at 2.0 s; its SDK minimum buffer is
  /// 1.0 s and so is the floor.
  factory LatencyController.forProfile(
    BufferProfile profile, {
    required bool enabled,
    DateTime Function()? now,
  }) => switch (profile) {
    BufferProfile.ultra => LatencyController(
      enabled: enabled,
      targetMs: 1300,
      bufferFloorMs: 700,
      now: now,
    ),
    BufferProfile.standard => LatencyController(
      enabled: enabled,
      targetMs: 2000,
      bufferFloorMs: 1000,
      now: now,
    ),
  };

  /// The rate of a catch-up: 5 % is invisible on video and, with the pitch
  /// kept by the platform, inaudible; it is still 1.7 times the SDK's own
  /// 1.03x, so 0.8 s of drift goes in 16 s.
  static const catchUpRate = 1.05;

  /// The highest rate the native live player accepts (it clamps to it too).
  static const maxLiveRate = 1.1;

  /// Starts once the latency is this far above the target...
  static const startAboveMs = 400;

  /// ...and stops once it is back within this of it.
  static const stopAboveMs = 100;

  /// Buffer that must be there, above the floor, to start a catch-up: what
  /// it is going to spend.
  static const bufferHeadroomMs = 300;

  /// Calm needed after a load before acting: the first seconds measure
  /// where the stream starts.
  static const startSettle = Duration(seconds: 6);

  /// Calm needed after a stall: the connection has to prove itself.
  static const calmAfterStall = Duration(seconds: 25);

  /// A tick gap longer than this (app in the background, player recreated)
  /// means the calm has to be seen again.
  static const maxSampleGap = Duration(seconds: 3);

  /// Minimum time at 1.0x between two catch-ups...
  static const restCooldown = Duration(seconds: 5);

  /// ...and minimum length of one (unless the buffer floor, a stall or a
  /// hold ends it), so the rate never flaps: at most one change every five
  /// seconds. Overshooting the stop threshold by the end of it costs at most
  /// 0.25 s of buffer, which the floor still guards.
  static const minCatchUp = Duration(seconds: 5);

  /// A stall or quality switch this soon after a catch-up counts against it.
  static const strikeWindow = Duration(seconds: 15);

  /// How much each strike raises the target.
  static const strikeBackoffMs = 500;

  /// Strikes after which the controller stops for the stream.
  static const maxStrikes = 3;

  /// Samples whose median the decisions use.
  static const smoothing = 5;

  /// Ticks in a row reporting another rate during a catch-up after which
  /// the rate is taken as not kept by the player (something else owns it).
  static const rateNotHeldTicks = 3;

  /// The rate of the SDK-like drain: the SDK speed-up's own 1.03x.
  static const drainRate = 1.03;

  /// The drain starts once the latency is this far above the target, with
  /// buffer above the floor...
  static const drainAboveMs = 1500;

  /// ...and stops once it is within this of it, or at the floor.
  static const drainStopAboveMs = 1000;

  /// The floor of a stream without low latency: the IVS normal-latency
  /// minimum buffer (2.0 s in the SDK schema).
  static const normalLatencyFloorMs = 2000;

  /// How long an ad holds the controller at least (and at most): the cue's
  /// duration is not trusted beyond that.
  static const minAdHold = Duration(seconds: 60);
  static const maxAdHold = Duration(seconds: 180);

  /// Whether auto latency applies to this stream (the setting, captured
  /// when it was opened).
  final bool enabled;

  /// The latency aimed at before any back-off.
  final int targetMs;

  /// The buffer a catch-up never goes below.
  final int bufferFloorMs;

  final DateTime Function() _now;

  final _latencies = <int>[];
  final _buffers = <int>[];
  DateTime? _lastSampleAt;
  DateTime? _calmSince;
  var _requiredCalm = startSettle;
  DateTime? _lastCatchUpEnd;
  DateTime? _catchUpStart;
  DateTime? _adUntil;
  var _strikes = 0;
  var _notHeld = 0;
  var _stopped = false;
  AutoLatencyReason? _stopReason;
  double? _stopRate;

  /// Whether the SDK-like drain may run once stopped: not when a rate was
  /// refused or not kept.
  var _drainable = false;
  DateTime? _lastStallAt;
  var _rate = 1.0;
  late AutoLatencyPhase _phase;
  AutoLatencyReason? _reason;
  double? _reasonRate;
  int? _calmLeftSeconds;

  /// The playback rate to apply now.
  double get rate => _rate;

  /// The target with the back-off of any strikes.
  int get effectiveTargetMs => targetMs + _strikes * strikeBackoffMs;

  AutoLatencyStatus get status => AutoLatencyStatus(
    phase: _phase,
    rate: _rate,
    targetMs: enabled ? effectiveTargetMs : null,
    reason: _reason,
    reasonRate: _reasonRate,
    calmLeftSeconds: _phase == AutoLatencyPhase.settling
        ? _calmLeftSeconds
        : null,
  );

  /// A new source was loaded (it starts near the edge): settle again. The
  /// strikes stay: an automatic reload does not fix the connection.
  void onLoad() {
    _toNormalRate();
    _lastCatchUpEnd = null;
    _adUntil = null;
    _restartCalm(startSettle);
    if (_active) _setPhase(AutoLatencyPhase.settling);
    if (_stopped) _setStopped();
  }

  /// The viewer refreshed the stream: forget the strikes and try again.
  void reset() {
    _strikes = 0;
    _stopped = false;
    _stopReason = null;
    _drainable = false;
    _notHeld = 0;
    if (enabled) _setPhase(AutoLatencyPhase.settling);
  }

  /// The player rebuffered: back to 1.0x at once, and wait for a longer calm.
  void onStall() {
    if (!enabled) return;
    _lastStallAt = _now();
    if (_stopped) {
      _toNormalRate();
      _clearCalm();
      _setStopped();
      return;
    }
    _strikeIfRecent();
    _toNormalRate();
    _restartCalm(calmAfterStall);
    if (_active) _setPhase(AutoLatencyPhase.settling);
  }

  /// The quality went down without being asked: only a catch-up that may
  /// have caused it (an ABR down-switch on a drained buffer) cares.
  void onQualityChanged() {
    if (!_active || !_recentCatchUp) return;
    onStall();
  }

  /// An ad starts: no correction for its length, within [minAdHold] and
  /// [maxAdHold].
  void onAd(Duration duration) {
    if (!enabled) return;
    final hold = duration < minAdHold
        ? minAdHold
        : (duration > maxAdHold ? maxAdHold : duration);
    _adUntil = _now().add(hold);
    _holdFor(AutoLatencyReason.ad);
  }

  /// The viewer is about to make correcting wrong (pause, the content
  /// warning, a refresh): back to 1.0x now, without waiting for the next
  /// tick. The catch-up it ends was ended by the viewer: a stall after it (a
  /// resume often rebuffers) is not a strike.
  void hold(AutoLatencyReason reason) {
    if (!enabled) return;
    _holdFor(reason);
    _lastCatchUpEnd = null;
  }

  /// The native player refused the rate: stop for the stream.
  void onRateRejected() => stop(AutoLatencyReason.rateRefused);

  /// Stops for the stream with [reason], without the drain: the rate itself
  /// is in doubt (the store saw the player refuse or keep a rate). [rate] is
  /// the rate it stayed at, for [AutoLatencyReason.stuckFast].
  void stop(AutoLatencyReason reason, {double? rate}) =>
      _stop(reason, drainable: false, rate: rate);

  /// A tick came without a usable latency: back to 1.0x and hold.
  void onMissingLatency() {
    _lastSampleAt = _now();
    _holdFor(AutoLatencyReason.noLatencyReading);
  }

  /// The watchdog, called between ticks: a rate above 1.0x whose ticks
  /// stopped coming for longer than [maxSampleGap] goes back to 1.0x. True
  /// when it did.
  bool checkTicks() {
    if (_rate <= 1) return false;
    final last = _lastSampleAt;
    if (last == null || _now().difference(last) <= maxSampleGap) return false;
    _holdFor(AutoLatencyReason.noLatencyTicks);
    return true;
  }

  /// One latency tick; returns the rate to apply.
  double onSample({
    required int latencyMs,
    int? bufferMs,
    bool? lowLatency,
    double? nativeRate,
    AutoLatencyReason? hold,
  }) {
    final now = _now();
    final last = _lastSampleAt;
    _lastSampleAt = now;
    if (!enabled) return _rate;
    // Unchecked for that long: back to 1.0x before anything else.
    if (last != null && now.difference(last) > maxSampleGap) _clearCalm();

    final adUntil = _adUntil;
    final heldBecause =
        hold ??
        (adUntil != null && now.isBefore(adUntil)
            ? AutoLatencyReason.ad
            : null) ??
        (bufferMs == null ? AutoLatencyReason.noBufferReading : null);
    if (heldBecause != null) {
      _holdFor(heldBecause);
      return _rate;
    }

    if (_stopped) {
      if (!_drainable) return _rate;
      return _drain(
        latencyMs,
        bufferMs!,
        nativeRate,
        lowLatency: lowLatency != false,
      );
    }
    if (lowLatency == false) {
      return _drain(latencyMs, bufferMs!, nativeRate, lowLatency: false);
    }

    _push(_latencies, latencyMs);
    _push(_buffers, bufferMs!);
    final calmSince = _calmSince ??= now;
    final calm = now.difference(calmSince);
    if (calm < _requiredCalm) {
      _toNormalRate();
      _calmLeftSeconds = (_requiredCalm - calm).inSeconds;
      _setPhase(AutoLatencyPhase.settling);
      return _rate;
    }

    final latency = _median(_latencies);
    final buffer = _median(_buffers);
    final target = effectiveTargetMs;
    if (_rate > 1) {
      if (_rateNotKept(nativeRate)) return _rate;
      final ran = now.difference(_catchUpStart ?? now) >= minCatchUp;
      if ((ran && latency <= target + stopAboveMs) || buffer <= bufferFloorMs) {
        _toNormalRate();
        _setPhase(AutoLatencyPhase.steady);
      }
      return _rate;
    }

    final lastEnd = _lastCatchUpEnd;
    final rested = lastEnd == null || now.difference(lastEnd) >= restCooldown;
    if (rested &&
        latency > target + startAboveMs &&
        buffer >= bufferFloorMs + bufferHeadroomMs) {
      _rate = catchUpRate;
      _catchUpStart = now;
      _notHeld = 0;
      _setPhase(AutoLatencyPhase.catchingUp);
    } else {
      _setPhase(AutoLatencyPhase.steady);
    }
    return _rate;
  }

  /// The SDK-like drain, for a stopped controller or a stream without low
  /// latency (which has no low-latency target: only its buffer is judged).
  double _drain(
    int latencyMs,
    int bufferMs,
    double? nativeRate, {
    required bool lowLatency,
  }) {
    final now = _now();
    _push(_latencies, latencyMs);
    _push(_buffers, bufferMs);
    void rest() {
      _toNormalRate();
      if (_stopped) {
        _setStopped();
      } else {
        _setPhase(
          AutoLatencyPhase.held,
          reason: AutoLatencyReason.notLowLatency,
        );
      }
    }

    final lastStall = _lastStallAt;
    final calm =
        lastStall == null || now.difference(lastStall) >= calmAfterStall;
    if (!calm || _latencies.length < smoothing) {
      rest();
      return _rate;
    }
    final latency = _median(_latencies);
    final buffer = _median(_buffers);
    final floor = lowLatency ? bufferFloorMs : normalLatencyFloorMs;
    final target = effectiveTargetMs;
    if (_rate > 1) {
      if (_rateNotKept(nativeRate)) return _rate;
      if (buffer <= floor ||
          (lowLatency && latency <= target + drainStopAboveMs)) {
        rest();
      }
      return _rate;
    }
    if (buffer > floor + bufferHeadroomMs &&
        (!lowLatency || latency > target + drainAboveMs)) {
      _rate = drainRate;
      _notHeld = 0;
      _setPhase(
        AutoLatencyPhase.draining,
        reason: _stopped ? _stopReason : AutoLatencyReason.notLowLatency,
        reasonRate: _stopped ? _stopRate : null,
      );
    } else {
      rest();
    }
    return _rate;
  }

  /// Counts ticks where the player reports another rate than the one asked
  /// for; true (and stopped, without the drain) once it is clearly not kept.
  bool _rateNotKept(double? nativeRate) {
    if (nativeRate == null || (nativeRate - _rate).abs() <= 0.005) {
      _notHeld = 0;
      return false;
    }
    if (++_notHeld < rateNotHeldTicks) return false;
    stop(AutoLatencyReason.rateNotKept);
    return true;
  }

  bool get _active => enabled && !_stopped;

  /// A catch-up at [catchUpRate] runs, or ended within [strikeWindow]. The
  /// drain is not one: it has its own stall guard, and its stalls are never
  /// strikes.
  bool get _recentCatchUp {
    if (_catchingUp) return true;
    final end = _lastCatchUpEnd;
    return end != null && _now().difference(end) <= strikeWindow;
  }

  void _strikeIfRecent() {
    if (!_recentCatchUp) return;
    _strikes++;
    if (_strikes >= maxStrikes) {
      _stop(AutoLatencyReason.stallsAfterCatchUp, drainable: true);
    }
  }

  void _holdFor(AutoLatencyReason reason) {
    _toNormalRate();
    _clearCalm();
    if (_stopped) {
      _setStopped();
    } else {
      _setPhase(AutoLatencyPhase.held, reason: reason);
    }
  }

  void _stop(
    AutoLatencyReason reason, {
    required bool drainable,
    double? rate,
  }) {
    if (!enabled) return;
    _toNormalRate();
    // A doubt about the rate, once seen, keeps the drain off for the stream.
    _drainable = drainable && (!_stopped || _drainable);
    _stopped = true;
    _stopReason = reason;
    _stopRate = rate;
    _clearCalm();
    _setStopped();
  }

  void _setStopped() => _setPhase(
    AutoLatencyPhase.stopped,
    reason: _stopReason,
    reasonRate: _stopRate,
  );

  bool get _catchingUp => _rate == catchUpRate;

  void _toNormalRate() {
    if (_catchingUp) _lastCatchUpEnd = _now();
    _rate = 1.0;
    _notHeld = 0;
  }

  void _restartCalm(Duration required) {
    _requiredCalm = required;
    _clearCalm();
  }

  /// Forgets the calm and the windows, and goes back to 1.0x: nothing that
  /// was judged on them may run on.
  void _clearCalm() {
    _toNormalRate();
    _calmSince = null;
    _latencies.clear();
    _buffers.clear();
  }

  void _setPhase(
    AutoLatencyPhase phase, {
    AutoLatencyReason? reason,
    double? reasonRate,
  }) {
    _phase = phase;
    _reason = reason;
    _reasonRate = reasonRate;
  }

  static void _push(List<int> window, int value) {
    window.add(value);
    if (window.length > smoothing) window.removeAt(0);
  }

  /// Upper median of the window.
  static int _median(List<int> window) {
    final sorted = [...window]..sort();
    return sorted[sorted.length ~/ 2];
  }
}

/// One line for the stats panel: what auto latency does and what it aims
/// at, in [l]'s language.
String describeAutoLatency(AutoLatencyStatus? status, AppLocalizations l) {
  if (status == null) return l.latencyAutoOff;
  String aimed(String text) => switch (status.targetMs) {
    final ms? => l.latencyAutoWithTarget(
      status: text,
      latency: displayLatency(formatLatency(ms), l),
    ),
    null => text,
  };
  String reason() =>
      autoLatencyReasonText(status.reason, l, rate: status.reasonRate);
  return switch (status.phase) {
    AutoLatencyPhase.off => l.latencyAutoOff,
    AutoLatencyPhase.stopped => l.latencyAutoStopped(
      reason: status.reason == null ? l.latencyReasonGaveUp : reason(),
    ),
    AutoLatencyPhase.held => aimed(
      l.latencyAutoHeld(
        reason: status.reason == null ? l.latencyReasonHeld : reason(),
      ),
    ),
    AutoLatencyPhase.settling => aimed(switch (status.calmLeftSeconds) {
      final seconds? => l.latencyAutoSettlingSeconds(seconds: seconds),
      null => l.latencyAutoSettling,
    }),
    AutoLatencyPhase.steady => aimed(l.latencyAutoSteady),
    AutoLatencyPhase.catchingUp => aimed(
      l.latencyAutoCatchingUp(rate: _rateText(status.rate)),
    ),
    AutoLatencyPhase.draining =>
      status.reason == null
          ? l.latencyAutoDraining(rate: _rateText(status.rate))
          : l.latencyAutoDrainingBecause(
              rate: _rateText(status.rate),
              reason: reason(),
            ),
  };
}

/// A playback rate as the stats panel writes it: two decimals, in the
/// language of `Intl` ("1.05", « 1,05 »).
String _rateText(double rate) => localDecimal(rate.toStringAsFixed(2));

/// Why auto latency is held or stopped, in [l]'s language; [rate] is the
/// rate of [AutoLatencyReason.stuckFast].
String autoLatencyReasonText(
  AutoLatencyReason? reason,
  AppLocalizations l, {
  double? rate,
}) => switch (reason) {
  null => '',
  AutoLatencyReason.ad => l.latencyReasonAd,
  AutoLatencyReason.noBufferReading => l.latencyReasonNoBufferReading,
  AutoLatencyReason.noLatencyReading => l.latencyReasonNoLatencyReading,
  AutoLatencyReason.noLatencyTicks => l.latencyReasonNoLatencyTicks,
  AutoLatencyReason.notLowLatency => l.latencyReasonNotLowLatency,
  AutoLatencyReason.paused => l.latencyReasonPaused,
  AutoLatencyReason.reconnecting => l.latencyReasonReconnecting,
  AutoLatencyReason.buffering => l.latencyReasonBuffering,
  AutoLatencyReason.rateRefused => l.latencyReasonRateRefused,
  AutoLatencyReason.rateNotKept => l.latencyReasonRateNotKept,
  AutoLatencyReason.stallsAfterCatchUp => l.latencyReasonStalls,
  AutoLatencyReason.stuckFast => l.latencyReasonStuckFast(
    rate: _rateText(rate ?? 1),
  ),
  AutoLatencyReason.notBackToNormal => l.latencyReasonNotBackToNormal(
    rate: localDecimal('1.0'),
  ),
};

/// The stats panel line of an active Ultra fallback, or null.
String? describeBufferFallback(DateTime? until, AppLocalizations l) {
  if (until == null) return null;
  String two(int v) => v.toString().padLeft(2, '0');
  return l.latencyBufferFallback(
    time: '${two(until.hour)}:${two(until.minute)}',
  );
}
