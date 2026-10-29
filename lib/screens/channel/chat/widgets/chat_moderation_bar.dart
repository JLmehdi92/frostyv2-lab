import 'package:flutter/material.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/channel/chat/chat_commands.dart';
import 'package:frosty/screens/channel/chat/moderation.dart';
import 'package:frosty/screens/channel/chat/moderation_notice.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';
import 'package:frosty/widgets/sheet/onset_panel.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';
import 'package:frosty/widgets/sheet/sheet_glyph.dart';

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
/// timeout, ban, unban and warn (board ChaineCarteUtilisateur: a row of
/// pills that scrolls sideways, the timeout lengths in a menu). Says how
/// the last one went under it.
class ChatModerationBar extends StatefulWidget {
  const ChatModerationBar({
    super.key,
    required this.login,
    required this.name,
    required this.onModerate,
    this.dense = false,
  });

  final String login;
  final String name;

  /// Runs the action (and says it in chat); null when the chat closed.
  final Future<ModerationOutcome?> Function(ModerationCommand command)
  onModerate;

  /// The tablet panel's smaller pills (40 dp).
  final bool dense;

  @override
  State<ChatModerationBar> createState() => _ChatModerationBarState();
}

class _ChatModerationBarState extends State<ChatModerationBar> {
  var _busy = false;
  ModerationOutcome? _last;
  final _menu = MenuController();
  var _menuOpen = false;

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
    final colors = SheetColors.of(context);
    final last = _last;
    final enabled = !_busy;
    final height = widget.dense ? 40.0 : 44.0;
    // The menu opens above the pill (board: 196 dp, 40 dp lengths).
    const menuPadding = 6.0;
    const itemHeight = 40.0;
    final menuHeight = kTimeoutPresets.length * itemHeight + menuPadding * 2;
    final timeout = MenuAnchor(
      controller: _menu,
      onOpen: () => setState(() => _menuOpen = true),
      onClose: () {
        if (mounted) setState(() => _menuOpen = false);
      },
      alignmentOffset: Offset(0, -(height + menuHeight + 6)),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF222222)
              : colors.dialog,
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        shadowColor: const WidgetStatePropertyAll(Colors.black),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(menuPadding)),
        minimumSize: const WidgetStatePropertyAll(Size(196, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colors.ring,
              width: FrostyTokens.hairlineWidth,
            ),
          ),
        ),
      ),
      menuChildren: [
        for (final duration in kTimeoutPresets)
          MenuItemButton(
            style: MenuItemButton.styleFrom(
              minimumSize: const Size(184, itemHeight),
              maximumSize: const Size(double.infinity, itemHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              foregroundColor: colors.text,
              textStyle: SheetText.body.copyWith(
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
            onPressed: () => _run(TimeoutCommand(widget.login, duration, '')),
            child: Text(
              duration.inSeconds == 1
                  ? '1 second (purge)'
                  : timeoutLength(duration.inSeconds),
            ),
          ),
      ],
      builder: (context, controller, _) => ModerationPill(
        label: 'Timeout',
        glyph: SheetGlyphKind.timer,
        height: height,
        tone: ModerationPillTone.raised,
        expanded: _menuOpen,
        onPressed: enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                spacing: widget.dense ? 5 : 6,
                children: [
                  timeout,
                  ModerationPill(
                    label: 'Ban',
                    glyph: SheetGlyphKind.block,
                    height: height,
                    tone: ModerationPillTone.danger,
                    onPressed: enabled ? _ban : null,
                  ),
                  ModerationPill(
                    label: 'Unban',
                    glyph: SheetGlyphKind.unban,
                    height: height,
                    onPressed: enabled
                        ? () => _run(UnbanCommand(widget.login))
                        : null,
                  ),
                  ModerationPill(
                    label: 'Warn',
                    glyph: SheetGlyphKind.warn,
                    height: height,
                    onPressed: enabled ? _warn : null,
                  ),
                ],
              ),
            ),
            // The row fades out at the end: more pills than fit scroll.
            PositionedDirectional(
              end: 0,
              top: 0,
              bottom: 0,
              width: 28,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        SheetPresentation.surfaceOf(
                          context,
                        ).withValues(alpha: 0),
                        SheetPresentation.surfaceOf(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SheetStatusLine(
          busy: _busy,
          message: last?.message,
          ok: last?.ok ?? true,
          minHeight: widget.dense ? 28 : 30,
          padding: EdgeInsets.fromLTRB(16, widget.dense ? 4 : 6, 16, 0),
        ),
      ],
    );
  }
}

/// How a [ModerationPill] reads.
enum ModerationPillTone {
  /// Timeout: a raised pill.
  raised,

  /// Ban: tinted red.
  danger,

  /// Unban, Warn: outlined.
  outlined,
}

/// A moderation action's pill: glyph and label, 44 dp (40 in a panel).
class ModerationPill extends StatelessWidget {
  const ModerationPill({
    super.key,
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.tone = ModerationPillTone.outlined,
    this.height = 44,
    this.expanded,
  });

  final String label;
  final SheetGlyphKind glyph;

  /// Null while an action runs.
  final VoidCallback? onPressed;
  final ModerationPillTone tone;
  final double height;

  /// Set for the pill that opens a menu: its chevron turns while open.
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (Color fill, Color fg, BorderSide side) = switch (tone) {
      ModerationPillTone.raised => (
        dark ? const Color(0xFF262626) : colors.raised,
        colors.text,
        BorderSide.none,
      ),
      ModerationPillTone.danger => (
        colors.dangerTint,
        colors.danger,
        BorderSide.none,
      ),
      ModerationPillTone.outlined => (
        Colors.transparent,
        colors.text,
        BorderSide(color: colors.ringStrong, width: FrostyTokens.hairlineWidth),
      ),
    };
    final open = expanded;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      expanded: open,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: Material(
          color: fill,
          shape: StadiumBorder(side: side),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  SheetGlyph(glyph, size: 16, color: fg),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: FrostyTokens.bodyFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  if (open != null)
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: motionDuration(
                        context,
                        const Duration(milliseconds: 220),
                      ),
                      curve: FrostyMotion.standard,
                      child: SheetGlyph(
                        SheetGlyphKind.chevronDown,
                        size: 16,
                        strokeWidth: 2,
                        color: colors.secondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
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
    final empty = _reason.text.trim().isEmpty;
    return OnsetDialog(
      title: widget.title,
      content: SheetTextField(
        controller: _reason,
        autofocus: true,
        label: widget.required ? 'Reason' : 'Reason (optional)',
        maxLength: TwitchApi.maxReasonLength,
        counter: true,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        SheetButton(
          label: 'Cancel',
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(context),
        ),
        SheetButton(
          label: widget.action,
          // A ban is the destructive one; a warning the plain confirmation.
          tone: widget.required
              ? SheetButtonTone.primary
              : SheetButtonTone.danger,
          onPressed: widget.required && empty
              ? null
              : () => Navigator.pop(context, _reason.text.trim()),
        ),
      ],
    );
  }
}
