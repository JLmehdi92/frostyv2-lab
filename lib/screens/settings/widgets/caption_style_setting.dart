import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/channel/video/captions.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/widgets/settings_list_select.dart';
import 'package:frosty/screens/settings/widgets/settings_list_switch.dart';

/// Closed captions in Settings › Video: Twitch's switch, then the line's
/// size and background (an ONSET addition; Twitch's line is Medium on
/// Black), with a sample.
class CaptionStyleSetting extends StatelessWidget {
  const CaptionStyleSetting({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  Widget build(BuildContext context) {
    final store = settingsStore;
    return Observer(
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsListSwitch(
            title: 'Closed Captions',
            subtitle: const Text(
              'Shows captions over live streams and videos that have them. '
              'When there are several, pick one in the player menu.',
            ),
            value: store.showCaptions,
            onChanged: (value) => store.showCaptions = value,
          ),
          SettingsListSelect(
            title: 'Caption size',
            selectedOption: store.captionSize.label,
            options: [for (final size in CaptionSize.values) size.label],
            onChanged: (label) => store.captionSize = CaptionSize.values
                .firstWhere((size) => size.label == label),
          ),
          SettingsListSelect(
            title: 'Caption background',
            selectedOption: store.captionBackground.label,
            options: [
              for (final background in CaptionBackground.values)
                background.label,
            ],
            onChanged: (label) => store.captionBackground = CaptionBackground
                .values
                .firstWhere((background) => background.label == label),
          ),
          Container(
            height: 72,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [Color(0xFF6B7A8F), Color(0xFFC9B79C)],
              ),
            ),
            child: CaptionText(
              text: 'This is how captions look.',
              size: store.captionSize,
              background: store.captionBackground,
            ),
          ),
        ],
      ),
    );
  }
}
