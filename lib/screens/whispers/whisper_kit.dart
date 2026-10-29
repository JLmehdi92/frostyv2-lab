import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/stores/whisper_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/press_scale.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/state_glyph.dart';
import 'package:frosty/widgets/state_views.dart';
import 'package:intl/intl.dart';

/// The colours of the whispers (boards Messages, MessagesTablette), dark
/// from the boards and their light counterparts.
@immutable
class WhisperColors {
  const WhisperColors({
    required this.text,
    required this.body,
    required this.secondary,
    required this.tertiary,
    required this.pane,
    required this.paneRing,
    required this.card,
    required this.field,
    required this.fieldRing,
    required this.raised,
    required this.hairline,
    required this.selected,
    required this.mineFill,
    required this.mineText,
    required this.mineTime,
    required this.theirFill,
    required this.theirText,
    required this.theirTime,
    required this.shadow,
  });

  final Color text;
  final Color body;
  final Color secondary;
  final Color tertiary;

  /// The tablet's conversation pane.
  final Color pane;
  final Color paneRing;

  /// A card (the status note, Activity's whispers column).
  final Color card;
  final Color field;
  final Color fieldRing;
  final Color raised;
  final Color hairline;

  /// The conversation on screen in the tablet's list.
  final Color selected;
  final Color mineFill;
  final Color mineText;
  final Color mineTime;
  final Color theirFill;
  final Color theirText;
  final Color theirTime;

  /// Under the conversation sliding over the list.
  final Color shadow;

  static const dark = WhisperColors(
    text: FrostyTokens.textPrimaryDark,
    body: FrostyTokens.textBodyDark,
    secondary: FrostyTokens.textSecondaryDark,
    tertiary: FrostyTokens.textTertiaryDark,
    pane: Color(0xFF111111),
    paneRing: Color(0x14FFFFFF),
    card: FrostyTokens.surfaceDark,
    field: FrostyTokens.surfaceDark,
    fieldRing: FrostyTokens.hairlineRaisedDark,
    raised: FrostyTokens.raisedDark,
    hairline: Color(0x12FFFFFF),
    selected: Color(0xFF1A1A1A),
    mineFill: FrostyTokens.textPrimaryDark,
    mineText: FrostyTokens.backgroundDark,
    mineTime: Color(0xFF5E5E5E),
    theirFill: FrostyTokens.raisedDark,
    theirText: FrostyTokens.textPrimaryDark,
    theirTime: FrostyTokens.textSecondaryDark,
    shadow: Color(0x8C000000),
  );

  static const light = WhisperColors(
    text: Color(0xFF0A0A0A),
    body: Color(0xFF3A3A3A),
    secondary: Color(0xFF6B6B6B),
    tertiary: Color(0xFF6B6B6B),
    pane: FrostyTokens.surfaceLight,
    paneRing: Color(0x14000000),
    card: FrostyTokens.surfaceLight,
    field: FrostyTokens.surfaceLight,
    fieldRing: Color(0x1F000000),
    raised: Color(0xFFF0F0F0),
    hairline: Color(0x14000000),
    selected: Color(0xFFEFEFEF),
    mineFill: Color(0xFF0A0A0A),
    mineText: FrostyTokens.textPrimaryDark,
    mineTime: FrostyTokens.textSecondaryDark,
    theirFill: Color(0xFFEDEDED),
    theirText: Color(0xFF0A0A0A),
    theirTime: Color(0xFF6B6B6B),
    shadow: Color(0x29000000),
  );

  static WhisperColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// When a whisper was sent, as the conversations show it ("9:41 PM").
String whisperTime(DateTime at) => DateFormat.jm().format(at.toLocal());

/// An unread count: the accent pill, 11/800 digits.
class WhisperCountPill extends StatelessWidget {
  const WhisperCountPill({super.key, required this.count, this.size = 20});

  final int count;

  /// 20 in a row, 18 next to a title.
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = context.frostyColors.live;
    // The pill grows with the text size, like the digits in it.
    final height = MediaQuery.textScalerOf(context).scale(size);
    return Semantics(
      label: '$count unread',
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minWidth: height),
        height: height,
        padding: EdgeInsets.symmetric(horizontal: size > 18 ? 6 : 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Text(
          '$count',
          maxLines: 1,
          style: FrostyType.tabular(
            TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w800,
              color: onFillColor(accent),
            ),
          ),
        ),
      ),
    );
  }
}

/// A conversation in a list (boards Messages, MessagesTablette, and
/// Activity's whispers): the person's picture, name, when, the last
/// whisper (a "You" arrow when it was the viewer's) and the unread count.
class WhisperThreadRow extends StatelessWidget {
  const WhisperThreadRow({
    super.key,
    required this.thread,
    required this.onTap,
    this.selected = false,
    this.compact = false,
    this.rounded = false,
  });

