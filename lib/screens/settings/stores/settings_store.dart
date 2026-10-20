import 'package:frosty/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:frosty/screens/channel/video/captions.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

part 'settings_store.g.dart';

@JsonSerializable()
class SettingsStore extends _SettingsStoreBase with _$SettingsStore {
  SettingsStore();

  factory SettingsStore.fromJson(Map<String, dynamic> json) =>
      _$SettingsStoreFromJson(json).._applyChatSyncDefault();
  Map<String, dynamic> toJson() => _$SettingsStoreToJson(this);
}

abstract class _SettingsStoreBase with Store {
  // * General Settings
  // Theme defaults
  static const defaultThemeType = ThemeType.system;

  /// Electric lime. Was Twitch's own `0xff9146ff`; the fork does not borrow the
  /// identity it is trying to move away from. Users who already picked a colour
  /// keep it — this only applies to fresh installs and to a settings reset.
  static const defaultAccentColor = 0xffc8ff3d;

  // Stream card defaults
  static const defaultShowThumbnails = true;
  static const defaultLargeStreamCard = false;

  // Browse defaults ('' is every language)
  static const defaultStreamLanguage = '';
  static const defaultHiddenContentLabels = <String>[];
  static const defaultStartTab = HomeTab.following;
  static const defaultFollowedSort = FollowedSort.viewers;

  // Links defaults
  static const defaultLaunchUrlExternal = false;

  // Notifications defaults
  static const defaultMentionNotifications = true;

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

  /// The tab the app opens on (Following falls back to Top when logged
  /// out).
  @JsonKey(defaultValue: defaultStartTab, unknownEnumValue: HomeTab.following)
  @observable
  var startTab = defaultStartTab;

  /// The order of the live channels in Following, remembered like Twitch's
  /// "Sorted by".
  @JsonKey(
    defaultValue: defaultFollowedSort,
    unknownEnumValue: FollowedSort.viewers,
  )
  @observable
  var followedSort = defaultFollowedSort;

  /// The language Top and category lists show (Helix `language`).
  @JsonKey(defaultValue: defaultStreamLanguage)
  @observable
  var streamLanguage = defaultStreamLanguage;

  /// Content classification labels (ids) whose streams are left out of
  /// browsing; followed channels always show.
  @JsonKey(defaultValue: defaultHiddenContentLabels)
  @observable
  List<String> hiddenContentLabels = defaultHiddenContentLabels;

  // Links options
  @JsonKey(defaultValue: defaultLaunchUrlExternal)
  @observable
  var launchUrlExternal = defaultLaunchUrlExternal;

  // Notifications options

  /// A notice when someone mentions the viewer in a chat they are
  /// connected to while the app is in the background or in PiP.
  @JsonKey(defaultValue: defaultMentionNotifications)
  @observable
  var mentionNotifications = defaultMentionNotifications;

  @action
  void resetGeneralSettings() {
    themeType = defaultThemeType;
    accentColor = defaultAccentColor;

    largeStreamCard = defaultLargeStreamCard;
    showThumbnails = defaultShowThumbnails;

    streamLanguage = defaultStreamLanguage;
    hiddenContentLabels = defaultHiddenContentLabels;
    startTab = defaultStartTab;
    followedSort = defaultFollowedSort;

    launchUrlExternal = defaultLaunchUrlExternal;

    mentionNotifications = defaultMentionNotifications;
  }

  // * Video Settings
  // Player defaults
  static const defaultShowVideo = true;
  static const defaultPortraitVideoScale = 1.0;
  static const defaultShowCaptions = false;
  static const defaultCaptionSize = CaptionSize.medium;
  static const defaultCaptionBackground = CaptionBackground.black;
  static const defaultCaptionLanguage = '';
  static const defaultWarnMatureContent = true;
  static const defaultDefaultToHighestQuality = false;
  static const defaultUseTextureRendering = true;
  static const defaultKeepScreenAwake = true;
  static const defaultBackgroundAudio = false;
  static const defaultPlayerEngine = PlayerEngine.ivs;
  static const defaultLiveCatchUpMode = LiveCatchUpMode.speedUp;
  static const defaultBufferProfile = BufferProfile.standard;
  static const defaultVodAutoplay = VodAutoplay.always;

  // Overlay defaults
  static const defaultShowOverlay = true;
  static const defaultToggleableOverlay = false;
  static const defaultShowLatency = true;

  // Player options
  @JsonKey(defaultValue: defaultShowVideo)
  @observable
  var showVideo = defaultShowVideo;

  /// Warn before entering a channel with content classification labels.
  @JsonKey(defaultValue: defaultWarnMatureContent)
  @observable
  var warnMatureContent = defaultWarnMatureContent;

  /// Closed captions over the video, when a stream has them (IVS only).
  @JsonKey(defaultValue: defaultShowCaptions)
  @observable
  var showCaptions = defaultShowCaptions;

  /// The caption line's size (Twitch's is Medium).
  @JsonKey(
    defaultValue: defaultCaptionSize,
    unknownEnumValue: CaptionSize.medium,
  )
  @observable
  var captionSize = defaultCaptionSize;

