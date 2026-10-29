import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/screens/channel_profile/widgets/profile_parts.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/services/notifications/schedule_reminders.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/state_views.dart';

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
Future<void> toggleScheduleReminder(
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

/// The segments still to come and not cancelled, the next first: what the
/// Home tab's "Coming up" shows.
List<ScheduleSegment> comingUp(ChannelSchedule schedule, DateTime now) => [
  for (final segment in schedule.upcoming(now))
    if (!segment.isCancelled && segment.startAt.isAfter(now)) segment,
];

/// A stream to come in the boards' card: its day in a tile, the time (and
/// category), the title, and Twitch's "Remind Me" when it can have one.
class ProfileScheduleCard extends StatelessWidget {
  const ProfileScheduleCard({
    super.key,
    required this.segment,
    required this.meta,
    this.next = false,
    this.reminders,
    this.login = '',
    this.channelName = '',
    this.large = false,
  });

  final ScheduleSegment segment;

  /// "Next stream · 21:00", "21:00 · Just Chatting".
  final String meta;

  /// The next stream: its weekday in the signal colour.
  final bool next;
  final ScheduleReminders? reminders;
  final String login;
  final String channelName;
  final bool large;

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
    final colors = FeedColors.of(context);
    final title = segment.title?.trim();
    final canRemind = reminders != null && reminders.canRemind(segment);
    return ProfileCard(
      child: Row(
        spacing: 12,
        children: [
          ProfileDateTile(
            date: segment.startAt.toLocal(),
            highlighted: next,
            large: large,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OnsetType.tabular(
                    TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: colors.secondary,
                    ),
                  ),
                ),
                Text(
                  title == null || title.isEmpty ? 'Stream' : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: large ? 15 : 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
          if (canRemind)
            ProfileRemindButton(
              set: reminders.isSet(segment.id),
              onPressed: () => toggleScheduleReminder(
                context,
                reminders,
                segment,
                login: login,
                channelName: channelName,
              ),
            ),
        ],
      ),
    );
  }
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
    this.large = false,
  });

  final ChannelSchedule schedule;
  final DateTime now;
  final ScheduleReminders? reminders;

  /// The channel the reminders are for.
  final String login;
  final String channelName;
  final bool large;

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
    final colors = FeedColors.of(context);
    final upcoming = schedule.upcoming(now);
    if (upcoming.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: const FeedStatusView.empty(message: 'No streams scheduled'),
      );
    }

    final next = schedule.nextStartAt;
    final nextSegment = next == null
        ? null
        : upcoming
              .where((s) => !s.isCancelled && s.startAt.isAtSameMomentAs(next))
              .firstOrNull;
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: nextSegment != null
                ? ProfileScheduleCard(
                    segment: nextSegment,
                    next: true,
                    meta:
                        'Next stream ${formatStartsIn(next, now)} · '
                        '${time.format(next.toLocal())}',
                    reminders: reminders,
                    login: login,
                    channelName: channelName,
                    large: large,
                  )
                : ProfileCard(
                    child: Text(
                      'Next stream ${formatStartsIn(next, now)} · '
                      '${DateFormat.MMMEd().add_jm().format(next.toLocal())}',
                      style: TextStyle(fontSize: 14, color: colors.text),
                    ),
                  ),
          ),
        for (final MapEntry(key: day, value: segments) in days.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 18, 2, 6),
            child: Semantics(
              header: true,
              child: Text(
                DateFormat.MMMMEEEEd().format(day),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.15,
                  color: colors.text,
                ),
              ),
            ),
          ),
          for (final segment in segments)
            _SegmentRow(
              segment: segment,
              time: time,
              reminder: reminders != null && reminders.canRemind(segment)
                  ? (
                      set: reminders.isSet(segment.id),
                      toggle: () => toggleScheduleReminder(
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

/// One stream of the day: the start in a narrow column, the title, the
/// hours and category, and its bell.
class _SegmentRow extends StatelessWidget {
  const _SegmentRow({required this.segment, required this.time, this.reminder});

  final ScheduleSegment segment;
  final DateFormat time;

  /// Its reminder, when it can have one.
  final ({bool set, VoidCallback toggle})? reminder;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
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
    final reminder = this.reminder;

    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.hairline,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: cancelled ? colors.raised : colors.pillBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Text(
                  title == null || title.isEmpty ? 'Stream' : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: cancelled ? colors.secondary : colors.text,
                  ).merge(strike),
                ),
                Text(
                  [
                    hours,
                    ?segment.categoryName,
                    if (cancelled) 'Cancelled',
                  ].join(' · '),
                  style: OnsetType.tabular(
                    TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: colors.secondary,
                    ).merge(strike),
                  ),
                ),
              ],
            ),
          ),
          if (reminder != null)
            IconButton(
              tooltip: reminder.set ? 'Reminder Set' : 'Remind Me',
              isSelected: reminder.set,
              onPressed: reminder.toggle,
              icon: SheetGlyph(SheetGlyphKind.bell, color: colors.secondary),
              // The signal reads on the dark ground only.
              selectedIcon: SheetGlyph(
                SheetGlyphKind.check,
                color: Theme.of(context).brightness == Brightness.dark
                    ? context.onsetColors.live
                    : colors.text,
                strokeWidth: 2.2,
              ),
            ),
        ],
      ),
    );
  }
}
