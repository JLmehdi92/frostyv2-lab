import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frosty/models/community_highlights.dart';
import 'package:frosty/screens/channel/community_highlights/highlight_reducers.dart';
import 'package:frosty/screens/channel/community_highlights/raid_text.dart';
import 'package:frosty/screens/channel/community_highlights/widgets/highlight_countdown.dart';
import 'package:frosty/screens/channel/community_highlights/widgets/raid_avatar.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/celebrations/onset_rocket.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';
import 'package:frosty/widgets/sheet/sheet_glyph.dart';

/// Where an outgoing raid stands on the card.
enum RaidCardPhase {
  /// Counting down: the track, "Go now" and "Stay here".
  counting,

  /// The viewer is on their way (this screen is leaving with the raid).
  leaving,

  /// The viewer chose to stay; the raid leaves without them.
  staying,

  /// It left while the viewer stayed here.
  gone,

  /// Called off before it left.
  cancelled,
}

/// The phase of [raid] on screen.
RaidCardPhase raidCardPhase(
  RaidState raid, {
  required bool staying,
  required bool leaving,
}) {
  if (raid.cancelled) return RaidCardPhase.cancelled;
  if (leaving) return RaidCardPhase.leaving;
  if (raid.gone) return RaidCardPhase.gone;
  if (staying) return RaidCardPhase.staying;
  return RaidCardPhase.counting;
}

/// How far the raid is from leaving, 0 at its start and 1 when it leaves.
double raidProgress(OutgoingRaid raid, Duration left) {
  final total = raid.forceRaidNowSeconds;
  if (total <= 0) return 1;
  return (1 - left.inMilliseconds / (total * 1000)).clamp(0.0, 1.0);
}

/// This channel raids another (board Raids): a card pinned above chat with
/// the RAID eyebrow, "X is raiding Y", the viewers, a countdown ring, a
/// dotted track from this channel to the target that the ONSET rocket
/// crosses as the time runs out, and "Go now" / "Stay here". Staying,
/// leaving, a raid gone without the viewer and a raid called off each
/// collapse it to one line; "Watch" stays at hand until it goes away.
///
/// [compact] (side chat, under a hype train, typing) leaves the track out;
/// a tap on the card then opens the details ([HighlightCardContext]).
class RaidCard extends StatelessWidget {
  const RaidCard({
    super.key,
    required this.raid,
    required this.sourceName,
    required this.onWatch,
    required this.now,
    this.sourceLogin,
    this.onStay,
    this.onDismiss,
    this.onOpen,
    this.staying = false,
    this.leaving = false,
    this.compact = false,
  });

  final RaidState raid;

  /// The raiding channel (the one being watched).
  final String sourceName;
  final String? sourceLogin;

  /// Takes the viewer to the target ("Go now", "Watch").
  final VoidCallback onWatch;

  /// Stays here when it leaves (null: the viewer is not taken along).
  final VoidCallback? onStay;
  final VoidCallback? onDismiss;

  /// A tap on the card (compact: opens the details).
  final VoidCallback? onOpen;
  final bool staying;
  final bool leaving;
  final bool compact;

  /// Twitch's current time, for the countdown.
  final DateTime Function() now;

  static const cardKey = ValueKey('raid-card');
  static const trackKey = ValueKey('raid-card-track');
  static const ringKey = ValueKey('raid-card-ring');
  static const rocketKey = ValueKey('raid-card-rocket');
  static const hitKey = ValueKey('raid-card-hit');

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final target = raid.raid;
    final phase = raidCardPhase(raid, staying: staying, leaving: leaving);
    final viewers = raidViewers(target.viewerCount);
    final duration = motionDuration(context, const Duration(milliseconds: 280));

