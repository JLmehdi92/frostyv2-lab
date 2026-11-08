import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/caption_style_setting.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_list_select.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/screens/settings/widgets/settings_twitch_web_token.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/new_feature_pill.dart';

/// Settings › Video: the low-latency player, playback,
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
        final l = context.l10n;
        return SettingsGroupsView(
          children: [
            // The IVS engine only exists natively on Android.
            if (android)
              SettingsGroup(
                title: l.settingsLowLatencyPlayer,
                children: [
                  SettingsListSwitch(
                    title: l.settingsLowLatencyPlayerSwitch,
                    subtitle: Text(l.settingsLowLatencyPlayerDetail),
                    value: settingsStore.playerEngine == PlayerEngine.ivs,
                    onChanged: (enabled) => settingsStore.playerEngine = enabled
                        ? PlayerEngine.ivs
                        : PlayerEngine.twitchWeb,
                  ),
                  if (ivs) ...[
                    SettingsListSwitch(
                      title: l.settingsAutoLatency,
                      subtitle: Text(l.settingsAutoLatencyDetail),
                      value: settingsStore.autoLatency,
                      onChanged: (enabled) =>
                          settingsStore.autoLatency = enabled,
                    ),
                    SettingsListSelect(
                      title: l.settingsLiveCatchUp,
                      subtitle: l.settingsLiveCatchUpDetail,
                      value: settingsStore.liveCatchUpMode,
                      values: LiveCatchUpMode.values,
                      labelOf: (mode) => mode.label(l),
                      onChanged: (mode) => settingsStore.liveCatchUpMode = mode,
                    ),
                    SettingsListSelect(
                      title: l.settingsBufferProfile,
                      subtitle: l.settingsBufferProfileDetail,
                      value: settingsStore.bufferProfile,
                      values: BufferProfile.values,
                      labelOf: (profile) => profile.label(l),
                      onChanged: (profile) =>
                          settingsStore.bufferProfile = profile,
                    ),
                    SettingsTwitchWebToken(authStore: context.authStore),
                  ],
                ],
              ),
            SettingsGroup(
              title: l.settingsPlayback,
              children: [
                SettingsListSwitch(
                  title: l.settingsEnableVideo,
                  value: settingsStore.showVideo,
                  onChanged: (newValue) => settingsStore.showVideo = newValue,
                ),
                if (!ios || isIPad())
                  SettingsListSwitch(
                    title: l.settingsHighestQuality,
                    value: settingsStore.defaultToHighestQuality,
                    onChanged: (newValue) =>
                        settingsStore.defaultToHighestQuality = newValue,
                  ),
                if (android)
                  SettingsListSwitch(
                    title: l.settingsFastRendering,
                    subtitle: Text(l.settingsFastRenderingDetail),
                    value: settingsStore.useTextureRendering,
                    onChanged: (newValue) =>
                        settingsStore.useTextureRendering = newValue,
                  ),
                SettingsListSwitch(
                  title: l.settingsKeepAwake,
                  subtitle: Text(l.settingsKeepAwakeDetail),
                  value: settingsStore.keepScreenAwake,
                  onChanged: (newValue) =>
                      settingsStore.keepScreenAwake = newValue,
                ),
                if (android)
                  SettingsListSwitch(
                    title: l.settingsBackgroundAudio,
                    subtitle: Text(l.settingsBackgroundAudioDetail),
                    value: settingsStore.backgroundAudio,
                    onChanged: (newValue) =>
                        settingsStore.backgroundAudio = newValue,
                  ),
                if (android && settingsStore.backgroundAudio)
                  SettingsListSwitch(
                    title: l.settingsBackgroundAudioHeadphonesOnly,
                    subtitle: Text(
                      l.settingsBackgroundAudioHeadphonesOnlyDetail,
                    ),
                    value: settingsStore.backgroundAudioHeadphonesOnly,
                    onChanged: (newValue) =>
                        settingsStore.backgroundAudioHeadphonesOnly = newValue,
                  ),
                if (android)
                  SettingsListSwitch(
                    title: l.settingsAutoPip,
                    subtitle: Text(l.settingsAutoPipDetail),
                    value: settingsStore.autoPictureInPicture,
                    onChanged: (newValue) =>
                        settingsStore.autoPictureInPicture = newValue,
                  ),
              ],
            ),
            SettingsGroup(
              title: l.settingsOverlay,
              children: [
                SettingsListSwitch(
                  title: l.settingsCustomOverlay,
                  subtitle: Text(l.settingsCustomOverlayDetail),
                  value: settingsStore.showOverlay,
                  onChanged: (newValue) => settingsStore.showOverlay = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsToggleOverlay,
                  subtitle: Text(l.settingsToggleOverlayDetail),
                  value: settingsStore.toggleableOverlay,
                  onChanged: (newValue) =>
                      settingsStore.toggleableOverlay = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsShowLatency,
                  subtitle: Text(l.settingsShowLatencyDetail),
                  value: settingsStore.showLatency,
                  onChanged: (newValue) => settingsStore.showLatency = newValue,
                ),
              ],
            ),
            SettingsGroup(
              title: l.settingsVideosAndContent,
              children: [
                SettingsListSelect(
                  title: l.settingsVodAutoplay,
                  subtitle: l.settingsVodAutoplayDetail,
                  stacked: true,
                  value: settingsStore.vodAutoplay,
                  values: VodAutoplay.values,
                  labelOf: (option) => option.label(l),
                  onChanged: (option) => settingsStore.vodAutoplay = option,
                ),
                SettingsListSwitch(
                  title: l.settingsStreamPreviews,
                  isNew: settingsStore.isNewFeature(
                    NewFeature.streamPreviews.name,
                  ),
                  subtitle: Text(l.settingsStreamPreviewsDetail),
                  value: settingsStore.streamPreviews,
                  onChanged: (newValue) {
                    settingsStore
                      ..streamPreviews = newValue
                      ..markFeatureSeen(NewFeature.streamPreviews.name);
                  },
                ),
                if (settingsStore.streamPreviews)
                  SettingsListSwitch(
                    title: l.settingsMutePreviews,
                    value: settingsStore.mutePreviews,
                    onChanged: (newValue) =>
                        settingsStore.mutePreviews = newValue,
                  ),
                SettingsListSwitch(
                  title: l.settingsDataSaver,
                  isNew: settingsStore.isNewFeature(NewFeature.dataSaver.name),
                  subtitle: Text(l.settingsDataSaverDetail),
                  value: settingsStore.dataSaver,
                  onChanged: (newValue) {
                    settingsStore
                      ..dataSaver = newValue
                      ..markFeatureSeen(NewFeature.dataSaver.name);
                  },
                ),
                SettingsListSwitch(
                  title: l.settingsWarnMature,
                  subtitle: Text(l.settingsWarnMatureDetail),
                  value: settingsStore.warnMatureContent,
                  onChanged: (newValue) =>
                      settingsStore.warnMatureContent = newValue,
                ),
              ],
            ),
            // Captions come from the IVS player, Android only.
            if (android)
              SettingsGroup(
                title: l.settingsCaptions,
                children: captionStyleRows(settingsStore),
              ),
          ],
        );
      },
    );
  }
}
