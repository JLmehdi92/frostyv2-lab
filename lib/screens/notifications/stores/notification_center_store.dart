import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_social_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/onsite_notification.dart';

part 'notification_center_store.g.dart';

class NotificationCenterStore = NotificationCenterStoreBase
    with _$NotificationCenterStore;

abstract class NotificationCenterStoreBase with Store {
  NotificationCenterStoreBase({required this.fetch, required this.markRead});

  final Future<OnsiteNotificationPage?> Function(String? cursor) fetch;
  final Future<ViewerActionOutcome> Function(List<String> ids) markRead;

  static const maxNotifications = 300;

  final notifications = ObservableList<OnsiteNotification>();

  @readonly
  var _loading = false;

  @readonly
  var _failed = false;

  @readonly
  var _marking = false;

  @readonly
  String? _cursor;

  var _epoch = 0;

  @computed
  int get unreadCount => notifications.where((n) => !n.isRead).length;

  @computed
  bool get hasMore => _cursor != null;

  @action
  Future<void> refresh() async {
    final epoch = ++_epoch;
    _loading = true;
    final page = await fetch(null);
    if (epoch != _epoch) return;
    runInAction(() {
      _loading = false;
      _failed = page == null;
      if (page == null) return;
      notifications
        ..clear()
        ..addAll(page.notifications);
      _cursor = page.cursor;
    });
  }

  @action
  Future<void> loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _loading) return;
    final epoch = _epoch;
    _loading = true;
    final page = await fetch(cursor);
    if (epoch != _epoch) return;
    runInAction(() {
      _loading = false;
      if (page == null) {
        _cursor = null;
        return;
      }
      final known = {for (final n in notifications) n.id};
      notifications.addAll(
        page.notifications.where((n) => !known.contains(n.id)),
      );
      if (notifications.length > maxNotifications) {
        notifications.removeRange(maxNotifications, notifications.length);
      }
      _cursor = notifications.length >= maxNotifications ? null : page.cursor;
    });
  }

  @action
  List<String> markAllReadLocally() {
    final ids = <String>[];
    for (var i = 0; i < notifications.length; i++) {
      if (notifications[i].isRead) continue;
      ids.add(notifications[i].id);
      notifications[i] = notifications[i].read();
    }
    return ids;
  }

  @action
  void restoreUnread(List<String> ids) {
    for (var i = 0; i < notifications.length; i++) {
      final n = notifications[i];
      if (ids.contains(n.id)) notifications[i] = n.unread();
    }
  }

  @action
  Future<ViewerActionOutcome> sendRead(List<String> ids) async {
    _marking = true;
    final outcome = await markRead(ids);
    runInAction(() {
      _marking = false;
      if (outcome != ViewerActionOutcome.done) restoreUnread(ids);
    });
    return outcome;
  }
}
