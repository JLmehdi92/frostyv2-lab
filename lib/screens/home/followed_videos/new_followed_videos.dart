import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/home/followed_videos/stores/followed_videos_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

int countNewVideos(Iterable<Vod> videos, String seenAt) {
  final since = DateTime.tryParse(seenAt);
  if (since == null) return 0;
  return videos.where((video) => video.createdAt.isAfter(since)).length;
}

abstract final class NewFollowedVideos {
  static final count = ValueNotifier<int>(0);
  static const recheckAfter = Duration(minutes: 30);
  static DateTime? _checkedAt;
  static Future<void>? _running;

  @visibleForTesting
  static void reset() {
    count.value = 0;
    _checkedAt = null;
    _running = null;
  }

  static Future<void> refresh(
    FollowedVideosStore store,
    SettingsStore settings, {
    DateTime Function() now = DateTime.now,
  }) {
    final checked = _checkedAt;
    if (checked != null && now().difference(checked) < recheckAfter) {
      return Future.value();
    }
    return _running ??= _refresh(
      store,
      settings,
      now,
    ).whenComplete(() => _running = null);
  }

  static Future<void> _refresh(
    FollowedVideosStore store,
    SettingsStore settings,
    DateTime Function() now,
  ) async {
    await store.load();
    if (store.error != null) return;
    _checkedAt = now();
    if (settings.followedVideosSeenAt.isEmpty) {
      markSeen(settings, now: now);
      return;
    }
    count.value = countNewVideos(store.videos, settings.followedVideosSeenAt);
  }

  static void markSeen(
    SettingsStore settings, {
    DateTime Function() now = DateTime.now,
  }) {
    runInAction(
      () => settings.followedVideosSeenAt = now().toUtc().toIso8601String(),
    );
    count.value = 0;
  }
}
