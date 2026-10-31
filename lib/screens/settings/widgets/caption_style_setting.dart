import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/video/captions.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_list_select.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';

/// Closed captions in Settings › Video: Twitch's switch, then the line's
/// size and background (an ONSET addition; Twitch's line is Medium on
/// Black), with a sample.
class CaptionStyleSetting extends StatelessWidget {
  const CaptionStyleSetting({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: captionStyleRows(settingsStore),
  );
}

/// The rows of [CaptionStyleSetting], for a settings group.
List<Widget> captionStyleRows(SettingsStore store) => [
  Observer(
    builder: (context) => SettingsListSwitch(
      title: context.l10n.settingsClosedCaptions,
      subtitle: Text(context.l10n.settingsClosedCaptionsDetail),
      value: store.showCaptions,
      onChanged: (value) => store.showCaptions = value,
    ),
  ),
  Observer(
    builder: (context) => SettingsListSelect(
      title: context.l10n.settingsCaptionSize,
      value: store.captionSize,
      values: CaptionSize.values,
      labelOf: (size) => size.label(context.l10n),
      onChanged: (size) => store.captionSize = size,
    ),
  ),
  Observer(
    builder: (context) => SettingsListSelect(
      title: context.l10n.settingsCaptionBackground,
      value: store.captionBackground,
      values: CaptionBackground.values,
      labelOf: (background) => background.label(context.l10n),
      onChanged: (background) => store.captionBackground = background,
    ),
  ),
  Observer(
    builder: (context) => Container(
      height: 76,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFF6B7A8F), Color(0xFFC9B79C)],
        ),
      ),
      child: CaptionText(
        text: context.l10n.settingsCaptionSample,
        size: store.captionSize,
        background: store.captionBackground,
      ),
    ),
  ),
];
