import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/up_next.dart';
import 'package:frosty/screens/vod/vod_resume.dart';
import 'package:mobx/mobx.dart';

part 'up_next_store.g.dart';

/// Where the Up Next card is.
enum UpNextPhase {
  /// The video has not ended.
  idle,

  /// Looking for the next video.
  loading,

  /// Counting down to the next video.
  countdown,

  /// Showing the next video until the viewer picks it (no autoplay).
  waiting,

  /// The viewer closed the card.
  dismissed,

  /// The next video was started.
  done,

  /// There is nothing to offer.
  none,
}

/// Why the countdown waits.
enum UpNextHold {
  /// Picture-in-picture: the card cannot be seen.
  pip,

  /// Another player took playback focus.
  focus,
}

class UpNextStore = UpNextStoreBase with _$UpNextStore;

/// The official app's Up Next at the end of a VOD: the next video of the
/// channel (else a similar one of its category), a 10 second countdown when
/// autoplay is allowed, Cancel, and play now.
abstract class UpNextStoreBase with Store {
  UpNextStoreBase({
    required this.current,
    required this.channelVideos,
    required this.similarVideos,
    required this.savedPositions,
    required this.autoplay,
    required this.isMetered,
    required this.onPlay,
    this.isVisible = _alwaysVisible,
  });

  static bool _alwaysVisible() => true;

  /// The countdown's length, like the official app.
  static const countdownSeconds = 10;

  final Vod current;

  /// The channel's videos, newest first.
  final Future<List<Vod>> Function() channelVideos;

  /// The most viewed videos of a category (by its id).
  final Future<List<Vod>> Function(String gameId) similarVideos;

  /// Where this device left each video (by id).
  final Future<Map<String, VodResumeEntry>> Function() savedPositions;

  final VodAutoplay Function() autoplay;

  /// Whether the network costs data (null when unknown).
  final Future<bool?> Function() isMetered;

  /// Starts [Vod] (called once).
  final void Function(Vod next) onPlay;

  /// Whether the card can be seen (its screen is the current route): read
  /// at each tick, so a screen pushed over the video holds the countdown.
  final bool Function() isVisible;

  /// Bumped by each end or reset: a lookup for an older one is dropped.
  var _generation = 0;
  Future<(Vod, bool)?>? _choice;
  Timer? _timer;
  final _holds = <UpNextHold>{};

  bool get _held => _holds.isNotEmpty;
  var _disposed = false;

  @readonly
  var _phase = UpNextPhase.idle;

  @readonly
  Vod? _next;

  /// The next video is from the category, not the channel.
  @readonly
  var _similar = false;

  @readonly
  var _secondsLeft = countdownSeconds;

  /// The video ended: find what comes next and offer it.
  @action
  Future<void> onEnded() async {
    if (_disposed || _phase != UpNextPhase.idle) return;
    final generation = ++_generation;
    _phase = UpNextPhase.loading;
    final choice = await (_choice ??= _choose());
    if (_disposed || generation != _generation) return;
    if (choice == null) {
      runInAction(() => _phase = UpNextPhase.none);
      return;
    }
    final (next, similar) = choice;
    final allowed = autoplayAllowed(autoplay(), metered: await isMetered());
    if (_disposed || generation != _generation) return;
    runInAction(() {
      _next = next;
      _similar = similar;
      _secondsLeft = countdownSeconds;
      _phase = allowed ? UpNextPhase.countdown : UpNextPhase.waiting;
    });
    if (allowed && !_held) _startTimer();
  }

  /// Looked up once per screen: ending again after a replay reuses it.
  Future<(Vod, bool)?> _choose() async {
    Map<String, VodResumeEntry> saved;
    try {
      saved = await savedPositions();
    } catch (e) {
      debugPrint('Up next positions failed: ${e.runtimeType}');
      saved = const {};
    }
    try {
      final next = pickUpNext(
        current: current,
        candidates: await channelVideos(),
        saved: saved,
      );
      if (next != null) return (next, false);
    } catch (e) {
      debugPrint('Up next channel videos failed: ${e.runtimeType}');
    }
    final gameId = current.gameId;
    if (gameId == null || gameId.isEmpty) return null;
    try {
      final next = pickUpNext(
        current: current,
        candidates: await similarVideos(gameId),
        saved: saved,
      );
      return next == null ? null : (next, true);
    } catch (e) {
      debugPrint('Up next similar videos failed: ${e.runtimeType}');
      return null;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @action
  void _tick() {
    if (_disposed || _phase != UpNextPhase.countdown) {
      _timer?.cancel();
      return;
    }
    if (!isVisible()) {
      // Covered: start over once it can be seen again.
      _secondsLeft = countdownSeconds;
      return;
    }
    _secondsLeft--;
    if (_secondsLeft <= 0) playNow();
  }

  /// Closes the card; the video stays at its end.
  @action
  void cancel() {
    _timer?.cancel();
    if (_phase == UpNextPhase.countdown || _phase == UpNextPhase.waiting) {
      _phase = UpNextPhase.dismissed;
    }
  }

  /// Starts the next video now.
  @action
  void playNow() {
    _timer?.cancel();
    final next = _next;
    if (_disposed || next == null || _phase == UpNextPhase.done) return;
    if (_phase != UpNextPhase.countdown && _phase != UpNextPhase.waiting) {
      return;
    }
    _phase = UpNextPhase.done;
    onPlay(next);
  }

  /// The video plays again (a replay, a seek back): no card until it ends.
  @action
  void reset() {
    _timer?.cancel();
    _generation++;
    if (_phase == UpNextPhase.done) return;
    _phase = UpNextPhase.idle;
    _secondsLeft = countdownSeconds;
  }

  /// While held for any [reason] (picture-in-picture, another player's
  /// focus), the countdown waits, and starts over once nothing holds it.
  @action
  void hold(bool held, {UpNextHold reason = UpNextHold.pip}) {
    final wasHeld = _held;
    if (held) {
      _holds.add(reason);
    } else {
      _holds.remove(reason);
    }
    if (wasHeld == _held || _phase != UpNextPhase.countdown) return;
    if (_held) {
      _timer?.cancel();
      _secondsLeft = countdownSeconds;
    } else {
      _startTimer();
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
