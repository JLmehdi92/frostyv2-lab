import 'package:flutter/material.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/screens/channel/chat/chat_commands.dart';
import 'package:frosty/screens/channel/chat/moderation.dart';
import 'package:frosty/screens/channel/chat/moderation_notice.dart';
import 'package:frosty/widgets/frosty_dialog.dart';

/// Twitch's slow-mode waits.
const kSlowModeWaits = [
  Duration(seconds: 3),
  Duration(seconds: 5),
  Duration(seconds: 10),
  Duration(seconds: 20),
  Duration(seconds: 30),
  Duration(seconds: 60),
  Duration(seconds: 120),
];

/// Twitch's follow ages for followers-only mode.
const kFollowAges = [
  Duration.zero,
  Duration(minutes: 10),
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(days: 1),
  Duration(days: 7),
  Duration(days: 30),
  Duration(days: 90),
];

String _followAgeLabel(Duration age) {
  if (age == Duration.zero) return 'Any follower';
  final days = age.inDays;
  if (days >= 30 && days % 30 == 0 && age.inSeconds % 86400 == 0) {
    final months = days ~/ 30;
    return '$months month${months == 1 ? '' : 's'}';
  }
  return timeoutLength(age.inSeconds);
}

/// A moderator's switches for the chat's room modes, and clearing the chat.
/// Shows the modes as [roomState] has them (Twitch's ROOMSTATE, which
/// follows every change).
class ChatModeControls extends StatefulWidget {
  const ChatModeControls({
    super.key,
    required this.roomState,
    required this.onModerate,
  });

  final ROOMSTATE roomState;

  /// Runs the change (and says it in chat); null when the chat closed.
  final Future<ModerationOutcome?> Function(ModerationCommand command)
  onModerate;

  @override
  State<ChatModeControls> createState() => _ChatModeControlsState();
}

class _ChatModeControlsState extends State<ChatModeControls> {
  var _busy = false;
  ModerationOutcome? _last;
  var _slowWait = const Duration(seconds: 30);
  var _followAge = Duration.zero;

  @override
  void initState() {
    super.initState();
    _readDurations();
  }

  @override
  void didUpdateWidget(ChatModeControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    _readDurations();
  }

  /// The active wait and follow age, so the pickers show them.
  void _readDurations() {
    final slow = int.tryParse(widget.roomState.slowMode) ?? 0;
    if (slow > 0) _slowWait = Duration(seconds: slow);
    final follow = int.tryParse(widget.roomState.followersOnly) ?? -1;
    if (follow >= 0) _followAge = Duration(minutes: follow);
  }

  Future<void> _run(ModerationCommand command) async {
    setState(() => _busy = true);
    final outcome = await widget.onModerate(command);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _last = outcome;
      // A refused change leaves the pickers on what the room still has.
      if (!(outcome?.ok ?? false)) _readDurations();
    });
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => FrostyDialog(
        title: 'Clear chat?',
        message: 'Every message is deleted for everyone.',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (mounted && (confirmed ?? false)) await _run(const ClearChatCommand());
  }

  /// A choice of [values] that, while the mode is on, applies at once.
  Widget _picker({
    required Duration value,
    required List<Duration> values,
    required String Function(Duration) label,
    required ValueChanged<Duration> onChanged,
  }) => DropdownButton<Duration>(
    value: values.contains(value) ? value : null,
    hint: Text(label(value), overflow: TextOverflow.ellipsis),
    isExpanded: true,
    underline: const SizedBox.shrink(),
    onChanged: _busy ? null : (value) => onChanged(value!),
    items: [
      for (final value in values)
        DropdownMenuItem(
          value: value,
          child: Text(label(value), overflow: TextOverflow.ellipsis),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final room = widget.roomState;
    final slowOn = room.slowMode != '0';
    final followersOn = room.followersOnly != '-1';
    final theme = Theme.of(context);
    final last = _last;

    void toggle(ChatMode mode, bool value, Duration? duration) => _run(
      ChatModeCommand(mode, on: value, duration: value ? duration : null),
    );

    /// A mode with a length keeps its picker apart from the switch, so a
    /// tap beside the picker does not change the room for everyone.
    Widget mode(
      ChatMode mode,
      bool on,
      IconData icon, {
      Duration? duration,
      Widget? picker,
    }) => picker == null
        ? SwitchListTile(
            secondary: Icon(icon),
            title: Text(mode.label),
            value: on,
            onChanged: _busy ? null : (value) => toggle(mode, value, null),
          )
        : ListTile(
            leading: Icon(icon),
            title: Text(mode.label),
            subtitle: picker,
            trailing: Switch(
              value: on,
              onChanged: _busy
                  ? null
                  : (value) => toggle(mode, value, duration),
            ),
          );

    return ListView(
      primary: false,
      shrinkWrap: true,
      children: [
        mode(
          ChatMode.slow,
          slowOn,
          Icons.hourglass_top_rounded,
          duration: _slowWait,
          picker: _picker(
            value: _slowWait,
            values: kSlowModeWaits,
            label: (wait) => '${wait.inSeconds}s between messages',
            onChanged: (wait) {
              setState(() => _slowWait = wait);
              if (slowOn) {
                _run(ChatModeCommand(ChatMode.slow, on: true, duration: wait));
              }
            },
          ),
        ),
        mode(
          ChatMode.followers,
          followersOn,
          Icons.favorite_rounded,
          duration: _followAge,
          picker: _picker(
            value: _followAge,
            values: kFollowAges,
            label: _followAgeLabel,
            onChanged: (age) {
              setState(() => _followAge = age);
              if (followersOn) {
                _run(
                  ChatModeCommand(ChatMode.followers, on: true, duration: age),
                );
              }
            },
          ),
        ),
        mode(
          ChatMode.subscribers,
          room.subMode != '0',
          Icons.monetization_on_rounded,
        ),
        mode(
          ChatMode.emoteOnly,
          room.emoteOnly != '0',
          Icons.emoji_emotions_rounded,
        ),
        mode(ChatMode.uniqueChat, room.r9k != '0', Icons.quiz_rounded),
        ListTile(
          leading: Icon(
            Icons.delete_sweep_rounded,
            color: theme.colorScheme.error,
          ),
          title: const Text('Clear chat'),
          enabled: !_busy,
          onTap: _clear,
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          )
        else if (last != null)
          Padding(
            padding: const EdgeInsets.all(16),
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
    );
  }
}
