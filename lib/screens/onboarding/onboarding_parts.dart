import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/motion/haptics.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/press_scale.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';
import 'package:frosty/widgets/sheet/svg_path.dart';

/// The colours of the first launch (boards Onboarding, OnboardingTablette,
/// OnboardingEtapes). The onboarding is always drawn in the intro's black,
/// whatever theme is picked in its Setup step: it continues the launch
/// intro, and only the Setup preview follows the theme.
abstract final class OnboardingColors {
  static const ground = FrostyTokens.backgroundDark;
  static const surface = FrostyTokens.surfaceDark;
  static const raised = FrostyTokens.raisedDark;

  /// The Twitch page's panel.
  static const web = Color(0xFF111111);

  /// A dialog's inner tile and an "off" switch track.
  static const control = Color(0xFF2A2A2A);
  static const handle = Color(0xFF3A3A3A);

  /// A card's 0.5 dp ring (white 8 %).
  static const ring = Color(0x14FFFFFF);

  /// A row divider inside a card (white 6 %).
  static const divider = Color(0x0FFFFFFF);

  /// A pill's ring (white 12 %), a number's ring (white 16 %).
  static const ringStrong = Color(0x1FFFFFFF);
  static const ringNumber = Color(0x29FFFFFF);

  static const text = FrostyTokens.textPrimaryDark;
  static const body = FrostyTokens.textBodyDark;
  static const secondary = FrostyTokens.textSecondaryDark;
  static const tertiary = FrostyTokens.textTertiaryDark;
  static const knobOff = FrostyTokens.textTertiaryDark;

  /// A progress segment already passed, one still to come.
  static const segmentDone = Color(0x8CF5F5F5);
  static const segmentTodo = Color(0x24FFFFFF);

  /// The scrim under the help and the accent picker.
  static const scrim = Color(0x9E000000);
}

/// What reads on [accent]: near-black on a light accent, white on a dark
/// one (whichever contrasts more, as the boards compute it).
Color onAccentFor(Color accent) {
  final luminance = accent.computeLuminance();
  final onBlack = (luminance + 0.05) / 0.0533;
  final onWhite = 1.05 / (luminance + 0.05);
  return onBlack >= onWhite ? FrostyTokens.backgroundDark : Colors.white;
}

/// The onboarding's type: titles 34 / 40 (tablet) at 800, the text under
/// them 15 / 16 at 1.5.
abstract final class OnboardingType {
  static TextStyle title({required bool tablet}) {
    final size = tablet ? 40.0 : 34.0;
    return TextStyle(
      fontFamily: FrostyTokens.displayFamily,
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.035 * size,
      height: 1.08,
      color: OnboardingColors.text,
    );
  }

  static TextStyle lead({required bool tablet}) => TextStyle(
    fontSize: tablet ? 16 : 15,
    height: 1.5,
    color: OnboardingColors.secondary,
  );

  static const eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.14 * 11,
    color: OnboardingColors.secondary,
  );

  static const rowTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: OnboardingColors.text,
  );

  static const rowDetail = TextStyle(
    fontSize: 12.5,
    height: 1.45,
    color: OnboardingColors.secondary,
  );
}

/// A card of the boards: #141414, 16 dp corners, the 0.5 dp ring.
BoxDecoration onboardingCard({double radius = 16}) => BoxDecoration(
  color: OnboardingColors.surface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(
    color: OnboardingColors.ring,
    width: FrostyTokens.hairlineWidth,
  ),
);

/// The onboarding's own icons, from the boards' 24 × 24 strokes (round caps
/// and joins).
enum OnboardingGlyphKind {
  arrowRight,
  login,
  chat,
  heart,
  smile,
  send,
  shield,
  scissors,
  userX,
  lock,
  help,
  chevronLeft,
  chevronRight,
  user,
  check,
  dice,
  refresh,
}

