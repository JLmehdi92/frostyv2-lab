import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/utils/share_link.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

Uri scheduleSlotUri(String login, ScheduleSegment segment) => Uri.https(
  'www.twitch.tv',
  '/${login.toLowerCase()}/schedule',
  {'segmentID': segment.id},
);

Future<void> showScheduleSlotSheet(
  BuildContext context, {
  required ScheduleSegment segment,
  required String login,
  required bool recurring,
  ({bool set, VoidCallback toggle})? reminder,
}) => showOnsetSheet<void>(
  context: context,
  builder: (_) => ScheduleSlotSheet(
    segment: segment,
    login: login,
    recurring: recurring,
    reminder: reminder,
  ),
);

class ScheduleSlotSheet extends StatelessWidget {
  const ScheduleSlotSheet({
    super.key,
    required this.segment,
    required this.login,
    required this.recurring,
    this.reminder,
  });

  final ScheduleSegment segment;
  final String login;
  final bool recurring;
  final ({bool set, VoidCallback toggle})? reminder;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final start = segment.startAt.toLocal();
    final end = segment.endAt?.toLocal();
    final day = DateFormat.yMMMMEEEEd().format(start);
    final time = DateFormat.jm();
    final hours = end == null
        ? time.format(start)
        : '${time.format(start)} – ${time.format(end)}';
    final title = segment.title?.trim();
    final reminder = this.reminder;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            title == null || title.isEmpty ? l.profileStreamUntitled : title,
            style: SheetText.title.copyWith(color: colors.text),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(day, style: SheetText.body.copyWith(color: colors.body)),
              Text(hours, style: SheetText.body.copyWith(color: colors.body)),
              if (segment.categoryName case final category?)
                Text(
                  category,
                  style: SheetText.body.copyWith(color: colors.secondary),
                ),
              if (recurring)
                Text(
                  l.scheduleRepeatsWeekly,
                  style: SheetText.body.copyWith(color: colors.secondary),
                ),
              if (segment.isCancelled)
                Text(
                  l.profileCancelled,
                  style: SheetText.body.copyWith(color: colors.secondary),
                ),
            ],
          ),
        ),
        if (reminder != null)
          SheetRow(
            key: const ValueKey('slot-remind'),
            glyph: reminder.set ? SheetGlyphKind.check : SheetGlyphKind.bell,
            label: reminder.set ? l.profileReminderSet : l.profileRemindMe,
            onTap: () {
              reminder.toggle();
              Navigator.pop(context);
            },
          ),
        SheetRow(
          key: const ValueKey('slot-share'),
          glyph: SheetGlyphKind.share,
          label: l.scheduleShareSlot,
          onTap: () => unawaited(
            shareLink(context, scheduleSlotUri(login, segment).toString()),
          ),
        ),
      ],
    );
  }
}
