import 'package:frosty/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

part 'settings_store.g.dart';

@JsonSerializable()
class SettingsStore extends _SettingsStoreBase with _$SettingsStore {
  SettingsStore();

  factory SettingsStore.fromJson(Map<String, dynamic> json) =>
      _$SettingsStoreFromJson(json);
  Map<String, dynamic> toJson() => _$SettingsStoreToJson(this);
}

abstract class _SettingsStoreBase with Store {
  // * General Settings
  // Theme defaults
  static const defaultThemeType = ThemeType.system;
  static const defaultAccentColor = 0xff9146ff;

  // Stream card defaults
  static const defaultShowThumbnails = true;
  static const defaultLargeStreamCard = false;

  // Browse defaults ('' is every language)
  static const defaultStreamLanguage = '';

  // Links defaults
  static const defaultLaunchUrlExternal = false;

  // Theme options
  @JsonKey(defaultValue: defaultThemeType, unknownEnumValue: ThemeType.system)
  @observable
  var themeType = defaultThemeType;

  @JsonKey(defaultValue: defaultAccentColor)
  @observable
  var accentColor = defaultAccentColor;

  // Stream card options
  @JsonKey(defaultValue: defaultShowThumbnails)
  @observable
  var showThumbnails = defaultShowThumbnails;

  @JsonKey(defaultValue: defaultLargeStreamCard)
  @observable
  var largeStreamCard = defaultLargeStreamCard;

  /// The language Top and category lists show (Helix `language`).
  @JsonKey(defaultValue: defaultStreamLanguage)
  @observable
  var streamLanguage = defaultStreamLanguage;

  // Links options
  @JsonKey(defaultValue: defaultLaunchUrlExternal)
  @observable
  var launchUrlExternal = defaultLaunchUrlExternal;

  @action
  void resetGeneralSettings() {
    themeType = defaultThemeType;
    accentColor = defaultAccentColor;

    largeStreamCard = defaultLargeStreamCard;
    showThumbnails = defaultShowThumbnails;

    streamLanguage = defaultStreamLanguage;

    launchUrlExternal = defaultLaunchUrlExternal;
  }

  // * Video Settings
  // Player defaults
  static const defaultShowVideo = true;
  static const defaultDefaultToHighestQuality = false;
  static const defaultUseTextureRendering = true;
  static const defaultKeepScreenAwake = true;
  static const defaultPlayerEngine = PlayerEngine.ivs;
  static const defaultLiveCatchUpMode = LiveCatchUpMode.speedUp;
  static const defaultBufferProfile = BufferProfile.standard;

  // Overlay defaults
  static const defaultShowOverlay = true;
  static const defaultToggleableOverlay = false;
  static const defaultShowLatency = true;

  // Player options
  @JsonKey(defaultValue: defaultShowVideo)
  @observable
  var showVideo = defaultShowVideo;

  @JsonKey(defaultValue: defaultDefaultToHighestQuality)
  @observable
  var defaultToHighestQuality = defaultDefaultToHighestQuality;

  @JsonKey(defaultValue: defaultUseTextureRendering)
  @observable
  var useTextureRendering = defaultUseTextureRendering;

  @JsonKey(defaultValue: defaultKeepScreenAwake)
  @observable
  var keepScreenAwake = defaultKeepScreenAwake;

  @JsonKey(
    defaultValue: defaultPlayerEngine,
    unknownEnumValue: PlayerEngine.ivs,
  )
  @observable
  var playerEngine = defaultPlayerEngine;

  /// How the IVS player gets back to the live edge after falling behind.
  @JsonKey(
    defaultValue: defaultLiveCatchUpMode,
    unknownEnumValue: LiveCatchUpMode.speedUp,
  )
  @observable
  var liveCatchUpMode = defaultLiveCatchUpMode;

  /// IVS low-latency buffer targets.
  @JsonKey(
    defaultValue: defaultBufferProfile,
    unknownEnumValue: BufferProfile.standard,
  )
  @observable
  var bufferProfile = defaultBufferProfile;

  // Overlay options
  @JsonKey(defaultValue: defaultShowOverlay)
  @observable
  var showOverlay = defaultShowOverlay;

  @JsonKey(defaultValue: defaultToggleableOverlay)
  @observable
  var toggleableOverlay = defaultToggleableOverlay;

  @JsonKey(defaultValue: defaultShowLatency)
  @observable
  var showLatency = defaultShowLatency;

