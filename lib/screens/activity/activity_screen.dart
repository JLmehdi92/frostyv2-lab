import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/activity/stores/activity_store.dart';
import 'package:frosty/screens/home/home_store.dart';
import 'package:frosty/screens/vod/vod_time.dart';
import 'package:frosty/screens/whispers/whispers_screen.dart';
import 'package:frosty/services/notifications/activity_log.dart';
import 'package:frosty/stores/whisper_store.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/readable_width.dart';
import 'package:mobx/mobx.dart';

/// Twitch's Activity: the notifications (here, those ONSET posted on this
/// device: go-live, mentions, reminders) and, when logged in, the
/// whispers. A section of the navigation shell, whose header holds the
/// tabs ([activityTabLabel]); this is the page under it.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    required this.store,
    required this.onOpenChannel,
    this.whispers,
    this.tab = ActivityTab.notifications,
    this.active = true,
    this.now = DateTime.now,
  });

  final ActivityStore store;

  /// The viewer's whispers; null when logged out (no Whispers tab).
  final WhisperStore? whispers;

  /// Opens a channel by login.
  final void Function(String login) onOpenChannel;

  /// The tab on screen (Whispers only with [whispers]).
  final ActivityTab tab;

  /// Whether Activity is the section on screen: opening it, and anything
  /// arriving while it is open, clears the count on the bar.
  final bool active;

  final DateTime Function() now;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

/// [tab]'s name in the header, with its unread count.
String activityTabLabel(
  ActivityTab tab, {
  required ActivityStore store,
  WhisperStore? whispers,
}) {
  final count = switch (tab) {
    ActivityTab.notifications => store.unreadCount,
    ActivityTab.whispers => whispers?.unreadCount ?? 0,
  };
  return count > 0 ? '${tab.label} ($count)' : tab.label;
}

class _ActivityScreenState extends State<ActivityScreen> {
  ReactionDisposer? _disposeSeen;

  @override
  void initState() {
    super.initState();
    if (widget.active) _opened();
    // Seen while open: what arrives meanwhile does not count as new.
    _disposeSeen = reaction((_) => widget.store.newCount, (int count) {
      if (widget.active && count > 0) unawaited(widget.store.markViewed());
    });
  }

  @override
  void didUpdateWidget(ActivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _opened();
  }

  /// Seen: the bar's count goes, the unread stay bold until opened.
  void _opened() =>
      unawaited(widget.store.refresh().then((_) => widget.store.markViewed()));

  @override
  void dispose() {
    _disposeSeen?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final whispers = widget.whispers;
    if (whispers != null && widget.tab == ActivityTab.whispers) {
      // The conversations do not scroll under the header.
      final padding = MediaQuery.paddingOf(context);
      return Padding(
        padding: EdgeInsets.only(top: padding.top),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: WhispersList(store: whispers),
        ),
      );
    }
    return _NotificationsList(
      store: widget.store,
      onOpenChannel: widget.onOpenChannel,
      now: widget.now,
    );
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({
    required this.store,
    required this.onOpenChannel,
    required this.now,
  });

  final ActivityStore store;
  final void Function(String login) onOpenChannel;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final entries = store.entries;
        final at = now();
        // Twitch splits at a day: "Most Recent", then "Earlier".
        final recent = [
          for (final e in entries)
            if (at.difference(e.at) <= const Duration(days: 1)) e,
        ];
        final earlier = [
          for (final e in entries)
            if (at.difference(e.at) > const Duration(days: 1)) e,
        ];
        final unread = store.unreadCount > 0;

        Widget header(String title, {required bool markAll}) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (markAll)
                TextButton(
                  onPressed: () => unawaited(store.markAllRead()),
                  child: const Text('Mark all as read'),
                ),
            ],
          ),
        );

        Widget tile(ActivityEntry entry) => _EntryTile(
          entry: entry,
          now: at,
          onTap: () {
            unawaited(store.markRead(entry.id));
            final login = entry.login;
            if (login != null) onOpenChannel(login);
          },
          onRemove: () => unawaited(store.remove(entry.id)),
        );

        final Widget content;
        if (entries.isEmpty) {
          content = ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [_UpToDate()],
          );
        } else {
          final firstGroup = recent.isNotEmpty ? recent : earlier;
          final secondGroup = recent.isNotEmpty
              ? earlier
              : const <ActivityEntry>[];
          content = ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              header('Most Recent', markAll: unread),
              ...firstGroup.map(tile),
              if (secondGroup.isNotEmpty) ...[
                header('Earlier', markAll: false),
                ...secondGroup.map(tile),
              ],
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Notifications ONSET posted on this device.',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kReadableMaxWidth),
            child: RefreshIndicator.adaptive(
              edgeOffset: MediaQuery.paddingOf(context).top,
              onRefresh: store.refresh,
              child: content,
            ),
          ),
        );
      },
    );
  }
}

/// Twitch's empty state.
class _UpToDate extends StatelessWidget {
  const _UpToDate();

  @override
  Widget build(BuildContext context) {
    final muted = context.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
      child: Column(
        children: [
          Icon(Icons.notifications_none_rounded, size: 48, color: muted),
          const SizedBox(height: 16),
          Text(
            "Hooray! You're up to date",
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back soon for alerts about you and the broadcasters you '
            'follow.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }
}

/// A notification: the channel's picture with an unread dot, bold while
/// unread, then when and its category, like Twitch's.
class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.now,
    required this.onTap,
    required this.onRemove,
  });

  final ActivityEntry entry;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  Future<void> _menu(BuildContext context) async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline_rounded),
          title: const Text('Remove notification'),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (remove == true) onRemove();
  }

  @override
  Widget build(BuildContext context) {
    final login = entry.login;
    final muted = context.colorScheme.onSurfaceVariant;
    final unread = !entry.read;
    final avatar = login != null
        ? ProfilePicture(userLogin: login)
        : CircleAvatar(
            child: Icon(switch (entry.kind) {
              ActivityKind.live => Icons.sensors_rounded,
              ActivityKind.mention => Icons.alternate_email_rounded,
              ActivityKind.reminder => Icons.event_rounded,
            }),
          );
    final when = formatTimeAgo(entry.at, now: now);
    return ListTile(
      leading: Badge(
        isLabelVisible: unread,
        smallSize: 10,
        backgroundColor: context.frostyColors.live,
        alignment: AlignmentDirectional.topStart,
        child: avatar,
      ),
      title: Text(
        entry.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: unread
            ? const TextStyle(fontWeight: FontWeight.w700)
            : TextStyle(color: muted),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.body.isNotEmpty)
            Text(entry.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(
            '$when • ${entry.kind.label}',
            style: context.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
      onTap: onTap,
      onLongPress: () => unawaited(_menu(context)),
    );
  }
}
