import 'package:clock/clock.dart';
import 'package:onset/screens/channel/video/latency_stats.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

/// What the auto latency controller is doing, as shown in the stats panel.
enum AutoLatencyPhase {
  /// The setting is off for this stream: the player is left as it was.
  off,

  /// Gave up for this stream (the player refused or did not keep the rate,
  /// or catching up kept causing stalls) until a manual refresh.
  stopped,

  /// Not allowed to act now: paused, picture-in-picture, mini player, ad,
  /// reconnecting, no buffer reading...
  held,

  /// Waiting for the connection to have been calm long enough.
  settling,

  /// Close enough to live: plays at 1.0x.
  steady,

  /// Plays at [LatencyController.catchUpRate] to get back to the target.
  catchingUp,
}

/// A snapshot of the controller for the stats panel. Compares by value so a
/// store only notifies observers when something they show changed.
class AutoLatencyStatus {
  const AutoLatencyStatus({
    required this.phase,
    required this.rate,
    this.targetMs,
    this.reason,
    this.calmLeftSeconds,
  });

  final AutoLatencyPhase phase;

  /// The playback rate the controller wants.
  final double rate;

  /// The latency aimed at (with any back-off); null when off.
  final int? targetMs;

  /// Why it is held or stopped.
  final String? reason;

  /// Seconds of calm still needed before it may act (while settling).
  final int? calmLeftSeconds;

  @override
  bool operator ==(Object other) =>
      other is AutoLatencyStatus &&
      other.phase == phase &&
      other.rate == rate &&
      other.targetMs == targetMs &&
      other.reason == reason &&
      other.calmLeftSeconds == calmLeftSeconds;

  @override
  int get hashCode =>
      Object.hash(phase, rate, targetMs, reason, calmLeftSeconds);
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
/// - it never acts while held (paused, picture-in-picture, mini player, ad,
///   reconnecting) and never above [maxLiveRate].
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
  var _rate = 1.0;
  late AutoLatencyPhase _phase;
  String? _reason;
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
  }

  /// The viewer refreshed the stream: forget the strikes and try again.
  void reset() {
    _strikes = 0;
    _stopped = false;
    _notHeld = 0;
    if (enabled) _setPhase(AutoLatencyPhase.settling);
  }

  /// The player rebuffered: back to 1.0x at once, and wait for a longer calm.
  void onStall() {
    if (!_active) return;
    _strikeIfRecent();
    _toNormalRate();
    _restartCalm(calmAfterStall);
    if (_active) _setPhase(AutoLatencyPhase.settling);
  }

  /// The quality changed: only a catch-up that may have caused it (an ABR
  /// down-switch on a drained buffer) cares.
  void onQualityChanged() {
    if (!_active || !_recentCatchUp) return;
    onStall();
  }

  /// An ad starts: no correction for its length, within [minAdHold] and
  /// [maxAdHold].
  void onAd(Duration duration) {
    if (!_active) return;
    final hold = duration < minAdHold
        ? minAdHold
        : (duration > maxAdHold ? maxAdHold : duration);
    _adUntil = _now().add(hold);
    _holdFor('ad');
  }

  /// The viewer is about to make correcting wrong (pause, picture-in-picture,
  /// mini player): back to 1.0x now, without waiting for the next tick. The
  /// catch-up it ends was ended by the viewer: a stall after it (a resume
  /// often rebuffers) is not a strike.
  void hold(String reason) {
    if (!_active) return;
    _holdFor(reason);
    _lastCatchUpEnd = null;
  }

  /// The native player refused the rate: stop for the stream.
  void onRateRejected() => _stop('the player refused the rate');

  /// One latency tick; returns the rate to apply.
  double onSample({
    required int latencyMs,
    int? bufferMs,
    bool? lowLatency,
    double? nativeRate,
    String? hold,
  }) {
    final now = _now();
    final last = _lastSampleAt;
    _lastSampleAt = now;
    if (!enabled) return _rate;
    if (_stopped) return _rate;
    if (last != null && now.difference(last) > maxSampleGap) _clearCalm();

    final adUntil = _adUntil;
    final heldBecause =
        hold ??
        (adUntil != null && now.isBefore(adUntil) ? 'ad' : null) ??
        (lowLatency == false ? 'not a low-latency stream' : null) ??
        (bufferMs == null ? 'no buffer reading' : null);
    if (heldBecause != null) {
      _holdFor(heldBecause);
      return _rate;
    }

    _push(_latencies, latencyMs);
    _push(_buffers, bufferMs!);
    final calmSince = _calmSince ??= now;
    final calm = now.difference(calmSince);
    if (calm < _requiredCalm) {
      _calmLeftSeconds = (_requiredCalm - calm).inSeconds;
      _setPhase(AutoLatencyPhase.settling);
      return _rate;
    }

    final latency = _median(_latencies);
    final buffer = _median(_buffers);
    final target = effectiveTargetMs;
    if (_rate > 1) {
      if (nativeRate != null && (nativeRate - _rate).abs() > 0.005) {
        if (++_notHeld >= rateNotHeldTicks) {
          _stop('the player did not keep the rate');
          return _rate;
        }
      } else {
        _notHeld = 0;
      }
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

  bool get _active => enabled && !_stopped;

  bool get _recentCatchUp {
    if (_rate > 1) return true;
    final end = _lastCatchUpEnd;
    return end != null && _now().difference(end) <= strikeWindow;
  }

  void _strikeIfRecent() {
    if (!_recentCatchUp) return;
    _strikes++;
    if (_strikes >= maxStrikes) _stop('stalls after catching up');
  }

  void _holdFor(String reason) {
    _toNormalRate();
    _clearCalm();
    _setPhase(AutoLatencyPhase.held, reason: reason);
  }

  void _stop(String reason) {
    if (!enabled) return;
    _toNormalRate();
    _stopped = true;
    _clearCalm();
    _setPhase(AutoLatencyPhase.stopped, reason: reason);
  }

  void _toNormalRate() {
    if (_rate > 1) _lastCatchUpEnd = _now();
    _rate = 1.0;
    _notHeld = 0;
  }

  void _restartCalm(Duration required) {
    _requiredCalm = required;
    _clearCalm();
  }

  void _clearCalm() {
    _calmSince = null;
    _latencies.clear();
    _buffers.clear();
  }

  void _setPhase(AutoLatencyPhase phase, {String? reason}) {
    _phase = phase;
    _reason = reason;
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

/// One line for the stats panel: what auto latency does and what it aims at.
String describeAutoLatency(AutoLatencyStatus? status) {
  if (status == null) return 'off';
  final target = switch (status.targetMs) {
    final ms? => ' · target ${formatLatency(ms)}',
    null => '',
  };
  return switch (status.phase) {
    AutoLatencyPhase.off => 'off',
    AutoLatencyPhase.stopped => 'stopped: ${status.reason ?? 'gave up'}',
    AutoLatencyPhase.held => 'held: ${status.reason ?? 'held'}$target',
    AutoLatencyPhase.settling =>
      'waiting for calm${switch (status.calmLeftSeconds) {
        final s? => ' ${s}s',
        null => '',
      }}$target',
    AutoLatencyPhase.steady => 'at target$target',
    AutoLatencyPhase.catchingUp =>
      'catching up ${status.rate.toStringAsFixed(2)}x$target',
  };
}

/// The stats panel line of an active Ultra fallback, or null.
String? describeBufferFallback(DateTime? until) {
  if (until == null) return null;
  String two(int v) => v.toString().padLeft(2, '0');
  return 'Standard until ${two(until.hour)}:${two(until.minute)} '
      '(Ultra stalled)';
}