const Map<OnboardingGlyphKind, List<String>> _glyphs = {
  OnboardingGlyphKind.arrowRight: ['M5 12h14', 'M12 5l7 7-7 7'],
  OnboardingGlyphKind.login: [
    'M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4',
    'M10 17l5-5-5-5',
    'M15 12H3',
  ],
  OnboardingGlyphKind.chat: [
    'M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z',
  ],
  OnboardingGlyphKind.heart: [
    'M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 '
        '2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 '
        '7z',
  ],
  OnboardingGlyphKind.smile: [
    'c:12,12,10',
    'M8 14s1.5 2 4 2 4-2 4-2',
    'M9 9h.01',
    'M15 9h.01',
  ],
  OnboardingGlyphKind.send: ['M22 2l-7 20-4-9-9-4z', 'M22 2L11 13'],
  OnboardingGlyphKind.shield: [
    'M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 '
        '1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 '
        '17 5 19 5a1 1 0 0 1 1 1z',
  ],
  OnboardingGlyphKind.scissors: [
    'c:6,6,3',
    'M8.12 8.12L12 12',
    'M20 4L8.12 15.88',
    'c:6,18,3',
    'M14.8 14.8L20 20',
  ],
  OnboardingGlyphKind.userX: [
    'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2',
    'c:9,7,4',
    'M17 8l5 5',
    'M22 8l-5 5',
  ],
  OnboardingGlyphKind.lock: ['r:3,11,18,11,2', 'M7 11V7a5 5 0 0 1 10 0v4'],
  OnboardingGlyphKind.help: [
    'c:12,12,10',
    'M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3',
    'M12 17h.01',
  ],
  OnboardingGlyphKind.chevronLeft: ['M15 18l-6-6 6-6'],
  OnboardingGlyphKind.chevronRight: ['M9 18l6-6-6-6'],
  OnboardingGlyphKind.user: [
    'M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2',
    'c:12,7,4',
  ],
  OnboardingGlyphKind.check: ['M20 6L9 17l-5-5'],
  OnboardingGlyphKind.dice: [
    'r:3,3,18,18,3',
    'M8 8h.01',
    'M16 8h.01',
    'M12 12h.01',
    'M8 16h.01',
    'M16 16h.01',
  ],
  OnboardingGlyphKind.refresh: ['M4 12a8 8 0 1 0 2.4-5.7', 'M4 4v4h4'],
};

final Map<OnboardingGlyphKind, Path> _paths = {};

Path _pathOf(OnboardingGlyphKind kind) => _paths.putIfAbsent(kind, () {
  final path = Path();
  for (final shape in _glyphs[kind]!) {
    if (shape.startsWith('c:')) {
      final v = shape.substring(2).split(',').map(double.parse).toList();
      path.addPath(svgCircle(v[0], v[1], v[2]), Offset.zero);
    } else if (shape.startsWith('r:')) {
      final v = shape.substring(2).split(',').map(double.parse).toList();
      path.addPath(svgRect(v[0], v[1], v[2], v[3], v[4]), Offset.zero);
    } else {
      path.addPath(parseSvgPath(shape), Offset.zero);
    }
  }
  return path;
});

/// One of the onboarding's icons, stroked in [color] (the surrounding
/// text colour when null).
class OnboardingGlyph extends StatelessWidget {
  const OnboardingGlyph(
    this.kind, {
    super.key,
    this.size = 20,
    this.strokeWidth = 1.8,
    this.color,
  });

  final OnboardingGlyphKind kind;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color =
        this.color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        OnboardingColors.text;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _GlyphPainter(kind, color, strokeWidth)),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.kind, this.color, this.strokeWidth);

  final OnboardingGlyphKind kind;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 24)
      ..drawPath(
        _pathOf(kind),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.kind != kind || old.color != color || old.strokeWidth != strokeWidth;
}

/// The boards' main button: a 52 dp pill in the accent ([accent], the
/// colour picked in Setup), 15 / 700 text, an optional 18 dp icon before
/// ([leading]) or after ([trailing]) the label; it presses in to 0.97.
class OnboardingButton extends StatelessWidget {
  const OnboardingButton({
    super.key,
    required this.label,
    required this.accent,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.height = 52,
  });