  @action
  void resetVideoSettings() {
    showVideo = defaultShowVideo;
    defaultToHighestQuality = defaultDefaultToHighestQuality;
    useTextureRendering = defaultUseTextureRendering;
    keepScreenAwake = defaultKeepScreenAwake;
    playerEngine = defaultPlayerEngine;
    liveCatchUpMode = defaultLiveCatchUpMode;
    bufferProfile = defaultBufferProfile;

    showOverlay = defaultShowOverlay;
    toggleableOverlay = defaultToggleableOverlay;
    showLatency = defaultShowLatency;
  }

  // * Chat Settings
  // Message sizing defaults
  static const defaultBadgeScale = 1.0;
  static const defaultEmoteScale = 1.0;
  static const defaultMessageScale = 1.0;
  static const defaultMessageSpacing = 8.0;
  static const defaultFontSize = 12.0;

  // Message appearance defaults
  static const defaultShowDeletedMessages = false;
  static const defaultShowModerationNotices = true;
  static const defaultAnimateEmotes = true;
  static const defaultShowChatMessageDividers = false;
  static const defaultTimestampType = TimestampType.disabled;

  // Delay defaults
  static const defaultAutoSyncChatDelay = false;
  static const defaultChatDelay = 0.0;

  // Alert defaults
  static const defaultHighlightFirstTimeChatter = true;
  static const defaultShowUserNotices = true;
  static const defaultShowHypeTrain = true;
  static const defaultShowCommunityHighlights = true;

  // Layout defaults
  static const defaultEmoteMenuButtonOnLeft = false;

  // Landscape mode defaults
  static const defaultLandscapeChatLeftSide = false;
  static const defaultLandscapeForceVerticalChat = false;
  static const defaultLandscapeCutout = LandscapeCutoutType.none;
  static const defaultChatWidth = 0.2;
  static const defaultFullScreenChatOverlayOpacity = 0.5;

  // mute words defaults
  static const defaultMutedWords = <String>[];
  static const defaultMatchWholeWord = true;

  // Autocomplete defaults
  static const defaultAutocomplete = true;

  // Emotes and badges defaults
  static const defaultShowTwitchEmotes = true;
  static const defaultShowTwitchBadges = true;
  static const defaultShow7TVEmotes = true;
  static const defaultShowBTTVEmotes = true;
  static const defaultShowBTTVBadges = true;
  static const defaultShowFFZEmotes = true;
  static const defaultShowFFZBadges = true;

  // Recent messages defaults
  static const defaultShowRecentMessages = false;

  // Chat tabs defaults
  static const defaultPersistChatTabs = true;
  static const defaultSecondaryTabs = <PersistedChatTab>[];

  // Message sizing options
  @JsonKey(defaultValue: defaultBadgeScale)
  @observable
  var badgeScale = defaultBadgeScale;

  @JsonKey(defaultValue: defaultEmoteScale)
  @observable
  var emoteScale = defaultEmoteScale;

  @JsonKey(defaultValue: defaultMessageScale)
  @observable
  var messageScale = defaultMessageScale;

  @JsonKey(defaultValue: defaultMessageSpacing)
  @observable
  var messageSpacing = defaultMessageSpacing;

  @JsonKey(defaultValue: defaultFontSize)
  @observable
  var fontSize = defaultFontSize;

  // Message appearance options
  @JsonKey(defaultValue: defaultShowDeletedMessages)
  @observable
  var showDeletedMessages = defaultShowDeletedMessages;

  /// Animated emotes move in chat; off shows their first frame.
  @JsonKey(defaultValue: defaultAnimateEmotes)
  @observable
  var animateEmotes = defaultAnimateEmotes;

  /// A line in chat when someone is timed out or banned.
  @JsonKey(defaultValue: defaultShowModerationNotices)
  @observable
  var showModerationNotices = defaultShowModerationNotices;

  @JsonKey(defaultValue: defaultShowChatMessageDividers)
  @observable
  var showChatMessageDividers = defaultShowChatMessageDividers;

  @JsonKey(
    defaultValue: defaultTimestampType,
    unknownEnumValue: TimestampType.disabled,
  )
  @observable
  var timestampType = defaultTimestampType;

  // Delay options
  @JsonKey(defaultValue: defaultAutoSyncChatDelay)
  @observable
  var autoSyncChatDelay = defaultAutoSyncChatDelay;

  @JsonKey(defaultValue: defaultChatDelay)
  @observable
  var chatDelay = defaultChatDelay;

