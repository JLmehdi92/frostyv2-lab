import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel/video/live_progress.dart';
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
    this.updatedAt,
  });

  final int positionSec;
  final int lengthSec;

  /// When it was saved (null when unknown).
  final DateTime? updatedAt;

  /// Watched to (nearly) the end: the next play starts over.
  final bool finished;

  /// Saved position as a fraction of the length, for list progress bars.
  double get progress => finished
      ? 1
      : lengthSec <= 0
      ? 0
      : (positionSec / lengthSec).clamp(0.0, 1.0);
}

/// Saved watch positions on this device (Twitch keeps the logged-in
/// viewer's own as well). One JSON map in SharedPreferences, keeping the
/// 300 most recently watched videos, each account apart: entries are keyed
/// `viewer|vod` (`|vod` when logged out). Entries saved before accounts
/// were kept apart (keyed by the bare VOD id) stay readable by everyone.
class VodResumeRepository {
  VodResumeRepository._();

  /// The one repository: every save goes through its queue, so screens
  /// open at the same time never overwrite each other's positions.
  static final shared = VodResumeRepository._();

  /// Bumped after each save, so lists can refresh their progress bars once
  /// the closing save of a player screen has landed.
  static final changes = ValueNotifier<int>(0);

  static const _key = 'vod_resume_v1';
  static const _maxEntries = 300;

  /// Saves in the first seconds are not worth keeping.
  static const _minPosition = 30;

  /// This close to the end, the video counts as finished.
  static const _endMargin = 30;

  /// Saves run one after the other (read-modify-write).
  Future<void> _queue = Future.value();

  /// Forgets pending saves (each widget test runs in its own fake zone).
  @visibleForTesting
  void resetQueue() => _queue = Future.value();

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
    updatedAt: DateTime.fromMicrosecondsSinceEpoch(raw['u']!, isUtc: true),
  );

  static String _entryKey(String vodId, String? viewer) =>
      '${viewer ?? ''}|$vodId';

  /// Where [viewer] (null: logged out) stopped in [vodId].
  Future<VodResumeEntry?> entry(String vodId, {String? viewer}) async {
    await _queue;
    final all = await _read();
    final raw = all[_entryKey(vodId, viewer)] ?? all[vodId];
    return raw == null ? null : _toEntry(raw);
  }

  /// Every video [viewer] saved, read once per list screen.
  Future<Map<String, VodResumeEntry>> snapshot({String? viewer}) async {
    await _queue;
    final all = await _read();
    final prefix = '${viewer ?? ''}|';
    return {
      for (final MapEntry(:key, :value) in all.entries)
        if (!key.contains('|')) key: _toEntry(value),
      for (final MapEntry(:key, :value) in all.entries)
        if (key.startsWith(prefix))
          key.substring(prefix.length): _toEntry(value),
    };
  }

  Future<void> save(
    String vodId, {
    required int positionSec,
    required int lengthSec,
    String? viewer,
  }) => _queue = _queue
      .then((_) async {
        if (positionSec < _minPosition) return;
        final finished = lengthSec > 0 && positionSec >= lengthSec - _endMargin;
        final all = await _read();
        all[_entryKey(vodId, viewer)] = {
          'p': finished ? 0 : positionSec,
          'l': lengthSec,
          'u': clock.now().microsecondsSinceEpoch,
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
        changes.value++;
      })
      .catchError((Object e) {
        debugPrint('VOD resume save failed: $e');
      });
}

/// Where to start a VOD, like the official app (J:gmx.a): a `?t=` link
/// wins; then 30 s before the position saved on this device ([saved]);
/// then where the viewer's Twitch account left it ([server], as is, live
/// sessions included); then 30 s before where this device saw them leave
/// the live broadcast it recorded ([live]); otherwise the beginning.
///
/// A position saved later than the one before it in that order wins (the
/// video was watched on another device since, or Twitch did not take the
/// live position). A start in the last 30 s of the video ([lengthSec], or
/// the saved length) starts over instead.
Duration startPositionFor({
  VodResumeEntry? saved,
  Duration? deepLink,
  ViewingHistory? server,
  LiveProgressEntry? live,
  int lengthSec = 0,
}) {
  if (deepLink != null) return deepLink;
  final candidates = <(int, DateTime?)>[
    if (saved != null)
      (saved.finished ? 0 : saved.positionSec - 30, saved.updatedAt),
    if (server != null) (server.positionSec, server.updatedAt),
    if (live != null) (live.offsetSec - 30, live.updatedAt),
  ];
  if (candidates.isEmpty) return Duration.zero;
  var best = candidates.first;
  for (final candidate in candidates.skip(1)) {
    final (_, at) = candidate;
    final bestAt = best.$2;
    if (at != null && bestAt != null && at.isAfter(bestAt)) best = candidate;
  }
  final start = best.$1 < 0 ? 0 : best.$1;
  final length = lengthSec > 0 ? lengthSec : saved?.lengthSec ?? 0;
  if (length > 0 && start >= length - 30) return Duration.zero;
  return Duration(seconds: start);
}

/// Saves the position of the current player every 20 s while it plays, when
/// it pauses, when the app goes to the background and when the screen
/// closes (the official app's cadence), on this device and to the viewer's
/// Twitch account ([report]).
class VodResumeController {
  VodResumeController({
    required this.vodId,
    required this.player,
    required this.repository,
    this.viewer,
    this.report,
    this.fallbackLengthSec = 0,
    @visibleForTesting this.interval = const Duration(seconds: 20),
  });

  final String vodId;

  /// The logged-in viewer's id (null: logged out).
  final String? Function()? viewer;

  /// Writes the position (seconds) to the viewer's Twitch account.
  final Future<bool> Function(int positionSec)? report;

  /// The current player (it changes on a fallback to the web engine).
  final VodPlayerController? Function() player;
  final VodResumeRepository repository;

  /// Used while the player does not know the length yet.
  final int fallbackLengthSec;
  final Duration interval;

  Timer? _timer;
  ReactionDisposer? _disposePauseReaction;

  /// Nothing is saved until playback really started: before that the
  /// position is the rewound start (30 s back), and saving it would move
  /// the resume point back on every quick open and close.
  var _started = false;

  void start() {
    _timer = Timer.periodic(interval, (_) {
      final p = player();
      if (p != null && !p.paused) unawaited(save());
    });
    _disposePauseReaction = reaction((_) => player()?.status, (
      VodPlaybackStatus? status,
    ) {
      if (status == VodPlaybackStatus.playing) _started = true;
      if (status == VodPlaybackStatus.paused ||
          status == VodPlaybackStatus.ended) {
        unawaited(save());
      }
    });
  }

  Future<void> save() async {
    final p = player();
    if (p == null || !_started) return;
    final at = await p.currentPositionForSave();
    if (at == null) return;
    final length = p.duration.inSeconds;
    final send = report;
    await Future.wait([
      repository.save(
        vodId,
        positionSec: at.inSeconds,
        lengthSec: length > 0 ? length : fallbackLengthSec,
        viewer: viewer?.call(),
      ),
      // The official app writes any position past the start (J:cc90.S2).
      if (send != null && at.inSeconds > 0)
        send(at.inSeconds).then<void>(
          (_) {},
          onError: (Object e) =>
              debugPrint('VOD position report failed: ${e.runtimeType}'),
        ),
    ]);
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
