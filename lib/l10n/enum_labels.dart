import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/l10n/app_localizations.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/video/captions.dart';
import 'package:onset/screens/home/stores/home_store.dart';
import 'package:onset/screens/settings/account/account_settings.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/release_notes.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/services/notifications/activity_log.dart';

/// The names the viewer reads for the app's enums, in their language. One
/// exhaustive switch per enum: a new value without a name does not compile.

extension AppLanguageLabel on AppLanguage {
  /// Its option in Settings › General › Language: the languages by their
  /// own names (endonyms), whatever the language on screen.
  String label(AppLocalizations l) => switch (this) {
    AppLanguage.system => l.appLanguageSystem,
    AppLanguage.en => l.languageNameEnglish,
    AppLanguage.fr => l.languageNameFrench,
  };

  /// The language named inside a sentence of the language on screen
  /// (« anglais » in French), for the explicit languages; System keeps its
  /// option name.
  String nameInText(AppLocalizations l) => switch (this) {
    AppLanguage.system => l.appLanguageSystem,
    AppLanguage.en => l.languageInTextEnglish,
    AppLanguage.fr => l.languageInTextFrench,
  };
}

extension ThemeTypeLabel on ThemeType {
  String label(AppLocalizations l) => switch (this) {
    ThemeType.system => l.themeSystem,
    ThemeType.light => l.themeLight,
    ThemeType.dark => l.themeDark,
  };
}

extension ShellSectionLabel on ShellSection {
  String label(AppLocalizations l) => switch (this) {
    ShellSection.home => l.shellSectionHome,
    ShellSection.browse => l.shellSectionBrowse,
    ShellSection.activity => l.shellSectionActivity,
    ShellSection.profile => l.shellSectionProfile,
  };
}

extension HomeFeedLabel on HomeFeed {
  String label(AppLocalizations l) => switch (this) {
    HomeFeed.following => l.shellFeedFollowing,
    HomeFeed.live => l.shellFeedLive,
    HomeFeed.clips => l.shellFeedClips,
  };
}

extension BrowseTabLabel on BrowseTab {
  String label(AppLocalizations l) => switch (this) {
    BrowseTab.categories => l.shellBrowseCategories,
    BrowseTab.live => l.shellBrowseLiveChannels,
  };
}

extension ActivityTabLabel on ActivityTab {
  String label(AppLocalizations l) => switch (this) {
    ActivityTab.notifications => l.shellActivityNotifications,
    ActivityTab.whispers => l.shellWhispers,
  };
}

extension HomeTabLabel on HomeTab {
  /// Its option in Settings › General › "Open the app on": the shell's own
  /// names for these tabs.
  String label(AppLocalizations l) => switch (this) {
    HomeTab.following => l.shellFeedFollowing,
    HomeTab.live => l.shellFeedLive,
    HomeTab.clips => l.shellFeedClips,
    HomeTab.browse => l.shellSectionBrowse,
  };
}

/// The category shown under a notification in Activity, like Twitch's.
extension ActivityKindLabel on ActivityKind {
  String label(AppLocalizations l) => switch (this) {
    ActivityKind.live => l.activityKindLive,
    ActivityKind.mention => l.activityKindMention,
    ActivityKind.reminder => l.activityKindReminder,
  };
}

extension ClipPeriodLabel on ClipPeriod {
  String label(AppLocalizations l) => switch (this) {
    ClipPeriod.lastDay => l.clipPeriodLastDay,
    ClipPeriod.lastWeek => l.clipPeriodLastWeek,
    ClipPeriod.lastMonth => l.clipPeriodLastMonth,
    ClipPeriod.allTime => l.clipPeriodAllTime,
  };
}

extension ClipSortLabel on ClipSort {
  String label(AppLocalizations l) => switch (this) {
    ClipSort.top => l.clipSortTop,
    ClipSort.trending => l.clipSortTrending,
  };
}

