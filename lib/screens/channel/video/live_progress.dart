import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel/video/player_controller.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _numericId = RegExp(r'^[0-9]{1,20}$');

/// How far into its broadcast a live stream is on screen, in seconds: the
/// time since it started minus the player's latency (`2.3s`). This is the
/// archive VOD's timeline. Null when the start cannot be read.
///
/// The official app reads the broadcast offset from the stream's ID3 tags
/// (`ld_lat_data.stream_offset`); our players do not surface them, so this
/// can differ by a few seconds.
int? liveOffsetSeconds({
  required StreamTwitch stream,
  String? latency,
  required DateTime now,
}) {
  final started = DateTime.tryParse(stream.startedAt);
  if (started == null) return null;
  final match = RegExp(
    r'^\s*([0-9]+(?:\.[0-9]+)?)\s*s\s*$',
  ).firstMatch(latency ?? '');
  final latencyMs = match == null
      ? 0
      : (double.parse(match.group(1)!) * 1000).round();
  final ms = now.difference(started).inMilliseconds - latencyMs;
  return ms <= 0 ? null : ms ~/ 1000;
}

/// Where a viewer was in a live broadcast.
@immutable
class LiveProgressEntry {
  const LiveProgressEntry({
    required this.streamId,
    required this.channelId,
    required this.startedAt,
    required this.offsetSec,
    required this.updatedAt,
  });

  /// The broadcast's id: its archive VOD's `broadcast { id }`.
  final String streamId;
  final String channelId;
  final DateTime startedAt;

  /// Seconds into the broadcast.
  final int offsetSec;
  final DateTime updatedAt;
}

/// Where each viewer left live broadcasts, on this device, so the archive
/// VOD can start there (also when Twitch's own history is out of reach).
/// One JSON map in SharedPreferences, each viewer apart (an account never
/// sees another's), keeping the 300 most recent broadcasts. Only ids and
/// times are kept.
class LiveProgressRepository {
  LiveProgressRepository._();

  static final shared = LiveProgressRepository._();

  static const _key = 'live_progress_v1';
  static const _maxEntries = 300;

  /// How far apart a broadcast's start and its VOD's creation may be for
  /// the VOD to be taken as that broadcast's, when it does not name it.
  static const _matchWindow = Duration(minutes: 10);

  Future<void> _queue = Future.value();

  /// Forgets pending saves (each test runs in its own fake zone).
  @visibleForTesting
  void resetQueue() => _queue = Future.value();

  static String _scope(String? viewer) => viewer ?? '';

  Future<Map<String, Map<String, Object>>> _read() async {
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
              value['c'] is String &&
              value['s'] is int &&
              value['p'] is int &&
              value['u'] is int)
            key: {
              'c': value['c'] as String,
              's': value['s'] as int,
              'p': value['p'] as int,
              'u': value['u'] as int,
            },
      };
    } catch (_) {
      return {};
    }
  }

  /// The [viewer]'s entries (null: logged out), by stream id.
  Future<Map<String, LiveProgressEntry>> snapshot({
    required String? viewer,
  }) async {
    await _queue;
    final prefix = '${_scope(viewer)}|';
    return {
      for (final MapEntry(:key, :value) in (await _read()).entries)
        if (key.startsWith(prefix))
          key.substring(prefix.length): LiveProgressEntry(
            streamId: key.substring(prefix.length),
            channelId: value['c']! as String,
            startedAt: DateTime.fromMillisecondsSinceEpoch(
              value['s']! as int,
              isUtc: true,
            ),
            offsetSec: value['p']! as int,
            updatedAt: DateTime.fromMicrosecondsSinceEpoch(
              value['u']! as int,
              isUtc: true,
            ),
          ),
    };
  }

  /// The live session [vod] recorded, for [viewer]: the broadcast it names,
  /// or (when it names none) the latest one of its channel that started
  /// with it. Only past broadcasts are recordings of a live session.
  Future<LiveProgressEntry?> forVod(Vod vod, {required String? viewer}) async {
    if (vod.type != VodType.archive) return null;
    final entries = await snapshot(viewer: viewer);
    final broadcastId = vod.broadcastId;
    if (broadcastId != null) return entries[broadcastId];
    LiveProgressEntry? best;
    for (final entry in entries.values) {
      if (entry.channelId != vod.ownerId) continue;
      if (entry.startedAt.difference(vod.createdAt).abs() > _matchWindow) {
        continue;
      }
      if (best == null || entry.updatedAt.isAfter(best.updatedAt)) {
        best = entry;
      }
    }
    return best;
  }

  Future<void> save({
    required String? viewer,
    required String streamId,
    required String channelId,
    required DateTime startedAt,
    required int offsetSec,
  }) => _queue = _queue
      .then((_) async {
        if (!_numericId.hasMatch(streamId) ||
            !_numericId.hasMatch(channelId) ||
            (viewer != null && !_numericId.hasMatch(viewer)) ||
            offsetSec <= 0) {
          return;
        }
        final all = await _read();
        all['${_scope(viewer)}|$streamId'] = {
          'c': channelId,
          's': startedAt.millisecondsSinceEpoch,
          'p': offsetSec,
          'u': clock.now().microsecondsSinceEpoch,
        };
        if (all.length > _maxEntries) {
          final oldestFirst = all.keys.toList()
            ..sort(
              (a, b) => (all[a]!['u']! as int).compareTo(all[b]!['u']! as int),
            );
          for (final key in oldestFirst.take(all.length - _maxEntries)) {
            all.remove(key);
          }
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, jsonEncode(all));
      })
      .catchError((Object e) {
        debugPrint('Live progress save failed: ${e.runtimeType}');
      });
}