    final Widget content = switch (phase) {
      RaidCardPhase.counting || RaidCardPhase.leaving => _Counting(
        card: this,
        phase: phase,
        viewers: viewers,
      ),
      RaidCardPhase.staying => _Line(
        glyph: SheetGlyphKind.check,
        glyphColor: colors.text,
        title: 'You stay on $sourceName',
        detail: 'The raid goes to ${target.targetDisplayName} without you',
        action: _watchButton(context, target),
        onDismiss: onDismiss,
      ),
      RaidCardPhase.gone => _Line(
        rocket: true,
        title: 'The raid left for ${target.targetDisplayName}',
        detail: '$viewers went along',
        action: _watchButton(context, target),
        onDismiss: onDismiss,
      ),
      RaidCardPhase.cancelled => _Line(
        glyph: SheetGlyphKind.close,
        glyphColor: colors.secondary,
        title: 'Raid cancelled',
        detail: '$sourceName stays live',
      ),
    };

    final semantics = switch (phase) {
      RaidCardPhase.counting =>
        '$sourceName is raiding ${target.targetDisplayName} with $viewers',
      RaidCardPhase.leaving => 'Heading to ${target.targetDisplayName}',
      RaidCardPhase.staying =>
        'You stay on $sourceName. The raid goes to '
            '${target.targetDisplayName} without you',
      RaidCardPhase.gone => 'The raid to ${target.targetDisplayName} has left',
      RaidCardPhase.cancelled => 'Raid cancelled',
    };

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        container: true,
        liveRegion: true,
        label: semantics,
        child: Container(
          key: cardKey,
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const [Color(0xFF161814), Color(0xFF121212)]
                  : [colors.sheet, colors.sheet],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: accent.withValues(alpha: 0.26),
                width: FrostyTokens.hairlineWidth,
              ),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AnimatedSize(
                  duration: duration,
                  curve: FrostyMotion.standard,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: duration,
                    switchInCurve: FrostyMotion.standard,
                    transitionBuilder: (child, animation) =>
                        _FadeUp(animation: animation, child: child),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, ?current],
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(
                        phase == RaidCardPhase.leaving
                            ? RaidCardPhase.counting
                            : phase,
                      ),
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _watchButton(BuildContext context, OutgoingRaid target) {
    final colors = SheetColors.of(context);
    return TextButton(
      onPressed: onWatch,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: colors.text,
        backgroundColor: colors.raised,
        shape: const StadiumBorder(),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontFamily: FrostyTokens.bodyFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text('Watch', semanticsLabel: 'Watch ${target.targetDisplayName}'),
    );
  }
}

/// The counting card: header and ring, the track (not compact), and the
/// two buttons, or "Heading out…" once the viewer is on their way.
class _Counting extends StatelessWidget {
  const _Counting({
    required this.card,
    required this.phase,
    required this.viewers,
  });

  final RaidCard card;
  final RaidCardPhase phase;
  final String viewers;

