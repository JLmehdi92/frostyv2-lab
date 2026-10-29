import 'dart:math';

import 'package:flutter/material.dart';
import 'package:frosty/screens/onboarding/onboarding_parts.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/motion/haptics.dart';

/// The accent colour picker of Setup (boards Onboarding: a sheet;
/// OnboardingTablette: a dialog): the colour square, the hue slider,
/// "Random", "Cancel" and "Done".
///
/// Every change is applied at once through [onChanged], so the whole
/// onboarding (and the preview) shows it; "Cancel", the scrim and the back
/// gesture put [initial] back, "Done" keeps the pick.
Future<void> showOnboardingAccentPicker(
  BuildContext context, {
  required bool tablet,
  required Color initial,
  required ValueChanged<Color> onChanged,
}) async {
  final theme = Theme.of(context);
  Widget picker(BuildContext context) => Theme(
    data: theme,
    child: _AccentPicker(initial: initial, onChanged: onChanged),
  );

  final bool? done;
  if (tablet) {
    done = await showDialog<bool>(
      context: context,
      barrierColor: OnboardingColors.scrim,
      builder: (context) => Dialog(
        backgroundColor: OnboardingColors.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FrostyTokens.radiusLarge),
          side: const BorderSide(
            color: OnboardingColors.ringStrong,
            width: FrostyTokens.hairlineWidth,
          ),
        ),
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: picker(context),
          ),
        ),
      ),
    );
  } else {
    done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: OnboardingColors.surface,
      barrierColor: OnboardingColors.scrim,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FrostyTokens.radiusLarge),
        ),
      ),
      builder: (context) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Color(0x24FFFFFF),
              width: FrostyTokens.hairlineWidth,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: OnboardingColors.handle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                picker(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
  if (done != true) onChanged(initial);
}

/// "#RRGGBB" of [color].
String hexOf(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class _AccentPicker extends StatefulWidget {
  const _AccentPicker({required this.initial, required this.onChanged});

  final Color initial;
  final ValueChanged<Color> onChanged;

  @override
  State<_AccentPicker> createState() => _AccentPickerState();
}

class _AccentPickerState extends State<_AccentPicker> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  final _random = Random();

  /// The hues the slider's eight segments name for a screen reader.
  static const _namedHues = [22, 67, 112, 157, 202, 247, 292, 337];

  Color get _color => _hsv.toColor();

  void _set(HSVColor hsv) {
    setState(() => _hsv = hsv);
    widget.onChanged(hsv.toColor());
  }

  void _setHue(double hue) => _set(_hsv.withHue(hue.clamp(0.0, 359.999)));

  void _randomize() {
    Haptics.light();
    _set(HSVColor.fromAHSV(1, _random.nextInt(360).toDouble(), 0.76, 1));
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Accent color',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Accent color',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.27,
                    color: OnboardingColors.text,
                  ),
                ),
              ),
              Text(
                hexOf(color),
                style: FrostyType.tabular(
                  const TextStyle(
                    fontSize: 13,
                    color: OnboardingColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0x4DFFFFFF),
                    width: FrostyTokens.hairlineWidth,
                  ),
                ),
              ),
            ],
          ),
          _SaturationValue(hsv: _hsv, onChanged: _set),
          _HueSlider(hue: _hsv.hue, namedHues: _namedHues, onChanged: _setHue),
          Semantics(
            button: true,
            child: Material(
              color: OnboardingColors.raised,
              shape: const StadiumBorder(
                side: BorderSide(
                  color: OnboardingColors.ringStrong,
                  width: FrostyTokens.hairlineWidth,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _randomize,
                child: const SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: [
                      OnboardingGlyph(
                        OnboardingGlyphKind.dice,
                        size: 17,
                        color: OnboardingColors.text,
                      ),
                      Text(
                        'Random',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: OnboardingColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                OnboardingTextButton(
                  label: 'Cancel',
                  fontSize: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  onPressed: () => Navigator.pop(context, false),
                ),
                SizedBox(
                  width: 96,
                  child: OnboardingButton(
                    label: 'Done',
                    accent: color,
                    height: 44,
                    onPressed: () => Navigator.pop(context, true),
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

/// The colour square: saturation across, brightness down, for the hue.
class _SaturationValue extends StatelessWidget {
  const _SaturationValue({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const height = 168.0;
        void pick(Offset position) => onChanged(
          hsv
              .withSaturation((position.dx / width).clamp(0.0, 1.0))
              .withValue(1 - (position.dy / height).clamp(0.0, 1.0)),
        );
        return Semantics(
          label: 'Saturation and brightness',
          value:
              '${(hsv.saturation * 100).round()} %, '
              '${(hsv.value * 100).round()} %',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (details) => pick(details.localPosition),
            onPanUpdate: (details) => pick(details.localPosition),
            child: SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                          ],
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black, Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: hsv.saturation * width - 10,
                    top: (1 - hsv.value) * height - 10,
                    child: _Thumb(color: hsv.toColor()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The hue slider: a 12 dp rainbow track in a 44 dp target.
class _HueSlider extends StatelessWidget {
  const _HueSlider({
    required this.hue,
    required this.namedHues,
    required this.onChanged,
  });

  final double hue;
  final List<int> namedHues;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void pick(Offset position) =>
            onChanged((position.dx / width).clamp(0.0, 1.0) * 360);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => pick(details.localPosition),
          onHorizontalDragStart: (details) => pick(details.localPosition),
          onHorizontalDragUpdate: (details) => pick(details.localPosition),
          child: SizedBox(
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 16,
                  height: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFFFFFF00),
                          Color(0xFF00FF00),
                          Color(0xFF00FFFF),
                          Color(0xFF0000FF),
                          Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: hue / 360 * width - 10,
                  top: 12,
                  child: _Thumb(
                    color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                  ),
                ),
                // Eight named hues for a screen reader (a tap lands on the
                // same hue through the slider itself).
                Positioned.fill(
                  child: Row(
                    children: [
                      for (final named in namedHues)
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: 'Hue $named degrees',
                            onTap: () => onChanged(named.toDouble()),
                            child: const SizedBox.expand(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}
