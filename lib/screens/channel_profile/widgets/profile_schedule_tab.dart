import 'package:flutter/material.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/services/notifications/schedule_reminders.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:intl/intl.dart';

/// "in 3 hours", "in 2 days", "now" for a start [at] seen from [now].
String formatStartsIn(DateTime at, DateTime now) {
  final left = at.difference(now);
  if (left <= Duration.zero) return 'now';
  if (left.inMinutes < 60) {
    final minutes = left.inMinutes.clamp(1, 59);
    return 'in $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
  }
  if (left.inHours < 24) {
    return 'in ${left.inHours} ${left.inHours == 1 ? 'hour' : 'hours'}';
  }
  final days = left.inDays;
  return 'in $days ${days == 1 ? 'day' : 'days'}';
}

/// Sets or clears [segment]'s reminder, and says when it could not.
Future<void> _toggleReminder(
  BuildContext context,
  ScheduleReminders reminders,
  ScheduleSegment segment, {
  required String login,
  required String channelName,
}) async {
  final result = await reminders.toggle(
    segment,
    login: login,
    channelName: channelName,
  );
  final message = switch (result) {
    ReminderResult.refused =>
      'Allow notifications for this app in the system settings.',
    ReminderResult.failed => "Couldn't set the reminder.",
    ReminderResult.set || ReminderResult.cleared => null,
  };
  if (message == null || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// The coming streams of a channel, by local day: time, title, category,
/// cancelled ones struck through; the next start on top. With [reminders],
/// "Remind Me" on the next stream and on each segment to come, like
/// Twitch.
class ProfileScheduleContent extends StatelessWidget {
  const ProfileScheduleContent({
    super.key,
    required this.schedule,
    required this.now,
    this.reminders,
    this.login = '',
    this.channelName = '',
  });

  final ChannelSchedule schedule;
  final DateTime now;
  final ScheduleReminders? reminders;

  /// The channel the reminders are for.
  final String login;
  final String channelName;

  @override
  Widget build(BuildContext context) {
    final reminders = this.reminders;
    if (reminders == null) return _build(context, null);
    return ListenableBuilder(
      listenable: reminders,
      builder: (context, _) => _build(context, reminders),
    );
  }

  Widget _build(BuildContext context, ScheduleReminders? reminders) {
    final muted = context.colorScheme.onSurfaceVariant;
    final upcoming = schedule.upcoming(now);
    if (upcoming.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Text(
          'No streams scheduled',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
      );
    }

    final next = schedule.nextStartAt;
    final nextSegment = next == null
        ? null
        : upcoming
              .where((s) => !s.isCancelled && s.startAt.isAtSameMomentAs(next))
              .firstOrNull;
    final remindNext =
        reminders != null &&
        nextSegment != null &&
        reminders.canRemind(nextSegment);
    final days = <DateTime, List<ScheduleSegment>>{};
    for (final segment in upcoming) {
      final local = segment.startAt.toLocal();
      days
          .putIfAbsent(DateTime(local.year, local.month, local.day), () => [])
          .add(segment);
    }
    final time = DateFormat.jm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next != null && next.isAfter(now))
          Card.filled(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text('Next stream ${formatStartsIn(next, now)}'),
                  subtitle: Text(
                    DateFormat.MMMEd().add_jm().format(next.toLocal()),
                  ),
                ),
                if (remindNext)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _RemindButton(
                      set: reminders.isSet(nextSegment.id),
                      onPressed: () => _toggleReminder(
                        context,
                        reminders,
                        nextSegment,
                        login: login,
                        channelName: channelName,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        for (final MapEntry(key: day, value: segments) in days.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(
              DateFormat.MMMMEEEEd().format(day),
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final segment in segments)
            _SegmentTile(
              segment: segment,
              time: time,
              reminder: reminders != null && reminders.canRemind(segment)
                  ? (
                      set: reminders.isSet(segment.id),
                      toggle: () => _toggleReminder(
                        context,
                        reminders,
                        segment,
                        login: login,
                        channelName: channelName,
                      ),
                    )
                  : null,
            ),
        ],
      ],
    );
  }
}

/// Twitch's toggle: "Remind Me" with a bell, then "Reminder Set" with a
/// check, the set state quieter.
class _RemindButton extends StatelessWidget {
  const _RemindButton({required this.set, required this.onPressed});

  final bool set;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = Text(set ? 'Reminder Set' : 'Remind Me');
    return set
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.check_rounded),
            label: label,
          )
        : FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.notifications_none_rounded),
            label: label,
          );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    required this.segment,
    required this.time,
    this.reminder,
  });

  final ScheduleSegment segment;
  final DateFormat time;

  /// Its reminder, when it can have one.
  final ({bool set, VoidCallback toggle})? reminder;

  @override
  Widget build(BuildContext context) {
    final muted = context.colorScheme.onSurfaceVariant;
    final end = segment.endAt;
    final hours = end == null
        ? time.format(segment.startAt.toLocal())
        : '${time.format(segment.startAt.toLocal())} – '
              '${time.format(end.toLocal())}';
    final title = segment.title?.trim();
    final cancelled = segment.isCancelled;
    final strike = cancelled
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        title == null || title.isEmpty ? 'Stream' : title,
        style: strike,
      ),
      subtitle: Text(
        [hours, ?segment.categoryName, if (cancelled) 'Cancelled'].join(' · '),
        style: TextStyle(color: muted).merge(strike),
      ),
      trailing: switch (reminder) {
        (:final set, :final toggle) => IconButton(
          tooltip: set ? 'Reminder Set' : 'Remind Me',
          isSelected: set,
          onPressed: toggle,
          icon: const Icon(Icons.notifications_none_rounded),
          selectedIcon: const Icon(Icons.notifications_active_rounded),
        ),
        null => null,
      },
    );
  }
}
