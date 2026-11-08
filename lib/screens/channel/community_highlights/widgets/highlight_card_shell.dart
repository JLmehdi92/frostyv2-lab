import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

/// The frame of a community highlight card: a
/// 16 dp card, the kind's tile, its title and a status line, the expand
/// chevron and close, the headline, and the [body] when [expanded]. A tap
/// anywhere on it expands or collapses it.
///
/// One semantics node per card ([semanticsLabel]); only [status] is a live
/// region, so screen readers hear state changes, never vote ticks.
class HighlightCardShell extends StatelessWidget {
  const HighlightCardShell({
    super.key,
    required this.icon,
    required this.title,
    required this.status,
    required this.semanticsLabel,
    required this.expanded,
    required this.onToggle,
    this.glyph,
    this.accent,
    this.tint,
    this.headline,
    this.body,
    this.onDismiss,
    this.dismissTooltip,
    this.footer,
    this.interactiveBody = false,
  });

  final IconData icon;

  /// The glyph for the kind, drawn instead of [icon].
  final SheetGlyphKind? glyph;

  /// "Poll", "Prediction"…
  final String title;

  /// "0:42 left", "Final results"…
  final Widget status;
  final String semanticsLabel;
  final bool expanded;
  final VoidCallback onToggle;

  /// The icon's colour, and its tile's ([tint]): a prediction's blue.
  final Color? accent;
  final Color? tint;

  /// The poll question, the pinned message… (always shown).
  final Widget? headline;
  final Widget? body;
  final VoidCallback? onDismiss;

  final String? dismissTooltip;

  /// Shown below, expanded or not (the raid's Watch button).
  final Widget? footer;
  final bool interactiveBody;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final body = this.body;
    final duration = motionDuration(context, const Duration(milliseconds: 260));
    final iconColor = accent ?? colors.text;
    final tile = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: tint ?? colors.raised,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: glyph != null
          ? SheetGlyph(glyph!, size: 15, strokeWidth: 2, color: iconColor)
          : Icon(icon, size: 15, color: iconColor),
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        container: true,
        button: true,
        expanded: body == null ? null : expanded,
        label: semanticsLabel,
        onTap: onToggle,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
                offset: const Offset(0, 10),
                blurRadius: 24,
              ),
            ],
          ),
          child: Material(
            color: colors.sheet,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colors.ring,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onToggle,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: [
                        ExcludeSemantics(child: tile),
                        const SizedBox(width: 9),
                        ExcludeSemantics(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: OnsetTokens.bodyFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: DefaultTextStyle.merge(
                            style: SheetText.tabular(
                              TextStyle(
                                fontFamily: OnsetTokens.bodyFamily,
                                fontSize: 12.5,
                                color: colors.secondary,
                              ),
                            ),
                            // Two lines rather than losing a status's
                            // words (« Annulée · points remboursés »).
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            child: Semantics(liveRegion: true, child: status),
                          ),
                        ),
                        // The chevron says what a tap on the card does.
                        if (body != null)
                          ExcludeSemantics(
                            child: SizedBox(
                              width: 40,
                              height: 44,
                              child: Center(
                                child: AnimatedRotation(
                                  turns: expanded ? 0.5 : 0,
                                  duration: duration,
                                  curve: OnsetMotion.standard,
                                  child: SheetGlyph(
                                    SheetGlyphKind.chevronDown,
                                    strokeWidth: 2,
                                    color: colors.secondary,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 44),
                        if (onDismiss != null)
                          IconButton(
                            tooltip: dismissTooltip ?? context.l10n.commonHide,
                            style: IconButton.styleFrom(
                              fixedSize: const Size(40, 44),
                              minimumSize: const Size(40, 44),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: SheetGlyph(
                              SheetGlyphKind.close,
                              size: 18,
                              strokeWidth: 2,
                              color: colors.secondary,
                            ),
                            onPressed: onDismiss,
                          ),
                      ],
                    ),
                  ),
                  if (headline case final headline?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: ExcludeSemantics(
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            fontFamily: OnsetTokens.bodyFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            color: colors.text,
                          ),
                          child: headline,
                        ),
                      ),
                    ),
                  AnimatedSize(
                    duration: duration,
                    curve: OnsetMotion.standard,
                    alignment: Alignment.topCenter,
                    child: expanded && body != null
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                            child: ExcludeSemantics(
                              excluding: !interactiveBody,
                              child: body,
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  if (footer case final footer?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                      child: footer,
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

/// A labelled bar: a fill of [fraction] in
/// [fill] behind [label] and [trailing], 36 dp, 10 dp corners. [leading]
/// marks a winner.
class HighlightBar extends StatelessWidget {
  const HighlightBar({
    super.key,
    required this.fraction,
    required this.fill,
    required this.label,
    required this.trailing,
    this.bold = false,
    this.leading,
  });

  final double fraction;
  final Color fill;
  final String label;
  final String trailing;
  final bool bold;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final style = TextStyle(
      fontFamily: OnsetTokens.bodyFamily,
      fontSize: 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: colors.text,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: fraction.clamp(0.0, 1.0)),
                duration: motionDuration(
                  context,
                  const Duration(milliseconds: 420),
                ),
                curve: OnsetMotion.standard,
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: value,
                  heightFactor: 1,
                  child: ColoredBox(color: fill),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              spacing: 8,
              children: [
                ?leading,
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
                Text(trailing, style: SheetText.tabular(style)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
