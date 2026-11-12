import 'dart:math';

import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/onboarding/onboarding_parts.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/accent_picker_controls.dart';
import 'package:onset/widgets/motion/haptics.dart';

/// The accent colour picker of Setup (a sheet; on a tablet, a dialog): the colour square, the hue slider,
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
  final apply = AccentThrottle(onChanged);
  Widget picker(BuildContext context) => Theme(
    data: theme,
    child: _AccentPicker(initial: initial, onChanged: apply.call),
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
          borderRadius: BorderRadius.circular(OnsetTokens.radiusLarge),
          side: const BorderSide(
            color: OnboardingColors.ringStrong,
            width: OnsetTokens.hairlineWidth,
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
          top: Radius.circular(OnsetTokens.radiusLarge),
        ),
      ),
      builder: (context) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Color(0x24FFFFFF),
              width: OnsetTokens.hairlineWidth,
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
  if (done == true) {
    apply.flush();
  } else {
    apply.cancel();
    onChanged(initial);
  }
}

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
      label: context.l10n.accentColorTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.accentColorTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.27,
                    color: OnboardingColors.text,
                  ),
                ),
              ),
              Text(
                accentHex(color),
                style: OnsetType.tabular(
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
                    width: OnsetTokens.hairlineWidth,
                  ),
                ),
              ),
            ],
          ),
          AccentSaturationValue(hsv: _hsv, onChanged: _set),
          AccentHueSlider(hue: _hsv.hue, onChanged: _setHue),
          Semantics(
            button: true,
            child: Material(
              color: OnboardingColors.raised,
              shape: const StadiumBorder(
                side: BorderSide(
                  color: OnboardingColors.ringStrong,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _randomize,
                child: SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: [
                      const OnboardingGlyph(
                        OnboardingGlyphKind.dice,
                        size: 17,
                        color: OnboardingColors.text,
                      ),
                      Text(
                        context.l10n.accentColorRandom,
                        style: const TextStyle(
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
                  label: context.l10n.commonCancel,
                  fontSize: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  onPressed: () => Navigator.pop(context, false),
                ),
                SizedBox(
                  width: 96,
                  child: OnboardingButton(
                    label: context.l10n.commonDone,
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