  final WhisperThread thread;
  final VoidCallback onTap;

  /// On screen in the tablet's pane: tinted, with the accent bar.
  final bool selected;

  /// Activity's column on a tablet: 64 dp, a 44 dp picture.
  final bool compact;

  /// The tablet's rows have rounded corners.
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final colors = WhisperColors.of(context);
    final accent = context.frostyColors.live;
    final avatar = compact ? 44.0 : 48.0;
    return Observer(
      builder: (context) {
        final last = thread.whispers.lastOrNull;
        final unread = thread.unread;
        final bold = unread > 0;
        final preview = last == null ? '' : whisperPreview(last.text);
        final time = last == null ? '' : whisperTime(last.sentAt);
        return Semantics(
          button: true,
          selected: selected,
          child: PressScale(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                splashFactory: NoSplash.splashFactory,
                borderRadius: rounded ? BorderRadius.circular(14) : null,
                child: _SelectedBar(
                  selected: selected,
                  color: accent,
                  radius: rounded ? 14 : 0,
                  child: Container(
                    constraints: BoxConstraints(minHeight: compact ? 64 : 72),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 12 : 16,
                      vertical: compact ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? colors.selected : null,
                      borderRadius: rounded ? BorderRadius.circular(14) : null,
                    ),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: ProfilePicture(
                            userLogin: thread.login,
                            radius: avatar / 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            spacing: 4,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Expanded(
                                    child: Text(
                                      whisperPreview(thread.displayName),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: bold
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        letterSpacing: -0.15,
                                        color: colors.text,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    time,
                                    style: FrostyType.tabular(
                                      TextStyle(
                                        fontSize: 12,
                                        color: bold
                                            ? colors.text
                                            : colors.tertiary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  // Yours carry an arrow, not a "You:" a
                                  // whisper could fake.
                                  if (last?.mine ?? false) ...[
                                    Semantics(
                                      label: 'You',
                                      child: StateGlyph(
                                        StateGlyphKind.reply,
                                        color: colors.tertiary,
                                        size: 15,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: Text(
                                      preview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: bold
                                            ? colors.text
                                            : colors.secondary,
                                      ),
                                    ),
                                  ),
                                  if (unread > 0) ...[
                                    const SizedBox(width: 6),
                                    WhisperCountPill(count: unread),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The board's inset accent bar on the left edge of the conversation on
/// screen.
class _SelectedBar extends StatelessWidget {
  const _SelectedBar({
    required this.selected,
    required this.color,
    required this.radius,
    required this.child,
  });

  final bool selected;
  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!selected) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          child,
          Positioned(
            key: const ValueKey('whisper-selected-bar'),
            left: 0,
            top: 0,
            bottom: 0,
            width: 2.5,
            child: ColoredBox(color: color),
          ),
        ],
      ),
    );
  }
}

/// Why whispers may not arrive, when they may not: a card above the
/// conversations (a turning ring while it reconnects), that folds away
/// once they do.
class WhisperStatusNote extends StatelessWidget {
  const WhisperStatusNote({
    super.key,
    required this.store,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  final WhisperStore store;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final colors = WhisperColors.of(context);
    final duration = motionDuration(context, const Duration(milliseconds: 300));
    return Observer(
      builder: (context) {
        final status = store.status;
        final hint = whisperStatusHint(status);
        Widget? card;
        if (hint != null) {
          final Widget mark = status == WhisperStatus.interrupted
              ? SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.body,
                    backgroundColor: colors.hairline,
                  ),
                )
              : StateGlyph(
                  status == WhisperStatus.refused
                      ? StateGlyphKind.alert
                      : StateGlyphKind.offline,
                  color: status == WhisperStatus.refused
                      ? FrostyTokens.danger
                      : colors.secondary,
                  size: 16,
                );
          card = Padding(
            key: ValueKey(status),
            padding: margin,
            child: Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.paneRing,
                    width: FrostyTokens.hairlineWidth,
                  ),
                ),
                child: Row(
                  children: [
                    mark,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hint,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: colors.body,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        // The rows below follow the card in and out (no jump).
        return AnimatedSize(
          duration: duration,
          curve: FrostyMotion.standard,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: duration,
            child: card ?? const SizedBox(width: double.infinity),
          ),
        );
      },
    );
  }
}

/// What to tell about [status] above the conversations, or null.
String? whisperStatusHint(WhisperStatus status) => switch (status) {
  WhisperStatus.refused =>
    'Twitch refused to send your whispers to this app. Log out and log in '
        'again to allow them.',
  WhisperStatus.interrupted => 'Reconnecting… whispers will arrive again soon.',
  WhisperStatus.unavailable =>
    "Twitch isn't sending whispers to this app right now. It tries again "
        'when you come back to the app.',
  WhisperStatus.off => 'Log in to get whispers.',
  WhisperStatus.connecting || WhisperStatus.listening => null,
};