  @override
  Widget build(BuildContext context) {
    final target = card.raid.raid;
    final goAt = target.goAt;
    final leaving = phase == RaidCardPhase.leaving;
    Widget body(Duration? left) {
      final progress = leaving
          ? 1.0
          : left == null
          ? 0.0
          : raidProgress(target, left);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          _Header(card: card, viewers: viewers, left: left, progress: progress),
          if (!card.compact)
            _Track(card: card, progress: progress, hit: leaving),
          if (leaving) const _HeadingOut() else _Buttons(card: card),
        ],
      );
    }

    if (goAt == null || leaving) return body(null);
    return HighlightCountdown(
      deadline: goAt,
      now: card.now,
      builder: (context, left) => body(left),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.card,
    required this.viewers,
    required this.left,
    required this.progress,
  });

  final RaidCard card;
  final String viewers;
  final Duration? left;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    final target = card.raid.raid;
    final left = this.left;
    return Row(
      spacing: 10,
      children: [
        Expanded(
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  'RAID',
                  style: TextStyle(
                    fontFamily: FrostyTokens.bodyFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.26,
                    height: 1.2,
                    color: accent,
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${card.sourceName} is raiding '),
                      TextSpan(
                        text: target.targetDisplayName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: FrostyTokens.bodyFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: colors.text,
                  ),
                ),
                Text(
                  card.onStay == null
                      ? viewers
                      : '$viewers · you go along automatically',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SheetText.tabular(
                    TextStyle(
                      fontFamily: FrostyTokens.bodyFamily,
                      fontSize: 12,
                      height: 1.3,
                      color: colors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (left != null)
          Semantics(
            label: 'Leaves in ${formatTimeLeft(left)}',
            child: _Ring(progress: progress, label: formatTimeLeft(left)),
          ),
        if (card.onDismiss case final onDismiss?)
          _HideButton(onPressed: onDismiss),
      ],
    );
  }
}

/// The 44 dp countdown ring: it fills as the time runs out.
class _Ring extends StatelessWidget {
  const _Ring({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _Smooth(
      value: progress,
      builder: (context, value) => CustomPaint(
        key: RaidCard.ringKey,
        painter: _RingPainter(
          progress: value,
          track: dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
          color: accent,
        ),
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                label,
                style: SheetText.tabular(
                  TextStyle(
                    fontFamily: FrostyTokens.bodyFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Board: r 18 in a 44 box, 2.5 stroke, from the top.
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 18);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.color != color;
}

/// From this channel to the target: a dotted line, the lime progress, and
/// the rocket riding it. When the viewer goes, the target's picture pulses
/// and a burst of dots goes off around it ([hit]).
class _Track extends StatelessWidget {
  const _Track({required this.card, required this.progress, required this.hit});

  final RaidCard card;
  final double progress;
  final bool hit;

  static const _height = 32.0;
  static const _avatar = 28.0;
  static const _inset = 36.0;
  static const _rocket = 24.0;

  @override
  Widget build(BuildContext context) {
    final accent = SheetColors.accentOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final target = card.raid.raid;
    final reduceMotion = reduceMotionOf(context);
    return ExcludeSemantics(
      child: SizedBox(
        key: RaidCard.trackKey,
        height: _height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 2,
              child: RaidAvatar(name: card.sourceName, login: card.sourceLogin),
            ),
            if (hit && !reduceMotion)
              const Positioned(right: 0, top: 2, child: _Hit(size: _avatar)),
            Positioned(
              right: 0,
              top: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: accent, spreadRadius: 1.5)],
                ),
                child: RaidAvatar(
                  name: target.targetDisplayName,
                  url: target.targetProfileImage,
                  login: target.targetLogin,
                ),
              ),
            ),
            Positioned(
              left: _inset,
              right: _inset,
              top: 0,
              bottom: 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return _Smooth(
                    value: progress,
                    builder: (context, value) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 15,
                          height: 2,
                          child: CustomPaint(
                            painter: _DotsPainter(
                              color: dark
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : Colors.black.withValues(alpha: 0.16),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 15,
                          height: 2,
                          width: width * value,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(1),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          key: RaidCard.rocketKey,
                          left: math.max(0.0, width - _rocket) * value,
                          top: 4,
                          child: const OnsetRocket(
                            angle: math.pi / 4,
                            flicker: true,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final radius = Radius.circular(size.height / 2);
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, math.min(4, size.width - x), size.height),
          radius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

/// Eases [value] to each new value (a short glide every countdown tick;
/// none under reduce motion).
class _Smooth extends StatelessWidget {
  const _Smooth({required this.value, required this.builder});

  final double value;
  final Widget Function(BuildContext context, double value) builder;

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return builder(context, value);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 300),
      curve: FrostyMotion.standard,
      builder: (context, value, _) => builder(context, value),
    );
  }
}

/// The target's picture hit: a lime ring spreading out (700 ms) and eight
/// dots bursting 26 dp away (560 ms), once.
class _Hit extends StatelessWidget {
  const _Hit({required this.size});

  final double size;

  static const _dots = [
    Color(0xFFC8FF3D),
    Color(0xFF3DDBA6),
    Color(0xFFC8FF3D),
    Color(0xFFF5F5F5),
    Color(0xFF3DDBA6),
    Color(0xFFC8FF3D),
    Color(0xFFF5F5F5),
    Color(0xFF3DDBA6),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = SheetColors.accentOf(context);
    return TweenAnimationBuilder<double>(
      key: RaidCard.hitKey,
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: FrostyMotion.standard,
      builder: (context, t, _) {
        final burst = (t * 700 / 560).clamp(0.0, 1.0);
        return SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.75 * (1 - t)),
                      spreadRadius: 14 * t,
                    ),
                  ],
                ),
                child: SizedBox.square(dimension: size),
              ),
              for (var i = 0; i < _dots.length; i++)
                Transform.translate(
                  offset: Offset.fromDirection(
                    -math.pi / 2 + i * math.pi / 4,
                    26 * burst,
                  ),
                  child: Opacity(
                    opacity: 1 - burst,
                    child: Container(
                      width: 5 * (1 - 0.8 * burst),
                      height: 5 * (1 - 0.8 * burst),
                      decoration: BoxDecoration(
                        color: _dots[i],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({required this.card});

  final RaidCard card;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    final target = card.raid.raid;
    final style = TextButton.styleFrom(
      minimumSize: const Size(0, 44),
      shape: const StadiumBorder(),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
    final go = TextButton(
      onPressed: card.onWatch,
      style: style.copyWith(
        backgroundColor: WidgetStatePropertyAll(accent),
        foregroundColor: WidgetStatePropertyAll(
          SheetColors.onAccentOf(context),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: FrostyTokens.bodyFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Text(
        'Go now',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        semanticsLabel: 'Go to ${target.targetDisplayName} now',
      ),
    );
    final onStay = card.onStay;
    if (onStay == null) return SizedBox(width: double.infinity, child: go);
    return Row(
      spacing: 8,
      children: [
        Expanded(child: go),
        Expanded(
          child: TextButton(
            onPressed: onStay,
            style: style.copyWith(
              backgroundColor: WidgetStatePropertyAll(colors.raised),
              foregroundColor: WidgetStatePropertyAll(colors.text),
              side: WidgetStatePropertyAll(
                BorderSide(
                  color: colors.ringStrong,
                  width: FrostyTokens.hairlineWidth,
                ),
              ),
              textStyle: const WidgetStatePropertyAll(
                TextStyle(
                  fontFamily: FrostyTokens.bodyFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            child: const Text(
              'Stay here',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeadingOut extends StatelessWidget {
  const _HeadingOut();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      // The card's label says it.
      child: ExcludeSemantics(
        child: Center(
          child: Text(
            'Heading out…',
            style: TextStyle(
              fontFamily: FrostyTokens.bodyFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SheetColors.accentOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// A collapsed state: a 32 dp round glyph (or the rocket), two lines, and
/// [action].
class _Line extends StatelessWidget {
  const _Line({
    required this.title,
    required this.detail,
    this.glyph,
    this.glyphColor,
    this.rocket = false,
    this.action,
    this.onDismiss,
  });

  final String title;
  final String detail;
  final SheetGlyphKind? glyph;
  final Color? glyphColor;
  final bool rocket;
  final Widget? action;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Row(
      spacing: 10,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.raised,
              shape: BoxShape.circle,
            ),
            child: rocket
                ? const OnsetRocket(size: 20)
                : SheetGlyph(
                    glyph!,
                    size: glyph == SheetGlyphKind.close ? 14 : 16,
                    strokeWidth: 2.4,
                    color: glyphColor ?? colors.text,
                  ),
          ),
        ),
        Expanded(
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: FrostyTokens.bodyFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: colors.text,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: FrostyTokens.bodyFamily,
                    fontSize: 12,
                    height: 1.3,
                    color: colors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        ?action,
        if (onDismiss != null) _HideButton(onPressed: onDismiss!),
      ],
    );
  }
}

/// The card's close button (it stays closable in every state but the
/// short "cancelled" one).
class _HideButton extends StatelessWidget {
  const _HideButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Hide',
      style: IconButton.styleFrom(
        fixedSize: const Size(32, 44),
        minimumSize: const Size(32, 44),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: SheetGlyph(
        SheetGlyphKind.close,
        size: 14,
        strokeWidth: 2.2,
        color: SheetColors.of(context).tertiary,
      ),
      onPressed: onPressed,
    );
  }
}

/// The board's `fadeup`: in from 6 dp below, fading in; out by fading.
class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = reduceMotionOf(context);
    final fade = FadeTransition(opacity: animation, child: child);
    if (reduceMotion) return fade;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          animation.status == AnimationStatus.reverse
              ? 0
              : 6 * (1 - animation.value),
        ),
        child: child,
      ),
      child: fade,
    );
  }
}
