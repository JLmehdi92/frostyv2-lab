import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:frosty/services/notifications/activity_log.dart';
import 'package:mobx/mobx.dart';

part 'activity_store.g.dart';

/// The Activity screen's list: the notifications ONSET posted on this
/// device, with the unread count shown on the Home bell.
class ActivityStore = ActivityStoreBase with _$ActivityStore;

abstract class ActivityStoreBase with Store {
  ActivityStoreBase({required this.log});

  final ActivityLog log;

  /// Newest first.
  @readonly
  var _entries = ObservableList<ActivityEntry>();

  @computed
  int get unreadCount => _entries.where((e) => !e.read).length;

  /// Reads the stored list again (the background go-live task adds to it).
  Future<void> refresh() => _run(log.reload);

  Future<void> addAll(Iterable<ActivityEntry> entries) =>
      _run(() => log.addAll(entries));

  Future<void> markRead(String id) => _run(() => log.markRead(id));

  Future<void> markAllRead() => _run(log.markAllRead);

  Future<void> remove(String id) => _run(() => log.remove(id));

  /// Runs [change], then shows the stored list. The list is a bonus: a
  /// storage failure is reported and leaves it as it was.
  Future<void> _run(Future<Object?> Function() change) async {
    try {
      await change();
      _show(log.entries);
    } catch (e, stack) {
      debugPrint('Activity list unavailable: $e');
      try {
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'activity list',
        );
      } catch (_) {
        // Firebase may not be initialized (e.g., in tests).
      }
    }
  }

  @action
  void _show(List<ActivityEntry> entries) =>
      _entries = ObservableList.of(entries);
}
