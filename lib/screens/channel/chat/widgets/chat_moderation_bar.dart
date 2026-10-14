import 'package:flutter/material.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/channel/chat/chat_commands.dart';
import 'package:frosty/screens/channel/chat/moderation.dart';
import 'package:frosty/screens/channel/chat/moderation_notice.dart';
import 'package:frosty/widgets/frosty_dialog.dart';

/// The timeout lengths offered in one tap; a 1-second timeout purges the
/// person's messages.
const kTimeoutPresets = [
  Duration(seconds: 1),
  Duration(minutes: 1),
  Duration(minutes: 10),
  Duration(hours: 1),
  Duration(days: 1),
  Duration(days: 7),
  Duration(days: 14),
];

/// A moderator's actions on one person of the chat, for the user card:
/// timeout, ban, unban and warn. Says how the last one went under it.
class ChatModerationBar extends StatefulWidget {
  const ChatModerationBar({
    super.key,
    required this.login,
    required this.name,
    required this.onModerate,
  });

  final String login;
  final String name;

  /// Runs the action (and says it in chat); null when the chat closed.
  final Future<ModerationOutcome?> Function(ModerationCommand command)
  onModerate;

  @override
  State<ChatModerationBar> createState() => _ChatModerationBarState();
}

class _ChatModerationBarState extends State<ChatModerationBar> {
  var _busy = false;
  ModerationOutcome? _last;

  Future<void> _run(ModerationCommand command) async {
    setState(() => _busy = true);
    final outcome = await widget.onModerate(command);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _last = outcome;
    });
  }

  Future<void> _ban() async {
    final reason = await showModerationReasonDialog(
      context,
      title: 'Ban ${widget.name}?',
      action: 'Ban',
      required: false,
    );
    if (mounted && reason != null) await _run(BanCommand(widget.login, reason));
  }

  Future<void> _warn() async {
    final reason = await showModerationReasonDialog(
      context,
      title: 'Warn ${widget.name}',
      action: 'Warn',
      required: true,
    );
    if (mounted && reason != null) {
      await _run(WarnCommand(widget.login, reason));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _last;
    final enabled = !_busy;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              children: [
                MenuAnchor(
                  menuChildren: [
                    for (final duration in kTimeoutPresets)
                      MenuItemButton(
                        onPressed: () =>
                            _run(TimeoutCommand(widget.login, duration, '')),
                        child: Text(
                          duration.inSeconds == 1
                              ? '1 second (purge)'
                              : timeoutLength(duration.inSeconds),
                        ),
                      ),
                  ],
                  builder: (context, controller, _) => FilledButton.tonalIcon(
                    onPressed: enabled
                        ? () => controller.isOpen
                              ? controller.close()
                              : controller.open()
                        : null,
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text('Timeout'),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: enabled ? _ban : null,
                  style: FilledButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  icon: const Icon(Icons.gavel_rounded),
                  label: const Text('Ban'),
                ),
                OutlinedButton.icon(
                  onPressed: enabled
                      ? () => _run(UnbanCommand(widget.login))
                      : null,
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Unban'),
                ),
                OutlinedButton.icon(
                  onPressed: enabled ? _warn : null,
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Warn'),
                ),
              ],
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            )
          else if (last != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                last.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: last.ok
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Asks for a moderation reason; null when cancelled. When not [required]
/// an empty reason confirms too.
Future<String?> showModerationReasonDialog(
  BuildContext context, {
  required String title,
  required String action,
  required bool required,
}) => showDialog<String>(
  context: context,
  builder: (context) =>
      _ReasonDialog(title: title, action: action, required: required),
);

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.action,
    required this.required,
  });

  final String title;
  final String action;
  final bool required;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FrostyDialog(
      title: widget.title,
      content: TextField(
        controller: _reason,
        autofocus: true,
        maxLength: TwitchApi.maxReasonLength,
        decoration: InputDecoration(
          labelText: widget.required ? 'Reason' : 'Reason (optional)',
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: widget.required && _reason.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _reason.text.trim()),
          child: Text(widget.action),
        ),
      ],
    );
  }
}
