import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/caption_style_setting.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_list_select.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/screens/settings/widgets/settings_twitch_web_token.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/utils/context_extensions.dart';

/// Settings › Video (board Parametres): the low-latency player, playback,
/// the overlay, videos and content, captions.
class VideoSettings extends StatelessWidget {
  final SettingsStore settingsStore;

  /// Android's own settings shown (tests stand in for a platform).
  final bool? isAndroid;

  /// iOS's (where an iPhone has no quality to default to).
  final bool? isIOS;

  const VideoSettings({
    super.key,
    required this.settingsStore,
    this.isAndroid,
    this.isIOS,
  });

  @override
  Widget build(BuildContext context) {
    final android = isAndroid ?? Platform.isAndroid;
    final ios = isIOS ?? Platform.isIOS;
    return Observer(
      builder: (context) {
        final ivs = android && settingsStore.playerEngine == PlayerEngine.ivs;
        return SettingsGroupsView(
          children: [
            // The IVS engine only exists natively on Android.
            if (android)
              SettingsGroup(
                title: 'Low-latency player',
                children: [
                  SettingsListSwitch(
                    title: 'Low-latency player (Twitch IVS)',
                    subtitle: const Text(
                      'Plays the stream with the same player the official '
                      'Twitch app uses, for matching low latency. Turn off '
                      'to use the original Twitch web player.',
                    ),
                    value: settingsStore.playerEngine == PlayerEngine.ivs,
                    onChanged: (enabled) => settingsStore.playerEngine = enabled
                        ? PlayerEngine.ivs
                        : PlayerEngine.twitchWeb,
                  ),
                  if (ivs) ...[
                    SettingsListSwitch(
                      title: 'Auto latency',
                      subtitle: const Text(
                        'Keeps the stream close to live by playing very '
                        'slightly faster when it drifts behind. Never reloads '
                        'the player. If Ultra keeps stalling, the next streams '
                        'use Standard for a while. Applies the next time a '
                        'stream is opened.',
                      ),
                      value: settingsStore.autoLatency,
                      onChanged: (enabled) =>
                          settingsStore.autoLatency = enabled,
                    ),
                    SettingsListSelect(
                      title: 'Live catch-up',
                      subtitle:
                          'Speed up plays slightly faster until it is back at '
                          'live, like the official app (Auto latency does it '
                          'when on). Jump to live skips ahead after a stall. '
                          'Applies the next time a stream is opened.',
                      selectedOption:
                          liveCatchUpModeNames[settingsStore
                              .liveCatchUpMode
                              .index],
                      options: liveCatchUpModeNames,
                      onChanged: (newValue) => settingsStore.liveCatchUpMode =
                          LiveCatchUpMode.values[liveCatchUpModeNames.indexOf(
                            newValue,
                          )],
                    ),
                    SettingsListSelect(
                      title: 'Buffer profile',
                      subtitle:
                          'Ultra keeps an even smaller buffer for lower '
                          'latency but may rebuffer more on weak connections. '
                          'Applies the next time a stream is opened.',
                      selectedOption:
                          bufferProfileNames[settingsStore.bufferProfile.index],
                      options: bufferProfileNames,
                      onChanged: (newValue) => settingsStore.bufferProfile =
                          BufferProfile.values[bufferProfileNames.indexOf(
                            newValue,
                          )],
                    ),
                    SettingsTwitchWebToken(authStore: context.authStore),
                  ],
                ],
              ),
            SettingsGroup(
              title: 'Playback',
              children: [
                SettingsListSwitch(
                  title: 'Enable video',
                  value: settingsStore.showVideo,
                  onChanged: (newValue) => settingsStore.showVideo = newValue,
                ),
                if (!ios || isIPad())
                  SettingsListSwitch(
                    title: 'Default to highest quality',
                    value: settingsStore.defaultToHighestQuality,
                    onChanged: (newValue) =>
                        settingsStore.defaultToHighestQuality = newValue,
                  ),
                if (android)
                  SettingsListSwitch(
                    title: 'Use fast video rendering',
                    subtitle: const Text(
                      'Uses a faster WebView rendering method. Disable if you '
                      'experience crashes while watching streams.',
                    ),
                    value: settingsStore.useTextureRendering,
                    onChanged: (newValue) =>
                        settingsStore.useTextureRendering = newValue,
                  ),
                SettingsListSwitch(
                  title: 'Keep screen awake',
                  subtitle: const Text(
                    'Prevents the screen from sleeping while a channel is '
                    'open.',
                  ),
                  value: settingsStore.keepScreenAwake,
                  onChanged: (newValue) =>
                      settingsStore.keepScreenAwake = newValue,
                ),
                if (android)
                  SettingsListSwitch(
                    title: 'Background audio',
                    subtitle: const Text(
                      'Keeps a live stream playing when you leave the app or '
                      'turn off the screen, with media controls in a '
                      'notification.',
                    ),
                    value: settingsStore.backgroundAudio,
                    onChanged: (newValue) =>
                        settingsStore.backgroundAudio = newValue,
                  ),
              ],
            ),
            SettingsGroup(
              title: 'Overlay',
              children: [
                SettingsListSwitch(
                  title: 'Use custom video overlay',
                  subtitle: const Text(
                    "Replaces Twitch's default web overlay with a "
                    'mobile-friendly version.',
                  ),
                  value: settingsStore.showOverlay,
                  onChanged: (newValue) => settingsStore.showOverlay = newValue,
                ),
                SettingsListSwitch(
                  title: 'Long-press player to toggle overlay',
                  subtitle: const Text(
                    "Allows switching between Twitch's overlay and the "
                    'custom overlay.',
                  ),
                  value: settingsStore.toggleableOverlay,
                  onChanged: (newValue) =>
                      settingsStore.toggleableOverlay = newValue,
                ),
                SettingsListSwitch(
                  title: 'Show latency',
                  subtitle: const Text(
                    'Displays the stream latency in the video overlay. With '
                    'the low-latency player, tap it to show live video '
                    'stats.',
                  ),
                  value: settingsStore.showLatency,
                  onChanged: (newValue) => settingsStore.showLatency = newValue,
                ),
              ],
            ),
            SettingsGroup(
              title: 'Videos and content',
              children: [
                SettingsListSelect(
                  title: 'Video Autoplaying',
                  subtitle: 'Choose when videos should play automatically',
                  stacked: true,
                  selectedOption: settingsStore.vodAutoplay.label,
                  options: [
                    for (final option in VodAutoplay.values) option.label,
                  ],
                  onChanged: (label) => settingsStore.vodAutoplay = VodAutoplay
                      .values
                      .firstWhere((option) => option.label == label),
                ),
                SettingsListSwitch(
                  title: 'Warn about mature content',
                  subtitle: const Text(
                    'Shows a warning before a channel labeled for mature '
                    'content.',
                  ),
                  value: settingsStore.warnMatureContent,
                  onChanged: (newValue) =>
                      settingsStore.warnMatureContent = newValue,
                ),
              ],
            ),
            // Captions come from the IVS player, Android only.
            if (android)
              SettingsGroup(
                title: 'Captions',
                children: captionStyleRows(settingsStore),
              ),
          ],
        );
      },
    );
  }
}
