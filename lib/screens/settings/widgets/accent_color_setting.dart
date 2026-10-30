import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/accent_picker_controls.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

/// "Accent color" in Settings › General: the colour's hex and swatch; a tap
/// opens the picker (a sheet on a phone, a dialog on a tablet), which
/// applies every change at once.
class AccentColorSetting extends StatelessWidget {
  final SettingsStore settingsStore;

  const AccentColorSetting({super.key, required this.settingsStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final colors = SettingsColors.of(context);
        final color = Color(settingsStore.accentColor);
        return SettingsRow(
          title: 'Accent color',
          semanticsLabel: 'Change accent color',
          onTap: () => showAccentColorPicker(context, settingsStore),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Text(
                accentHex(color),
                style: OnsetType.tabular(
                  TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.48,
                    color: colors.secondary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    // The double ring: the card, then the text.
                    boxShadow: [
                      BoxShadow(color: colors.text, spreadRadius: 3.5),
                      BoxShadow(color: colors.card, spreadRadius: 2),
                    ],
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

/// "#RRGGBB" of [color].
String accentHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// The accent picker of Settings: the colour square, the hue slider, the
/// colour and "Random"; every change goes to [settingsStore] at once, and
/// "Done" (or the scrim) closes it.
Future<void> showAccentColorPicker(
  BuildContext context,
  SettingsStore settingsStore,
) {
  final colors = SettingsColors.of(context);
  Widget picker(BuildContext context) =>
      _AccentPicker(settingsStore: settingsStore);
  if (context.isLargeScreen) {
    return showDialog<void>(
      context: context,
      barrierColor: kSheetScrim,
      builder: (context) => Dialog(
        backgroundColor: colors.dialog,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OnsetTokens.radiusLarge),
          side: BorderSide(
            color: colors.cardRing,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        child: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
            child: picker(context),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Dragging down the colour square picks a darker colour: it must not
    // drag the sheet away.
    enableDrag: false,
    showDragHandle: false,
    backgroundColor: colors.sheet,
    barrierColor: kSheetScrim,
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(OnsetTokens.radiusLarge),
      ),
    ),
    builder: (context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.handle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            picker(context),
          ],
        ),
      ),
    ),
  );
}

class _AccentPicker extends StatefulWidget {
  const _AccentPicker({required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  State<_AccentPicker> createState() => _AccentPickerState();
}

class _AccentPickerState extends State<_AccentPicker> {
  late HSVColor _hsv = HSVColor.fromColor(
    Color(widget.settingsStore.accentColor),
  );
  final _random = Random();

  void _set(HSVColor hsv) {
    setState(() => _hsv = hsv);
    widget.settingsStore.accentColor = hsv.toColor().toARGB32();
  }

  void _randomize() {
    HapticFeedback.lightImpact();
    _set(
      HSVColor.fromColor(
        Color.fromARGB(
          255,
          _random.nextInt(256),
          _random.nextInt(256),
          _random.nextInt(256),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final color = _hsv.toColor();
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Accent color',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 8, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Accent color',
                    style: SettingsText.pageTitle.copyWith(
                      letterSpacing: -0.27,
                      color: colors.text,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: SettingsColors.accentOf(context),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                AccentSaturationValue(hsv: _hsv, onChanged: _set, radius: 12),
                AccentHueSlider(
                  hue: _hsv.hue,
                  trackHeight: 14,
                  onChanged: (hue) => _set(_hsv.withHue(hue.clamp(0, 359.999))),
                ),
                Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0x33FFFFFF),
                          width: OnsetTokens.hairlineWidth,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(
                            accentHex(color),
                            style: OnsetType.tabular(
                              TextStyle(
                                fontFamily: OnsetTokens.bodyFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: colors.text,
                              ),
                            ),
                          ),
                          Text(
                            'Applies everywhere as you pick',
                            style: TextStyle(
                              fontFamily: OnsetTokens.bodyFamily,
                              fontSize: 12,
                              color: colors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SettingsButton(
                      label: 'Random',
                      icon: SettingsGlyph(
                        SettingsGlyphKind.dice,
                        size: 17,
                        color: colors.text,
                      ),
                      onPressed: _randomize,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
