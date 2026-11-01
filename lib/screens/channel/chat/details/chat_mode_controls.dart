import 'package:flutter/material.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/moderation.dart';
import 'package:onset/screens/channel/chat/moderation_notice.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

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

String _followAgeLabel(Duration age, AppLocalizations l) {
  if (age == Duration.zero) return l.chatModesAnyFollower;
  final days = age.inDays;
  if (days >= 30 && days % 30 == 0 && age.inSeconds % 86400 == 0) {
    return l.chatDurationMonths(count: days ~/ 30);
  }
  return timeoutLength(age.inSeconds, l);
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
    ModerationOutcome? outcome;
    try {
      outcome = await widget.onModerate(command);
    } catch (error) {
      // A throw (rather than a refusal) must not leave every button
      // disabled for good.
      debugPrint('Moderation action failed: $error');
      outcome = moderationFailed;
    }
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
      builder: (context) => OnsetDialog(
        title: context.l10n.chatModesClearTitle,
        message: context.l10n.chatModesClearMessage,
        actions: [
          SheetButton(
            label: context.l10n.commonCancel,
            tone: SheetButtonTone.text,
            onPressed: () => Navigator.pop(context, false),
          ),
          SheetButton(
            label: context.l10n.chatClear,
            tone: SheetButtonTone.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (mounted && (confirmed ?? false)) await _run(const ClearChatCommand());
  }

  /// A choice of [values] that, while the mode is on, applies at once: the
  /// 34 dp select under the mode's name.
  Widget _picker({
    required Duration value,
    required List<Duration> values,
    required String Function(Duration) label,
    required ValueChanged<Duration> onChanged,
  }) {
    final colors = SheetColors.of(context);
    final style = TextStyle(
      fontFamily: OnsetTokens.bodyFamily,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: colors.text,
    );
    return Container(
      height: 34,
      // The select, as wide as its longest choice reads.
      constraints: const BoxConstraints(maxWidth: 220),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.ring,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Duration>(
          value: values.contains(value) ? value : null,
          hint: Text(
            label(value),
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
          isDense: true,
          isExpanded: true,
          style: style,
          dropdownColor: colors.dialog,
          borderRadius: BorderRadius.circular(12),
          icon: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: SheetGlyph(
              SheetGlyphKind.chevronDown,
              size: 16,
              strokeWidth: 2.2,
              color: colors.secondary,
            ),
          ),
          onChanged: _busy ? null : (value) => onChanged(value!),
          items: [
            for (final value in values)
              DropdownMenuItem(
                value: value,
                child: Text(label(value), overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.roomState;
    final slowOn = room.slowMode != '0';
    final followersOn = room.followersOnly != '-1';
    final colors = SheetColors.of(context);
    final last = _last;

    void toggle(ChatMode mode, bool value, Duration? duration) => _run(
      ChatModeCommand(mode, on: value, duration: value ? duration : null),
    );

    /// A mode with a length keeps its picker apart from the switch, so a
    /// tap beside the picker does not change the room for everyone.
    Widget mode(
      ChatMode mode,
      bool on,
      SheetGlyphKind glyph, {
      Duration? duration,
      Widget? picker,
    }) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          spacing: 14,
          children: [
            SheetGlyph(glyph, color: colors.secondary),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mode.label(context.l10n),
                    style: SheetText.row.copyWith(color: colors.text),
                  ),
                  ?picker,
                ],
              ),
            ),
            OnsetSwitch(
              value: on,
              semanticsLabel: mode.label(context.l10n),
              onChanged: _busy
                  ? null
                  : (value) => toggle(mode, value, duration),
            ),
          ],
        ),
      ),
    );

    // "Chat modes", the five switches, then
    // "Clear chat" in red and how the last change went.
    return ListView(
      primary: false,
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    context.l10n.chatDetailsModes,
                    style: SheetText.title.copyWith(color: colors.text),
                  ),
                ),
              ),
              Text(
                context.l10n.chatModesModerator,
                style: SheetText.status.copyWith(
                  fontSize: 12,
                  color: colors.secondary,
                ),
              ),
            ],
          ),
        ),
        mode(
          ChatMode.slow,
          slowOn,
          SheetGlyphKind.hourglass,
          duration: _slowWait,
          picker: _picker(
            value: _slowWait,
            values: kSlowModeWaits,
            label: (wait) =>
                context.l10n.chatModesSlowWait(seconds: wait.inSeconds),
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
          SheetGlyphKind.heart,
          duration: _followAge,
          picker: _picker(
            value: _followAge,
            values: kFollowAges,
            label: (age) => _followAgeLabel(age, context.l10n),
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
        mode(ChatMode.subscribers, room.subMode != '0', SheetGlyphKind.star),
        mode(ChatMode.emoteOnly, room.emoteOnly != '0', SheetGlyphKind.emote),
        mode(ChatMode.uniqueChat, room.r9k != '0', SheetGlyphKind.unique),
        Container(
          height: OnsetTokens.hairlineWidth,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: colors.hairline,
        ),
        SheetRow(
          glyph: SheetGlyphKind.clearChat,
          label: context.l10n.chatModesClearChat,
          danger: true,
          onTap: _busy ? null : _clear,
        ),
        SheetStatusLine(
          busy: _busy,
          message: last?.message,
          ok: last?.ok ?? true,
          minHeight: 26,
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
        ),
      ],
    );
  }
}