  final String label;
  final Color accent;
  final VoidCallback? onPressed;
  final OnboardingGlyphKind? leading;
  final OnboardingGlyphKind? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    final onAccent = onAccentFor(accent);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: PressScale(
        child: Material(
          color: accent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed == null
                ? null
                : () {
                    Haptics.light();
                    onPressed!();
                  },
            child: SizedBox(
              height: height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  if (leading case final glyph?)
                    OnboardingGlyph(
                      glyph,
                      size: 18,
                      strokeWidth: 2,
                      color: onAccent,
                    ),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.15,
                        color: onAccent,
                      ),
                    ),
                  ),
                  if (trailing case final glyph?)
                    OnboardingGlyph(
                      glyph,
                      size: 18,
                      strokeWidth: 2,
                      color: onAccent,
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

/// The boards' quiet button: transparent, 15 / 600 (#D6D6D6), a pill.
class OnboardingTextButton extends StatelessWidget {
  const OnboardingTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 44,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
    this.color = OnboardingColors.body,
    this.fontSize = 15,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;
  final EdgeInsets padding;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: PressScale(
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Haptics.selection();
              onPressed();
            },
            child: SizedBox(
              height: height,
              child: Padding(
                padding: padding,
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: color,
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
}

/// A round 44 dp icon button of the top bar (back, help).
class OnboardingIconButton extends StatelessWidget {
  const OnboardingIconButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
    this.size = 22,
    this.strokeWidth = 2,
  });

  final OnboardingGlyphKind glyph;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: tooltip,
        child: PressScale(
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: OnboardingGlyph(
                    glyph,
                    size: size,
                    strokeWidth: strokeWidth,
                    color: OnboardingColors.text,
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

/// The boards' switch: a 48 × 28 track (the accent when on, #2A2A2A off), a
/// 22 dp knob that slides in 260 ms, in a 52 × 44 target.
class OnboardingSwitch extends StatelessWidget {
  const OnboardingSwitch({
    super.key,
    required this.value,
    required this.accent,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final slide = reduce ? Duration.zero : const Duration(milliseconds: 260);
    final tint = reduce
        ? FrostyMotion.reducedFade
        : const Duration(milliseconds: 200);
    return Semantics(
      toggled: value,
      label: label,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!value);
          },
          child: SizedBox(
            width: 52,
            height: 44,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AnimatedContainer(
                duration: tint,
                width: 48,
                height: 28,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: value ? accent : OnboardingColors.control,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0x24FFFFFF),
                    width: FrostyTokens.hairlineWidth,
                  ),
                ),
                child: AnimatedAlign(
                  duration: slide,
                  curve: FrostyMotion.standard,
                  alignment: value
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: AnimatedContainer(
                    duration: tint,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value
                          ? onAccentFor(accent)
                          : OnboardingColors.knobOff,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x59000000),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
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
}

/// How a step's parts come in: they rise 12 dp and fade in, 460 ms on the
/// emphasized-decelerate curve, each a little after the one before (boards'
/// `.st` with delays `.d1`–`.d7`). Given by the flow to the step it opens
/// going forward; a step opened going back shows at once, as the boards do.
class StepEntrance extends InheritedWidget {
  const StepEntrance({
    super.key,
    required this.animation,
    required this.delays,
    required this.total,
    required super.child,
  });

  /// Runs 0 → 1 over [total].
  final Animation<double> animation;

  /// Each part's delay, by its order.
  final List<Duration> delays;
  final Duration total;

  /// The boards' step delays (`.d0`–`.d7`).
  static const stepDelays = [
    Duration.zero,
    Duration(milliseconds: 30),
    Duration(milliseconds: 70),
    Duration(milliseconds: 110),
    Duration(milliseconds: 150),
    Duration(milliseconds: 190),
    Duration(milliseconds: 230),
    Duration(milliseconds: 270),
  ];

  /// One part's rise.
  static const rise = Duration(milliseconds: 460);

  static StepEntrance? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StepEntrance>();

  @override
  bool updateShouldNotify(StepEntrance oldWidget) =>
      oldWidget.animation != animation || oldWidget.delays != delays;
}

/// One part of a step, rising in at its [order] when the step opens (see
/// [StepEntrance]); shown at once otherwise.
class StepRise extends StatelessWidget {
  const StepRise({super.key, required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final entrance = StepEntrance._of(context);
    if (entrance == null) return child;
    final delays = entrance.delays;
    final delay = delays[order.clamp(0, delays.length - 1)];
    final total = entrance.total.inMicroseconds;
    final start = delay.inMicroseconds / total;
    final end = (delay + StepEntrance.rise).inMicroseconds / total;
    final span = (end - start).clamp(0.0001, 1.0);
    return AnimatedBuilder(
      animation: entrance.animation,
      child: child,
      builder: (context, child) {
        final t = ((entrance.animation.value - start) / span).clamp(0.0, 1.0);
        final progress = FrostyMotion.emphasizedDecelerate.transform(t);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Where a step is laid out: its padding inside the step area, and whether
/// it is a tablet's (footer buttons at the bottom right instead of full
/// width).
class OnboardingStepLayout {
  const OnboardingStepLayout({required this.tablet, required this.padding});

  final bool tablet;
  final EdgeInsets padding;
}

/// A step's frame: [content] scrolls when the window is short, [footer]
/// (the buttons) stays at the bottom.
class OnboardingStepFrame extends StatelessWidget {
  const OnboardingStepFrame({
    super.key,
    required this.layout,
    required this.content,
    required this.footer,
  });

  final OnboardingStepLayout layout;
  final List<Widget> content;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final padding = layout.padding;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              padding.top,
              padding.right,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: content,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            padding.left,
            0,
            padding.right,
            padding.bottom,
          ),
          child: footer,
        ),
      ],
    );
  }
}

/// A step's footer: on a phone the buttons stacked full width, on a tablet
/// in a row at the bottom right ([primaryWidth] for the main one).
class OnboardingFooter extends StatelessWidget {
  const OnboardingFooter({
    super.key,
    required this.tablet,
    required this.primary,
    this.secondary,
    this.note,
    this.primaryWidth = 220,
  });

  final bool tablet;
  final Widget primary;
  final Widget? secondary;

  /// A line above the buttons (phone only; a tablet puts it in the content).
  final Widget? note;
  final double primaryWidth;

  @override
  Widget build(BuildContext context) {
    if (tablet) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 12,
        children: [
          ?secondary,
          Flexible(
            child: SizedBox(width: primaryWidth, child: primary),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (note case final note?)
          Padding(padding: const EdgeInsets.only(bottom: 14), child: note),
        primary,
        if (secondary case final secondary?)
          Padding(padding: const EdgeInsets.only(top: 4), child: secondary),
      ],
    );
  }
}
