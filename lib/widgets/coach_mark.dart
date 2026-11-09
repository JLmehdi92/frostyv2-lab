import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/settings_lookup.dart';
import 'package:onset/widgets/new_feature_pill.dart';

class CoachMark extends StatefulWidget {
  const CoachMark({
    super.key,
    required this.feature,
    required this.message,
    required this.child,
    this.after,
    this.settings,
    this.delay = const Duration(milliseconds: 600),
  });

  final NewFeature feature;
  final String message;
  final Widget child;
  final NewFeature? after;
  final SettingsStore? settings;
  final Duration delay;

  @override
  State<CoachMark> createState() => _CoachMarkState();
}

class _CoachMarkState extends State<CoachMark> {
  OverlayEntry? _entry;
  var _scheduled = false;
  Timer? _timer;

  SettingsStore? get _settings => widget.settings ?? maybeSettings(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    final settings = _settings;
    if (settings == null || !settings.isNewFeature(widget.feature.name)) {
      return;
    }
    final after = widget.after;
    if (after != null && settings.isNewFeature(after.name)) return;
    _scheduled = true;
    _timer = Timer(widget.delay, _show);
  }

  void _show() {
    if (!mounted || _entry != null) return;
    final overlay = Overlay.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null || !box.hasSize) return;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final target =
        box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
    final entry = OverlayEntry(
      builder: (_) => _CoachBubble(
        target: target,
        message: widget.message,
        onDismiss: _dismiss,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  void _dismiss() {
    _settings?.markFeatureSeen(widget.feature.name);
    _removeEntry();
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _removeEntry();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _CoachBubble extends StatelessWidget {
  const _CoachBubble({
    required this.target,
    required this.message,
    required this.onDismiss,
  });

  static const width = 240.0;

  final Rect target;
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screen = MediaQuery.sizeOf(context);
    final bubbleWidth = width.clamp(0.0, screen.width - 32);
    final below = target.center.dy < screen.height / 2;
    final left = (target.center.dx - bubbleWidth / 2).clamp(
      16.0,
      screen.width - bubbleWidth - 16,
    );
    return Positioned(
      width: bubbleWidth,
      left: left,
      top: below ? target.bottom + 6 : null,
      bottom: below ? null : screen.height - target.top + 6,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
        ),
        child: Semantics(
          liveRegion: true,
          container: true,
          child: Material(
            key: const ValueKey('coach-mark'),
            color: OnsetTokens.accent,
            borderRadius: BorderRadius.circular(14),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.newFeaturePill.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: OnsetTokens.backgroundDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontFamily: OnsetTokens.bodyFamily,
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: OnsetTokens.backgroundDark,
                      ),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: onDismiss,
                      style: TextButton.styleFrom(
                        foregroundColor: OnsetTokens.backgroundDark,
                        textStyle: const TextStyle(
                          fontFamily: OnsetTokens.bodyFamily,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(l.coachMarkGotIt),
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
