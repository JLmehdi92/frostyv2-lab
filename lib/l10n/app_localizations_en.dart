// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageNameEnglish => 'English';

  @override
  String get languageNameFrench => 'Français';

  @override
  String get languageChoiceSemantics => 'Language · Langue';

  @override
  String get appLanguageSystem => 'System';

  @override
  String get commonNext => 'Next';

  @override
  String get commonBack => 'Back';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDone => 'Done';

  @override
  String get commonClose => 'Close';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLiveBadge => 'LIVE';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get commonConnectWithTwitch => 'Connect with Twitch';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String settingsLanguageSystemSubtitle({required String language}) {
    return '“System” uses your device’s language (currently $language).';
  }

  @override
  String get languagePromptTitle => 'Choose your language';

  @override
  String get languagePromptBody =>
      'ONSET is now available in English and French. You can change the language anytime in Settings › General.';

  @override
  String get languagePromptConfirm => 'Continue';

  @override
  String get onboardingIntroDescription =>
      'A mobile Twitch client with 7TV, BetterTTV (BTTV), and FrankerFaceZ (FFZ) support.';

  @override
  String get onboardingIntroEyebrow => 'First launch';

  @override
  String get onboardingProgressLabel => 'Onboarding progress';

  @override
  String onboardingProgressValue({required int step, required int count}) {
    return 'Step $step of $count';
  }

  @override
  String get onboardingLoginTitle => 'Log in';

  @override
  String get onboardingLoginLead =>
      'ONSET needs your permission in order to enable the ability to chat, view followed streams, and more.';

  @override
  String get onboardingLoginAuthorizeHeader => 'What you will authorize';

  @override
  String get onboardingPermissionChatTitle => 'Chat';

  @override
  String get onboardingPermissionChatDetail => 'Read and send messages';

  @override
  String get onboardingPermissionFollowsTitle => 'Followed channels';

  @override
  String get onboardingPermissionFollowsDetail => 'See who is live right now';

  @override
  String get onboardingPermissionEmotesTitle => 'Your emotes';

  @override
  String get onboardingPermissionEmotesDetail =>
      'Use your sub and follower emotes';

  @override
  String get onboardingPermissionWhispersTitle => 'Whispers';

  @override
  String get onboardingPermissionWhispersDetail => 'Read and send whispers';

  @override
  String get onboardingPermissionModerationTitle => 'Moderation';

  @override
  String get onboardingPermissionModerationDetail =>
      'Bans, warnings, messages, chat modes';

  @override
  String get onboardingPermissionClipsTitle => 'Clips';

  @override
  String get onboardingPermissionClipsDetail => 'Create clips from a stream';

  @override
  String get onboardingPermissionBlocksTitle => 'Blocks and name color';

  @override
  String get onboardingPermissionBlocksDetail =>
      'Manage blocks, change your chat color';

  @override
  String get onboardingLoginDisclaimer =>
      'ONSET only asks for the necessary permissions through the official Twitch API. You’ll be able to review them before authorizing.';

  @override
  String get onboardingLoginSkip => 'Skip';

  @override
  String get onboardingSetupTitle => 'Setup';

  @override
  String get onboardingSetupLead =>
      'Let’s tweak some settings before you get started. You can always change these and more later.';

  @override
  String onboardingSetupLoggedInAs({required String name}) {
    return 'Logged in as $name';
  }

  @override
  String get loginSigningIn => 'Signing you in…';

  @override
  String get onboardingSetupLoginFailed =>
      'Login failed · go back to try again, or log in later from Profile';

  @override
  String get onboardingSetupNotLoggedIn =>
      'Not logged in · you can log in later from Profile';

  @override
  String get onboardingSetupPreviewChannel => 'A live channel';

  @override
  String get onboardingSetupPreviewDetail => 'Category · viewers';

  @override
  String onboardingSetupPreviewSemantics({
    required String name,
    required String detail,
  }) {
    return 'Preview: $name, $detail';
  }

  @override
  String get onboardingSetupPreviewBadge => 'PREVIEW';

  @override
  String get onboardingSetupThemeTitle => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get onboardingSetupThemeSystemNote => 'Follows your device';

  @override
  String get onboardingSetupThemeLightNote => 'Light surfaces everywhere';

  @override
  String get onboardingSetupThemeDarkNote => 'Noir, the ONSET default';

  @override
  String get accentColorTitle => 'Accent color';

  @override
  String accentColorSemantics({required String hex}) {
    return 'Accent color, $hex';
  }

  @override
  String get accentColorRandom => 'Random';

  @override
  String get accentSaturationBrightness => 'Saturation and brightness';

  @override
  String accentSaturationBrightnessValue({
    required int saturation,
    required int brightness,
  }) {
    return '$saturation %, $brightness %';
  }

  @override
  String accentHue({required int degrees}) {
    String _temp0 = intl.Intl.pluralLogic(
      degrees,
      locale: localeName,
      other: 'Hue $degrees degrees',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSetupHistoryTitle =>
      'Fallback chat history (third-party)';

  @override
  String onboardingSetupHistoryDetail({required String link}) {
    return 'When Twitch\'s own chat history is unavailable, fails or is empty, loads recent messages from $link, which then receives the channel name.';
  }

  @override
  String get onboardingSetupCrashTitle => 'Share crash logs and analytics';

  @override
  String get onboardingSetupCrashDetail =>
      'Help improve ONSET by sending crash logs and analytics through Firebase, without your Twitch account or channels.';

  @override
  String get onboardingWelcomeTitle => 'Welcome!';

  @override
  String get onboardingWelcomeLead => 'Just a few more things…';

  @override
  String get onboardingWelcomeTipGitHub =>
      'Check out the GitHub repo at the top-right of the settings page to explore ONSET’s source code, report bugs, make feature requests, and more.';

  @override
  String get onboardingWelcomeTipChangelog =>
      'Links to the full changelog and FAQ are in the settings page under “Other”.';

  @override
  String get onboardingWelcomeTipRating =>
      'Don’t forget to leave a rating and/or review on the app store!';

  @override
  String get onboardingWelcomeGo => 'Let’s go!';

  @override
  String get loginHelpTooltip => 'Login help';

  @override
  String get loginHelpTitle => 'Workaround for the Twitch cookie banner';

  @override
  String get loginHelpBodyOnboarding =>
      'If the Twitch cookie banner is still blocking the login, try clicking one of the links in the cookie policy description and navigating until you reach the Twitch home page. From there, you can try logging in on the top right profile icon. Once logged in, go back to the first step of the onboarding and then try again.';

  @override
  String get loginHelpBodyElsewhere =>
      'If the Twitch cookie banner is still blocking the login, try clicking one of the links in the cookie policy description and navigating until you reach the Twitch home page. From there, you can try logging in on the top right profile icon. Once logged in, go back, then open the login again.';

  @override
  String loginHostSecure({required String host}) {
    return 'Secure page: $host';
  }

  @override
  String loginHostPage({required String host}) {
    return 'Page: $host';
  }

  @override
  String get loginFailedLine => 'Twitch did not sign you in. Try again.';

  @override
  String get loginLoadFailedTitle => 'Twitch could not be reached';

  @override
  String get loginLoadFailedDetail => 'Check your connection, then try again.';

  @override
  String get shellSectionHome => 'Home';

  @override
  String get shellSectionBrowse => 'Browse';

  @override
  String get shellSectionActivity => 'Activity';

  @override
  String get shellSectionProfile => 'Profile';

  @override
  String shellActivityNew({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Activity, $count new',
    );
    return '$_temp0';
  }

  @override
  String get shellFeedFollowing => 'Following';

  @override
  String get shellFeedLive => 'Live';

  @override
  String get shellFeedClips => 'Clips';

  @override
  String get shellBrowseCategories => 'Categories';

  @override
  String get shellBrowseLiveChannels => 'Live channels';

  @override
  String get shellActivityNotifications => 'Notifications';

  @override
  String get shellWhispers => 'Whispers';

  @override
  String shellWhispersUnread({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Whispers ($count unread)',
    );
    return '$_temp0';
  }

  @override
  String get shellWhispersRefused => 'Whispers (log in again to get them)';

  @override
  String shellTabUnread({required String label, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$label, $count unread',
    );
    return '$_temp0';
  }

  @override
  String get shellNavSemantics => 'Main';

  @override
  String get shellSearch => 'Search';

  @override
  String get shellSearchHint => 'Search channels, categories or videos';

  @override
  String get shellSettings => 'Settings';

  @override
  String homeOpenChannelFailed({required String login}) {
    return 'Couldn\'t open $login\'s channel.';
  }

  @override
  String mentionNotice({required String login}) {
    return 'You were mentioned in $login\'s chat';
  }

  @override
  String get deepLinkCategoryFallback => 'Category';

  @override
  String deepLinkFailed({required String uri}) {
    return 'Unable to navigate to \'$uri\'';
  }

  @override
  String get deepLinkOpenInBrowser => 'Open in browser';

  @override
  String get scrollToTop => 'Scroll to top';

  @override
  String get miniPlayerReturn => 'Return to stream';

  @override
  String get miniPlayerClose => 'Close mini player';

  @override
  String get userActionsProfile => 'Profile';

  @override
  String get userActionsVideos => 'Videos';

  @override
  String userActionsPin({required String name}) {
    return 'Pin $name';
  }

  @override
  String userActionsUnpin({required String name}) {
    return 'Unpin $name';
  }

  @override
  String userActionsBlock({required String name}) {
    return 'Block $name';
  }

  @override
  String userActionsFollowOnTwitch({required String name}) {
    return 'Follow $name on Twitch';
  }

  @override
  String get userActionsFollowDetail => 'Opens the channel on twitch.tv';

  @override
  String get userActionsCopyLink => 'Copy link';

  @override
  String get userActionsLinkCopied => 'Link copied';

  @override
  String userActionsShare({required String name}) {
    return 'Share $name';
  }

  @override
  String userActionsReport({required String name}) {
    return 'Report $name';
  }

  @override
  String get draggableDividerChatWidth => 'Chat width';

  @override
  String draggableDividerValue({required int percent}) {
    return '$percent%';
  }

  @override
  String get photoViewThumbnail => 'View thumbnail';

  @override
  String get photoViewOriginal => 'View original';

  @override
  String get videoListEmptyHint => 'Pull down to check again.';

  @override
  String get releaseNotesEarlierVersions => 'Earlier versions';
}
