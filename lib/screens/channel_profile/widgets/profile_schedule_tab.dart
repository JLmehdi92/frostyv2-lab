import 'package:flutter/material.dart';
import 'package:frosty/models/channel_profile.dart';
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

/// The coming streams of a channel, by local day: time, title, category,
/// cancelled ones struck through; the next start on top.
class ProfileScheduleContent extends StatelessWidget {
  const ProfileScheduleContent({
    super.key,
    required this.schedule,
    required this.now,
  });

  final ChannelSchedule schedule;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
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
            child: ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: Text('Next stream ${formatStartsIn(next, now)}'),
              subtitle: Text(
                DateFormat.MMMEd().add_jm().format(next.toLocal()),
              ),
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
            _SegmentTile(segment: segment, time: time),
        ],
      ],
    );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({required this.segment, required this.time});

  final ScheduleSegment segment;
  final DateFormat time;

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
    );
  }
}
