import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/widgets/caption_style_setting.dart';
import 'package:frosty/screens/settings/widgets/settings_list_select.dart';
import 'package:frosty/screens/settings/widgets/settings_list_switch.dart';
import 'package:frosty/screens/settings/widgets/settings_twitch_web_token.dart';
import 'package:frosty/utils.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/section_header.dart';
import 'package:frosty/widgets/settings_page_layout.dart';

class VideoSettings extends StatelessWidget {
  final SettingsStore settingsStore;

  const VideoSettings({super.key, required this.settingsStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => SettingsPageLayout(
        children: [
          const SectionHeader('Player', isFirst: true),
          // The IVS engine only exists natively on Android.
          if (Platform.isAndroid)
            SettingsListSwitch(
              title: 'Low-latency player (Twitch IVS)',
              subtitle: const Text(
                'Plays the stream with the same player the official Twitch app '
                'uses, for matching low latency. Turn off to use the original '
                'Twitch web player.',
              ),
              value: settingsStore.playerEngine == PlayerEngine.ivs,
              onChanged: (enabled) => settingsStore.playerEngine = enabled
                  ? PlayerEngine.ivs
                  : PlayerEngine.twitchWeb,
            ),
          if (Platform.isAndroid &&
              settingsStore.playerEngine == PlayerEngine.ivs) ...[
            SettingsListSelect(
              title: 'Live catch-up',
              subtitle:
                  'Speed up plays slightly faster until it is back at live, '
                  'like the official app. Jump to live skips ahead after a '
                  'stall. Applies the next time a stream is opened.',
              selectedOption:
                  liveCatchUpModeNames[settingsStore.liveCatchUpMode.index],
              options: liveCatchUpModeNames,
              onChanged: (newValue) => settingsStore.liveCatchUpMode =
                  LiveCatchUpMode.values[liveCatchUpModeNames.indexOf(
                    newValue,
                  )],
            ),
            SettingsListSelect(
              title: 'Buffer profile',
              subtitle:
                  'Ultra (experimental) keeps an even smaller buffer for '
                  'lower latency but may rebuffer more on weak connections. '
                  'Applies the next time a stream is opened.',
              selectedOption:
                  bufferProfileNames[settingsStore.bufferProfile.index],
              options: bufferProfileNames,
              onChanged: (newValue) => settingsStore.bufferProfile =
                  BufferProfile.values[bufferProfileNames.indexOf(newValue)],
            ),
          ],
          if (Platform.isAndroid &&
              settingsStore.playerEngine == PlayerEngine.ivs)
            SettingsTwitchWebToken(authStore: context.authStore),
          SettingsListSwitch(
            title: 'Enable video',
            value: settingsStore.showVideo,
            onChanged: (newValue) => settingsStore.showVideo = newValue,
          ),
          if (!Platform.isIOS || isIPad())
            SettingsListSwitch(
              title: 'Default to highest quality',
              value: settingsStore.defaultToHighestQuality,
              onChanged: (newValue) =>
                  settingsStore.defaultToHighestQuality = newValue,
            ),
          if (Platform.isAndroid)
            SettingsListSwitch(
              title: 'Use fast video rendering',
              subtitle: const Text(
                'Uses a faster WebView rendering method. Disable if you experience crashes while watching streams.',
              ),
              value: settingsStore.useTextureRendering,
              onChanged: (newValue) =>
                  settingsStore.useTextureRendering = newValue,
            ),
          SettingsListSwitch(
            title: 'Keep screen awake',
            subtitle: const Text(
              'Prevents the screen from sleeping while a channel is open.',
            ),
            value: settingsStore.keepScreenAwake,
            onChanged: (newValue) => settingsStore.keepScreenAwake = newValue,
          ),
          if (Platform.isAndroid)
            SettingsListSwitch(
              title: 'Background audio',
              subtitle: const Text(
                'Keeps a live stream playing when you leave the app or turn off the screen, with media controls in a notification.',
              ),
              value: settingsStore.backgroundAudio,
              onChanged: (newValue) => settingsStore.backgroundAudio = newValue,
            ),
          SettingsListSelect(
            title: 'Video Autoplaying',
            subtitle: 'Choose when videos should play automatically',
            selectedOption: settingsStore.vodAutoplay.label,
            options: [for (final option in VodAutoplay.values) option.label],
            onChanged: (label) => settingsStore.vodAutoplay = VodAutoplay.values
                .firstWhere((option) => option.label == label),
          ),
          SettingsListSwitch(
            title: 'Warn about mature content',
            subtitle: const Text(
              'Shows a warning before a channel labeled for mature content.',
            ),
            value: settingsStore.warnMatureContent,
            onChanged: (newValue) => settingsStore.warnMatureContent = newValue,
          ),
          // Captions come from the IVS player, Android only.
          if (Platform.isAndroid) ...[
            const SectionHeader('Captions'),
            CaptionStyleSetting(settingsStore: settingsStore),
          ],
          const SectionHeader('Overlay'),
          SettingsListSwitch(
            title: 'Use custom video overlay',
            subtitle: const Text(
              'Replaces Twitch\'s default web overlay with a mobile-friendly version.',
            ),
            value: settingsStore.showOverlay,
            onChanged: (newValue) => settingsStore.showOverlay = newValue,
          ),
          SettingsListSwitch(
            title: 'Long-press player to toggle overlay',
            subtitle: const Text(
              'Allows switching between Twitch\'s overlay and the custom overlay.',
            ),
            value: settingsStore.toggleableOverlay,
            onChanged: (newValue) => settingsStore.toggleableOverlay = newValue,
          ),
          SettingsListSwitch(
            title: 'Show latency',
            subtitle: const Text(
              'Displays the stream latency in the video overlay. With the '
              'low-latency player, tap it to show live video stats.',
            ),
            value: settingsStore.showLatency,
            onChanged: (newValue) => settingsStore.showLatency = newValue,
          ),
        ],
      ),
    );
  }
}
