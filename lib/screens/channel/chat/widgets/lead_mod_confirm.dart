import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

const leadModConfirmKey = ValueKey('lead-mod-confirm');

Future<bool> confirmLeadModerator(
  BuildContext context,
  LeadModCommand command,
) async {
  final change = command.granted ? 'add' : 'remove';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => OnsetDialog(
      title: context.l10n.leadModConfirmTitle(
        change: change,
        name: command.login,
      ),
      message: context.l10n.leadModConfirmBody,
      actions: [
        SheetButton(
          label: context.l10n.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(context, false),
        ),
        SheetButton(
          key: leadModConfirmKey,
          label: context.l10n.leadModConfirmAction(change: change),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  return confirmed == true;
}