  @JsonKey(includeFromJson: false, includeToJson: false)
  @observable
  var syncedChatDelay = defaultChatDelay;

  @computed
  double get effectiveChatDelay =>
      autoSyncChatDelay ? syncedChatDelay : chatDelay;

  // Alert options
  @JsonKey(defaultValue: defaultHighlightFirstTimeChatter)
  @observable
  var highlightFirstTimeChatter = defaultHighlightFirstTimeChatter;

  @JsonKey(defaultValue: defaultShowUserNotices)
  @observable
  var showUserNotices = defaultShowUserNotices;

  @JsonKey(defaultValue: defaultShowHypeTrain)
  @observable
  var showHypeTrain = defaultShowHypeTrain;

  @JsonKey(defaultValue: defaultShowCommunityHighlights)
  @observable
  var showCommunityHighlights = defaultShowCommunityHighlights;

  // Layout options
  @JsonKey(defaultValue: defaultEmoteMenuButtonOnLeft)
  @observable
  var emoteMenuButtonOnLeft = defaultEmoteMenuButtonOnLeft;

  // Landscape mode options
  @JsonKey(defaultValue: defaultLandscapeChatLeftSide)
  @observable
  var landscapeChatLeftSide = defaultLandscapeChatLeftSide;

  @JsonKey(defaultValue: defaultLandscapeForceVerticalChat)
  @observable
  var landscapeForceVerticalChat = defaultLandscapeForceVerticalChat;

  @JsonKey(defaultValue: defaultLandscapeCutout)
  @observable
  var landscapeCutout = defaultLandscapeCutout;

  @JsonKey(defaultValue: defaultChatWidth)
  @observable
  var chatWidth = defaultChatWidth;

  @JsonKey(defaultValue: defaultFullScreenChatOverlayOpacity)
  @observable
  var fullScreenChatOverlayOpacity = defaultFullScreenChatOverlayOpacity;

  // Autocomplete options
  @JsonKey(defaultValue: defaultAutocomplete)
  @observable
  var autocomplete = defaultAutocomplete;

  // Emotes and badges
  @JsonKey(defaultValue: defaultShowTwitchEmotes)
  @observable
  var showTwitchEmotes = defaultShowTwitchEmotes;

  @JsonKey(defaultValue: defaultShowTwitchBadges)
  @observable
  var showTwitchBadges = defaultShowTwitchBadges;

  @JsonKey(defaultValue: defaultShow7TVEmotes)
  @observable
  var show7TVEmotes = defaultShow7TVEmotes;

  @JsonKey(defaultValue: defaultShowBTTVEmotes)
  @observable
  var showBTTVEmotes = defaultShowBTTVEmotes;

  @JsonKey(defaultValue: defaultShowBTTVBadges)
  @observable
  var showBTTVBadges = defaultShowBTTVBadges;

  @JsonKey(defaultValue: defaultShowFFZEmotes)
  @observable
  var showFFZEmotes = defaultShowFFZEmotes;

  @JsonKey(defaultValue: defaultShowFFZBadges)
  @observable
  var showFFZBadges = defaultShowFFZBadges;

  // Recent messages
  @JsonKey(defaultValue: defaultShowRecentMessages)
  @observable
  var showRecentMessages = defaultShowRecentMessages;

  // Chat tabs
  @JsonKey(defaultValue: defaultPersistChatTabs)
  @observable
  var persistChatTabs = defaultPersistChatTabs;

  @JsonKey(defaultValue: defaultSecondaryTabs)
  @observable
  var secondaryTabs = defaultSecondaryTabs;

  @JsonKey(defaultValue: defaultMutedWords)
  @observable
  List<String> mutedWords = defaultMutedWords;

  @JsonKey(defaultValue: defaultMatchWholeWord)
  @observable
  bool matchWholeWord = defaultMatchWholeWord;

