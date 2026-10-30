import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/constants.dart';
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

/// Settings › Chat (board Parametres): sizing with its preview, how
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
      builder: (context) => SettingsGroupsView(
        children: [
          SettingsGroup(
            title: 'Message sizing',
            children: [
              _ChatPreview(settingsStore: settingsStore),
              SettingsListSlider(
                title: 'Badge scale',
                trailing: '${settingsStore.badgeScale.toStringAsFixed(2)}x',
                value: settingsStore.badgeScale,
                min: 0.25,
                max: 3.0,
                divisions: 11,
                onChanged: (newValue) => settingsStore.badgeScale = newValue,
              ),
              SettingsListSlider(
                title: 'Emote scale',
                trailing: '${settingsStore.emoteScale.toStringAsFixed(2)}x',
                value: settingsStore.emoteScale,
                min: 0.25,
                max: 3.0,
                divisions: 11,
                onChanged: (newValue) => settingsStore.emoteScale = newValue,
              ),
              SettingsListSlider(
                title: 'Message scale',
                trailing: '${settingsStore.messageScale.toStringAsFixed(2)}x',
                value: settingsStore.messageScale,
                min: 0.5,
                max: 2.0,
                divisions: 6,
                onChanged: (newValue) => settingsStore.messageScale = newValue,
              ),
              SettingsListSlider(
                title: 'Message spacing',
                trailing:
                    '${settingsStore.messageSpacing.toStringAsFixed(0)}px',
                value: settingsStore.messageSpacing,
                max: 30.0,
                divisions: 15,
                onChanged: (newValue) =>
                    settingsStore.messageSpacing = newValue,
              ),
              SettingsListSlider(
                title: 'Font size',
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
            title: 'Message appearance',
            children: [
              SettingsListSwitch(
                title: 'Show deleted messages',
                subtitle: const Text(
                  'Restores the original message of deleted messages.',
                ),
                value: settingsStore.showDeletedMessages,
                onChanged: (newValue) =>
                    settingsStore.showDeletedMessages = newValue,
              ),
              SettingsListSwitch(
                title: 'Animate emotes',
                subtitle: const Text(
                  'Off shows the first frame of animated emotes in chat.',
                ),
                value: settingsStore.animateEmotes,
                onChanged: (newValue) => settingsStore.animateEmotes = newValue,
              ),
              SettingsListSwitch(
                title: 'Animated GIFs',
                subtitle: const Text(
                  'Off shows the first frame of GIFs sent in chat.',
                ),
                value: settingsStore.animateGifs,
                onChanged: (newValue) => settingsStore.animateGifs = newValue,
              ),
              SettingsListSwitch(
                title: 'Show GIFs in Chat',
                subtitle: const Text(
                  'Off shows the title of a GIF instead of the GIF.',
                ),
                value: settingsStore.showGifs,
                onChanged: (newValue) => settingsStore.showGifs = newValue,
              ),
              SettingsListSwitch(
                title: 'Preview clips and videos',
                subtitle: const Text(
                  'Shows a card under messages that link a Twitch clip or '
                  'video.',
                ),
                value: settingsStore.showLinkPreviews,
                onChanged: (newValue) =>
                    settingsStore.showLinkPreviews = newValue,
              ),
              SettingsListSwitch(
                title: 'Show timeouts and bans',
                subtitle: const Text(
                  'Adds a line when a moderator times out or bans someone.',
                ),
                value: settingsStore.showModerationNotices,
                onChanged: (newValue) =>
                    settingsStore.showModerationNotices = newValue,
              ),
              SettingsListSwitch(
                title: 'Show message dividers',
                value: settingsStore.showChatMessageDividers,
                onChanged: (newValue) =>
                    settingsStore.showChatMessageDividers = newValue,
              ),
              SettingsListSelect(
                title: 'Message timestamps',
                selectedOption:
                    timestampNames[settingsStore.timestampType.index],
                options: timestampNames,
                onChanged: (newValue) => settingsStore.timestampType =
                    TimestampType.values[timestampNames.indexOf(newValue)],
              ),
            ],
          ),
          SettingsGroup(
            title: 'Delay and latency',
            children: [
              SettingsListSwitch(
                title: 'Sync message delay and stream latency',
                subtitle: const Text(
                  'Holds each message for as long as the video is behind '
                  'live, so chat matches what you see. Your own messages '
                  'show at once.',
                ),
                value: settingsStore.autoSyncChatDelay,
                onChanged: (newValue) =>
                    settingsStore.autoSyncChatDelay = newValue,
              ),
              if (!settingsStore.autoSyncChatDelay)
                SettingsListSlider(
                  title: 'Message delay',
                  trailing: '${settingsStore.chatDelay.toInt()} seconds',
                  subtitle:
                      'Adds a delay before each message is rendered in chat. '
                      '${Platform.isIOS ? '15 seconds is recommended for iOS.' : ''}',
                  value: settingsStore.chatDelay,
                  max: 30.0,
                  divisions: 30,
                  onChanged: (newValue) => settingsStore.chatDelay = newValue,
                ),
            ],
          ),
          SettingsGroup(
            title: 'Layout',
            children: [
              SettingsListSwitch(
                title: 'Move emote menu button left',
                subtitle: const Text(
                  'Places the emote menu button on the left side to avoid '
                  'accidental presses.',
                ),
                value: settingsStore.emoteMenuButtonOnLeft,
                onChanged: (newValue) =>
                    settingsStore.emoteMenuButtonOnLeft = newValue,
              ),
              SettingsListSwitch(
                title: 'Persist chat tabs',
                subtitle: const Text(
                  'Secondary chat tabs are remembered when switching '
                  'channels.',
                ),
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
            title: 'Alerts',
            children: [
              SettingsListSwitch(
                title: 'Highlight first time chatters',
                value: settingsStore.highlightFirstTimeChatter,
                onChanged: (newValue) =>
                    settingsStore.highlightFirstTimeChatter = newValue,
              ),
              SettingsListSwitch(
                title: 'Show notices',
                subtitle: const Text(
                  'Shows notices such as subs and re-subs, announcements, '
                  'and raids.',
                ),
                value: settingsStore.showUserNotices,
                onChanged: (newValue) =>
                    settingsStore.showUserNotices = newValue,
              ),
              SettingsListSwitch(
                title: 'Collapse gift bombs',
                subtitle: const Text(
                  'Folds a gift bomb of five subs or more into its first '
                  'line; tap "recipients" to see who got one.',
                ),
                value: settingsStore.collapseGiftBombs,
                onChanged: (newValue) =>
                    settingsStore.collapseGiftBombs = newValue,
              ),
              SettingsListSwitch(
                title: 'Show Hype Trains',
                subtitle: const Text(
                  'Shows Hype Train progress, levels and rewards above chat.',
                ),
                value: settingsStore.showHypeTrain,
                onChanged: (newValue) => settingsStore.showHypeTrain = newValue,
              ),
              SettingsListSwitch(
                title: 'Show community highlights',
                subtitle: const Text(
                  'Shows polls, predictions, pinned messages, gift bombs '
                  'and raids above chat.',
                ),
                value: settingsStore.showCommunityHighlights,
                onChanged: (newValue) =>
                    settingsStore.showCommunityHighlights = newValue,
              ),
              SettingsListSwitch(
                title: 'Show celebrations',
                subtitle: const Text(
                  'Plays an animation over the channel when someone gifts '
                  'subs.',
                ),
                value: settingsStore.showCelebrations,
                onChanged: (newValue) =>
                    settingsStore.showCelebrations = newValue,
              ),
              if (settingsStore.showCelebrations)
                SettingsListSelect(
                  title: 'Celebrations on video',
                  subtitle:
                      'Full plays the animation over the video. Subtle keeps '
                      'the video clear and says it with a line in chat.',
                  selectedOption: settingsStore.celebrationsOnVideo.label,
                  options: [
                    for (final option in CelebrationsOnVideo.values)
                      option.label,
                  ],
                  onChanged: (label) =>
                      settingsStore.celebrationsOnVideo = CelebrationsOnVideo
                          .values
                          .firstWhere((option) => option.label == label),
                ),
            ],
          ),
          SettingsGroup(
            title: 'Autocomplete',
            children: [
              SettingsListSwitch(
                title: 'Show autocomplete bar',
                subtitle: const Text(
                  'Shows a bar containing matching emotes and mentions while '
                  'typing.',
                ),
                value: settingsStore.autocomplete,
                onChanged: (newValue) => settingsStore.autocomplete = newValue,
              ),
            ],
          ),
          SettingsGroup(
            title: 'Landscape mode',
            children: [
              SettingsListSwitch(
                title: 'Move chat left',
                value: settingsStore.landscapeChatLeftSide,
                onChanged: (newValue) =>
                    settingsStore.landscapeChatLeftSide = newValue,
              ),
              SettingsListSwitch(
                title: 'Force vertical chat',
                subtitle: const Text(
                  'Intended for tablets and other larger displays.',
                ),
                value: settingsStore.landscapeForceVerticalChat,
                onChanged: (newValue) =>
                    settingsStore.landscapeForceVerticalChat = newValue,
              ),
              SettingsListSelect(
                title: 'Fill notch side',
                subtitle:
                    'Overrides and fills the available space in devices with '
                    'a display notch.',
                selectedOption:
                    landscapeCutoutNames[settingsStore.landscapeCutout.index],
                options: landscapeCutoutNames,
                onChanged: (newValue) => settingsStore.landscapeCutout =
                    LandscapeCutoutType.values[landscapeCutoutNames.indexOf(
                      newValue,
                    )],
              ),
              SettingsListSlider(
                title: 'Chat overlay opacity',
                trailing:
                    '${(settingsStore.fullScreenChatOverlayOpacity * 100).toStringAsFixed(0)}%',
                subtitle:
                    'Sets the opacity (transparency) of the overlay chat in '
                    'fullscreen mode.',
                value: settingsStore.fullScreenChatOverlayOpacity,
                divisions: 10,
                onChanged: (newValue) =>
                    settingsStore.fullScreenChatOverlayOpacity = newValue,
              ),
            ],
          ),
          SettingsGroup(
            title: 'Chat filters and muted keywords',
            children: [
              SettingsRow(
                glyph: SettingsGlyphKind.filter,
                title: 'Edit Chat Filters',
                value: settingsStore.chatFiltersEnabled ? 'On' : 'Off',
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
                title: 'Match whole words',
                subtitle: const Text(
                  'Only matches whole words instead of partial matches.',
                ),
                value: settingsStore.matchWholeWord,
                onChanged: (newValue) =>
                    settingsStore.matchWholeWord = newValue,
              ),
            ],
          ),
          SettingsGroup(
            title: 'Emotes and badges',
            children: [
              SettingsListSwitch(
                title: 'Show Twitch emotes',
                value: settingsStore.showTwitchEmotes,
                onChanged: (newValue) =>
                    settingsStore.showTwitchEmotes = newValue,
              ),
              SettingsListSwitch(
                title: 'Show Twitch badges',
                value: settingsStore.showTwitchBadges,
                onChanged: (newValue) =>
                    settingsStore.showTwitchBadges = newValue,
              ),
              SettingsListSwitch(
                title: 'Show 7TV emotes',
                value: settingsStore.show7TVEmotes,
                onChanged: (newValue) => settingsStore.show7TVEmotes = newValue,
              ),
              SettingsListSwitch(
                title: 'Show BTTV emotes',
                value: settingsStore.showBTTVEmotes,
                onChanged: (newValue) =>
                    settingsStore.showBTTVEmotes = newValue,
              ),
              SettingsListSwitch(
                title: 'Show BTTV badges',
                value: settingsStore.showBTTVBadges,
                onChanged: (newValue) =>
                    settingsStore.showBTTVBadges = newValue,
              ),
              SettingsListSwitch(
                title: 'Show FFZ emotes',
                value: settingsStore.showFFZEmotes,
                onChanged: (newValue) => settingsStore.showFFZEmotes = newValue,
              ),
              SettingsListSwitch(
                title: 'Show FFZ badges',
                value: settingsStore.showFFZBadges,
                onChanged: (newValue) => settingsStore.showFFZBadges = newValue,
              ),
            ],
          ),
          SettingsGroup(
            title: 'Recent messages',
            children: [
              SettingsListSwitch(
                title: 'Fallback chat history (third-party)',
                subtitle: Text.rich(
                  TextSpan(
                    text:
                        'When Twitch\'s own chat history is unavailable, '
                        'fails or is empty, loads recent messages from ',
                    children: [
                      TextSpan(
                        text: 'https://recent-messages.robotty.de/',
                        style: TextStyle(
                          color: SettingsColors.accentOf(context),
                          decoration: TextDecoration.underline,
                          decorationColor: SettingsColors.accentOf(context),
                        ),
                        recognizer: _recentLink
                          ..onTap = () => launchSettingsLink(
                            'https://recent-messages.robotty.de/',
                            external: settingsStore.launchUrlExternal,
                          ),
                      ),
                      const TextSpan(
                        text: ', which then receives the channel name.',
                      ),
                    ],
                  ),
                ),
                value: settingsStore.showRecentMessages,
                onChanged: (newValue) =>
                    settingsStore.showRecentMessages = newValue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
            title: 'Preview',
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
                                const TextSpan(
                                  text: ' Badge and emote preview. ',
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
                            "Hello! Here's a text preview.",
                            textScaler: store.messageScale.textScaler,
                          ),
                          SizedBox(height: store.messageSpacing),
                          Text(
                            'And another for spacing without an emote!',
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
