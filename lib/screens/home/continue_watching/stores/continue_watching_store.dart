import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/vod/vod_resume.dart';
import 'package:mobx/mobx.dart';

part 'continue_watching_store.g.dart';

/// A video of the "Continue watching" shelf and where the viewer left it.
@immutable
class ContinueWatchingItem {
  const ContinueWatchingItem({
    required this.vod,
    required this.positionSec,
    this.updatedAt,
  });

  final Vod vod;

  /// Where the viewer left it, in seconds.
  final int positionSec;

  /// When that position was saved (null when unknown).
  final DateTime? updatedAt;

  /// [positionSec] as a fraction of the video, for its progress bar.
  double get progress => vod.lengthSeconds <= 0
      ? 0
      : (positionSec / vod.lengthSeconds).clamp(0.0, 1.0);
}

class ContinueWatchingStore = ContinueWatchingStoreBase
    with _$ContinueWatchingStore;

/// Following's "Continue watching": the videos the viewer started and did
/// not finish, newest first, from this device's saved positions and from
/// their Twitch account (any device, live sessions Twitch tied to their
/// VOD included), like the official app's shelf.
///
/// - A video saved in both places shows the later save.
/// - Twitch's answer is asked by [load] only (the list's refresh); a
///   position saved on this device (a VOD closing) updates the shelf from
///   memory, asking Twitch only for a video it has never named.
/// - Never throws: what cannot be read is left out.
abstract class ContinueWatchingStoreBase with Store {
  ContinueWatchingStoreBase({
    required this.vodService,
    VodResumeRepository? repository,
    this.maxItems = 20,
  }) : repository = repository ?? VodResumeRepository.shared {
    VodResumeRepository.changes.addListener(_onLocalChange);
  }

  final TwitchVodService vodService;
  final VodResumeRepository repository;

  /// Videos on the shelf at most.
  final int maxItems;

  /// Positions this close to the end are done with (as the VOD screen
  /// starts them over).
  static const _endMargin = 30;

  @readonly
  List<ContinueWatchingItem> _items = const [];

  /// The first load has not answered yet.
  @readonly
  var _loading = true;

  /// Twitch's shelf, as last read (null: unknown, logged out or refused).
  List<ResumeWatchingEntry>? _server;

  /// Whose shelf [_server] is.
  String? _serverViewer;

  /// Videos already named, by id (from Twitch's shelf or asked by id).
  final _known = <String, Vod>{};

  /// Ids Twitch said do not exist (deleted videos): not asked again until
  /// the next [load].
  final _gone = <String>{};

  /// Bumped by each merge: a slower, older one never overwrites it.
  var _generation = 0;
  var _disposed = false;

  String? get _viewer => vodService.viewerId?.call();

  /// Reads Twitch's shelf again, then this device's positions. Videos
  /// taken as deleted are asked again (a video can come back).
  Future<void> load() async {
    _gone.clear();
    final viewer = _viewer;
    List<ResumeWatchingEntry>? server;
    try {
      server = await vodService.getResumeWatching(limit: maxItems);
    } catch (e) {
      // The service never throws; a broken one must not break the list.
      debugPrint('Continue watching: shelf unavailable: ${e.runtimeType}');
    }
    if (_disposed) return;
    // The account changed while Twitch answered: that answer is not theirs
    // (the shelf still shows the new account's own positions).
    if (viewer == _viewer) {
      // A refusal keeps what Twitch said last for this viewer (a network
      // blip must not empty the shelf); another viewer never sees it.
      _server = server ?? (viewer == _serverViewer ? _server : null);
      _serverViewer = viewer;
      for (final entry in server ?? const <ResumeWatchingEntry>[]) {
        _known[entry.vod.id] = entry.vod;
      }
    }
    await _merge();
  }

  void _onLocalChange() => unawaited(_merge());

  Future<void> _merge() async {
    final generation = ++_generation;
    final viewer = _viewer;
    Map<String, VodResumeEntry> local;
    try {
      local = await repository.snapshot(viewer: viewer);
    } catch (e) {
      debugPrint('Continue watching: saved positions unreadable: $e');
      local = const {};
    }
    if (_disposed || generation != _generation) return;

    // Where each video was left, the later save winning. Twitch's shelf
    // only for the account it was read for.
    final server = viewer == _serverViewer ? _server : null;
    final positions = <String, (int, DateTime?)>{};
    for (final entry in server ?? const <ResumeWatchingEntry>[]) {
      positions[entry.vod.id] = (
        entry.history.positionSec,
        entry.history.updatedAt,
      );
    }
    for (final MapEntry(key: id, value: entry) in local.entries) {
      final server = positions[id];
      final serverAt = server?.$2;
      final localAt = entry.updatedAt;
      if (server != null &&
          serverAt != null &&
          (localAt == null || serverAt.isAfter(localAt))) {
        continue;
      }
      // Finished here, after Twitch's position: done with it.
      positions[id] = (entry.finished ? -1 : entry.positionSec, localAt);
    }
    positions.removeWhere((id, value) => value.$1 <= 0 || _gone.contains(id));

    final newestFirst = positions.keys.toList()
      ..sort((a, b) {
        final x = positions[a]!.$2;
        final y = positions[b]!.$2;
        if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
        return y.compareTo(x);
      });
    final shown = newestFirst.take(maxItems).toList();

    final unknown = [
      for (final id in shown)
        if (!_known.containsKey(id)) id,
    ];
    if (unknown.isNotEmpty) {
      try {
        final lookup = await vodService.getVideos(unknown);
        for (final vod in lookup.videos) {
          _known[vod.id] = vod;
        }
        // Twitch said there is no such video (not merely refused it).
        _gone.addAll(lookup.missing);
      } catch (e) {
        debugPrint('Continue watching: videos unavailable: ${e.runtimeType}');
      }
      if (_disposed || generation != _generation) return;
    }

    final items = <ContinueWatchingItem>[];
    for (final id in shown) {
      final vod = _known[id];
      if (vod == null) continue;
      final (position, at) = positions[id]!;
      final nearEnd =
          !vod.isRecording &&
          vod.lengthSeconds > 0 &&
          position >= vod.lengthSeconds - _endMargin;
      if (nearEnd) continue;
      items.add(
        ContinueWatchingItem(vod: vod, positionSec: position, updatedAt: at),
      );
    }
    runInAction(() {
      _items = items;
      _loading = false;
    });
  }

  void dispose() {
    _disposed = true;
    VodResumeRepository.changes.removeListener(_onLocalChange);
  }
}