  @action
  void resetChatSettings() {
    badgeScale = defaultBadgeScale;
    emoteScale = defaultEmoteScale;
    messageScale = defaultMessageScale;
    messageSpacing = defaultMessageSpacing;
    fontSize = defaultFontSize;

    showDeletedMessages = defaultShowDeletedMessages;
    showModerationNotices = defaultShowModerationNotices;
    animateEmotes = defaultAnimateEmotes;
    showChatMessageDividers = defaultShowChatMessageDividers;
    timestampType = defaultTimestampType;

    autoSyncChatDelay = defaultAutoSyncChatDelay;
    chatDelay = defaultChatDelay;
    syncedChatDelay = defaultChatDelay;

    highlightFirstTimeChatter = defaultHighlightFirstTimeChatter;
    showUserNotices = defaultShowUserNotices;
    showHypeTrain = defaultShowHypeTrain;
    showCommunityHighlights = defaultShowCommunityHighlights;

    emoteMenuButtonOnLeft = defaultEmoteMenuButtonOnLeft;

    landscapeChatLeftSide = defaultLandscapeChatLeftSide;
    landscapeForceVerticalChat = defaultLandscapeForceVerticalChat;
    landscapeCutout = defaultLandscapeCutout;
    chatWidth = defaultChatWidth;
    fullScreenChatOverlayOpacity = defaultFullScreenChatOverlayOpacity;

    mutedWords = defaultMutedWords;
    matchWholeWord = defaultMatchWholeWord;

    autocomplete = defaultAutocomplete;

    showTwitchEmotes = defaultShowTwitchEmotes;
    showTwitchBadges = defaultShowTwitchBadges;
    show7TVEmotes = defaultShow7TVEmotes;
    showBTTVEmotes = defaultShowBTTVEmotes;
    showBTTVBadges = defaultShowBTTVBadges;
    showFFZEmotes = defaultShowFFZEmotes;
    showFFZBadges = defaultShowFFZBadges;

    showRecentMessages = defaultShowRecentMessages;

    persistChatTabs = defaultPersistChatTabs;
    secondaryTabs = defaultSecondaryTabs;
  }

  // * Other settings
  static const defaultShareCrashLogsAndAnalytics = true;

  @JsonKey(defaultValue: defaultShareCrashLogsAndAnalytics)
  @observable
  var shareCrashLogsAndAnalytics = defaultShareCrashLogsAndAnalytics;

  @action
  void resetOtherSettings() {
    shareCrashLogsAndAnalytics = defaultShareCrashLogsAndAnalytics;
  }

  // * Global configs
  static const defaultFullScreen = false;
  static const defaultFullScreenChatOverlay = false;
  static const defaultPinnedChannelIds = <String>[];

  @JsonKey(defaultValue: defaultFullScreen)
  @observable
  var fullScreen = defaultFullScreen;

  @JsonKey(defaultValue: defaultFullScreenChatOverlay)
  @observable
  var fullScreenChatOverlay = defaultFullScreenChatOverlay;

  @JsonKey(defaultValue: defaultPinnedChannelIds)
  @observable
  var pinnedChannelIds = defaultPinnedChannelIds;

  @action
  void resetGlobalConfigs() {
    fullScreen = defaultFullScreen;
    fullScreenChatOverlay = defaultFullScreenChatOverlay;
    pinnedChannelIds = defaultPinnedChannelIds;
  }

  @action
  void resetAllSettings() {
    resetGeneralSettings();
    resetVideoSettings();
    resetChatSettings();
    resetOtherSettings();
    resetGlobalConfigs();
  }
}

const themeNames = ['System', 'Light', 'Dark'];

enum ThemeType { system, light, dark }

const timestampNames = ['Disabled', '12-hour', '24-hour'];

enum TimestampType { disabled, twelve, twentyFour }

const landscapeCutoutNames = ['None', 'Left', 'Right', 'Both'];

enum LandscapeCutoutType { none, left, right, both }

const playerEngineNames = ['IVS (Twitch player)', 'Native (mpv)', 'Twitch web'];

const liveCatchUpModeNames = ['Speed up', 'Jump to live'];

/// How the IVS player returns to the live edge after falling behind.
enum LiveCatchUpMode {
  /// Plays slightly faster until it is back at the live edge (official app).
  speedUp,

  /// Skips straight to the live edge after a rebuffer (previous behaviour).
  jumpToLive,
}

const bufferProfileNames = ['Standard', 'Ultra'];

/// IVS low-latency buffer targets.
enum BufferProfile {
  /// IVS defaults, like the official app.
  standard,

  /// Smaller buffer for even lower latency; may rebuffer more.
  ultra,
}

/// Which engine plays the live video.
enum PlayerEngine {
  /// Amazon IVS player — the exact engine the official Twitch app uses, for
  /// exact-parity low latency. Default.
  ivs,

  /// Native low-latency HLS player (media_kit / mpv). Fallback.
  nativeLowLatency,

  /// Original Twitch web embed in a WebView. Fallback.
  twitchWeb,
}