  /// What sits behind the caption line (Twitch's is Black).
  @JsonKey(
    defaultValue: defaultCaptionBackground,
    unknownEnumValue: CaptionBackground.black,
  )
  @observable
  var captionBackground = defaultCaptionBackground;

  /// The language of the caption track last picked, chosen again when a
  /// stream offers it ('' for the player's first track).
  @JsonKey(defaultValue: defaultCaptionLanguage)
  @observable
  var captionLanguage = defaultCaptionLanguage;

  /// The portrait video's width share (smaller leaves more room to chat).
  @JsonKey(defaultValue: defaultPortraitVideoScale)
  @observable
  var portraitVideoScale = defaultPortraitVideoScale;

  @JsonKey(defaultValue: defaultDefaultToHighestQuality)
  @observable
  var defaultToHighestQuality = defaultDefaultToHighestQuality;

  @JsonKey(defaultValue: defaultUseTextureRendering)
  @observable
  var useTextureRendering = defaultUseTextureRendering;

  @JsonKey(defaultValue: defaultKeepScreenAwake)
  @observable
  var keepScreenAwake = defaultKeepScreenAwake;

  /// Keeps a live stream's sound playing outside the app, with a media
  /// notification (Android).
  @JsonKey(defaultValue: defaultBackgroundAudio)
  @observable
  var backgroundAudio = defaultBackgroundAudio;

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

  /// When the next video starts by itself at the end of a VOD (Twitch's
  /// "Video Autoplaying").
  @JsonKey(
    defaultValue: defaultVodAutoplay,
    unknownEnumValue: VodAutoplay.always,
  )
  @observable
  var vodAutoplay = defaultVodAutoplay;

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
    portraitVideoScale = defaultPortraitVideoScale;
    showCaptions = defaultShowCaptions;
    captionSize = defaultCaptionSize;
    captionBackground = defaultCaptionBackground;
    captionLanguage = defaultCaptionLanguage;
    warnMatureContent = defaultWarnMatureContent;
    defaultToHighestQuality = defaultDefaultToHighestQuality;
    useTextureRendering = defaultUseTextureRendering;
    keepScreenAwake = defaultKeepScreenAwake;
    backgroundAudio = defaultBackgroundAudio;
    playerEngine = defaultPlayerEngine;
    liveCatchUpMode = defaultLiveCatchUpMode;
    bufferProfile = defaultBufferProfile;
    vodAutoplay = defaultVodAutoplay;

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
  static const defaultShowDeletedMessages = true;
  static const defaultShowModerationNotices = true;
  static const defaultAnimateEmotes = true;
  static const defaultShowGifs = true;
  static const defaultAnimateGifs = true;
  static const defaultShowLinkPreviews = true;
  static const defaultShowChatMessageDividers = false;
  static const defaultTimestampType = TimestampType.disabled;

  // Delay defaults
  /// Chat waits as long as the video is behind live, so answers to the
  /// streamer never show before the question (see [chatSyncDefaultApplied]).
  static const defaultAutoSyncChatDelay = true;
  static const defaultChatDelay = 0.0;

  // Alert defaults
  static const defaultHighlightFirstTimeChatter = true;
  static const defaultShowUserNotices = true;
  static const defaultCollapseGiftBombs = false;
  static const defaultShowHypeTrain = true;
  static const defaultShowCommunityHighlights = true;
  static const defaultShowCelebrations = true;

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

  // Twitch's chat filters: off until turned on, every category then on.
  static const defaultChatFiltersEnabled = false;
  static const defaultChatFilterDiscrimination = true;
  static const defaultChatFilterSexual = true;
  static const defaultChatFilterHarassment = true;
  static const defaultChatFilterProfanity = true;

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
  /// Saved under a new key since the default became true: older installs hold
  /// `showDeletedMessages: false`, mostly the old default nobody chose. The old
  /// key is ignored, so every install shows deleted messages without a tap
  /// once, including one whose owner had turned them off on purpose: they have
  /// to turn the switch off again. Choices saved after that are kept.
  @JsonKey(
    name: 'revealDeletedMessages',
    defaultValue: defaultShowDeletedMessages,
  )
  @observable
  var showDeletedMessages = defaultShowDeletedMessages;

  /// Animated emotes move in chat; off shows their first frame.
  @JsonKey(defaultValue: defaultAnimateEmotes)
  @observable
  var animateEmotes = defaultAnimateEmotes;

  /// GIFs sent with Twitch's GIF keyboard are drawn in chat; off shows their
  /// title instead (Twitch's "Show GIFs in Chat").
  @JsonKey(defaultValue: defaultShowGifs)
  @observable
  var showGifs = defaultShowGifs;

  /// Chat GIFs play; off shows their first frame (Twitch's "Animated GIFs").
  @JsonKey(defaultValue: defaultAnimateGifs)
  @observable
  var animateGifs = defaultAnimateGifs;

  /// A card under chat messages that link a clip or a video.
  @JsonKey(defaultValue: defaultShowLinkPreviews)
  @observable
  var showLinkPreviews = defaultShowLinkPreviews;

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

