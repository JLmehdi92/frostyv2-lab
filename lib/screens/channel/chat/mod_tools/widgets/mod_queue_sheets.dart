import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_action_text.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';
import 'package:onset/screens/channel/chat/mod_tools/stores/mod_tools_store.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_sheet_parts.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

String _clock(BuildContext context, DateTime at) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(at.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

class AutoModQueueSheet extends StatefulWidget {
  const AutoModQueueSheet({super.key, required this.tools});

  final ModToolsStore tools;

  @override
  State<AutoModQueueSheet> createState() => _AutoModQueueSheetState();
}

class _AutoModQueueSheetState extends State<AutoModQueueSheet> {
  final _working = <String>{};
  String? _failure;

  Future<void> _resolve(HeldMessage message, AutoModDecision decision) async {
    setState(() {
      _working.add(message.id);
      _failure = null;
    });
    final failure = await widget.tools.resolveHeld(message.id, decision);
    if (!mounted) return;
    setState(() {
      _working.remove(message.id);
      _failure = failure;
    });
  }

  String _reason(AppLocalizations l, HeldMessage message) {
    final reason = l.modToolsHeldReason(
      reason: switch (message.reason) {
        'blocked_term' => 'blockedTerm',
        'blocked_link' => 'blockedLink',
        _ => 'automod',
      },
    );
    if (message.level <= 0) return reason;
    return l.modToolsHeldLevel(reason: reason, level: message.level);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Observer(
      builder: (context) {
        final messages = widget.tools.heldMessages.toList();
        final hasResolved = messages.any((m) => !m.isPending);
        return ModSheetBody(
          children: [
            ModSheetTitle(
              l.modToolsAutoModQueue,
              caption: l.modToolsAutoModCaption,
            ),
            if (messages.isEmpty) ModNote(l.modToolsAutoModEmpty),
            for (final message in messages)
              ModItemTile(
                title: message.userName,
                subtitle: [
                  _clock(context, message.heldAt),
                  _reason(l, message),
                  if (!message.isPending)
                    l.modToolsHeldStatus(status: message.status.name),
                ].join(' · '),
                body: message.text,
                actions: message.isPending
                    ? [
                        ModCompactButton(
                          label: l.modToolsAllow,
                          primary: true,
                          onPressed: _working.contains(message.id)
                              ? null
                              : () => _resolve(message, AutoModDecision.allow),
                        ),
                        ModCompactButton(
                          label: l.modToolsDeny,
                          danger: true,
                          onPressed: _working.contains(message.id)
                              ? null
                              : () => _resolve(message, AutoModDecision.deny),
                        ),
                      ]
                    : const [],
              ),
            if (hasResolved)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SheetButton(
                    label: l.modToolsClearResolved,
                    tone: SheetButtonTone.text,
                    onPressed: widget.tools.clearResolvedHeld,
                  ),
                ),
              ),
            SheetStatusLine(
              busy: false,
              message: _failure,
              ok: false,
              minHeight: 26,
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            ),
          ],
        );
      },
    );
  }
}

class ModActionLogSheet extends StatelessWidget {
  const ModActionLogSheet({super.key, required this.tools});

  final ModToolsStore tools;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Observer(
      builder: (context) {
        final actions = tools.actions.toList();
        return ModSheetBody(
          children: [
            ModSheetTitle(
              l.modToolsActionLog,
              caption: l.modToolsActionLogCaption,
            ),
            if (actions.isEmpty) ModNote(l.modToolsActionLogEmpty),
            for (final entry in actions)
              ModItemTile(
                title: entry.moderatorName,
                subtitle: _clock(context, entry.at),
                body: modActionLine(l, entry),
              ),
          ],
        );
      },
    );
  }
}
