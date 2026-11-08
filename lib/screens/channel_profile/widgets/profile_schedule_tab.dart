import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/screens/channel_profile/widgets/profile_parts.dart';
import 'package:onset/screens/channel_profile/widgets/schedule_slot_sheet.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/settings/widgets/go_live_setting.dart';
import 'package:onset/services/notifications/schedule_reminders.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/notification_permission_prompt.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/state_views.dart';

/// "in 3 hours", "in 2 days", "now" for a start [at] seen from [now], in
/// [l]'s language.
String formatStartsIn(DateTime at, DateTime now, AppLocalizations l) {
  final left = at.difference(now);
  if (left <= Duration.zero) return l.startsNow;
  if (left.inMinutes < 60) {
    return l.startsInMinutes(count: left.inMinutes.clamp(1, 59));
  }
  if (left.inHours < 24) return l.startsInHours(count: left.inHours);
  return l.startsInDays(count: left.inDays);
}

/// The heading of [day] in the schedule, in the language of `Intl`:
/// "Sunday, November 1"; in French a title's capital and the first of the
/// month's ordinal, « Dimanche 1er novembre » (intl gives « dimanche 1
/// novembre »).
String scheduleDayTitle(DateTime day) {
  final format = DateFormat.MMMMEEEEd();
  final text = format.format(day);
  if (!format.locale.startsWith('fr')) return text;
  final ordinal = day.day == 1
      ? text.replaceFirst(RegExp(r'(?<!\d)1(?!\d)'), '1er')
      : text;
  return toBeginningOfSentenceCase(ordinal, format.locale);
}

/// Sets or clears [segment]'s reminder, and says when it could not.
Future<void> toggleScheduleReminder(
  BuildContext context,
  ScheduleReminders reminders,
  ScheduleSegment segment, {
  required String login,
  required String channelName,
  GoLivePlatform notificationPlatform = const GoLivePlatform(),
}) async {
  if (!reminders.isSet(segment.id) &&
      !await explainUnlessAllowed(context, notificationPlatform.allowed)) {
    return;
  }
  if (!context.mounted) return;
  final result = await reminders.toggle(
    segment,
    login: login,
    channelName: channelName,
  );
  if (!context.mounted) return;
  final message = switch (result) {
    ReminderResult.refused => context.l10n.profileReminderRefused,
    ReminderResult.failed => context.l10n.profileReminderFailed,
    ReminderResult.set || ReminderResult.cleared => null,
  };
  if (message == null) return;
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

/// A stream to come in the card: its day in a tile, the time (and
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
                  title == null || title.isEmpty
                      ? context.l10n.profileStreamUntitled
                      : title,
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
    this.extras = ScheduleExtras.none,
  });

  final ChannelSchedule schedule;
  final ScheduleExtras extras;
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
    final vacation = extras.onVacationAfter(now)
        ? Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ScheduleVacationBanner(extras: extras),
          )
        : null;
    if (upcoming.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?vacation,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: FeedStatusView.empty(
              message: context.l10n.profileNoSchedule,
            ),
          ),
        ],
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
        ?vacation,
        if (next != null && next.isAfter(now))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: nextSegment != null
                ? ProfileScheduleCard(
                    segment: nextSegment,
                    next: true,
                    meta: context.l10n.profileNextStreamIn(
                      when: formatStartsIn(next, now, context.l10n),
                      time: time.format(next.toLocal()),
                    ),
                    reminders: reminders,
                    login: login,
                    channelName: channelName,
                    large: large,
                  )
                : ProfileCard(
                    child: Text(
                      context.l10n.profileNextStreamIn(
                        when: formatStartsIn(next, now, context.l10n),
                        time: DateFormat.MMMEd().add_jm().format(
                          next.toLocal(),
                        ),
                      ),
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
                scheduleDayTitle(day),
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
              recurring: extras.isRecurring(segment),
              onOpen: (reminder) => showScheduleSlotSheet(
                context,
                segment: segment,
                login: login,
                recurring: extras.isRecurring(segment),
                reminder: reminder,
              ),
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
  const _SegmentRow({
    required this.segment,
    required this.time,
    required this.onOpen,
    this.recurring = false,
    this.reminder,
  });

  final ScheduleSegment segment;
  final DateFormat time;
  final bool recurring;
  final void Function(({bool set, VoidCallback toggle})? reminder) onOpen;

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

    return InkWell(
      key: ValueKey('schedule-segment-${segment.id}'),
      onTap: () => onOpen(reminder),
      child: Container(
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
                    title == null || title.isEmpty
                        ? context.l10n.profileStreamUntitled
                        : title,
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
                      if (recurring) context.l10n.scheduleWeekly,
                      if (cancelled) context.l10n.profileCancelled,
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
                tooltip: reminder.set
                    ? context.l10n.profileReminderSet
                    : context.l10n.profileRemindMe,
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
      ),
    );
  }
}

class ScheduleVacationBanner extends StatelessWidget {
  const ScheduleVacationBanner({super.key, required this.extras});

  final ScheduleExtras extras;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final format = DateFormat.MMMd();
    return ProfileCard(
      child: Row(
        spacing: 12,
        children: [
          Icon(Icons.beach_access_outlined, color: colors.secondary),
          Expanded(
            child: Text(
              context.l10n.scheduleVacation(
                start: format.format(extras.vacationStart!.toLocal()),
                end: format.format(extras.vacationEnd!.toLocal()),
              ),
              style: TextStyle(fontSize: 14, height: 1.4, color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}
