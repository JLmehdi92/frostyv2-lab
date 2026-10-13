import 'package:flutter/material.dart';

/// The frame of a community highlight card: icon, title, a status line,
/// close and expand controls, and the [body] when [expanded].
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
    this.accent,
    this.headline,
    this.body,
    this.onDismiss,
    this.footer,
  });

  final IconData icon;

  /// "Poll", "Prediction"…
  final String title;

  /// "0:42 left", "Final results"…
  final Widget status;
  final String semanticsLabel;
  final bool expanded;
  final VoidCallback onToggle;
  final Color? accent;

  /// The poll question, the pinned message… (always shown).
  final Widget? headline;
  final Widget? body;
  final VoidCallback? onDismiss;

  /// Shown below, expanded or not (the raid's Watch button).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final muted = scheme.onSurfaceVariant;
    final body = this.body;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        container: true,
        button: true,
        expanded: body == null ? null : expanded,
        label: semanticsLabel,
        onTap: onToggle,
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          icon,
                          size: 18,
                          color: accent ?? scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ExcludeSemantics(
                        child: Text(
                          title,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: textTheme.labelMedium?.copyWith(color: muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: Semantics(liveRegion: true, child: status),
                        ),
                      ),
                      if (body != null)
                        ExcludeSemantics(
                          child: Icon(
                            expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: muted,
                          ),
                        ),
                      if (onDismiss != null)
                        IconButton(
                          tooltip: 'Hide',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: muted,
                          ),
                          onPressed: onDismiss,
                        ),
                    ],
                  ),
                  if (headline case final headline?)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 8),
                      child: ExcludeSemantics(child: headline),
                    ),
                  if (expanded && body != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 8),
                      child: ExcludeSemantics(child: body),
                    ),
                  if (footer case final footer?)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
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

/// A labelled bar: a fill of [fraction] behind [label] and [trailing].
class HighlightBar extends StatelessWidget {
  const HighlightBar({
    super.key,
    required this.fraction,
    required this.color,
    required this.label,
    required this.trailing,
    this.bold = false,
  });

  final double fraction;
  final Color color;
  final String label;
  final String trailing;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: fraction.clamp(0.0, 1.0)),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: value,
                  heightFactor: 1,
                  child: ColoredBox(color: color.withValues(alpha: 0.35)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  trailing,
                  style: style?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
