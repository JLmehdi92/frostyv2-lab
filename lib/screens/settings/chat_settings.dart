import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/constants.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/chat_filters_setting.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_list_select.dart';
import 'package:onset/screens/settings/widgets/settings_list_slider.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';
import 'package:onset/screens/settings/widgets/settings_muted_words.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';

/// Settings › Chat: sizing with its preview, how
/// messages look, the delay, layout, alerts, autocomplete, landscape,
/// filters and muted keywords, emote and badge providers, recent messages.
class ChatSettings extends StatefulWidget {
  final SettingsStore settingsStore;

  const ChatSettings({super.key, required this.settingsStore});

  @override
  State<ChatSettings> createState() => _ChatSettingsState();
}

class _ChatSettingsState extends State<ChatSettings> {
  final _recentLink = TapGestureRecognizer();

  @override
  void dispose() {
    _recentLink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsStore = widget.settingsStore;

    return Observer(
      builder: (context) {
        final l = context.l10n;
        return SettingsGroupsView(
          children: [
            SettingsGroup(
              title: l.settingsMessageSizing,
              children: [
                _ChatPreview(settingsStore: settingsStore),
                SettingsListSlider(
                  title: l.settingsBadgeScale,
                  trailing: l.settingsScaleValue(
                    scale: settingsStore.badgeScale,
                  ),
                  value: settingsStore.badgeScale,
                  min: 0.25,
                  max: 3.0,
                  divisions: 11,
                  onChanged: (newValue) => settingsStore.badgeScale = newValue,
                ),
                SettingsListSlider(
                  title: l.settingsEmoteScale,
                  trailing: l.settingsScaleValue(
                    scale: settingsStore.emoteScale,
                  ),
                  value: settingsStore.emoteScale,
                  min: 0.25,
                  max: 3.0,
                  divisions: 11,
                  onChanged: (newValue) => settingsStore.emoteScale = newValue,
                ),
                SettingsListSlider(
                  title: l.settingsMessageScale,
                  trailing: l.settingsScaleValue(
                    scale: settingsStore.messageScale,
                  ),
                  value: settingsStore.messageScale,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  onChanged: (newValue) =>
                      settingsStore.messageScale = newValue,
                ),
                SettingsListSlider(
                  title: l.settingsMessageSpacing,
                  trailing: l.settingsSpacingValue(
                    pixels: settingsStore.messageSpacing.round(),
                  ),
                  value: settingsStore.messageSpacing,
                  max: 30.0,
                  divisions: 15,
                  onChanged: (newValue) =>
                      settingsStore.messageSpacing = newValue,
                ),
                SettingsListSlider(
                  title: l.settingsFontSize,
                  trailing: settingsStore.fontSize.toInt().toString(),
                  value: settingsStore.fontSize,
                  min: 5,
                  max: 20,
                  divisions: 15,
                  onChanged: (newValue) => settingsStore.fontSize = newValue,
                ),
              ],
            ),
            SettingsGroup(
              title: l.settingsMessageAppearance,
              children: [
                SettingsListSwitch(
                  title: l.settingsShowDeleted,
                  subtitle: Text(l.settingsShowDeletedDetail),
                  value: settingsStore.showDeletedMessages,
                  onChanged: (newValue) =>
                      settingsStore.showDeletedMessages = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsAnimateEmotes,
                  subtitle: Text(l.settingsAnimateEmotesDetail),
                  value: settingsStore.animateEmotes,
                  onChanged: (newValue) =>
                      settingsStore.animateEmotes = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsAnimatedGifs,
                  subtitle: Text(l.settingsAnimatedGifsDetail),
                  value: settingsStore.animateGifs,
                  onChanged: (newValue) => settingsStore.animateGifs = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsShowGifs,
                  subtitle: Text(l.settingsShowGifsDetail),
                  value: settingsStore.showGifs,
                  onChanged: (newValue) => settingsStore.showGifs = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsLinkPreviews,
                  subtitle: Text(l.settingsLinkPreviewsDetail),
                  value: settingsStore.showLinkPreviews,
                  onChanged: (newValue) =>
                      settingsStore.showLinkPreviews = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsModerationNotices,
                  subtitle: Text(l.settingsModerationNoticesDetail),
                  value: settingsStore.showModerationNotices,
                  onChanged: (newValue) =>
                      settingsStore.showModerationNotices = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsMessageDividers,
                  value: settingsStore.showChatMessageDividers,
                  onChanged: (newValue) =>
                      settingsStore.showChatMessageDividers = newValue,
                ),
                SettingsListSelect(
                  title: l.settingsTimestamps,
                  value: settingsStore.timestampType,
                  values: TimestampType.values,
                  labelOf: (type) => type.label(l),
                  onChanged: (type) => settingsStore.timestampType = type,
                ),
              ],
            ),
            SettingsGroup(
              title: l.settingsDelayAndLatency,
              children: [
                SettingsListSwitch(
                  title: l.settingsSyncDelay,
                  subtitle: Text(l.settingsSyncDelayDetail),
                  value: settingsStore.autoSyncChatDelay,
                  onChanged: (newValue) =>
                      settingsStore.autoSyncChatDelay = newValue,
                ),
                if (!settingsStore.autoSyncChatDelay)
                  SettingsListSlider(
                    title: l.settingsMessageDelay,
                    trailing: l.settingsMessageDelayValue(
                      seconds: settingsStore.chatDelay.toInt(),
                    ),
                    subtitle: Platform.isIOS
                        ? l.settingsMessageDelayDetailIos
                        : l.settingsMessageDelayDetail,
                    value: settingsStore.chatDelay,
                    max: 30.0,
                    divisions: 30,
                    onChanged: (newValue) => settingsStore.chatDelay = newValue,
                  ),
              ],
            ),
            SettingsGroup(
              title: l.settingsLayout,
              children: [
                SettingsListSwitch(
                  title: l.settingsEmoteButtonLeft,
                  subtitle: Text(l.settingsEmoteButtonLeftDetail),
                  value: settingsStore.emoteMenuButtonOnLeft,
                  onChanged: (newValue) =>
                      settingsStore.emoteMenuButtonOnLeft = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsPersistTabs,
                  subtitle: Text(l.settingsPersistTabsDetail),
                  value: settingsStore.persistChatTabs,
                  onChanged: (newValue) {
                    settingsStore.persistChatTabs = newValue;
                    if (!newValue) {
                      settingsStore.secondaryTabs = [];
                    }
                  },
                ),
              ],
            ),
            SettingsGroup(
              title: l.settingsAlerts,
              children: [
                SettingsListSwitch(
                  title: l.settingsFirstTimeChatters,
                  value: settingsStore.highlightFirstTimeChatter,
                  onChanged: (newValue) =>
                      settingsStore.highlightFirstTimeChatter = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsUserNotices,
                  subtitle: Text(l.settingsUserNoticesDetail),
                  value: settingsStore.showUserNotices,
                  onChanged: (newValue) =>
                      settingsStore.showUserNotices = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsCollapseGiftBombs,
                  subtitle: Text(l.settingsCollapseGiftBombsDetail),
                  value: settingsStore.collapseGiftBombs,
                  onChanged: (newValue) =>
                      settingsStore.collapseGiftBombs = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsHideGiftSubNotices,
                  subtitle: Text(l.settingsHideGiftSubNoticesDetail),
                  value: settingsStore.hideGiftSubNotices,
                  onChanged: (newValue) =>
                      settingsStore.hideGiftSubNotices = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsHideGiftCount,
                  subtitle: Text(l.settingsHideGiftCountDetail),
                  value: settingsStore.hideGiftCount,
                  onChanged: (newValue) =>
                      settingsStore.hideGiftCount = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsShowHypeTrains,
                  subtitle: Text(l.settingsShowHypeTrainsDetail),
                  value: settingsStore.showHypeTrain,
                  onChanged: (newValue) =>
                      settingsStore.showHypeTrain = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsCommunityHighlights,
                  subtitle: Text(l.settingsCommunityHighlightsDetail),
                  value: settingsStore.showCommunityHighlights,
                  onChanged: (newValue) =>
                      settingsStore.showCommunityHighlights = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsCelebrations,
                  subtitle: Text(l.settingsCelebrationsDetail),
                  value: settingsStore.showCelebrations,
                  onChanged: (newValue) =>
                      settingsStore.showCelebrations = newValue,
                ),
                if (settingsStore.showCelebrations)
                  SettingsListSelect(
                    title: l.settingsCelebrationsOnVideo,
                    subtitle: l.settingsCelebrationsOnVideoDetail,
                    value: settingsStore.celebrationsOnVideo,
                    values: CelebrationsOnVideo.values,
                    labelOf: (option) => option.label(l),
                    onChanged: (option) =>
                        settingsStore.celebrationsOnVideo = option,
                  ),
              ],
            ),
            SettingsGroup(
              title: l.settingsAutocomplete,
              children: [
                SettingsListSwitch(
                  title: l.settingsAutocompleteBar,
                  subtitle: Text(l.settingsAutocompleteBarDetail),
                  value: settingsStore.autocomplete,
                  onChanged: (newValue) =>
                      settingsStore.autocomplete = newValue,
                ),
              ],
            ),
            SettingsGroup(
              title: l.settingsLandscape,
              children: [
                SettingsListSwitch(
                  title: l.settingsChatLeft,
                  value: settingsStore.landscapeChatLeftSide,
                  onChanged: (newValue) =>
                      settingsStore.landscapeChatLeftSide = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsVerticalChat,
                  subtitle: Text(l.settingsVerticalChatDetail),
                  value: settingsStore.landscapeForceVerticalChat,
                  onChanged: (newValue) =>
                      settingsStore.landscapeForceVerticalChat = newValue,
                ),
                SettingsListSelect(
                  title: l.settingsNotchSide,
                  subtitle: l.settingsNotchSideDetail,
                  value: settingsStore.landscapeCutout,
                  values: LandscapeCutoutType.values,
                  labelOf: (side) => side.label(l),
                  onChanged: (side) => settingsStore.landscapeCutout = side,
                ),
                SettingsListSlider(
                  title: l.settingsOverlayOpacity,
                  trailing: l.settingsOverlayOpacityValue(
                    percent: (settingsStore.fullScreenChatOverlayOpacity * 100)
                        .round(),
                  ),
                  subtitle: l.settingsOverlayOpacityDetail,
                  value: settingsStore.fullScreenChatOverlayOpacity,
                  divisions: 10,
                  onChanged: (newValue) =>
                      settingsStore.fullScreenChatOverlayOpacity = newValue,
                ),
              ],
            ),
            SettingsGroup(
              title: l.settingsFiltersGroup,
              children: [
                SettingsRow(
                  glyph: SettingsGlyphKind.filter,
                  title: l.settingsPageChatFilters,
                  value: settingsStore.chatFiltersEnabled
                      ? l.settingsFiltersOn
                      : l.settingsFiltersOff,
                  end: SettingsRowEnd.chevron,
                  onTap: () => openSettingsPage(
                    context,
                    id: SettingsPageId.chatFilters,
                    builder: (context) =>
                        ChatFiltersSetting(settingsStore: settingsStore),
                  ),
                ),
                SettingsMutedWords(settingsStore: settingsStore),
                SettingsListSwitch(
                  title: l.settingsWholeWords,
                  subtitle: Text(l.settingsWholeWordsDetail),
                  value: settingsStore.matchWholeWord,
                  onChanged: (newValue) =>
                      settingsStore.matchWholeWord = newValue,
                ),
              ],
            ),
            SettingsGroup(
              title: l.settingsEmotesAndBadges,
              children: [
                SettingsListSwitch(
                  title: l.settingsShowTwitchEmotes,
                  value: settingsStore.showTwitchEmotes,
                  onChanged: (newValue) =>
                      settingsStore.showTwitchEmotes = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsShowTwitchBadges,
                  value: settingsStore.showTwitchBadges,
                  onChanged: (newValue) =>
                      settingsStore.showTwitchBadges = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsShow7tvEmotes,
                  value: settingsStore.show7TVEmotes,
                  onChanged: (newValue) =>
                      settingsStore.show7TVEmotes = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsShowBttvEmotes,
                  value: settingsStore.showBTTVEmotes,
                  onChanged: (newValue) =>
                      settingsStore.showBTTVEmotes = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsShowBttvBadges,
                  value: settingsStore.showBTTVBadges,
                  onChanged: (newValue) =>
                      settingsStore.showBTTVBadges = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsShowFfzEmotes,
                  value: settingsStore.showFFZEmotes,
                  onChanged: (newValue) =>
                      settingsStore.showFFZEmotes = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsShowFfzBadges,
                  value: settingsStore.showFFZBadges,
                  onChanged: (newValue) =>
                      settingsStore.showFFZBadges = newValue,
                ),
              ],
            ),
            SettingsGroup(
              title: l.settingsRecentMessages,
              children: [
                SettingsListSwitch(
                  title: l.onboardingSetupHistoryTitle,
                  subtitle: Text.rich(
                    TextSpan(
                      children: l10nSpans(
                        l.onboardingSetupHistoryDetail(link: l10nMark(0)),
                        [
                          TextSpan(
                            text: _recentMessagesUrl,
                            style: TextStyle(
                              color: SettingsColors.accentOf(context),
                              decoration: TextDecoration.underline,
                              decorationColor: SettingsColors.accentOf(context),
                            ),
                            recognizer: _recentLink
                              ..onTap = () => launchSettingsLink(
                                _recentMessagesUrl,
                                external: settingsStore.launchUrlExternal,
                              ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  value: settingsStore.showRecentMessages,
                  onChanged: (newValue) =>
                      settingsStore.showRecentMessages = newValue,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The third party asked for recent messages when Twitch has none.
const _recentMessagesUrl = 'https://recent-messages.robotty.de/';

/// "Preview": opens a sample of chat drawn with the sizes below (real badge
/// and emote, loaded only once it is open).
class _ChatPreview extends StatefulWidget {
  const _ChatPreview({required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  State<_ChatPreview> createState() => _ChatPreviewState();
}

class _ChatPreviewState extends State<_ChatPreview> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final store = widget.settingsStore;
    final duration = settingsMotion(context, 300);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: _open,
          child: SettingsRow(
            title: context.l10n.settingsChatPreview,
            minHeight: 52,
            onTap: () => setState(() => _open = !_open),
            trailing: AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: duration,
              curve: OnsetMotion.standard,
              child: SettingsGlyph(
                SettingsGlyphKind.chevronDown,
                strokeWidth: 2,
                color: colors.secondary,
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: duration,
          curve: OnsetMotion.standard,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Observer(
                  builder: (context) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.well,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.cardRing, width: 0.5),
                    ),
                    child: DefaultTextStyle(
                      style: DefaultTextStyle.of(context).style.copyWith(
                        fontSize: store.fontSize,
                        height: 1.4,
                        color: colors.body,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: OnsetCachedNetworkImage(
                                    imageUrl:
                                        'https://static-cdn.jtvnw.net/badges/v1/bbbe0db0-a598-423e-86d0-f9fb98ca1933/3',
                                    height: defaultBadgeSize * store.badgeScale,
                                    width: defaultBadgeSize * store.badgeScale,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ' ${context.l10n.settingsChatPreviewBadgeEmote} ',
                                ),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: OnsetCachedNetworkImage(
                                    imageUrl:
                                        'https://static-cdn.jtvnw.net/emoticons/v2/425618/default/dark/3.0',
                                    height: defaultEmoteSize * store.emoteScale,
                                    width: defaultEmoteSize * store.emoteScale,
                                  ),
                                ),
                              ],
                            ),
                            textScaler: store.messageScale.textScaler,
                          ),
                          SizedBox(height: store.messageSpacing),
                          Text(
                            context.l10n.settingsChatPreviewText,
                            textScaler: store.messageScale.textScaler,
                          ),
                          SizedBox(height: store.messageSpacing),
                          Text(
                            context.l10n.settingsChatPreviewSpacing,
                            textScaler: store.messageScale.textScaler,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