extension StreamSortLabel on StreamSort {
  String label(AppLocalizations l) => switch (this) {
    StreamSort.viewersHigh => l.streamSortViewersHigh,
    StreamSort.recommended => l.streamSortRecommended,
    StreamSort.viewersLow => l.streamSortViewersLow,
    StreamSort.recent => l.streamSortRecent,
  };
}

extension FollowedSortLabel on FollowedSort {
  String label(AppLocalizations l) => switch (this) {
    FollowedSort.viewers => l.followedSortViewers,
    FollowedSort.recent => l.followedSortRecent,
    FollowedSort.name => l.followedSortName,
    FollowedSort.category => l.followedSortCategory,
  };
}

extension TimestampTypeLabel on TimestampType {
  String label(AppLocalizations l) => switch (this) {
    TimestampType.disabled => l.timestampDisabled,
    TimestampType.twelve => l.timestampTwelve,
    TimestampType.twentyFour => l.timestampTwentyFour,
  };
}

extension LandscapeCutoutTypeLabel on LandscapeCutoutType {
  String label(AppLocalizations l) => switch (this) {
    LandscapeCutoutType.none => l.notchSideNone,
    LandscapeCutoutType.left => l.notchSideLeft,
    LandscapeCutoutType.right => l.notchSideRight,
    LandscapeCutoutType.both => l.notchSideBoth,
  };
}

extension LiveCatchUpModeLabel on LiveCatchUpMode {
  String label(AppLocalizations l) => switch (this) {
    LiveCatchUpMode.speedUp => l.liveCatchUpSpeedUp,
    LiveCatchUpMode.jumpToLive => l.liveCatchUpJumpToLive,
  };
}

extension BufferProfileLabel on BufferProfile {
  String label(AppLocalizations l) => switch (this) {
    BufferProfile.standard => l.bufferProfileStandard,
    BufferProfile.ultra => l.bufferProfileUltra,
  };
}

extension VodAutoplayLabel on VodAutoplay {
  String label(AppLocalizations l) => switch (this) {
    VodAutoplay.always => l.vodAutoplayAlways,
    VodAutoplay.wifiOnly => l.vodAutoplayWifiOnly,
    VodAutoplay.never => l.vodAutoplayNever,
  };
}

extension CelebrationsOnVideoLabel on CelebrationsOnVideo {
  String label(AppLocalizations l) => switch (this) {
    CelebrationsOnVideo.full => l.celebrationsFull,
    CelebrationsOnVideo.subtle => l.celebrationsSubtle,
  };
}

extension CaptionSizeLabel on CaptionSize {
  String label(AppLocalizations l) => switch (this) {
    CaptionSize.small => l.captionSizeSmall,
    CaptionSize.medium => l.captionSizeMedium,
    CaptionSize.large => l.captionSizeLarge,
    CaptionSize.extraLarge => l.captionSizeExtraLarge,
  };
}

extension CaptionBackgroundLabel on CaptionBackground {
  String label(AppLocalizations l) => switch (this) {
    CaptionBackground.black => l.captionBackgroundBlack,
    CaptionBackground.translucent => l.captionBackgroundTranslucent,
    CaptionBackground.none => l.captionBackgroundNone,
  };
}

extension SettingsPageIdLabel on SettingsPageId {
  /// Its name: the row that opens it, its title, its side column entry.
  String title(AppLocalizations l) => switch (this) {
    SettingsPageId.general => l.settingsPageGeneral,
    SettingsPageId.video => l.settingsPageVideo,
    SettingsPageId.chat => l.settingsPageChat,
    SettingsPageId.notifications => l.settingsPageNotifications,
    SettingsPageId.other => l.settingsPageOther,
    SettingsPageId.account => l.settingsPageAccount,
    SettingsPageId.blocked => l.settingsPageBlocked,
    SettingsPageId.chatFilters => l.settingsPageChatFilters,
  };

