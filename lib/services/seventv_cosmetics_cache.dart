import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onset/apis/seventv_api.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/third_party_cosmetics.dart';

class SevenTvCosmeticsCache {
  final SevenTVApi api;
  final Duration batchWindow;
  final int batchSize;
  final int capacity;
  final int setCapacity;
  final Duration pauseAfterFailure;
  final DateTime Function() now;

  SevenTvCosmeticsCache(
    this.api, {
    this.batchWindow = const Duration(milliseconds: 400),
    this.batchSize = 20,
    this.capacity = 4000,
    this.setCapacity = 200,
    this.pauseAfterFailure = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final _known = <String, SevenTvUserCosmetics>{};
  final _waiting = <String, Completer<SevenTvUserCosmetics>>{};
  final _sets = <String, Future<List<Emote>>>{};
  Timer? _flushTimer;
  DateTime? _pausedUntil;

  bool get _isPaused {
    final pausedUntil = _pausedUntil;
    return pausedUntil != null && now().isBefore(pausedUntil);
  }

  SevenTvUserCosmetics? cached(String twitchId) => _known[twitchId];

  void remember(String twitchId, SevenTvUserCosmetics cosmetics) {
    _known.remove(twitchId);
    _known[twitchId] = cosmetics;
    while (_known.length > capacity) {
      _known.remove(_known.keys.first);
    }
  }

  Future<SevenTvUserCosmetics> lookup(String twitchId) {
    if (_known[twitchId] case final known?) return Future.value(known);
    if (_waiting[twitchId] case final waiting?) return waiting.future;
    if (_isPaused) return Future.value(SevenTvUserCosmetics.none);
    final completer = Completer<SevenTvUserCosmetics>();
    _waiting[twitchId] = completer;
    _flushTimer ??= Timer(batchWindow, _flush);
    return completer.future;
  }

  Future<List<Emote>> emoteSet(String setId) {
    final known = _sets.remove(setId);
    if (known != null) return _sets[setId] = known;
    while (_sets.length >= setCapacity) {
      _sets.remove(_sets.keys.first);
    }
    return _sets[setId] = api
        .getEmoteSet(id: setId, type: EmoteType.sevenTVPersonal)
        .catchError((Object error) {
          _sets.remove(setId);
          debugPrint('7TV emote set unavailable: $error');
          return <Emote>[];
        });
  }

  void forgetEmoteSet(String setId) => _sets.remove(setId);

  Future<void> _flush() async {
    _flushTimer = null;
    final pending = Map.of(_waiting);
    _waiting.clear();
    final ids = pending.keys.toList();
    for (var start = 0; start < ids.length; start += batchSize) {
      if (_isPaused) {
        for (final id in ids.skip(start)) {
          pending[id]!.complete(SevenTvUserCosmetics.none);
        }
        return;
      }
      final batch = ids.sublist(
        start,
        (start + batchSize).clamp(0, ids.length),
      );
      Map<String, SevenTvUserCosmetics> found;
      try {
        found = await api.getUsersCosmetics(batch);
      } catch (error) {
        debugPrint('7TV cosmetics unavailable: $error');
        _pausedUntil = now().add(pauseAfterFailure);
        found = const {};
      }
      for (final id in batch) {
        final cosmetics = found[id];
        if (cosmetics != null) remember(id, cosmetics);
        pending[id]!.complete(cosmetics ?? SevenTvUserCosmetics.none);
      }
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
    for (final waiting in _waiting.values) {
      waiting.complete(SevenTvUserCosmetics.none);
    }
    _waiting.clear();
  }
}
