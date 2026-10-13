import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the viewer stopped in a VOD.
@immutable
class VodResumeEntry {
  const VodResumeEntry({
    required this.positionSec,
    required this.lengthSec,
    this.finished = false,
  });

  final int positionSec;
  final int lengthSec;

  /// Watched to (nearly) the end: the next play starts over.
  final bool finished;

  /// Saved position as a fraction of the length, for list progress bars.
  double get progress => finished
      ? 1
      : lengthSec <= 0
      ? 0
      : (positionSec / lengthSec).clamp(0.0, 1.0);
}

/// Saved watch positions, on this device only (the server-side history
/// needs a Twitch session). One JSON map in SharedPreferences, keeping the
/// 300 most recently watched videos.
class VodResumeRepository {
  static const _key = 'vod_resume_v1';
  static const _maxEntries = 300;

  /// Saves in the first seconds are not worth keeping.
  static const _minPosition = 30;

  /// This close to the end, the video counts as finished.
  static const _endMargin = 30;

  /// Saves run one after the other (read-modify-write).
  Future<void> _queue = Future.value();

  Future<Map<String, Map<String, int>>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final MapEntry(:key, :value) in decoded.entries)
          if (key is String &&
              value is Map &&
              value['p'] is int &&
              value['l'] is int &&
              value['u'] is int)
            key: {
              'p': value['p'] as int,
              'l': value['l'] as int,
              'u': value['u'] as int,
              if (value['f'] == 1) 'f': 1,
            },
      };
    } catch (_) {
      return {};
    }
  }

  static VodResumeEntry _toEntry(Map<String, int> raw) => VodResumeEntry(
    positionSec: raw['p']!,
    lengthSec: raw['l']!,
    finished: raw['f'] == 1,
  );

  Future<VodResumeEntry?> entry(String vodId) async {
    await _queue;
    final raw = (await _read())[vodId];
    return raw == null ? null : _toEntry(raw);
  }

  /// Every saved video, read once per list screen.
  Future<Map<String, VodResumeEntry>> snapshot() async {
    await _queue;
    return (await _read()).map((id, raw) => MapEntry(id, _toEntry(raw)));
  }

  Future<void> save(
    String vodId, {
    required int positionSec,
    required int lengthSec,
  }) => _queue = _queue
      .then((_) async {
        if (positionSec < _minPosition) return;
        final finished = lengthSec > 0 && positionSec >= lengthSec - _endMargin;
        final all = await _read();
        all[vodId] = {
          'p': finished ? 0 : positionSec,
          'l': lengthSec,
          'u': DateTime.now().microsecondsSinceEpoch,
          if (finished) 'f': 1,
        };
        if (all.length > _maxEntries) {
          final oldestFirst = all.keys.toList()
            ..sort((a, b) => all[a]!['u']!.compareTo(all[b]!['u']!));
          for (final id in oldestFirst.take(all.length - _maxEntries)) {
            all.remove(id);
          }
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, jsonEncode(all));
      })
      .catchError((Object e) {
        debugPrint('VOD resume save failed: $e');
      });
}

/// Where to start a VOD, like the official app: a `?t=` link wins,
/// otherwise 30 s before the saved position, otherwise the beginning.
Duration startPositionFor({VodResumeEntry? saved, Duration? deepLink}) {
  if (deepLink != null) return deepLink;
  if (saved == null || saved.finished) return Duration.zero;
  final start = saved.positionSec - 30;
  return Duration(seconds: start < 0 ? 0 : start);
}

/// Saves the position of the current player every 20 s while it plays, when
/// it pauses, when the app goes to the background and when the screen
/// closes (the official app's cadence).
class VodResumeController {
  VodResumeController({
    required this.vodId,
    required this.player,
    required this.repository,
    this.fallbackLengthSec = 0,
    @visibleForTesting this.interval = const Duration(seconds: 20),
  });

  final String vodId;

  /// The current player (it changes on a fallback to the web engine).
  final VodPlayerController? Function() player;
  final VodResumeRepository repository;

  /// Used while the player does not know the length yet.
  final int fallbackLengthSec;
  final Duration interval;

  Timer? _timer;
  ReactionDisposer? _disposePauseReaction;

  void start() {
    _timer = Timer.periodic(interval, (_) {
      final p = player();
      if (p != null && !p.paused) unawaited(save());
    });
    _disposePauseReaction = reaction((_) => player()?.status, (
      VodPlaybackStatus? status,
    ) {
      if (status == VodPlaybackStatus.paused ||
          status == VodPlaybackStatus.ended) {
        unawaited(save());
      }
    });
  }

  Future<void> save() async {
    final p = player();
    if (p == null) return;
    final at = await p.currentPositionForSave();
    if (at == null) return;
    final length = p.duration.inSeconds;
    await repository.save(
      vodId,
      positionSec: at.inSeconds,
      lengthSec: length > 0 ? length : fallbackLengthSec,
    );
  }

  /// Stops saving without a last save.
  void cancel() {
    _timer?.cancel();
    _disposePauseReaction?.call();
  }

  /// Stops saving and saves one last time.
  Future<void> close() {
    cancel();
    return save();
  }
}