  /// Whether the switch of [autoSyncChatDelay] to on by default reached
  /// these settings. Saved settings always store the old `false` default,
  /// so it is turned on once for settings that never chose a delay (a
  /// manual delay is kept); turning it off afterwards sticks.
  @JsonKey(defaultValue: false)
  var chatSyncDefaultApplied = false;

  void _applyChatSyncDefault() {
    if (chatSyncDefaultApplied) return;
    chatSyncDefaultApplied = true;
    if (chatDelay == 0) autoSyncChatDelay = true;
  }

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

  /// Whether a gift bomb shows only its header. Off by default: Twitch shows
  /// the header and then one line per gifted sub.
  @JsonKey(defaultValue: defaultCollapseGiftBombs)
  @observable
  var collapseGiftBombs = defaultCollapseGiftBombs;

  @JsonKey(defaultValue: defaultShowHypeTrain)
  @observable
  var showHypeTrain = defaultShowHypeTrain;

  @JsonKey(defaultValue: defaultShowCommunityHighlights)
  @observable
  var showCommunityHighlights = defaultShowCommunityHighlights;

  /// Whether Twitch's celebration animations play over the channel.
  ///
  /// Twitch offers the same switch; a full-screen animation on every gifted
  /// sub is not to everyone's taste, and on a busy channel it is frequent.
  @JsonKey(defaultValue: defaultShowCelebrations)
  @observable
  var showCelebrations = defaultShowCelebrations;

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

  /// Hides the words AutoMod rates 3 or more in a category turned on below,
  /// like Twitch's "Enable filtering in chat".
  @JsonKey(defaultValue: defaultChatFiltersEnabled)
  @observable
  bool chatFiltersEnabled = defaultChatFiltersEnabled;

  @JsonKey(defaultValue: defaultChatFilterDiscrimination)
  @observable
  bool chatFilterDiscrimination = defaultChatFilterDiscrimination;

  @JsonKey(defaultValue: defaultChatFilterSexual)
  @observable
  bool chatFilterSexual = defaultChatFilterSexual;

  @JsonKey(defaultValue: defaultChatFilterHarassment)
  @observable
  bool chatFilterHarassment = defaultChatFilterHarassment;

  @JsonKey(defaultValue: defaultChatFilterProfanity)
  @observable
  bool chatFilterProfanity = defaultChatFilterProfanity;

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
    showGifs = defaultShowGifs;
    animateGifs = defaultAnimateGifs;
    showLinkPreviews = defaultShowLinkPreviews;
    showChatMessageDividers = defaultShowChatMessageDividers;
    timestampType = defaultTimestampType;

    autoSyncChatDelay = defaultAutoSyncChatDelay;
    chatDelay = defaultChatDelay;
    syncedChatDelay = defaultChatDelay;

    highlightFirstTimeChatter = defaultHighlightFirstTimeChatter;
    showUserNotices = defaultShowUserNotices;
    collapseGiftBombs = defaultCollapseGiftBombs;
    showHypeTrain = defaultShowHypeTrain;
    showCommunityHighlights = defaultShowCommunityHighlights;
    showCelebrations = defaultShowCelebrations;

    emoteMenuButtonOnLeft = defaultEmoteMenuButtonOnLeft;

    landscapeChatLeftSide = defaultLandscapeChatLeftSide;
    landscapeForceVerticalChat = defaultLandscapeForceVerticalChat;
    landscapeCutout = defaultLandscapeCutout;
    chatWidth = defaultChatWidth;
    fullScreenChatOverlayOpacity = defaultFullScreenChatOverlayOpacity;

    mutedWords = defaultMutedWords;
    matchWholeWord = defaultMatchWholeWord;

    chatFiltersEnabled = defaultChatFiltersEnabled;
    chatFilterDiscrimination = defaultChatFilterDiscrimination;
    chatFilterSexual = defaultChatFilterSexual;
    chatFilterHarassment = defaultChatFilterHarassment;
    chatFilterProfanity = defaultChatFilterProfanity;

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

/// The home tabs, as named in the bottom bar.
enum HomeTab {
  following('Following'),
  top('Top'),
  search('Search');

  const HomeTab(this.label);

  final String label;

  /// Where this tab sits in the bar; logged out, there is no Following.
  int indexWhen({required bool loggedIn}) =>
      loggedIn ? index : (this == following ? 0 : index - 1);
}

/// How Following orders its live channels. Twitch's other order,
/// "Recommended For You", is its own server ranking, which Helix does not
/// give.
enum FollowedSort {
  viewers('Viewers (High to Low)'),
  recent('Recently Started'),
  name('Name (A-Z)'),
  category('Category');

  const FollowedSort(this.label);

  final String label;
}

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

/// When the next video plays by itself at the end of a VOD, with Twitch's
/// options and wording.
enum VodAutoplay {
  /// Twitch's default.
  always('Mobile data & Wi-Fi'),
  wifiOnly('Wi-Fi Only'),
  never('Never');

  const VodAutoplay(this.label);

  final String label;
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