/// Records where the viewer is in a live broadcast, like the official app
/// does so the broadcast can later resume in its VOD: kept on this device
/// every 20 s while playing, and written to the viewer's Twitch account
/// every 5 minutes while playing (the official app's interval), on pause,
/// when the app goes to the background and when the screen closes.
class LiveProgressTracker {
  LiveProgressTracker({
    required this.repository,
    required this.viewer,
    this.report,
    @visibleForTesting this.interval = const Duration(seconds: 20),
    @visibleForTesting this.reportInterval = const Duration(minutes: 5),
  });

  final LiveProgressRepository repository;

  /// The logged-in viewer's id (null: logged out, kept on this device only).
  final String? Function() viewer;

  /// Writes the position to the viewer's Twitch account (stream id,
  /// seconds into the broadcast).
  final Future<bool> Function(String streamId, int offsetSec)? report;

  final Duration interval;
  final Duration reportInterval;

  PlayerController? _player;
  ReactionDisposer? _disposePauseReaction;
  Timer? _timer;
  DateTime? _lastReport;

  /// Nothing is saved for a stream that never played on screen.
  var _watched = false;

  /// A position was sent to Twitch already.
  var _reported = false;

  /// The frame on screen when the player paused (stream id, offset): the
  /// clock keeps running, the picture does not, so saves while paused (the
  /// app going to the background, the screen closing, maybe much later)
  /// keep it. Null while playing.
  (String, int)? _pausedAt;

  /// The last position sent to Twitch (stream id, offset).
  (String, int)? _lastSent;

  /// Where the player is now, by the clock (null when unknown).
  (String, int)? _currentPosition() {
    final player = _player;
    final stream = player?.streamInfo;
    if (player == null || stream == null || !_numericId.hasMatch(stream.id)) {
      return null;
    }
    final offset = liveOffsetSeconds(
      stream: stream,
      latency: player.latency,
      now: clock.now(),
    );
    return offset == null ? null : (stream.id, offset);
  }

  /// Follows [player] (the first one, or the web one after a fallback).
  void attach(PlayerController player) {
    _disposePauseReaction?.call();
    _player = player;
    _pausedAt = null;
    if (!player.paused) _watched = true;
    _disposePauseReaction = reaction((_) => player.paused, (bool paused) {
      if (!paused) {
        _watched = true;
        _pausedAt = null;
      } else {
        _pausedAt = _currentPosition();
        unawaited(save(report: true));
      }
    });
  }

  void start() {
    _timer?.cancel();
    _lastReport = clock.now();
    _timer = Timer.periodic(interval, (_) {
      final player = _player;
      if (player == null || player.paused) return;
      _watched = true;
      final last = _lastReport;
      unawaited(
        save(
          report:
              last == null || clock.now().difference(last) >= reportInterval,
        ),
      );
    });
  }

  /// A report this soon after the last one is skipped (a pause and the app
  /// going to the background arrive together), except the closing one.
  static const _reportGap = Duration(seconds: 10);

  /// Saves the current position on this device, and to Twitch when
  /// [report] is set and a viewer is logged in.
  Future<void> save({bool report = false}) => _save(report: report);

  Future<void> _save({required bool report, bool closing = false}) async {
    final player = _player;
    if (player == null || !_watched) return;
    final stream = player.streamInfo;
    if (stream == null || !_numericId.hasMatch(stream.id)) return;
    final started = DateTime.tryParse(stream.startedAt);
    final now = clock.now();
    final paused = _pausedAt;
    // Paused: the frame it stopped on, never the time since. Paused with
    // no known frame (attached paused): nothing to save.
    final offset = player.paused
        ? (paused != null && paused.$1 == stream.id ? paused.$2 : null)
        : liveOffsetSeconds(stream: stream, latency: player.latency, now: now);
    if (started == null || offset == null) return;
    final viewerId = viewer();
    final writes = <Future<void>>[
      repository.save(
        viewer: viewerId,
        streamId: stream.id,
        channelId: stream.userId,
        startedAt: started,
        offsetSec: offset,
      ),
    ];
    final send = this.report;
    final last = _lastReport;
    final tooSoon =
        !closing &&
        _reported &&
        last != null &&
        now.difference(last) < _reportGap;
    final alreadySent = _lastSent == (stream.id, offset);
    if (report &&
        viewerId != null &&
        send != null &&
        !tooSoon &&
        !alreadySent) {
      _reported = true;
      _lastReport = now;
      _lastSent = (stream.id, offset);
      writes.add(
        send(stream.id, offset).then<void>(
          (_) {},
          onError: (Object e) =>
              debugPrint('Live progress report failed: ${e.runtimeType}'),
        ),
      );
    }
    await Future.wait(writes);
  }

  /// Stops without a last save.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _disposePauseReaction?.call();
    _disposePauseReaction = null;
  }

  /// Stops and saves one last time (to Twitch too).
  Future<void> close() {
    cancel();
    return _save(report: true, closing: true);
  }
}