  /// The line under its title on a tablet; none for a page inside a
  /// section (the chat filters).
  String? description(AppLocalizations l) => switch (this) {
    SettingsPageId.general => l.settingsPageGeneralDescription,
    SettingsPageId.video => l.settingsPageVideoDescription,
    SettingsPageId.chat => l.settingsPageChatDescription,
    SettingsPageId.notifications => l.settingsPageNotificationsDescription,
    SettingsPageId.other => l.settingsPageOtherDescription,
    SettingsPageId.account => l.settingsPageAccountDescription,
    SettingsPageId.blocked => l.settingsPageBlockedDescription,
    SettingsPageId.chatFilters => null,
  };
}

extension TokenNoticeLabel on TokenNotice {
  /// The snackbar that tells it.
  String label(AppLocalizations l) => switch (this) {
    TokenNotice.foreignToken => l.authForeignTokenNotice,
    TokenNotice.sessionEnded => l.authSessionEndedNotice,
  };
}

extension TwitchAccountPageLabel on TwitchAccountPage {
  /// Its name, as Twitch calls the page.
  String title(AppLocalizations l) => switch (this) {
    TwitchAccountPage.security => l.settingsTwitchSecurity,
    TwitchAccountPage.connections => l.settingsTwitchConnections,
  };

  /// The line under its name: what it holds, and that it is on twitch.tv.
  String detail(AppLocalizations l) => switch (this) {
    TwitchAccountPage.security => l.settingsTwitchSecurityDetail,
    TwitchAccountPage.connections => l.settingsTwitchConnectionsDetail,
  };
}

extension ReleaseSectionKindLabel on ReleaseSectionKind {
  /// [count] points of this kind, in the line summing up a version
  /// ("2 new", "1 fix").
  String count(AppLocalizations l, int count) => switch (this) {
    ReleaseSectionKind.added => l.releaseKindAdded(count: count),
    ReleaseSectionKind.improved => l.releaseKindImproved(count: count),
    ReleaseSectionKind.fixed => l.releaseKindFixed(count: count),
    ReleaseSectionKind.other => l.releaseKindOther(count: count),
  };
}

extension ChatModeLabel on ChatMode {
  /// A room mode's name: the moderator's switches and their outcomes. Every
  /// value is listed: a new one must be named in chatModeName too.
  String label(AppLocalizations l) => switch (this) {
    ChatMode.slow ||
    ChatMode.followers ||
    ChatMode.subscribers ||
    ChatMode.emoteOnly ||
    ChatMode.uniqueChat => l.chatModeName(mode: name),
  };

  /// Its pill at the top of the chat's details while it is on.
  String pill(AppLocalizations l) => switch (this) {
    ChatMode.slow ||
    ChatMode.followers ||
    ChatMode.subscribers ||
    ChatMode.emoteOnly ||
    ChatMode.uniqueChat => l.chatModePill(mode: name),
  };
}

extension EmoteTypeLabel on EmoteType {
  /// An emote's kind, in its details ("Twitch global emote"). Every value
  /// is listed: a new one must be named in emoteTypeName too.
  String label(AppLocalizations l) => switch (this) {
    EmoteType.twitchBits ||
    EmoteType.twitchFollower ||
    EmoteType.twitchSub ||
    EmoteType.twitchGlobal ||
    EmoteType.twitchUnlocked ||
    EmoteType.twitchChannel ||
    EmoteType.ffzGlobal ||
    EmoteType.ffzChannel ||
    EmoteType.bttvGlobal ||
    EmoteType.bttvChannel ||
    EmoteType.bttvShared ||
    EmoteType.sevenTVGlobal ||
    EmoteType.sevenTVChannel => l.emoteTypeName(type: name),
  };
}

extension BadgeTypeLabel on BadgeType {
  /// A chat badge's source, in its details ("Twitch badge").
  String label(AppLocalizations l) => switch (this) {
    BadgeType.twitch ||
    BadgeType.bttv ||
    BadgeType.ffz ||
    BadgeType.sevenTV => l.badgeTypeName(type: name),
  };
}
