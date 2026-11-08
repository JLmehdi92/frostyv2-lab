import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

class ChatWarningDialog extends StatelessWidget {
  const ChatWarningDialog({super.key});

  static const acknowledgeKey = ValueKey('chat-warning-acknowledge');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return OnsetDialog(
      title: l.chatWarningTitle,
      message: l.chatWarningBody,
      actions: [
        SheetButton(
          label: l.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(context, false),
        ),
        SheetButton(
          key: acknowledgeKey,
          label: l.chatWarningAcknowledge,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}

Future<void> acknowledgeChatWarning(
  BuildContext context,
  ChatStore chatStore,
  TwitchViewerActionsService service,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const ChatWarningDialog(),
  );
  if (confirmed != true) return;
  final outcome = await chatStore.acknowledgeWarning(service);
  if (outcome == null || outcome == ViewerActionOutcome.done) return;
  if (messenger == null || !messenger.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(l.viewerActionResult(status: outcome.name))),
    );
}
