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
  String get commonConnectWithTwitch => 'Log in with Twitch';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String settingsLanguageSystemSubtitle({required String language}) {
    return '“System” follows your device’s language (currently $language).';
  }

  @override
  String get languageInTextEnglish => 'English';

  @override
  String get languageInTextFrench => 'French';

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
      'ONSET needs your permission to let you chat, see followed streams, and more.';

  @override
  String get onboardingLoginAuthorizeHeader => 'What you’ll authorize';

  @override
  String get onboardingPermissionChatTitle => 'Chat';

  @override
  String get onboardingPermissionChatDetail => 'Read and send messages';

  @override
  String get onboardingPermissionFollowsTitle => 'Followed channels';

  @override
  String get onboardingPermissionFollowsDetail => 'See who’s live right now';

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
      'Manage blocks and change your name color';

  @override
  String get onboardingLoginDisclaimer =>
      'ONSET asks only for the permissions it needs, through the official Twitch API. You’ll be able to review them before authorizing.';

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
  String get loginSigningIn => 'Logging you in…';

  @override
  String get onboardingSetupLoginFailed =>
      'Couldn’t log in · go back to try again, or log in later from Profile';

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
  String get onboardingSetupThemeDarkNote => 'The ONSET default';

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
    return '$saturation%, $brightness%';
  }

  @override
  String accentHue({required int degrees}) {
    String _temp0 = intl.Intl.pluralLogic(
      degrees,
      locale: localeName,
      other: 'Hue $degrees degrees',
      one: 'Hue $degrees degree',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSetupHistoryTitle =>
      'Fallback chat history (third-party)';

  @override
  String onboardingSetupHistoryDetail({required String link}) {
    return 'When Twitch’s own chat history is unavailable, fails, or is empty, ONSET loads recent messages from $link, which then receives the channel name.';
  }

  @override
  String get onboardingSetupCrashTitle => 'Share crash logs and analytics';

  @override
  String get onboardingSetupCrashDetail =>
      'Help improve ONSET by sending crash logs and analytics through Firebase. Neither your Twitch account nor your channels are sent.';

  @override
  String get onboardingWelcomeTitle => 'Welcome!';

  @override
  String get onboardingWelcomeLead => 'Just a few more things…';

  @override
  String get onboardingWelcomeTipGitHub =>
      'Check out the GitHub repo (top-right corner of Settings) to explore ONSET’s source code, report bugs, request features, and more.';

  @override
  String get onboardingWelcomeTipChangelog =>
      'Links to the full changelog and the FAQ are in Settings › Other.';

  @override
  String get onboardingWelcomeTipRating =>
      'ONSET checks for new builds by itself, and the release notes open after each update.';

  @override
  String get onboardingWelcomeGo => 'Let’s go!';

  @override
  String get loginHelpTooltip => 'Login help';

  @override
  String get loginHelpTitle => 'Workaround for the Twitch cookie banner';

  @override
  String get loginHelpBodyOnboarding =>
      'If the Twitch cookie banner still blocks the login, tap one of the links in the cookie policy text and keep going until you reach the Twitch home page. From there, log in with the profile icon in the top-right corner. Once you’re logged in, go back to the first step of setup and try again.';

  @override
  String get loginHelpBodyElsewhere =>
      'If the Twitch cookie banner still blocks the login, tap one of the links in the cookie policy text and keep going until you reach the Twitch home page. From there, log in with the profile icon in the top-right corner. Once you’re logged in, go back and open the login page again.';

  @override
  String loginHostSecure({required String host}) {
    return 'Secure page: $host';
  }

  @override
  String loginHostPage({required String host}) {
    return 'Page: $host';
  }

  @override
  String get loginFailedLine => 'Twitch didn’t log you in. Try again.';

  @override
  String get loginLoadFailedTitle => 'Couldn’t reach Twitch.';

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
      one: 'Activity, $count new',
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
      one: 'Whispers ($count unread)',
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
      one: '$label, $count unread',
    );
    return '$_temp0';
  }

  @override
  String get shellNavSemantics => 'Main';

  @override
  String get shellSearch => 'Search';

  @override
  String get shellSearchHint => 'Search channels, categories, or videos';

  @override
  String get shellSettings => 'Settings';

  @override
  String homeOpenChannelFailed({required String login}) {
    return 'Couldn’t open $login’s channel.';
  }

  @override
  String mentionNotice({required String login}) {
    return 'You were mentioned in $login’s chat.';
  }

  @override
  String get deepLinkCategoryFallback => 'Category';

  @override
  String deepLinkFailed({required String uri}) {
    return 'Couldn’t open “$uri”.';
  }

  @override
  String get deepLinkOpenInBrowser => 'Open in browser';

  @override
  String get scrollToTop => 'Scroll to top';

  @override
  String get miniPlayerReturn => 'Return to stream';

  @override
  String get miniPlayerClose => 'Close miniplayer';

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

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsCustomize => 'Customize';

  @override
  String get settingsSectionsSemantics => 'Settings sections';

  @override
  String get settingsJumpToGroup => 'Jump to a group';

  @override
  String get settingsPageGeneral => 'General';

  @override
  String get settingsPageGeneralDescription =>
      'Theme, stream cards, browsing, and links';

  @override
  String get settingsPageVideo => 'Video';

  @override
  String get settingsPageVideoDescription =>
      'Low-latency player, playback, overlay, videos, and captions';

  @override
  String get settingsPageChat => 'Chat';

  @override
  String get settingsPageChatDescription =>
      'Appearance, delay, alerts, and filters';

  @override
  String get settingsPageNotifications => 'Notifications';

  @override
  String get settingsPageNotificationsDescription =>
      'Go-live and chat mention notifications';

  @override
  String get settingsPageOther => 'Other';

  @override
  String get settingsPageOtherDescription =>
      'Updates, storage, privacy, and about';

  @override
  String get settingsPageAccount => 'Account';

  @override
  String get settingsPageAccountDescription => 'Your Twitch account in ONSET';

  @override
  String get settingsPageBlocked => 'Blocked users';

  @override
  String get settingsPageBlockedDescription => 'People you blocked on Twitch';

  @override
  String get settingsPageChatFilters => 'Edit chat filters';

  @override
  String get settingsSummaryGeneral => 'Theme, accent color, browsing, links';

  @override
  String get settingsSummaryVideo => 'Low-latency player, captions, overlay';

  @override
  String get settingsSummaryChat => 'Sizing, alerts, filters, emotes';

  @override
  String get settingsSummaryNotifications => 'Go-live and chat mentions';

  @override
  String get settingsSummaryNotificationsLoggedOut =>
      'Log in to get go-live and mention notifications';

  @override
  String get settingsSummaryOther => 'Updates, storage, privacy, about';

  @override
  String settingsSummaryMentions({required String mentions}) {
    String _temp0 = intl.Intl.selectLogic(mentions, {
      'on': 'Mentions on',
      'other': 'Mentions off',
    });
    return '$_temp0';
  }

  @override
  String settingsSummaryGoLiveMentions({
    required String goLive,
    required String mentions,
  }) {
    String _temp0 = intl.Intl.selectLogic(goLive, {
      'on': 'Go-live on',
      'other': 'Go-live off',
    });
    String _temp1 = intl.Intl.selectLogic(mentions, {
      'on': 'mentions on',
      'other': 'mentions off',
    });
    return '$_temp0 · $_temp1';
  }

  @override
  String get settingsUnableToReachTwitch => 'Couldn’t connect to Twitch.';

  @override
  String get settingsCheckConnection =>
      'Check your connection, then try again.';

  @override
  String get settingsReconnect => 'Reconnect';

  @override
  String get settingsAccountCardDetail => 'Blocked users, twitch.tv, log out';

  @override
  String get settingsAnonymous => 'Anonymous';

  @override
  String get settingsWatchingWithoutAccount => 'Watching without an account';

  @override
  String get settingsLoginPitch =>
      'Log in to chat, see followed streams, and more.';

  @override
  String get settingsLoginDisclaimer =>
      'ONSET asks only for the permissions it needs, through the official Twitch API. You’ll be able to review them before authorizing.';

  @override
  String get settingsTokenLoginTip =>
      'Have a token copied? Long-press this card to log in with it.';

  @override
  String get settingsTokenLoginHint => 'log in with a copied token';

  @override
  String get settingsYourAccount => 'Your account';

  @override
  String get settingsMyChannel => 'My channel';

  @override
  String get settingsOnTwitch => 'On twitch.tv';

  @override
  String get settingsTwitchSecurity => 'Security and privacy';

  @override
  String get settingsTwitchSecurityDetail =>
      'Password, email, phone, two-factor authentication — on twitch.tv';

  @override
  String get settingsTwitchConnections => 'Connections';

  @override
  String get settingsTwitchConnectionsDetail =>
      'Linked accounts — on twitch.tv';

  @override
  String get settingsLogOut => 'Log out';

  @override
  String get settingsLogOutTitle => 'Log out';

  @override
  String get settingsLogOutMessage => 'Are you sure you want to log out?';

  @override
  String settingsJoined({required DateTime date}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMM(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Joined $dateString';
  }

  @override
  String get settingsYourProfile => 'Your profile';

  @override
  String get settingsUnblock => 'Unblock';

  @override
  String settingsUnblockName({required String name}) {
    return 'Unblock $name';
  }

  @override
  String settingsUnblockMessage({required String name}) {
    return 'Are you sure you want to unblock $name?';
  }

  @override
  String get settingsBlock => 'Block';

  @override
  String settingsBlockMessage({required String name}) {
    return 'Are you sure you want to block $name? This removes them from channel lists, search results, and chat messages.';
  }

  @override
  String get commonYes => 'Yes';

  @override
  String get settingsNoBlockedUsers => 'No blocked users';

  @override
  String settingsBlockedCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocked',
      one: '$count blocked',
    );
    return '$_temp0';
  }

  @override
  String get settingsBlockedNote =>
      'Blocked users are removed from channel lists, search results, and chat messages. Pull down to refresh.';

  @override
  String get authForeignTokenNotice =>
      'This token was created for another app — some features may not work.';

  @override
  String get authSessionEndedNotice =>
      'Your Twitch session has ended. Log in again from Settings.';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsAccentColorChange => 'Change accent color';

  @override
  String get settingsAccentColorLive => 'Applies everywhere as you pick';

  @override
  String get settingsStreamCard => 'Stream card';

  @override
  String get settingsLargeStreamCard => 'Use large stream cards';

  @override
  String get settingsShowThumbnail => 'Show thumbnail';

  @override
  String get settingsBrowse => 'Browse';

  @override
  String get settingsStartTab => 'Open the app on';

  @override
  String get settingsLinks => 'Links';

  @override
  String get settingsExternalBrowser => 'Open links in external browser';

  @override
  String get settingsStreamLanguage => 'Stream language';

  @override
  String get streamLanguageAll => 'All languages';

  @override
  String get streamLanguageOther => 'Other';

  @override
  String get settingsHideLabeled => 'Hide labeled streams';

  @override
  String settingsHideLabeledValue({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count labels',
      one: '$count label',
      zero: 'None',
    );
    return '$_temp0';
  }

  @override
  String get settingsHideLabeledNote =>
      'Streams with these labels are left out of Live, Live channels, categories, and tags. Followed channels always show.';

  @override
  String get contentLabelDrugs =>
      'Drugs, intoxication, or excessive tobacco use';

  @override
  String get contentLabelSexualThemes => 'Sexual themes';

  @override
  String get contentLabelViolentGraphic => 'Violent and graphic depictions';

  @override
  String get contentLabelGambling => 'Gambling';

  @override
  String get contentLabelProfanity => 'Significant profanity or vulgarity';

  @override
  String get contentLabelMatureGame => 'Mature-rated game';

  @override
  String get contentLabelPolitics => 'Politics and sensitive social issues';

  @override
  String get settingsLowLatencyPlayer => 'Low-latency player';

  @override
  String get settingsLowLatencyPlayerSwitch =>
      'Low-latency player (Amazon IVS)';

  @override
  String get settingsLowLatencyPlayerDetail =>
      'Plays the stream with the Amazon IVS player, built on the same video technology as Twitch, for low latency. Turn off to use the original Twitch web player.';

  @override
  String get settingsAutoLatency => 'Auto latency';

  @override
  String get settingsAutoLatencyDetail =>
      'Keeps the stream close to live by playing very slightly faster when it falls behind, without reloading it. If Ultra keeps stalling, the next few streams use Standard. Applies the next time you open a stream.';

  @override
  String get settingsLiveCatchUp => 'Live catch-up';

  @override
  String get settingsLiveCatchUpDetail =>
      '“Speed up” plays slightly faster until the stream is back to live (Auto latency already does this when it’s on). “Jump to live” skips ahead after a stall. Applies the next time you open a stream.';

  @override
  String get liveCatchUpSpeedUp => 'Speed up';

  @override
  String get liveCatchUpJumpToLive => 'Jump to live';

  @override
  String get settingsBufferProfile => 'Buffer profile';

  @override
  String get settingsBufferProfileDetail =>
      'Ultra keeps a smaller buffer than Standard for lower latency, but may rebuffer more on weak connections. Applies the next time you open a stream.';

  @override
  String get bufferProfileStandard => 'Standard';

  @override
  String get bufferProfileUltra => 'Ultra';

  @override
  String get playerConfigAuto => 'Auto';

  @override
  String get playerConfigJumpToLiveAuto => 'Jump to live + auto';

  @override
  String playerConfigUltraStalled({
    required String mode,
    required String buffer,
  }) {
    return '$mode · $buffer (Ultra stalled)';
  }

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get settingsEnableVideo => 'Enable video';

  @override
  String get settingsHighestQuality => 'Default to highest quality';

  @override
  String get settingsFastRendering => 'Use fast video rendering';

  @override
  String get settingsFastRenderingDetail =>
      'Uses a faster WebView rendering method. Turn it off if streams crash while you watch.';

  @override
  String get settingsKeepAwake => 'Keep screen awake';

  @override
  String get settingsKeepAwakeDetail =>
      'Prevents the screen from sleeping while a channel is open.';

  @override
  String get settingsBackgroundAudio => 'Background audio';

  @override
  String get settingsBackgroundAudioDetail =>
      'Keeps a live stream playing when you leave the app or turn off the screen, with media controls in a notification.';

  @override
  String get settingsOverlay => 'Overlay';

  @override
  String get settingsCustomOverlay => 'Use custom video overlay';

  @override
  String get settingsCustomOverlayDetail =>
      'Replaces Twitch’s default web overlay with a mobile-friendly version.';

  @override
  String get settingsToggleOverlay =>
      'Long-press the player to toggle the overlay';

  @override
  String get settingsToggleOverlayDetail =>
      'Lets you switch between Twitch’s overlay and the custom overlay.';

  @override
  String get settingsShowLatency => 'Show latency';

  @override
  String get settingsShowLatencyDetail =>
      'Displays the stream latency in the video overlay. With the low-latency player, tap it to show live video stats.';

  @override
  String get settingsVideosAndContent => 'Videos and content';

  @override
  String get settingsVodAutoplay => 'Autoplay videos';

  @override
  String get settingsVodAutoplayDetail =>
      'Choose when videos play automatically.';

  @override
  String get vodAutoplayAlways => 'Wi-Fi and mobile data';

  @override
  String get vodAutoplayWifiOnly => 'Wi-Fi only';

  @override
  String get vodAutoplayNever => 'Never';

  @override
  String get settingsWarnMature => 'Warn about mature content';

  @override
  String get settingsWarnMatureDetail =>
      'Shows a warning before opening a channel labeled for mature content.';

  @override
  String get settingsCaptions => 'Captions';

  @override
  String get settingsClosedCaptions => 'Closed captions';

  @override
  String get settingsClosedCaptionsDetail =>
      'Shows captions over live streams and videos that have them. When there are several, pick one in the player menu.';

  @override
  String get settingsCaptionSize => 'Caption size';

  @override
  String get captionSizeSmall => 'Small';

  @override
  String get captionSizeMedium => 'Medium';

  @override
  String get captionSizeLarge => 'Large';

  @override
  String get captionSizeExtraLarge => 'Extra large';

  @override
  String get settingsCaptionBackground => 'Caption background';

  @override
  String get captionBackgroundBlack => 'Black';

  @override
  String get captionBackgroundTranslucent => 'Translucent';

  @override
  String get captionBackgroundNone => 'None';

  @override
  String get settingsCaptionSample => 'This is how captions look.';

  @override
  String get webTokenTitle => 'Twitch web token (2K)';

  @override
  String get webTokenExpired =>
      'Twitch session expired — log in again to restore 2K';

  @override
  String get webTokenUnset => 'Not set — log in to pick it up automatically';

  @override
  String get webTokenActive => 'Active — picked up automatically, 2K requested';

  @override
  String get webTokenNotSet => 'Not set';

  @override
  String get webTokenExplanation =>
      'Some streams offer 2K (1440p HEVC) only to logged-in viewers. ONSET normally picks up this token by itself when you log in and refreshes it on each launch, so you should never need to touch it. Fill it in by hand only if that fails: paste the value of the “auth-token” cookie from twitch.tv in a browser.';

  @override
  String get webTokenIsSet => 'A token is set.';

  @override
  String get webTokenNoneSet => 'No token set.';

  @override
  String get webTokenClear => 'Clear';

  @override
  String get webTokenNewField => 'New auth-token';

  @override
  String get webTokenFieldHint => 'Paste to replace — never shown';

  @override
  String get webTokenReplace => 'Replace';

  @override
  String get webTokenSave => 'Save';

  @override
  String get settingsMessageSizing => 'Message sizing';

  @override
  String get settingsChatPreview => 'Preview';

  @override
  String get settingsChatPreviewBadgeEmote => 'Badge and emote preview.';

  @override
  String get settingsChatPreviewText => 'Hello! Here’s a text preview.';

  @override
  String get settingsChatPreviewSpacing =>
      'And another for spacing without an emote!';

  @override
  String get settingsBadgeScale => 'Badge scale';

  @override
  String get settingsEmoteScale => 'Emote scale';

  @override
  String get settingsMessageScale => 'Message scale';

  @override
  String settingsScaleValue({required double scale}) {
    final intl.NumberFormat scaleNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 2,
        );
    final String scaleString = scaleNumberFormat.format(scale);

    return '$scaleString×';
  }

  @override
  String get settingsMessageSpacing => 'Message spacing';

  @override
  String settingsSpacingValue({required int pixels}) {
    return '${pixels}px';
  }

  @override
  String get settingsFontSize => 'Font size';

  @override
  String get settingsMessageAppearance => 'Message appearance';

  @override
  String get settingsShowDeleted => 'Show deleted messages';

  @override
  String get settingsShowDeletedDetail =>
      'Shows the original text of deleted messages.';

  @override
  String get settingsAnimateEmotes => 'Animate emotes';

  @override
  String get settingsAnimateEmotesDetail =>
      'When off, shows only the first frame of animated emotes in chat.';

  @override
  String get settingsAnimatedGifs => 'Animated GIFs';

  @override
  String get settingsAnimatedGifsDetail =>
      'When off, shows only the first frame of GIFs sent in chat.';

  @override
  String get settingsShowGifs => 'Show GIFs in chat';

  @override
  String get settingsShowGifsDetail =>
      'When off, shows the GIF’s title instead.';

  @override
  String get settingsLinkPreviews => 'Preview clips and videos';

  @override
  String get settingsLinkPreviewsDetail =>
      'Shows a card under messages that link to a Twitch clip or video.';

  @override
  String get settingsModerationNotices => 'Show timeouts and bans';

  @override
  String get settingsModerationNoticesDetail =>
      'Adds a line when a moderator times out or bans someone.';

  @override
  String get settingsMessageDividers => 'Show message dividers';

  @override
  String get settingsTimestamps => 'Message timestamps';

  @override
  String get timestampDisabled => 'Disabled';

  @override
  String get timestampTwelve => '12-hour';

  @override
  String get timestampTwentyFour => '24-hour';

  @override
  String get settingsDelayAndLatency => 'Delay and latency';

  @override
  String get settingsSyncDelay => 'Sync message delay and stream latency';

  @override
  String get settingsSyncDelayDetail =>
      'Holds each message for as long as the video is behind live, so chat matches what you see. Your own messages show right away.';

  @override
  String get settingsMessageDelay => 'Message delay';

  @override
  String settingsMessageDelayValue({required int seconds}) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '$seconds second',
    );
    return '$_temp0';
  }

  @override
  String get settingsMessageDelayDetail =>
      'Adds a delay before each message appears in chat.';

  @override
  String get settingsMessageDelayDetailIos =>
      'Adds a delay before each message appears in chat. 15 seconds is recommended on iOS.';

  @override
  String get settingsLayout => 'Layout';

  @override
  String get settingsEmoteButtonLeft => 'Move emote menu button left';

  @override
  String get settingsEmoteButtonLeftDetail =>
      'Places the emote menu button on the left side to avoid accidental presses.';

  @override
  String get settingsPersistTabs => 'Persist chat tabs';

  @override
  String get settingsPersistTabsDetail =>
      'Secondary chat tabs are remembered when switching channels.';

  @override
  String get settingsAlerts => 'Alerts';

  @override
  String get settingsFirstTimeChatters => 'Highlight first-time chatters';

  @override
  String get settingsUserNotices => 'Show notices';

  @override
  String get settingsUserNoticesDetail =>
      'Shows notices such as subs, resubs, announcements, and raids.';

  @override
  String get settingsCollapseGiftBombs => 'Collapse gift bombs';

  @override
  String get settingsCollapseGiftBombsDetail =>
      'Folds a gift bomb of five subs or more into its first line; tap “recipients” to see who got one.';

  @override
  String get settingsHideGiftSubNotices => 'Hide gift subs';

  @override
  String get settingsHideGiftSubNoticesDetail =>
      'Gift subs, community gifts, and sponsored bonus subs no longer show in chat.';

  @override
  String get settingsHideGiftCount => 'Hide gift totals';

  @override
  String get settingsHideGiftCountDetail =>
      'Leaves out how many subs a viewer has gifted in the channel.';

  @override
  String get settingsShowHypeTrains => 'Show Hype Trains';

  @override
  String get settingsShowHypeTrainsDetail =>
      'Shows Hype Train progress, levels, and rewards above chat.';

  @override
  String get settingsCommunityHighlights => 'Show community highlights';

  @override
  String get settingsCommunityHighlightsDetail =>
      'Shows polls, predictions, pinned messages, gift bombs, and raids above chat.';

  @override
  String get settingsCelebrations => 'Show celebrations';

  @override
  String get settingsCelebrationsDetail =>
      'Plays an animation over the channel when someone gifts subs.';

  @override
  String get settingsCelebrationsOnVideo => 'Celebrations on video';

  @override
  String get settingsCelebrationsOnVideoDetail =>
      '“Full” plays the animation over the video. “Subtle” keeps the video clear and posts a line in chat instead.';

  @override
  String get celebrationsFull => 'Full';

  @override
  String get celebrationsSubtle => 'Subtle';

  @override
  String get settingsAutocomplete => 'Autocomplete';

  @override
  String get settingsAutocompleteBar => 'Show autocomplete bar';

  @override
  String get settingsAutocompleteBarDetail =>
      'Shows a bar containing matching emotes and mentions while typing.';

  @override
  String get settingsLandscape => 'Landscape mode';

  @override
  String get settingsChatLeft => 'Move chat left';

  @override
  String get settingsVerticalChat => 'Force vertical chat';

  @override
  String get settingsVerticalChatDetail =>
      'Intended for tablets and other larger displays.';

  @override
  String get settingsNotchSide => 'Fill notch side';

  @override
  String get settingsNotchSideDetail =>
      'Fills the space beside the display notch on devices that have one.';

  @override
  String get notchSideNone => 'None';

  @override
  String get notchSideLeft => 'Left';

  @override
  String get notchSideRight => 'Right';

  @override
  String get notchSideBoth => 'Both';

  @override
  String get settingsOverlayOpacity => 'Chat overlay opacity';

  @override
  String settingsOverlayOpacityValue({required int percent}) {
    return '$percent%';
  }

  @override
  String get settingsOverlayOpacityDetail =>
      'Sets the opacity of the chat overlay in full-screen mode.';

  @override
  String get settingsFiltersGroup => 'Chat filters and muted keywords';

  @override
  String get settingsFiltersOn => 'On';

  @override
  String get settingsFiltersOff => 'Off';

  @override
  String get settingsWholeWords => 'Match whole words';

  @override
  String get settingsWholeWordsDetail =>
      'Matches whole words only, not parts of words.';

  @override
  String get settingsEmotesAndBadges => 'Emotes and badges';

  @override
  String get settingsShowTwitchEmotes => 'Show Twitch emotes';

  @override
  String get settingsShowTwitchBadges => 'Show Twitch badges';

  @override
  String get settingsShow7tvEmotes => 'Show 7TV emotes';

  @override
  String get settingsShowBttvEmotes => 'Show BTTV emotes';

  @override
  String get settingsShowBttvBadges => 'Show BTTV badges';

  @override
  String get settingsShowFfzEmotes => 'Show FFZ emotes';

  @override
  String get settingsShowFfzBadges => 'Show FFZ badges';

  @override
  String get settingsRecentMessages => 'Recent messages';

  @override
  String get chatFiltersEnable => 'Enable filtering in chat';

  @override
  String get chatFiltersExplanation =>
      'Choose what to filter out of chat in every channel. In channels you moderate, you’ll still see every message.';

  @override
  String get chatFiltersGroup => 'Filters';

  @override
  String get chatFilterDiscrimination => 'Discrimination';

  @override
  String get chatFilterDiscriminationDetail =>
      'Negative language about race, gender, sexual orientation, or similar';

  @override
  String get chatFilterSexual => 'Sexually explicit language';

  @override
  String get chatFilterSexualDetail =>
      'References to sexual acts, sexual content, and body parts';

  @override
  String get chatFilterHarassment => 'Harassment';

  @override
  String get chatFilterHarassmentDetail =>
      'Aggressive or sexually harassing language toward other people';

  @override
  String get chatFilterProfanity => 'Profanity';

  @override
  String get chatFilterProfanityDetail =>
      'Curse words, expletives, or other obscenities';

  @override
  String get chatFiltersNote =>
      'Twitch’s AutoMod checks the words of each live chat message and hides only the ones it flags, so a message with no flagged words always shows. Hidden words show as stars: tap them to see the message. Chat replays of past broadcasts aren’t filtered.';

  @override
  String get mutedKeywordsTitle => 'Muted keywords';

  @override
  String mutedKeywordsCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keywords',
      one: '$count keyword',
      zero: 'None',
    );
    return '$_temp0';
  }

  @override
  String get mutedKeywordsHint => 'Enter keywords to mute';

  @override
  String get mutedKeywordsAdd => 'Add keyword';

  @override
  String get mutedKeywordsEmpty => 'No muted keywords';

  @override
  String mutedKeywordsRemove({required String word}) {
    return 'Remove $word';
  }

  @override
  String mutedKeywordsRemoved({required String word}) {
    return 'Removed “$word”';
  }

  @override
  String get commonUndo => 'Undo';

  @override
  String get settingsChannelsYouFollow => 'Channels you follow';

  @override
  String get goLiveTitle => 'Go-live notifications';

  @override
  String get goLiveAndroidOnly => 'Android only.';

  @override
  String get goLiveLoggedOut =>
      'Log in to be told when channels you follow go live.';

  @override
  String get goLiveBlocked =>
      'Notifications are blocked for this app. Allow them in the system settings.';

  @override
  String get goLiveOnDetail =>
      'Checked every 90 seconds while ONSET is open or playing, and about every 15 minutes otherwise, when the system allows. Turn a channel’s bell off from its menu.';

  @override
  String get goLiveOffDetail => 'Be told when channels you follow go live.';

  @override
  String get goLiveLogInAgain => 'Log in again to get go-live notifications.';

  @override
  String get goLiveReadFailed => 'Couldn’t read the go-live setting.';

  @override
  String get goLiveTurnOnFailed => 'Couldn’t turn on go-live notifications.';

  @override
  String get goLiveTurnOffFailed => 'Couldn’t turn off go-live notifications.';

  @override
  String get notificationsAllowInSystem =>
      'Allow notifications for this app in the system settings.';

  @override
  String get goLiveBellFailed => 'Couldn’t change the bell.';

  @override
  String goLiveBell({required String name}) {
    return 'Notify when $name goes live';
  }

  @override
  String get mentionTitle => 'Chat mention notifications';

  @override
  String get mentionLoggedOut =>
      'Log in to be told when someone mentions you in chat.';

  @override
  String get mentionBlocked => 'Notifications are blocked for this app.';

  @override
  String get mentionAllow => 'Allow';

  @override
  String get mentionDetail =>
      'When someone mentions you in a chat you’re watching while ONSET is in the background or in picture-in-picture.';

  @override
  String get settingsUpdates => 'Updates';

  @override
  String get settingsReleaseNotes => 'Release notes';

  @override
  String get settingsUpdatesNote =>
      'ONSET looks for a newer build when it starts and when it comes back to the foreground. Release notes open automatically after an update.';

  @override
  String get settingsStorage => 'Storage and reset';

  @override
  String get settingsClearCache => 'Clear image cache';

  @override
  String get settingsCacheCleared => 'Image cache cleared';

  @override
  String get settingsReset => 'Reset settings';

  @override
  String get settingsResetTitle => 'Reset all settings';

  @override
  String get settingsResetMessage =>
      'Are you sure you want to reset all settings?';

  @override
  String get settingsResetConfirm => 'Reset';

  @override
  String get settingsResetDone => 'All settings reset';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsSourceCode => 'Source code';

  @override
  String get settingsLicenses => 'Licenses';

  @override
  String settingsLegalese({required String url}) {
    return 'ONSET is free software under the GNU AGPL-3.0-or-later, with NO WARRANTY. Source code: $url';
  }

  @override
  String get updatesUpToDate => 'You’re up to date';

  @override
  String get updatesCheckFailed => 'Couldn’t check for updates.';

  @override
  String get updatesCheck => 'Check for updates';

  @override
  String updatesBuild({required int build}) {
    return 'Build $build';
  }

  @override
  String get updatesChecking => 'Checking…';

  @override
  String get followedSortViewers => 'Viewers (high to low)';

  @override
  String get followedSortRecent => 'Recently started';

  @override
  String get followedSortName => 'Name (A–Z)';

  @override
  String get followedSortCategory => 'Category';

  @override
  String releaseKindAdded({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new',
      one: '$count new',
    );
    return '$_temp0';
  }

  @override
  String releaseKindImproved({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count improvements',
      one: '$count improvement',
    );
    return '$_temp0';
  }

  @override
  String releaseKindFixed({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fixes',
      one: '$count fix',
    );
    return '$_temp0';
  }

  @override
  String releaseKindOther({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '$count change',
    );
    return '$_temp0';
  }

  @override
  String get releaseNotesWhatsNew => 'WHAT’S NEW';

  @override
  String releaseNotesWhatsNewIn({required String version}) {
    return 'WHAT’S NEW IN $version';
  }

  @override
  String releaseNotesUpdatedTo({required String version}) {
    return 'Updated to $version';
  }

  @override
  String releaseNotesWasOn({required String version}) {
    return 'You were on $version';
  }

  @override
  String releaseNotesWasOnSince({required String version}) {
    return 'You were on $version. Here’s what’s changed since.';
  }

  @override
  String get releaseNotesOtherVersions => 'Other versions';

  @override
  String get releaseNotesGotIt => 'Got it';

  @override
  String get releaseNotesVersions => 'Versions';

  @override
  String get releaseNotesFootnote =>
      'Release notes open automatically after an update.';

  @override
  String releaseNotesPoints({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '$count point',
    );
    return '$_temp0';
  }

  @override
  String get releaseNotesLatest => 'Latest';

  @override
  String get releaseNotesLatestBadge => 'LATEST';

  @override
  String get releaseNotesNewer => 'Newer';

  @override
  String get releaseNotesOlder => 'Older';

  @override
  String get releaseNotesEmpty => 'No release notes yet';

  @override
  String get releaseNotesEmptyDetail =>
      'Changes in each ONSET version appear here and open automatically after an update.';

  @override
  String get updateAllowTitle => 'Allow updates';

  @override
  String get updateAllowMessage =>
      'Android asks you to let ONSET install apps. Turn on “Allow from this source” on the next screen, then come back.';

  @override
  String get updateOpenSettings => 'Open settings';

  @override
  String get updateNotAllowed => 'ONSET isn’t allowed to install updates.';

  @override
  String get updateCorrupted => 'The download was corrupted. Try again.';

  @override
  String get updateInstallFailed => 'Android couldn’t install the update.';

  @override
  String get updateDownloadFailed => 'Couldn’t download the update.';

  @override
  String updateInstalledBuild({required int build}) {
    return 'Installed: build $build';
  }

  @override
  String updateSize({required double megabytes}) {
    final intl.NumberFormat megabytesNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String megabytesString = megabytesNumberFormat.format(megabytes);

    return '$megabytesString MB';
  }

  @override
  String get updateChecked => 'Verified with SHA-256 before installing';

  @override
  String get updateAvailable => 'Update available';

  @override
  String get updateNewBuild => 'NEW BUILD';

  @override
  String updateReady({required int build}) {
    return 'ONSET build $build is ready.';
  }

  @override
  String get updateNow => 'Update';

  @override
  String get updateLater => 'Later';

  @override
  String get updateInstalling => 'Installing update…';

  @override
  String get updateDownloading => 'Downloading update…';

  @override
  String updateProgress({required double received, required double total}) {
    final intl.NumberFormat receivedNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String receivedString = receivedNumberFormat.format(received);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String totalString = totalNumberFormat.format(total);

    return '$receivedString / $totalString MB';
  }

  @override
  String streamPreviewSemantics({required String name}) {
    return '$name stream preview';
  }

  @override
  String get streamEnlargeHint => 'enlarge';

  @override
  String streamViewers({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString viewers',
      one: '$countString viewer',
    );
    return '$_temp0';
  }

  @override
  String streamViewersCompact({required int count}) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString viewers',
      one: '$countString viewer',
    );
    return '$_temp0';
  }

  @override
  String streamWatching({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString watching',
      one: '$countString watching',
    );
    return '$_temp0';
  }

  @override
  String streamWatchingShort({required int count, required String viewers}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$viewers watching',
      one: '$viewers watching',
    );
    return '$_temp0';
  }

  @override
  String streamWatchStreakSemantics({required int value}) {
    return 'Watch Streak $value';
  }

  @override
  String streamStreak({required int value}) {
    return 'Streak $value';
  }

  @override
  String get streamNoCategory => 'No category';

  @override
  String streamTagsSemantics({required String tags}) {
    return 'Tags: $tags';
  }

  @override
  String streamTagSemantics({required String tag}) {
    return 'Tag $tag';
  }

  @override
  String get streamWatch => 'Watch';

  @override
  String get streamOffline => 'Offline';

  @override
  String streamFollowingForYears({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Following for $count years',
      one: 'Following for $count year',
    );
    return '$_temp0';
  }

  @override
  String streamFollowingForMonths({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Following for $count months',
      one: 'Following for $count month',
    );
    return '$_temp0';
  }

  @override
  String streamFollowingForDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Following for $count days',
      one: 'Following for $count day',
    );
    return '$_temp0';
  }

  @override
  String streamFollowingForHours({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Following for $count hours',
      one: 'Following for $count hour',
    );
    return '$_temp0';
  }

  @override
  String streamFollowingForMinutes({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Following for $count minutes',
      one: 'Following for $count minute',
    );
    return '$_temp0';
  }

  @override
  String get followedCategoriesTitle => 'Categories';

  @override
  String get apiErrorUnableToConnect => 'Couldn’t connect to Twitch.';

  @override
  String get apiErrorNetwork => 'No internet connection. Check your network.';

  @override
  String get apiErrorConnectionTimeout =>
      'The connection timed out. Try again.';

  @override
  String get apiErrorSendTimeout => 'Sending took too long. Try again.';

  @override
  String get apiErrorReceiveTimeout =>
      'Twitch took too long to respond. Try again.';

  @override
  String get apiErrorCancelled => 'The request was canceled.';

  @override
  String get apiErrorCertificate =>
      'Couldn’t verify Twitch’s security certificate.';

  @override
  String get apiErrorUnexpected => 'An unexpected error occurred.';

  @override
  String get apiErrorBadRequest => 'The request wasn’t valid.';

  @override
  String get apiErrorUnauthorized => 'Log in to continue.';

  @override
  String get apiErrorForbidden => 'Access denied: missing permissions.';

  @override
  String get apiErrorNotFound => 'This content couldn’t be found.';

  @override
  String get apiErrorConflict =>
      'This changed in the meantime. Refresh and try again.';

  @override
  String get apiErrorInvalid => 'The data sent wasn’t valid.';

  @override
  String get apiErrorRateLimited =>
      'Too many requests. Wait a moment, then try again.';

  @override
  String get apiErrorServer => 'Twitch had a server error. Try again later.';

  @override
  String get apiErrorUnavailable => 'Twitch is temporarily unavailable.';

  @override
  String get apiErrorMaintenance =>
      'Twitch is under maintenance. Try again later.';

  @override
  String get apiErrorServerTimeout =>
      'Twitch’s server didn’t respond. Try again.';

  @override
  String apiErrorHttp({required int status}) {
    return 'HTTP error $status.';
  }

  @override
  String get apiErrorUserNotFound => 'This user doesn’t exist.';

  @override
  String get apiErrorChannelNotFound => 'This channel doesn’t exist.';

  @override
  String get apiErrorCategoryNotFound => 'Category not found.';

  @override
  String get apiErrorTokenProxyTimeout =>
      'The ONSET token service didn’t respond in time.';

  @override
  String get streamSortViewersHigh => 'Viewers (high to low)';

  @override
  String get streamSortRecommended => 'Recommended';

  @override
  String get streamSortViewersLow => 'Viewers (low to high)';

  @override
  String get streamSortRecent => 'Recently started';

  @override
  String get streamSortTooltip => 'Sort streams';

  @override
  String get followedSortTooltip => 'Sort live channels';

  @override
  String streamSortedBy({required String sort}) {
    return 'Sorted by $sort';
  }

  @override
  String get streamListTagUnavailable =>
      'Streams for this tag aren’t available right now.';

  @override
  String streamListSortFailed({
    required String sort,
    required String fallback,
  }) {
    return 'Twitch couldn’t sort by $sort. $fallback still works.';
  }

  @override
  String get streamListLoadFailed => 'Couldn’t load streams.';

  @override
  String get streamListPinnedFailed => 'Couldn’t load pinned streams.';

  @override
  String get streamListOfflineFailed => 'Couldn’t load offline channels.';

  @override
  String get streamListAllHidden => 'Every stream here has a label you hide';

  @override
  String get streamListShowHidden => 'Show them';

  @override
  String get streamListEmptyFollowed => 'No followed streams';

  @override
  String get streamListEmptyTop => 'No live streams right now';

  @override
  String get streamListEmptyLive => 'No live streams';

  @override
  String get streamListPinned => 'Pinned';

  @override
  String get streamListAll => 'All';

  @override
  String get streamListLiveNow => 'Live now';

  @override
  String streamListHiddenCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count streams hidden by your content preferences',
      one: '$count stream hidden by your content preferences',
    );
    return '$_temp0';
  }

  @override
  String get streamListShow => 'Show';

  @override
  String get followedVideosTitle => 'Followed videos';

  @override
  String get contentWarningTitle => 'Just one second…';

  @override
  String get contentWarningAudience =>
      'This content is intended for certain audiences.';

  @override
  String contentWarningAudienceOf({required String name}) {
    return '$name’s content is intended for certain audiences.';
  }

  @override
  String contentWarningMayContain({required String labels}) {
    return 'It may contain: $labels';
  }

  @override
  String get contentWarningStart => 'Start watching';

  @override
  String get contentWarningBack => 'Go back';

  @override
  String liveFeedHidden({required String name}) {
    return 'You won’t see $name in Live for now.';
  }

  @override
  String get liveFeedUndo => 'Undo';

  @override
  String get liveFeedAllCategories => 'All';

  @override
  String get liveFeedPreviewUnavailable => 'Preview unavailable';

  @override
  String get liveFeedContentWarningSemantics => 'Content warning. Play preview';

  @override
  String get liveFeedContentWarning => 'Content warning · Play preview';

  @override
  String get liveFeedPlayPreview => 'Play preview';

  @override
  String get liveFeedUnmute => 'Unmute';

  @override
  String get liveFeedMute => 'Mute';

  @override
  String get liveFeedSoundOn => 'Sound on';

  @override
  String get liveFeedMuted => 'Muted preview';

  @override
  String get liveFeedWatchWithChat => 'Watch with chat';

  @override
  String liveFeedFollowOnTwitch({required String name}) {
    return 'Follow $name on Twitch';
  }

  @override
  String get liveFeedFollow => 'Follow';

  @override
  String liveFeedPreviewSemantics({required String name}) {
    return '$name live preview. Opens the channel';
  }

  @override
  String get liveFeedChannelActions => 'Channel actions';

  @override
  String get liveFeedNotInterested => 'Not interested';

  @override
  String get liveFeedShare => 'Share';

  @override
  String get liveFeedSwipeHint => 'SWIPE UP FOR THE NEXT STREAM';

  @override
  String get liveFeedUpNext => 'UP NEXT';

  @override
  String get liveFeedUpNextHelp =>
      'Swipe up on the preview, or tap a stream in the list. Previews never start with sound.';

  @override
  String get liveFeedLoadingMore => 'Loading more live channels…';

  @override
  String get liveFeedEnd => 'That’s every live channel here for now';

  @override
  String get liveFeedBackToFirst => 'Back to the top';

  @override
  String get commonSeeAll => 'See all';

  @override
  String get searchTabTop => 'Top';

  @override
  String get searchTabChannels => 'Channels';

  @override
  String get searchTabCategories => 'Categories';

  @override
  String get searchTabVideos => 'Videos';

  @override
  String get searchClear => 'Clear';

  @override
  String get searchHint => 'Search';

  @override
  String searchSeeAllSemantics({required String section}) {
    return 'See all $section';
  }

  @override
  String get searchHistory => 'Recent searches';

  @override
  String searchRemoveFromHistory({required String query}) {
    return 'Remove $query from history';
  }

  @override
  String get searchNoHistory => 'No recent searches';

  @override
  String get searchCategoriesFailed => 'Couldn’t load categories.';

  @override
  String get searchCategoriesUnavailable => 'Couldn’t get categories.';

  @override
  String get searchNoCategories => 'No matching categories';

  @override
  String get searchChannelNotFound => 'Couldn’t find that channel.';

  @override
  String get searchChannelsFailed => 'Couldn’t load channels.';

  @override
  String searchGoToChannel({required String query}) {
    return 'Go to channel “$query”';
  }

  @override
  String get searchVideosFailed => 'Couldn’t load videos.';

  @override
  String get searchNoResults => 'No results found';

  @override
  String browseLiveChannels({required String where}) {
    return 'Live channels $where';
  }

  @override
  String get browseAcrossTwitch => 'across Twitch';

  @override
  String get categoriesEmpty => 'No top categories';

  @override
  String get categoriesLoadFailed => 'Couldn’t load categories.';

  @override
  String get categoriesRailTitle => 'Top categories';

  @override
  String get categoriesRailNote => 'Most-watched first';

  @override
  String get categorySectionLive => 'Live';

  @override
  String get categorySectionVideos => 'Videos';

  @override
  String get categorySectionClips => 'Clips';

  @override
  String get categoryNoVideos => 'No videos in this category';

  @override
  String get categoryEyebrow => 'CATEGORY';

  @override
  String get categoryFollowOnTwitch => 'Follow on Twitch';

  @override
  String get followedVideosToday => 'Today';

  @override
  String get followedVideosYesterday => 'Yesterday';

  @override
  String get followedVideosThisWeek => 'This week';

  @override
  String get followedVideosOlder => 'Older';

  @override
  String get followedVideosEmpty => 'No recent videos';

  @override
  String get followedVideosSubtitle =>
      'The newest videos from channels you follow';

  @override
  String get followedVideosRefresh => 'Refresh';

  @override
  String get followedVideosLoadFailed => 'Couldn’t load videos.';

  @override
  String get continueWatchingTitle => 'Continue watching';

  @override
  String continueWatchingResumeAt({required String time}) {
    return 'Resume at $time';
  }

  @override
  String get continueWatchingEmpty => 'Nothing to resume';

  @override
  String get savedToday => 'today';

  @override
  String get savedYesterday => 'yesterday';

  @override
  String savedDaysAgo({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '$count day ago',
    );
    return '$_temp0';
  }

  @override
  String savedWeeksAgo({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks ago',
      one: '$count week ago',
    );
    return '$_temp0';
  }

  @override
  String savedMonthsAgo({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '$count month ago',
    );
    return '$_temp0';
  }

  @override
  String get timeAgoJustNow => 'Just now';

  @override
  String timeAgoMinutes({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '$count minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHours({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '$count hour ago',
    );
    return '$_temp0';
  }

  @override
  String get timeAgoYesterday => 'Yesterday';

  @override
  String timeAgoDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '$count day ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoWeeks({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks ago',
      one: '$count week ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoMonths({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '$count month ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoYears({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '$count year ago',
    );
    return '$_temp0';
  }

  @override
  String videoViews({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString views',
      one: '$countString view',
    );
    return '$_temp0';
  }

  @override
  String videoViewsCompact({required int count}) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString views',
      one: '$countString view',
    );
    return '$_temp0';
  }

  @override
  String videoViewsShort({required int count, required String views}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$views views',
      one: '$views view',
    );
    return '$_temp0';
  }

  @override
  String get clipUntitled => 'Untitled clip';

  @override
  String get clipsPlayerSemantics =>
      'Clip player. Double-tap to play or pause.';

  @override
  String get clipsCannotPlay => 'This clip can’t be played here.';

  @override
  String get clipsLoadingMore => 'Loading more clips…';

  @override
  String get clipsLoadFailed => 'Couldn’t load clips.';

  @override
  String get clipsEmpty => 'No clips right now';

  @override
  String get clipsOpen => 'Open clip';

  @override
  String clipsNextSemantics({required String channel, required String title}) {
    return 'Next clip, $channel, $title';
  }

  @override
  String get clipsNext => 'NEXT';

  @override
  String get clipsSwipeHint => 'Swipe for the next clip';

  @override
  String get clipsLoadMoreFailed => 'Couldn’t load more clips.';

  @override
  String get clipsEnd =>
      'That’s all for now! Check out more clips from previous streams.';

  @override
  String get clipsUpNext => 'Up next in Clips';

  @override
  String get clipsUpNextHelp => 'Swipe the video or pick one';

  @override
  String clipOpenChannel({required String channel}) {
    return 'Open $channel';
  }

  @override
  String clipOpenChannelClippedBy({
    required String channel,
    required String curator,
  }) {
    return 'Open $channel, clipped by $curator';
  }

  @override
  String clipClippedBy({required String curator}) {
    return 'Clipped by $curator';
  }

  @override
  String get clipWatchFullVideo => 'Watch full video';

  @override
  String get clipCopyLink => 'Copy link';

  @override
  String get clipShare => 'Share';

  @override
  String get clipsNoneForPeriod => 'No clips for this period';

  @override
  String clipsShowingTop({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Showing the first $count clips',
      one: 'Showing the first clip',
    );
    return '$_temp0';
  }

  @override
  String get clipsCategoryNotFound => 'Category not found.';

  @override
  String get clipsChannelNotFound => 'Channel not found.';

  @override
  String get clipsListFailed => 'Couldn’t load clips.';

  @override
  String clipsMoreFrom({required String channel}) {
    return 'More clips from $channel';
  }

  @override
  String get clipLinkCopied => 'Link copied';

  @override
  String get clipCopyClipLink => 'Copy clip link';

  @override
  String get clipDetailsFailed => 'Couldn’t load the clip details.';

  @override
  String get clipSyncedToClip => 'synced to the clip';

  @override
  String playbackSubscriberOnly({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'This clip is available only to subscribers.',
      'other': 'This video is available only to subscribers.',
    });
    return '$_temp0';
  }

  @override
  String playbackGeoBlocked({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'This clip isn’t available in your region.',
      'other': 'This video isn’t available in your region.',
    });
    return '$_temp0';
  }

  @override
  String playbackNotFound({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'This clip is no longer available.',
      'other': 'This video is no longer available.',
    });
    return '$_temp0';
  }

  @override
  String playbackFailed({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'Couldn’t play this clip.',
      'other': 'Couldn’t play this video.',
    });
    return '$_temp0';
  }

  @override
  String get playbackSubscribeDetail =>
      'Subscribe now to watch and support this channel.';

  @override
  String get clipPeriodLastDay => '24 hours';

  @override
  String get clipPeriodLastWeek => '7 days';

  @override
  String get clipPeriodLastMonth => '30 days';

  @override
  String get clipPeriodAllTime => 'All time';

  @override
  String get clipSortTop => 'Top';

  @override
  String get clipSortTrending => 'Trending';

  @override
  String get profileTabHome => 'Home';

  @override
  String get profileTabVideos => 'Videos';

  @override
  String get profileTabClips => 'Clips';

  @override
  String get profileTabSchedule => 'Schedule';

  @override
  String get profileTabAbout => 'About';

  @override
  String get profileRefreshFailed => 'Couldn’t refresh this channel.';

  @override
  String get profileOpenFailed =>
      'Couldn’t open this channel. Check your connection.';

  @override
  String get profileShare => 'Share';

  @override
  String get profileMore => 'More';

  @override
  String get profileLoadFailed => 'Couldn’t load this channel’s profile.';

  @override
  String get profileNoDetails => 'No details';

  @override
  String get profileScheduleFailed => 'Couldn’t load the schedule.';

  @override
  String get profileNotFound => 'Channel not found.';

  @override
  String profileFollowers({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString followers',
      one: '$countString follower',
    );
    return '$_temp0';
  }

  @override
  String profileFollowersShort({
    required int count,
    required String followers,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$followers followers',
      one: '$followers follower',
    );
    return '$_temp0';
  }

  @override
  String profileJoined({required DateTime date}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMM(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Joined $dateString';
  }

  @override
  String get profilePartner => 'Partner';

  @override
  String get profileAffiliate => 'Affiliate';

  @override
  String profileAboutTitle({required String name}) {
    return 'About $name';
  }

  @override
  String get profileNoBio => 'No bio yet.';

  @override
  String get profilePanelImage => 'Panel image';

  @override
  String get profileWatchLive => 'Watch live';

  @override
  String get profileChat => 'Chat';

  @override
  String profileNextStreamAt({required String time}) {
    return 'Next stream · $time';
  }

  @override
  String get profileComingUp => 'Coming up';

  @override
  String get profileRecentBroadcasts => 'Recent broadcasts';

  @override
  String get profilePopularClips => 'Popular clips';

  @override
  String get profileThumbnail => 'Thumbnail';

  @override
  String get videoUntitled => 'Untitled';

  @override
  String get profileRecording => 'Recording';

  @override
  String get profileWatched => 'Watched';

  @override
  String get profileSubscribersOnly => 'Subscribers only';

  @override
  String profileLastLive({required String when}) {
    return 'Last live $when';
  }

  @override
  String get profileRerun => 'Rerun';

  @override
  String get profileRerunBadge => 'RERUN';

  @override
  String get profileLive => 'Live';

  @override
  String get profileReminderSet => 'Reminder set';

  @override
  String get profileRemindMe => 'Remind me';

  @override
  String get startsNow => 'starting now';

  @override
  String startsInMinutes({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count minutes',
      one: 'in $count minute',
    );
    return '$_temp0';
  }

  @override
  String startsInHours({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count hours',
      one: 'in $count hour',
    );
    return '$_temp0';
  }

  @override
  String startsInDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'in $count day',
    );
    return '$_temp0';
  }

  @override
  String get profileReminderRefused =>
      'Allow notifications for this app in the system settings.';

  @override
  String get profileReminderFailed => 'Couldn’t set the reminder.';

  @override
  String get profileStreamUntitled => 'Untitled stream';

  @override
  String get profileNoSchedule => 'No streams scheduled';

  @override
  String profileNextStreamIn({required String when, required String time}) {
    return 'Next stream $when · $time';
  }

  @override
  String get profileCancelled => 'Canceled';

  @override
  String get profilePastBroadcasts => 'Past broadcasts';

  @override
  String get profileNoPastBroadcasts => 'No past broadcasts';

  @override
  String get profileHighlights => 'Highlights';

  @override
  String get profileNoHighlights => 'No highlights';

  @override
  String get profileUploads => 'Uploads';

  @override
  String get profileNoUploads => 'No uploads';

  @override
  String get videosListFailed => 'Couldn’t load videos.';

  @override
  String videosShowingMostViewed({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Showing the $count most-viewed videos',
      one: 'Showing the most-viewed video',
    );
    return '$_temp0';
  }

  @override
  String videosShowingMostRecent({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Showing the $count most recent videos',
      one: 'Showing the most recent video',
    );
    return '$_temp0';
  }

  @override
  String get videoProcessing => 'Processing';

  @override
  String get videoUntitledBroadcast => 'Untitled broadcast';

  @override
  String get activityTitle => 'Activity';

  @override
  String get activityNote => 'Notifications ONSET has shown on this device.';

  @override
  String get activityRemove => 'Remove notification';

  @override
  String get activityEmpty => 'Hooray! You’re up to date';

  @override
  String get activityEmptyDetail =>
      'Check back soon for alerts about you and the broadcasters you follow.';

  @override
  String get activityMostRecent => 'Most recent';

  @override
  String get activityEarlier => 'Earlier';

  @override
  String get activityMarkAllRead => 'Mark all as read';

  @override
  String get activityOptions => 'Options';

  @override
  String get activityUnread => 'Unread';

  @override
  String get activityNoWhispers =>
      'No whispers yet. Whispers you get while the app is open show up here.';

  @override
  String get activityKindLive => 'Live';

  @override
  String get activityKindMention => 'Chat mentions';

  @override
  String get activityKindReminder => 'Events';

  @override
  String get whispersTitle => 'Whispers';

  @override
  String whispersUnreadCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '$count unread',
    );
    return '$_temp0';
  }

  @override
  String get whispersAllRead => 'All read';

  @override
  String get whispersChoose => 'Choose a conversation';

  @override
  String get whispersEmpty => 'No whispers yet';

  @override
  String get whispersEmptyDetail =>
      'Whispers you get while the app is open show up here.';

  @override
  String get whisperSessionNote =>
      'Twitch keeps no history the app can show, so only this session’s whispers appear here.';

  @override
  String whisperHint({required String name}) {
    return 'Whisper $name';
  }

  @override
  String get whisperSend => 'Send';

  @override
  String get whisperYou => 'You';

  @override
  String get whisperOpen => 'Open';

  @override
  String get whisperStatusRefused =>
      'Twitch refused to send your whispers to this app. Log out and log in again to allow them.';

  @override
  String get whisperStatusInterrupted =>
      'Reconnecting… whispers will arrive again soon.';

  @override
  String get whisperStatusUnavailable =>
      'Twitch isn’t sending whispers to this app right now. ONSET will try again when you come back to the app.';

  @override
  String get whisperStatusOff => 'Log in to get whispers.';

  @override
  String get playerBack10 => 'Rewind 10 seconds';

  @override
  String get playerForward10 => 'Skip ahead 10 seconds';

  @override
  String get playerChangeChatLayout => 'Change chat layout';

  @override
  String get playerHideChatOverlay => 'Hide chat overlay';

  @override
  String get playerShowChatOverlay => 'Show chat overlay';

  @override
  String get playerStopLooping => 'Stop looping';

  @override
  String get playerLoop => 'Loop';

  @override
  String get playerSettings => 'Settings';

  @override
  String get playerReplay => 'Replay';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String playerElapsed({required String elapsed, required String total}) {
    return 'Elapsed time $elapsed of $total';
  }

  @override
  String get playerPictureInPicture => 'Picture-in-picture';

  @override
  String get playerFitScreen => 'Fit to screen';

  @override
  String get playerFillScreen => 'Fill screen';

  @override
  String get playerExitFullScreen => 'Exit full screen';

  @override
  String get playerFullScreen => 'Full screen';

  @override
  String get playerSpeed => 'Playback speed';

  @override
  String get playerQuality => 'Quality';

  @override
  String get playerVolume => 'Volume';

  @override
  String get playerCaptions => 'Closed captions';

  @override
  String get playerCaptionsDetail => 'When the video has them';

  @override
  String get playerSpeedNormal => 'Normal';

  @override
  String get playerSemantics => 'Video player';

  @override
  String get playerHideControls => 'hide controls';

  @override
  String get playerShowControls => 'show controls';

  @override
  String get channelFollow => 'Follow';

  @override
  String get channelFollowing => 'Following';

  @override
  String channelFollowTooltip({required String name}) {
    return 'Follow $name on Twitch';
  }

  @override
  String channelFollowingTooltip({required String name}) {
    return 'Following $name · opens twitch.tv';
  }

  @override
  String get channelSubscribe => 'Subscribe';

  @override
  String channelSubscribeTooltip({required String name}) {
    return 'Subscribe to $name · opens twitch.tv';
  }

  @override
  String get channelProfile => 'Channel profile';

  @override
  String get channelVideos => 'Videos';

  @override
  String channelWebFallback({required String notice}) {
    return '$notice Switching to the web player.';
  }

  @override
  String get channelSwipeDownForPip => 'Swipe down to enter picture-in-picture';

  @override
  String get channelResizeVideo => 'Resize video';

  @override
  String get channelResizeVideoHint =>
      'Drag to resize the video. Double-tap for full width.';

  @override
  String channelUptimeMinutes({required int minutes}) {
    return '${minutes}m';
  }

  @override
  String channelUptimeHours({required int hours, required String minutes}) {
    return '${hours}h ${minutes}m';
  }

  @override
  String channelWatchStreak({required int value}) {
    return 'Watch Streak $value';
  }

  @override
  String get channelAlsoLive => 'ALSO LIVE FROM CHANNELS YOU FOLLOW';

  @override
  String get channelChat => 'Chat';

  @override
  String get channelChatSynced => 'synced to video';

  @override
  String channelChatDelay({required int seconds}) {
    return '${seconds}s delay';
  }

  @override
  String get channelChatSettings => 'Chat settings';

  @override
  String get livePlayerQualityAndSettings => 'Quality and settings';

  @override
  String get livePlayerMute => 'Mute';

  @override
  String get livePlayerUnmute => 'Unmute';

  @override
  String get livePlayerRefresh => 'Refresh';

  @override
  String get livePlayerEnterFullScreen => 'Full screen';

  @override
  String get livePlayerExitFullScreen => 'Exit full screen';

  @override
  String get livePlayerShowChat => 'Show chat';

  @override
  String get livePlayerHideChat => 'Hide chat';

  @override
  String get livePlayerEnterLandscape => 'Enter landscape mode';

  @override
  String get livePlayerExitLandscape => 'Exit landscape mode';

  @override
  String get livePlayerEnterPip => 'Enter picture-in-picture';

  @override
  String get livePlayerExitPip => 'Exit picture-in-picture';

  @override
  String get livePlayerStreamQuality => 'Stream quality';

  @override
  String get livePlayerAudioOnly => 'Audio only';

  @override
  String get livePlayerMeasurement => 'Measurement';

  @override
  String get livePlayerVideoStats => 'Video stats';

  @override
  String get livePlayerVideoStatsDetail =>
      'Latency, buffer, bitrate, and frames over the video';

  @override
  String get livePlayerResetStats => 'Reset stats';

  @override
  String get livePlayerResetStatsDetail => 'Start a new latency measurement';

  @override
  String livePlayerSharedChatTitle({required String title}) {
    return 'Shared chat · $title';
  }

  @override
  String get livePlayerUptime => 'Stream uptime';

  @override
  String get livePlayerViewerCount => 'Viewer count';

  @override
  String get liveCaptionsDetail => 'When the stream has them';

  @override
  String liveCaptionsTrack({required int number}) {
    return 'Captions $number';
  }

  @override
  String liveRefusedSubscribersOnly({required String name}) {
    return '$name is streaming for subscribers only.';
  }

  @override
  String get liveRefusedGeoblocked =>
      'This stream is not available in your region.';

  @override
  String liveRefusedBanned({required String name}) {
    return 'You’re banned from $name’s channel.';
  }

  @override
  String get liveRefusedUnauthorized =>
      'Twitch won’t play this stream in the low-latency player.';

  @override
  String get liveRefused => 'Twitch refused this stream.';

  @override
  String liveRefusedBecause({required String reason}) {
    return 'Twitch refused this stream: $reason';
  }

  @override
  String latencySeconds({required String value}) {
    return '${value}s';
  }

  @override
  String get latencyPillTooltip => 'Latency to broadcaster';

  @override
  String get latencyPillTooltipStats =>
      'Latency to broadcaster · tap for video stats';

  @override
  String latencyPillSemantics({required String latency}) {
    return 'Latency $latency';
  }

  @override
  String latencyMegabits({required String value}) {
    return '$value Mbps';
  }

  @override
  String latencyKilobits({required int value}) {
    return '$value kbps';
  }

  @override
  String get latencyStatsLatency => 'Latency';

  @override
  String get latencyStatsSpread => 'Med / p90 / max';

  @override
  String get latencyStatsBuffer => 'Buffer';

  @override
  String get latencyStatsBitrate => 'Bitrate';

  @override
  String latencyStatsBitrateValue({
    required String bitrate,
    required String network,
  }) {
    return '$bitrate · net $network';
  }

  @override
  String get latencyStatsFrames => 'Frames';

  @override
  String latencyStatsFramesValue({
    required String fps,
    required String dropped,
    required String decoded,
  }) {
    return '$fps fps · $dropped dropped / $decoded';
  }

  @override
  String get latencyStatsLowLatency => 'Low latency';

  @override
  String get latencyStatsOn => 'on';

  @override
  String get latencyStatsOff => 'off';

  @override
  String get latencyStatsSpeed => 'Speed';

  @override
  String latencyStatsRate({required String rate}) {
    return '$rate×';
  }

  @override
  String get latencyStatsMode => 'Mode';

  @override
  String get latencyStatsAutoLatency => 'Auto latency';

  @override
  String get latencyStatsNextStreams => 'Next streams';

  @override
  String get latencyStatsStartup => 'Startup';

  @override
  String get latencyStatsRebuffers => 'Rebuffers';

  @override
  String get latencyStatsLiveJumps => 'Jumps to live';

  @override
  String get latencyAutoOff => 'off';

  @override
  String latencyAutoWithTarget({
    required String status,
    required String latency,
  }) {
    return '$status · target $latency';
  }

  @override
  String latencyAutoStopped({required String reason}) {
    return 'stopped: $reason';
  }

  @override
  String latencyAutoHeld({required String reason}) {
    return 'held: $reason';
  }

  @override
  String get latencyAutoSettling => 'waiting for calm';

  @override
  String latencyAutoSettlingSeconds({required int seconds}) {
    return 'waiting for calm ${seconds}s';
  }

  @override
  String get latencyAutoSteady => 'at target';

  @override
  String latencyAutoCatchingUp({required String rate}) {
    return 'catching up $rate×';
  }

  @override
  String latencyAutoDraining({required String rate}) {
    return 'draining $rate×';
  }

  @override
  String latencyAutoDrainingBecause({
    required String rate,
    required String reason,
  }) {
    return 'draining $rate× ($reason)';
  }

  @override
  String get latencyReasonGaveUp => 'gave up';

  @override
  String get latencyReasonHeld => 'waiting';

  @override
  String get latencyReasonAd => 'ad';

  @override
  String get latencyReasonNoBufferReading => 'no buffer reading';

  @override
  String get latencyReasonNoLatencyReading => 'no latency reading';

  @override
  String get latencyReasonNoLatencyTicks => 'no latency ticks';

  @override
  String get latencyReasonNotLowLatency => 'not a low-latency stream';

  @override
  String get latencyReasonPaused => 'paused';

  @override
  String get latencyReasonReconnecting => 'reconnecting';

  @override
  String get latencyReasonBuffering => 'buffering';

  @override
  String get latencyReasonRateRefused => 'the player refused the rate';

  @override
  String get latencyReasonRateNotKept => 'the player didn’t keep the rate';

  @override
  String get latencyReasonStalls => 'stalls after catching up';

  @override
  String latencyReasonStuckFast({required String rate}) {
    return 'the player stayed at $rate×';
  }

  @override
  String latencyReasonNotBackToNormal({required String rate}) {
    return 'the player didn’t return to $rate×';
  }

  @override
  String latencyBufferFallback({required String time}) {
    return 'Standard until $time (Ultra stalled)';
  }

  @override
  String get clipCreateTitle => 'Create clip';

  @override
  String get clipCreateButton => 'Clip';

  @override
  String get clipCreateGenerating => 'Creating clip…';

  @override
  String get clipCreateRendering => 'Rendering clip…';

  @override
  String get clipCreateLogIn => 'Log in to create clips.';

  @override
  String get clipCreateLogInAction => 'Log in';

  @override
  String get clipCreateMissingScope =>
      'Creating clips needs a permission your Twitch login doesn’t have yet. Reconnect to Twitch to allow it.';

  @override
  String get clipCreateReconnect => 'Reconnect to Twitch';

  @override
  String get clipCreateShare => 'Share clip';

  @override
  String get clipCreateLinkCopied => 'Clip link copied';

  @override
  String get clipCreateThumbnail => 'Clip thumbnail';

  @override
  String get clipCreateEdit => 'Edit';

  @override
  String get clipCreateEditDetail =>
      'Title and moment, in the twitch.tv clip editor';

  @override
  String get clipCreateEditorTitle => 'Edit clip';

  @override
  String get clipCreateFailedMissingScope =>
      'Your Twitch login doesn’t allow creating clips.';

  @override
  String get clipCreateFailedRestricted =>
      'You can’t clip this channel right now: clips may be off or limited to followers or subscribers, or you’re banned or timed out here.';

  @override
  String get clipCreateFailedOffline => 'Only live streams can be clipped.';

  @override
  String get clipCreateFailedNotClippable =>
      'This channel doesn’t allow clips of this category.';

  @override
  String get clipCreateFailedRateLimited =>
      'Too many clips at once. Try again in a moment.';

  @override
  String get clipCreateFailedUnknown => 'Hmm… something went wrong.';

  @override
  String get commonHide => 'Hide';

  @override
  String commonPercent({required int value}) {
    return '$value%';
  }

  @override
  String celebrationEffect({required String effect}) {
    String _temp0 = intl.Intl.selectLogic(effect, {
      'fireworks': 'Fireworks',
      'rain': 'Rain',
      'float': 'Float',
      'flamethrower': 'Flamethrower',
      'extinctionEvent': 'Extinction event',
      'other': 'Sparkles',
    });
    return '$_temp0';
  }

  @override
  String celebrationChatLine({required String effect}) {
    return 'Celebration: $effect';
  }

  @override
  String celebrationChatLineGiftedSubs({required String effect}) {
    return 'Gifted subs celebration: $effect';
  }

  @override
  String highlightKind({required String kind}) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'poll': 'Poll',
      'prediction': 'Prediction',
      'pinned': 'Pinned',
      'raid': 'Raid',
      'giftBomb': 'Gift subs',
      'incomingRaid': 'Incoming raid',
      'other': 'Highlight',
    });
    return '$_temp0';
  }

  @override
  String highlightNew({required String kind}) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'poll': 'New poll',
      'prediction': 'New prediction',
      'pinned': 'New pinned',
      'raid': 'New raid',
      'giftBomb': 'New gift subs',
      'incomingRaid': 'New incoming raid',
      'other': 'New highlight',
    });
    return '$_temp0';
  }

  @override
  String highlightAndMore({required String label, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more',
      one: '$count more',
    );
    return '$label and $_temp0';
  }

  @override
  String get highlightPrevious => 'Previous highlight';

  @override
  String get highlightNext => 'Next highlight';

  @override
  String highlightPosition({required int index, required int count}) {
    return 'Highlight $index of $count';
  }

  @override
  String get highlightTwitchChat => 'Twitch chat';

  @override
  String get highlightThisChannel => 'This channel';

  @override
  String highlightTimeLeft({required String time}) {
    return '$time left';
  }

  @override
  String highlightVotes({required int count}) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString votes',
      one: '$countString vote',
    );
    return '$_temp0';
  }

  @override
  String get highlightFinalResults => 'Final results';

  @override
  String get highlightFinalResultsLower => 'final results';

  @override
  String highlightPollLeads({required String choice, required int percent}) {
    return '$choice leads with $percent percent';
  }

  @override
  String get highlightVote => 'Vote on Twitch';

  @override
  String get highlightPredictionsOpen => 'Predictions open';

  @override
  String get highlightPredictionsClosed => 'Predictions closed';

  @override
  String get highlightPredictionWaiting => 'Waiting for the result';

  @override
  String get highlightPredictionResult => 'Result';

  @override
  String get highlightPredictionCanceled => 'Canceled · points refunded';

  @override
  String highlightWinnerLower({required String outcome}) {
    return 'winner $outcome';
  }

  @override
  String highlightOutcomeShare({
    required String outcome,
    required int percent,
  }) {
    return '$outcome $percent percent';
  }

  @override
  String highlightTimeToPredict({required String time}) {
    return '$time to predict';
  }

  @override
  String highlightWinner({required String outcome}) {
    return 'Winner: $outcome';
  }

  @override
  String get highlightPredict => 'Predict on Twitch';

  @override
  String get highlightWinnerMark => 'Winner';

  @override
  String highlightPoints({required int count}) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString points',
      one: '$countString point',
    );
    return '$_temp0';
  }

  @override
  String highlightPredictors({required int count}) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString predictors',
      one: '$countString predictor',
    );
    return '$_temp0';
  }

  @override
  String highlightTopPredictor({required String name}) {
    return 'Top: $name';
  }

  @override
  String highlightPinnedFrom({required String sender, required String text}) {
    return 'Pinned message from $sender: $text';
  }

  @override
  String highlightPinnedBy({required String name}) {
    return 'by $name';
  }

  @override
  String raidViewers({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString viewers',
      one: '$countString viewer',
    );
    return '$_temp0';
  }

  @override
  String raidStay({required String source}) {
    return 'You’re staying on $source';
  }

  @override
  String raidStayDetail({required String target}) {
    return 'The raid goes to $target without you';
  }

  @override
  String raidLeftFor({required String target}) {
    return 'The raid left for $target';
  }

  @override
  String raidWentAlong({required int count, required String viewers}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$viewers went along',
      one: '$viewers went along',
    );
    return '$_temp0';
  }

  @override
  String get raidCancelled => 'Raid canceled';

  @override
  String raidStaysLive({required String source}) {
    return '$source stays live';
  }

  @override
  String raidRaidingWith({
    required String source,
    required String target,
    required String viewers,
  }) {
    return '$source is raiding $target with $viewers';
  }

  @override
  String raidRaiding({required String source, required String target}) {
    return '$source is raiding $target';
  }

  @override
  String raidHeadingTo({required String target}) {
    return 'Heading to $target';
  }

  @override
  String raidToHasLeft({required String target}) {
    return 'The raid to $target has left';
  }

  @override
  String raidWatchTarget({required String target}) {
    return 'Watch $target';
  }

  @override
  String get raidBadge => 'RAID';

  @override
  String raidGoAlong({required String viewers}) {
    return '$viewers · you go along automatically';
  }

  @override
  String raidLeavesIn({required String time}) {
    return 'Leaves in $time';
  }

  @override
  String get raidGoNow => 'Go now';

  @override
  String raidGoNowTarget({required String target}) {
    return 'Go to $target now';
  }

  @override
  String get raidStayHere => 'Stay here';

  @override
  String get raidHeadingOut => 'Heading out…';

  @override
  String raidIncoming({
    required int count,
    required String name,
    required String viewers,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name is raiding with $viewers viewers',
      one: '$name is raiding with $viewers viewer',
    );
    return '$_temp0';
  }

  @override
  String get raidSayHi => 'Say hi in chat';

  @override
  String raidComingWithYou({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString viewers coming with you',
      one: '$countString viewer coming with you',
    );
    return '$_temp0';
  }

  @override
  String giftBombGifting({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'is gifting $count subs',
      one: 'is gifting $count sub',
    );
    return '$_temp0';
  }

  @override
  String giftBombSemantics({required int count, required String name}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name is gifting $count subs',
      one: '$name is gifting $count sub',
    );
    return '$_temp0';
  }

  @override
  String giftBombAllHandedOut({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'all $count handed out',
      one: 'all $count handed out',
    );
    return '$_temp0';
  }

  @override
  String giftBombHandedOutSemantics({
    required int received,
    required int count,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      received,
      locale: localeName,
      other: '$received of $count handed out',
      one: '$received of $count handed out',
    );
    return '$_temp0';
  }

  @override
  String giftBombProgress({
    required int receivedCount,
    required String received,
    required int total,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      receivedCount,
      locale: localeName,
      other: '$received of $total handed out',
      one: '$received of $total handed out',
    );
    return '$_temp0';
  }

  @override
  String giftBombDone({required int count}) {
    return '$count of $count · thanks!';
  }

  @override
  String get htTitle => 'Hype Train';

  @override
  String htTrainTitle({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Golden Kappa Train',
      'treasure': 'Treasure Train',
      'community': 'Community Train',
      'mythic': 'Mythic Train',
      'other': 'Hype Train',
    });
    return '$_temp0';
  }

  @override
  String htSharedTrainTitle({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Shared Golden Kappa Train',
      'community': 'Shared Community Train',
      'mythic': 'Shared Mythic Train',
      'other': 'Shared Hype Train',
    });
    return '$_temp0';
  }

  @override
  String htLevelShort({required int level}) {
    return 'LVL $level';
  }

  @override
  String get htSubtitle => 'Sub, gift, or use Bits!';

  @override
  String get htFinalLevel => 'Final level!';

  @override
  String get htAthApproaching =>
      'About to beat the channel’s record. Keep up the support.';

  @override
  String get htAthApproachingCompact => 'About to beat the channel’s record.';

  @override
  String get htAthReached =>
      'Setting a new record! Keep going until the clock runs out.';

  @override
  String get htAthReachedShared =>
      'Setting a new shared record! Keep going until the clock runs out.';

  @override
  String htTreasureLocked({required int level, required int discount}) {
    return 'Reach level $level to unlock $discount% off gift subs!';
  }

  @override
  String htTreasureUnlockedSubtitle({required int discount}) {
    return '$discount% off 5+ gift subs for the rest of this Hype Train';
  }

  @override
  String htCommunityLocked({required int level}) {
    return 'Hit level $level and chat will receive emotes too!';
  }

  @override
  String htCommunityUnlockedSubtitle({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString emotes for chat',
      one: '$countString emote for chat',
    );
    return '$_temp0';
  }

  @override
  String htLevelComplete({required int level}) {
    return 'Level $level complete!';
  }

  @override
  String htStarted({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Golden Kappa Train starting!',
      'treasure': 'Treasure Train incoming!',
      'community': 'Community Train incoming!',
      'mythic': 'Mythic Train incoming!',
      'other': 'Hype Train starting!',
    });
    return '$_temp0';
  }

  @override
  String htSharedStarted({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Shared Golden Kappa Train starting!',
      'other': 'Shared Hype Train starting!',
    });
    return '$_temp0';
  }

  @override
  String get htLevelUp => 'hyyyyypeeee';

  @override
  String htCompleted({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Golden Kappa Train success!',
      'treasure': 'Treasure Train success!',
      'community': 'Community Train success!',
      'mythic': 'Mythic Train success!',
      'other': 'Hype Train success!',
    });
    return '$_temp0';
  }

  @override
  String htSharedCompleted({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Shared Golden Kappa Train success!',
      'other': 'Shared Hype Train success!',
    });
    return '$_temp0';
  }

  @override
  String get htTreasureUnlockedMarquee => 'TREASURE TRAIN UNLOCKED!';

  @override
  String get htCommunityUnlockedMarquee => 'COMMUNITY REWARDS UNLOCKED!';

  @override
  String get htMerging =>
      'Get excited! Your powers are combining and levels are getting a boost!';

  @override
  String get htSummaryRecord =>
      'All-time record shattered!\nYou’ve reached new levels of support!';

  @override
  String htSummary({required String variant, required int level}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'treasure':
          'Such strong support!\nTreasure Train level $level completed!',
      'community':
          'Such strong support!\nCommunity Train level $level completed!',
      'mythic': 'Such strong support!\nMythic Train level $level completed!',
      'other': 'Such strong support!\nLevel $level completed!',
    });
    return '$_temp0';
  }

  @override
  String get htAthReachedTitle => 'All-time record shattered!';

  @override
  String get htSomeone => 'Someone';

  @override
  String htContributionBits({required int count, required String name}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name just used $countString Bits!',
      one: '$name just used $countString Bit!',
    );
    return '$_temp0';
  }

  @override
  String htContributionGift({
    required int count,
    required String name,
    required int tier,
  }) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name just gifted $countString Tier $tier subs!',
      one: '$name just gifted $countString Tier $tier sub!',
    );
    return '$_temp0';
  }

  @override
  String htContributionSub({required String name, required int tier}) {
    return '$name just subscribed at Tier $tier!';
  }

  @override
  String htContributionOther({required String name}) {
    return '$name just boosted the train!';
  }

  @override
  String htSubs({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString subs',
      one: '$countString sub',
    );
    return '$_temp0';
  }

  @override
  String htBits({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Bits',
      one: '$countString Bit',
    );
    return '$_temp0';
  }

  @override
  String htInstructionStart({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa':
          'You’ll have a limited time to earn an exclusive Golden Kappa emote, valid for 24 hours',
      'community': 'Whoa, this is a rare Community Train!',
      'mythic': 'Whoa, this is a rare Mythic Train!',
      'other': 'You’ll have a limited time to earn exclusive emotes',
    });
    return '$_temp0';
  }

  @override
  String htInstructionTreasureReachLevel({
    required int level,
    required int discount,
  }) {
    return 'Reach level $level during this train to unlock $discount% off gift subs!';
  }

  @override
  String get htInstructionTreasureOneAway =>
      'One more level unlocks a discount for the rest of this train. Keep going!';

  @override
  String htInstructionTreasureUnlocked({required int discount}) {
    return 'You’ve unlocked $discount% off 5+ gift subs! Don’t miss out!';
  }

  @override
  String htCommunityUnlocked({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You unlocked $countString emotes for chat! Level up to give away more emotes.',
      one:
          'You unlocked $countString emote for chat! Level up to give away more emotes.',
    );
    return '$_temp0';
  }

  @override
  String get htInstructionCommunityRewards =>
      'Emotes for chat are on their way!';

  @override
  String get htInstructionSeeYouNextTime =>
      'See you next time in a Shared Hype Train!';

  @override
  String htSharedLevel({required int level, required int percent}) {
    return 'LVL $level, $percent%';
  }

  @override
  String get htSharedLevelReached => 'Shared Train level reached';

  @override
  String htContinuesIn({required int level}) {
    return 'LVL $level train continues in';
  }

  @override
  String htOtherChannelRecord({required String name}) {
    return '$name’s new all-time shared record!';
  }

  @override
  String get htSharedRecordReached => 'Shared Train record broken!';

  @override
  String get htSharedNew => 'New Shared Hype Train';

  @override
  String htApproachingTitle({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Golden Kappa Train approaching!',
      'treasure': 'A Treasure Train is close!',
      'community': 'A Community Train is close!',
      'mythic': 'A Mythic Train is close!',
      'other': 'A Hype Train is approaching!',
    });
    return '$_temp0';
  }

  @override
  String htApproachingSubtitle({required String train}) {
    return 'Sub, gift, or use Bits now to start a $train';
  }

  @override
  String htApproachingMore({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more people need to sub, gift, or use Bits',
      one: '$count more person needs to sub, gift, or use Bits',
    );
    return '$_temp0';
  }

  @override
  String get htApproachingShort => 'Approaching';

  @override
  String htApproachingQuestion({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'What is a Golden Kappa Train?',
      'other': 'What is a Hype Train?',
    });
    return '$_temp0';
  }

  @override
  String htApproachingExplanationFirst({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa':
          'A Golden Kappa Train starts when multiple people subscribe, use Bits, or gift subscriptions to the community.',
      'other':
          'A Hype Train starts when multiple people subscribe, use Bits, or gift subscriptions to the community.',
    });
    return '$_temp0';
  }

  @override
  String htApproachingExplanationSecond({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa':
          'Once a Golden Kappa Train is underway, the community fills up the Hype Meter with more subs, gifts, or Bits. Everyone who contributes enough to be eligible for rewards will receive the Golden Kappa emote for 24 hours in addition to the regular emote rewards.',
      'other':
          'Once a Hype Train is underway, the community fills up the Hype Meter with more subs, gifts, or Bits. Everyone who contributes receives one unique emote based on the highest level completed.',
    });
    return '$_temp0';
  }

  @override
  String get htRewards =>
      'Great work! Emotes are being delivered to supporters';

  @override
  String get htGoldenRewards =>
      'Great work! Supporters can enjoy the exclusive Golden Kappa emote for 24 hours';

  @override
  String get htExpired => 'You missed the train. Better luck next time!';

  @override
  String get htGoldenExpired =>
      'The Golden Kappa Train is long gone. Better luck next time!';

  @override
  String get htConductorsHeader => 'HYPE CONDUCTORS';

  @override
  String get htConductorsDescription => 'Current Hype Train top supporters.';

  @override
  String get htRewardsHeader => 'AVAILABLE REWARDS';

  @override
  String get htRewardsDescription =>
      'You can earn one emote per train by subbing, gifting, or using more than 100 Bits in total during the event. Exclusive emotes are given out at the end of the Hype Train event and will stick around until the end of the current season.';

  @override
  String get htGoldenRewardsDescription =>
      'Contribute by subbing, gifting, or using more than 100 Bits in total during the event to earn an exclusive Golden Kappa emote for 24 hours in addition to the regular emote rewards.';

  @override
  String get htContributionsHeader => 'CONTRIBUTIONS';

  @override
  String htLevelEmotes({required int level}) {
    return 'Level $level emotes';
  }

  @override
  String get htMoreInfo => 'More info';

  @override
  String get htLearnMore => 'Learn more';

  @override
  String get htUnlockedSoFar => 'Unlocked so far';

  @override
  String get htComingUp => 'Coming up';

  @override
  String get htNothingMore => 'Nothing more to show yet';

  @override
  String htLevelTarget({
    required int level,
    required int subs,
    required int bits,
  }) {
    final intl.NumberFormat subsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String subsString = subsNumberFormat.format(subs);
    final intl.NumberFormat bitsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String bitsString = bitsNumberFormat.format(bits);

    String _temp0 = intl.Intl.pluralLogic(
      subs,
      locale: localeName,
      other: '$subsString Tier 1 subs',
      one: '$subsString Tier 1 sub',
    );
    String _temp1 = intl.Intl.pluralLogic(
      bits,
      locale: localeName,
      other: '$bitsString Bits',
      one: '$bitsString Bit',
    );
    return 'Level $level needs $_temp0 or $_temp1 in total';
  }

  @override
  String htSubsConductor({required int count, required String name}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name has contributed $countString subs!',
      one: '$name has contributed $countString sub!',
    );
    return '$_temp0';
  }

  @override
  String htBitsConductor({required int count, required String name}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name has used $countString Bits',
      one: '$name has used $countString Bit',
    );
    return '$_temp0';
  }

  @override
  String get htNoSubsConductor => 'Sub or gift to take over this spot!';

  @override
  String get htNoBitsConductor => 'Use Bits to take over this spot!';

  @override
  String htChannelRecord({required int percent, required int level}) {
    return 'Channel all-time record! Level $level at $percent%';
  }

  @override
  String htTreasureCardUnlocked({required int discount}) {
    return 'Save $discount% on 5 or more gift subs, only during this train. All aboard!';
  }

  @override
  String htTreasureCardLocked({required int level, required int discount}) {
    return 'Unlock a limited-time $discount% discount on gift subs at level $level during this train!';
  }

  @override
  String htMythicCard({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Unlock 1 of $count exclusive emotes for 24 hours!',
      one: 'Unlock 1 of $count exclusive emote for 24 hours!',
    );
    return '$_temp0';
  }

  @override
  String htCardLevelRecord({required int level}) {
    return 'All-time record · Level $level';
  }

  @override
  String htCardLevel({required String train, required int level}) {
    return '$train level $level';
  }

  @override
  String get htCollapse => 'Collapse Hype Train';

  @override
  String get htExpand => 'Show Hype Train';

  @override
  String get htDetailsHint => 'show details';

  @override
  String get htSemanticsApproaching => 'Hype Train approaching';

  @override
  String htSemanticsMinutes({required int minutes}) {
    return '$minutes min';
  }

  @override
  String htSemanticsSeconds({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '$count second',
    );
    return '$_temp0';
  }

  @override
  String htSemanticsOngoing({
    required int level,
    required int percent,
    required String time,
  }) {
    return 'Hype Train level $level, $percent percent, $time left';
  }

  @override
  String htSemanticsEnded({required int level}) {
    return 'Hype Train ended at level $level';
  }

  @override
  String get htSemanticsExpired => 'Hype Train expired';

  @override
  String htRewardLocked({required String name}) {
    return 'Locked reward $name';
  }

  @override
  String htRewardUnlocked({required String name}) {
    return 'Unlocked reward $name';
  }

  @override
  String chatDurationSeconds({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '$count second',
    );
    return '$_temp0';
  }

  @override
  String chatDurationMinutes({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '$count minute',
    );
    return '$_temp0';
  }

  @override
  String chatDurationHours({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '$count hour',
    );
    return '$_temp0';
  }

  @override
  String chatDurationDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String chatDurationWeeks({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '$count week',
    );
    return '$_temp0';
  }

  @override
  String chatDurationMonths({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '$count month',
    );
    return '$_temp0';
  }

  @override
  String chatShortSeconds({required int seconds}) {
    return '${seconds}s';
  }

  @override
  String chatShortMinutes({required int minutes}) {
    return '${minutes}m';
  }

  @override
  String chatShortMinutesSeconds({required int minutes, required int seconds}) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String chatShortHours({required int hours}) {
    return '${hours}h';
  }

  @override
  String chatShortHoursMinutes({required int hours, required int minutes}) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get chatConnecting => 'Connecting to chat…';

  @override
  String chatWelcome({required String name}) {
    return 'Welcome to $name’s chat!';
  }

  @override
  String chatReconnected({required int attempts, required int seconds}) {
    String _temp0 = intl.Intl.pluralLogic(
      attempts,
      locale: localeName,
      other: 'Reconnected ($attempts attempts, ${seconds}s)',
      one: 'Reconnected ($attempts attempt, ${seconds}s)',
    );
    return '$_temp0';
  }

  @override
  String chatReconnectingIn({
    required int seconds,
    required int attempt,
    required int max,
  }) {
    return 'Reconnecting in ${seconds}s… (attempt $attempt of $max)';
  }

  @override
  String chatReconnecting({required int attempt, required int max}) {
    return 'Reconnecting… (attempt $attempt of $max)';
  }

  @override
  String get chatDisconnected => 'Chat disconnected. Check your connection.';

  @override
  String get chatReconnect => 'Reconnect';

  @override
  String get chatReconnectingNotice => 'Reconnecting to chat…';

  @override
  String chatSyncIn({required int seconds}) {
    return 'Chat will sync in ${seconds}s…';
  }

  @override
  String chatSevenTvEmoteAdded({required String name, required String emote}) {
    return '$name added the 7TV emote “$emote” to chat.';
  }

  @override
  String chatSevenTvEmoteRemoved({
    required String name,
    required String emote,
  }) {
    return '$name removed the 7TV emote “$emote” from chat.';
  }

  @override
  String chatMessageTooLong({required int max}) {
    return 'Messages can be $max characters at most.';
  }

  @override
  String get chatWaitCommand => 'Running the previous command…';

  @override
  String get chatWaitMessage => 'Sending the previous message…';

  @override
  String get chatCannotSendDisconnected =>
      'Can’t send: chat is disconnected. Reconnecting…';

  @override
  String get chatMaybeNotSent =>
      'Your message may not have been sent. Try again.';

  @override
  String get chatClearedByModerator => 'Chat was cleared by a moderator.';

  @override
  String chatHelpCommands({required String commands}) {
    return 'Commands: $commands';
  }

  @override
  String get chatLogInToWhisper => 'Log in to whisper.';

  @override
  String chatWhisperSent({required String name}) {
    return 'Whisper sent to $name.';
  }

  @override
  String chatWhisperSentNoReplies({required String name}) {
    return 'Whisper sent to $name. Replies can’t reach this app until you log in again.';
  }

  @override
  String chatWhisperNoUser({required String login}) {
    return 'Couldn’t whisper: no user named $login.';
  }

  @override
  String chatUserCardNoUser({required String login}) {
    return 'Couldn’t open the user card: no user named $login.';
  }

  @override
  String chatUserCardFailed({required String login}) {
    return 'Couldn’t open the user card for $login.';
  }

  @override
  String chatWhisperFailedBecause({required String reason}) {
    return 'Couldn’t whisper: $reason';
  }

  @override
  String get chatWhisperFailed => 'Couldn’t whisper.';

  @override
  String get chatLogInToChangeColor => 'Log in to change your name color.';

  @override
  String get chatColorChanged => 'Your name color was changed.';

  @override
  String get chatColorFailedHex =>
      'Couldn’t change your name color (hex colors need Turbo or Prime).';

  @override
  String chatAlreadyBlocked({required String name}) {
    return '$name is already blocked.';
  }

  @override
  String chatBlockedUser({required String name}) {
    return 'Blocked $name.';
  }

  @override
  String chatUnblockedUser({required String name}) {
    return 'Unblocked $name.';
  }

  @override
  String chatBlockFailed({required String login}) {
    return 'Couldn’t block $login.';
  }

  @override
  String chatUnblockFailed({required String login}) {
    return 'Couldn’t unblock $login.';
  }

  @override
  String get chatLogInToModerate => 'Log in to moderate.';

  @override
  String get chatCommandArgUser => 'user';

  @override
  String get chatCommandArgMessage => 'message';

  @override
  String get chatCommandArgColor => 'color';

  @override
  String get chatCommandArgReason => 'reason';

  @override
  String get chatCommandArgLength => 'length';

  @override
  String get chatCommandArgSeconds => 'seconds';

  @override
  String get chatCommandArgMessageId => 'message id';

  @override
  String chatCommandDescription({required String command}) {
    String _temp0 = intl.Intl.selectLogic(command, {
      'me': 'Speak in the third person',
      'color': 'Change your name color',
      'block': 'Block a user',
      'unblock': 'Unblock a user',
      'w': 'Whisper a user',
      'user': 'Open a user’s card',
      'disconnect': 'Reconnect to chat',
      'help': 'List the commands',
      'ban': 'Ban a user',
      'unban': 'Lift a ban',
      'timeout': 'Time out a user (default 10m; s, m, h, d, w)',
      'untimeout': 'Lift a timeout',
      'warn': 'Warn a user',
      'delete': 'Delete a message',
      'clear': 'Delete every message',
      'slow': 'Turn slow mode on (default 30s)',
      'slowoff': 'Turn slow mode off',
      'followers': 'Turn followers-only mode on (m, h, d, w, mo)',
      'followersoff': 'Turn followers-only mode off',
      'subscribers': 'Turn subscribers-only mode on',
      'subscribersoff': 'Turn subscribers-only mode off',
      'emoteonly': 'Turn emote-only mode on',
      'emoteonlyoff': 'Turn emote-only mode off',
      'uniquechat': 'Turn unique chat mode on (no repeated messages)',
      'uniquechatoff': 'Turn unique chat mode off',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String chatCommandUsage({required String usage}) {
    return 'Usage: $usage';
  }

  @override
  String chatCommandBadLength({required String length}) {
    return 'Unknown length “$length”. Try 30, 10m, 2h, 1d, or 1w.';
  }

  @override
  String get chatCommandTimeoutRange =>
      'Timeouts must be between 1 second and 2 weeks.';

  @override
  String get chatCommandSlowRange =>
      'Slow mode must be between 3 and 120 seconds.';

  @override
  String get chatCommandFollowAgeRange =>
      'Follow age must be between 0 minutes and 3 months (e.g., 10m, 1w, 3mo).';

  @override
  String get chatCommandUnknownColor =>
      'Unknown color. Try Blue, Coral, HotPink, or #RRGGBB (Turbo or Prime).';

  @override
  String chatCommandNotInApp({required String command}) {
    return '/$command is not available in this app.';
  }

  @override
  String chatCommandUnknown({required String command}) {
    return 'Unknown command /$command. Type /help for the commands you can use.';
  }

  @override
  String chatModeName({required String mode}) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'slow': 'Slow mode',
      'followers': 'Followers-only mode',
      'subscribers': 'Subscribers-only mode',
      'emoteOnly': 'Emote-only mode',
      'uniqueChat': 'Unique chat mode',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String chatModeChanged({required String mode, required String state}) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'slow': 'Slow mode',
      'followers': 'Followers-only mode',
      'subscribers': 'Subscribers-only mode',
      'emoteOnly': 'Emote-only mode',
      'uniqueChat': 'Unique chat mode',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(state, {'on': 'on', 'other': 'off'});
    return '$_temp0 $_temp1.';
  }

  @override
  String chatModeSlowOn({required String duration}) {
    return 'Slow mode on ($duration).';
  }

  @override
  String chatModeFollowersOn({required String duration}) {
    return 'Followers-only mode on (must follow for $duration).';
  }

  @override
  String chatModFailed({required String command, required String reason}) {
    String _temp0 = intl.Intl.selectLogic(command, {
      'ban': 'ban the user',
      'timeout': 'time out the user',
      'untimeout': 'lift the timeout',
      'unban': 'unban the user',
      'warn': 'warn the user',
      'delete': 'delete the message',
      'clear': 'clear the chat',
      'slowOn': 'turn slow mode on',
      'slowOff': 'turn slow mode off',
      'followersOn': 'turn followers-only mode on',
      'followersOff': 'turn followers-only mode off',
      'subscribersOn': 'turn subscribers-only mode on',
      'subscribersOff': 'turn subscribers-only mode off',
      'emoteOnlyOn': 'turn emote-only mode on',
      'emoteOnlyOff': 'turn emote-only mode off',
      'uniqueChatOn': 'turn unique chat mode on',
      'uniqueChatOff': 'turn unique chat mode off',
      'other': 'do that',
    });
    return 'Couldn’t $_temp0: $reason';
  }

  @override
  String chatModFailedUnexpected({required String command}) {
    String _temp0 = intl.Intl.selectLogic(command, {
      'ban': 'ban the user',
      'timeout': 'time out the user',
      'untimeout': 'lift the timeout',
      'unban': 'unban the user',
      'warn': 'warn the user',
      'delete': 'delete the message',
      'clear': 'clear the chat',
      'slowOn': 'turn slow mode on',
      'slowOff': 'turn slow mode off',
      'followersOn': 'turn followers-only mode on',
      'followersOff': 'turn followers-only mode off',
      'subscribersOn': 'turn subscribers-only mode on',
      'subscribersOff': 'turn subscribers-only mode off',
      'emoteOnlyOn': 'turn emote-only mode on',
      'emoteOnlyOff': 'turn emote-only mode off',
      'uniqueChatOn': 'turn unique chat mode on',
      'uniqueChatOff': 'turn unique chat mode off',
      'other': 'do that',
    });
    return 'Couldn’t $_temp0 (unexpected error).';
  }

  @override
  String get chatModCannotModerate =>
      'Twitch says you can’t moderate this chat.';

  @override
  String chatTwitchReason({required String reason}) {
    return 'Twitch’s reason: “$reason”';
  }

  @override
  String chatModNoUser({required String login}) {
    return 'no user named $login.';
  }

  @override
  String get chatModLogInAgain => 'Log in again to moderate from this app.';

  @override
  String get chatModNotThrough => 'That didn’t go through. Try again.';

  @override
  String chatModBanned({required String name}) {
    return 'You banned $name.';
  }

  @override
  String chatModTimedOut({required String name, required String duration}) {
    return 'You timed out $name for $duration.';
  }

  @override
  String chatModUntimedOut({required String name}) {
    return 'You lifted $name’s timeout.';
  }

  @override
  String chatModUnbanned({required String name}) {
    return 'You unbanned $name.';
  }

  @override
  String chatModWarned({required String name}) {
    return 'You warned $name.';
  }

  @override
  String get chatModMessageDeleted => 'Message deleted.';

  @override
  String get chatModCleared => 'You cleared the chat.';

  @override
  String chatNoticeBanned({required String name}) {
    return '$name has been permanently banned.';
  }

  @override
  String chatNoticeTimedOut({required String name}) {
    return '$name has been timed out.';
  }

  @override
  String chatNoticeTimedOutFor({
    required String name,
    required String duration,
  }) {
    return '$name has been timed out for $duration.';
  }

  @override
  String chatServerNotice({required String notice}) {
    String _temp0 = intl.Intl.selectLogic(notice, {
      'rateLimit':
          'Couldn’t send your message. You’re sending messages too quickly.',
      'duplicate':
          'Couldn’t send your message. It’s the same as one you sent less than 30 seconds ago.',
      'subsOnly':
          'Couldn’t send your message. This chat is in subscribers-only mode: subscribe to the channel to chat.',
      'emoteOnly':
          'Couldn’t send your message. This chat is in emote-only mode.',
      'uniqueChat':
          'Couldn’t send your message. This chat is in unique chat mode, and your message isn’t original.',
      'followRequired':
          'Couldn’t send your message. This chat is in followers-only mode: follow the channel to chat.',
      'followedTooRecently':
          'Couldn’t send your message. You haven’t followed this channel long enough to chat yet.',
      'verifiedEmail':
          'Couldn’t send your message. This channel requires a verified email address: verify yours in your Twitch security settings.',
      'verifiedPhone':
          'Couldn’t send your message. This channel requires a verified phone number: verify yours in your Twitch security settings.',
      'emailAliasBanned':
          'Couldn’t send your message. Your email address is banned from this channel.',
      'phoneAliasBanned':
          'Couldn’t send your message. Your phone number is banned from this channel.',
      'channelSuspended': 'This channel doesn’t exist or is suspended.',
      'accountSuspended':
          'Couldn’t send your message. Your account is suspended.',
      'channelBlocked':
          'Couldn’t send your message. Your account isn’t in good standing in this channel.',
      'userRestricted':
          'Couldn’t send your message. Your account can’t send chat messages for now. Learn more at appeals.twitch.tv.',
      'channelRestricted':
          'Couldn’t send your message. This channel can’t receive chat messages for now.',
      'invalidReply':
          'Couldn’t send your reply. That message can’t be replied to.',
      'unexpected': 'Couldn’t send your message. Try again.',
      'badCharacters':
          'Couldn’t send your message. It contains too many characters Twitch can’t process.',
      'rejectedBySettings':
          'Couldn’t send your message. It conflicts with the channel’s moderation settings.',
      'tooManyChats':
          'Too many chats are open at once. Leave one to join this one.',
      'warned':
          'Couldn’t send your message. A moderator warned you: acknowledge the warning on twitch.tv to chat again.',
      'banned': 'You’re permanently banned from this chat.',
      'followersOnNow': 'This chat is now in followers-only mode.',
      'noPermission': 'You don’t have permission to do that.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String chatServerNoticeTimedOut({required String wait}) {
    return 'You’re timed out: you can chat again in $wait.';
  }

  @override
  String chatServerNoticeSlowMode({required String wait}) {
    return 'Couldn’t send your message. This chat is in slow mode: you can chat again in $wait.';
  }

  @override
  String chatServerNoticeUnknownCommand({required String command}) {
    return 'Unknown command: $command.';
  }

  @override
  String chatNoticeOwnMessageDeleted({required String message}) {
    return 'Your message was deleted: “$message”.';
  }

  @override
  String get chatRestrictionBanned => 'Permanently banned';

  @override
  String get chatRestrictionTimedOut => 'You’re timed out';

  @override
  String chatRestrictionTimedOutFor({required String wait}) {
    return 'You’re timed out · $wait';
  }

  @override
  String chatRestrictionSlow({required String wait}) {
    return 'Slow mode · you can chat again in $wait';
  }

  @override
  String get chatRestrictionEmoteOnly => 'Emote-only chat';

  @override
  String get chatRestrictionSubscribersOnly => 'Subscribers-only chat';

  @override
  String get chatRestrictionFollowersOnly => 'Followers-only chat';

  @override
  String chatRestrictionFollowersFor({required String duration}) {
    return 'Followers-only · $duration';
  }

  @override
  String chatRestrictionAccount({required String reason}) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'verifiedEmail': 'Verified email required',
      'verifiedPhone': 'Verified phone required',
      'emailAliasBanned': 'Email banned here',
      'phoneAliasBanned': 'Phone banned here',
      'accountRestricted': 'Account restricted',
      'channelRestricted': 'Chat suspended here',
      'followRequired': 'Follow to chat',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String chatNewMessages({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages',
      one: '$count new message',
    );
    return '$_temp0';
  }

  @override
  String get chatResumeScroll => 'Resume scroll';

  @override
  String get chatHistoricalMessage => 'Historical message';

  @override
  String chatSentFromCurrent({required String name}) {
    return 'Sent from $name (current channel)';
  }

  @override
  String chatSentFrom({required String name}) {
    return 'Sent from $name';
  }

  @override
  String get chatMessageDeletedInline => '<message deleted>';

  @override
  String get chatDeletedUser => 'Deleted user';

  @override
  String get chatFilteredWord => 'Filtered word';

  @override
  String chatCheerSemantics({required String prefix, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$prefix $count Bits',
      one: '$prefix $count Bit',
    );
    return '$_temp0';
  }

  @override
  String chatEmoteStackWith({required String emotes}) {
    return 'with $emotes';
  }

  @override
  String chatEmoteBy({required String name}) {
    return 'by $name';
  }

  @override
  String get chatCopyName => 'Copy name';

  @override
  String get chatCopyImageUrl => 'Copy image URL';

  @override
  String get chatOpenInBrowser => 'Open in browser';

  @override
  String get chatMessageCopied => 'Message copied';

  @override
  String get chatCopyMessage => 'Copy message';

  @override
  String get chatCopyMessageAndPaste => 'Copy into message box';

  @override
  String get chatReplyToMessage => 'Reply to message';

  @override
  String get chatDeleteMessage => 'Delete message';

  @override
  String get chatFirstMessage => 'First message';

  @override
  String get chatHighlightedMessage => 'Highlighted message';

  @override
  String chatCheeredIn({required String channel}) {
    return 'Cheered in $channel';
  }

  @override
  String get chatSubsOnlyRedemption =>
      'Sent with channel points in subscribers-only chat';

  @override
  String get chatAnimatedMessage => 'Animated message';

  @override
  String get chatMessageDeleted => 'Message deleted';

  @override
  String get chatPermanentlyBanned => 'Permanently banned';

  @override
  String chatTimedOutForLength({required String duration}) {
    return 'Timed out for $duration';
  }

  @override
  String get chatAnnouncement => 'Announcement';

  @override
  String get chatMessageOptionsHint => 'open message options';

  @override
  String get chatCopyMessageHint => 'copy message';

  @override
  String get chatReplies => 'Replies';

  @override
  String get chatEmoteMenu => 'Emote menu';

  @override
  String get chatLogInToChat => 'Log in to chat';

  @override
  String get chatCancelReply => 'Cancel reply';

  @override
  String get chatEnterMessage => 'Send a message';

  @override
  String get chatCannotChatNow => 'You can’t chat right now';

  @override
  String get chatInputDisconnected => 'Chat disconnected';

  @override
  String get chatInputConnecting => 'Connecting…';

  @override
  String get chatSending => 'Sending…';

  @override
  String get chatSend => 'Send';

  @override
  String chatReplyIn({required String name}) {
    return 'Reply in $name';
  }

  @override
  String get chatReply => 'Reply';

  @override
  String chatInChannelDelayed({required String name, required int seconds}) {
    return '$name · ${seconds}s delay';
  }

  @override
  String chatDelayed({required int seconds}) {
    return 'Chat · ${seconds}s delay';
  }

  @override
  String chatInChannel({required String name}) {
    return 'Chat in $name';
  }

  @override
  String get chatInputPlaceholder => 'Chat';

  @override
  String get chatMoreOptions => 'More';

  @override
  String chatCharactersLeft({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters left',
      one: '$count character left',
    );
    return '$_temp0';
  }

  @override
  String get chatColorUpdated => 'Name color updated';

  @override
  String get chatColorUpdateFailed =>
      'Couldn’t update your name color. Try again.';

  @override
  String get chatDetailsChatOnly => 'Chat only';

  @override
  String get chatDetailsShowVideo => 'Show video';

  @override
  String get chatDetailsRefreshAssets => 'Refresh emotes and badges';

  @override
  String get chatDetailsUsernameColor => 'Name color';

  @override
  String get chatDetailsPointsPollsPredictions =>
      'Channel points, polls, and predictions';

  @override
  String get chatDetailsOpensTwitchChat => 'Opens the chat on twitch.tv';

  @override
  String get chatDetailsTwitchChat => 'Twitch chat';

  @override
  String get chatDetailsOpensTwitch => 'Opens twitch.tv';

  @override
  String get chatDetailsGiftSub => 'Gift a sub';

  @override
  String get chatDetailsModes => 'Chat modes';

  @override
  String get chatDetailsModesDetail => 'Slow, followers-only, clear chat…';

  @override
  String get chatDetailsChatters => 'Chatters';

  @override
  String get chatDetailsAddChat => 'Add chat';

  @override
  String get chatDetailsSleepTimer => 'Sleep timer';

  @override
  String get chatSave => 'Save';

  @override
  String get chatColorPreview => 'How it will look in chat';

  @override
  String chatColorName({required String color}) {
    String _temp0 = intl.Intl.selectLogic(color, {
      'blue': 'Blue',
      'blue_violet': 'Blue violet',
      'cadet_blue': 'Cadet blue',
      'chocolate': 'Chocolate',
      'coral': 'Coral',
      'dodger_blue': 'Dodger blue',
      'firebrick': 'Firebrick',
      'golden_rod': 'Goldenrod',
      'green': 'Green',
      'hot_pink': 'Hot pink',
      'orange_red': 'Orange red',
      'red': 'Red',
      'sea_green': 'Sea green',
      'spring_green': 'Spring green',
      'yellow_green': 'Yellow green',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get chatModesAnyFollower => 'Any follower';

  @override
  String get chatModesClearTitle => 'Clear chat?';

  @override
  String get chatModesClearMessage => 'Every message is deleted for everyone.';

  @override
  String get chatClear => 'Clear';

  @override
  String get chatModesModerator => 'Moderator';

  @override
  String chatBadgeModeratorBot({required String moderator}) {
    return '$moderator (bot)';
  }

  @override
  String chatModesSlowWait({required int seconds}) {
    return '${seconds}s between messages';
  }

  @override
  String get chatModesClearChat => 'Clear chat';

  @override
  String chatModePill({required String mode}) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'emoteOnly': 'Emote-only',
      'followers': 'Followers-only',
      'slow': 'Slow mode',
      'subscribers': 'Subscribers-only',
      'uniqueChat': 'Unique chat',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get chatChattersFilter => 'Filter chatters';

  @override
  String chatChattersFound({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString chatters found',
      one: '$countString chatter found',
    );
    return '$_temp0';
  }

  @override
  String get chatChattersNone => 'No chatters found';

  @override
  String get chatChattersNoMatch => 'No matching chatters';

  @override
  String get emoteMenuRecent => 'Recent';

  @override
  String get emoteMenuClearRecent => 'Clear recent emotes';

  @override
  String get emoteMenuRecentCleared => 'Recent emotes cleared';

  @override
  String get emoteMenuNoRecent => 'No recent emotes';

  @override
  String emoteMenuLocked({required String name}) {
    return '$name, locked';
  }

  @override
  String get emoteMenuChannel => 'Channel';

  @override
  String get emoteMenuGlobal => 'Global';

  @override
  String get emoteMenuUnlocked => 'Unlocked';

  @override
  String get emoteMenuOther => 'Other';

  @override
  String chatHeldDecision({required String decision}) {
    String _temp0 = intl.Intl.selectLogic(decision, {
      'approved': 'Moderators approved your held message',
      'denied': 'Moderators denied your held message',
      'other': 'Your held message can no longer be reviewed',
    });
    return '$_temp0';
  }

  @override
  String chatHeldQuoted({required String decision, required String quote}) {
    return '$decision: “$quote”';
  }

  @override
  String get chatAddChatSearchFailed => 'Couldn’t search channels.';

  @override
  String get chatAddChatTitle => 'Add chat';

  @override
  String get chatAddChatSearch => 'Search for a channel';

  @override
  String get chatAddChatPrompt => 'Search for a channel to add';

  @override
  String get chatAddChatNoChannels => 'No channels found';

  @override
  String get chatTabsSplit => 'Split chats';

  @override
  String get chatTabsMerge => 'Merge loaded chats';

  @override
  String get chatTabsDisconnect => 'Disconnect';

  @override
  String get chatTabsRemove => 'Remove';

  @override
  String get chatTabsOptions => 'Tab options';

  @override
  String get chatTabsMaximum => 'Maximum 10 chats open';

  @override
  String get chatTabsAlreadyOpen => 'Channel already open — switched to it';

  @override
  String get chatUserWhisper => 'Whisper';

  @override
  String get chatUserProfile => 'Profile';

  @override
  String get chatUserNoRecentMessages => 'No recent messages';

  @override
  String get chatUserRecentMessages => 'Recent messages';

  @override
  String chatUserBadgeMonths({required String name, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name · $count months',
      one: '$name · $count month',
    );
    return '$_temp0';
  }

  @override
  String chatUserAccountCreated({required String date}) {
    return 'Account created $date';
  }

  @override
  String chatUserFollowingSince({required String date}) {
    return 'Following since $date';
  }

  @override
  String get chatFilteredTitle => 'Message hidden';

  @override
  String get chatFilteredBody =>
      'This message was hidden by your chat filters. Show it anyway?';

  @override
  String get chatFilteredShow => 'Show message';

  @override
  String get chatRulesTitle => 'Chat rules';

  @override
  String get chatRulesHeading => 'Chat rules';

  @override
  String get chatRulesAccept => 'Got it';

  @override
  String chatRaidWelcomeSemantics({
    required String from,
    required String target,
  }) {
    return 'You followed $from’s raid. Welcome to $target’s chat';
  }

  @override
  String chatRaidWelcomeFrom({required String name}) {
    return 'You followed $name’s raid';
  }

  @override
  String chatRaidWelcomeTo({required String name}) {
    return 'Welcome to $name’s chat';
  }

  @override
  String chatGiftRecipientsReceived({
    required int received,
    required int count,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$received of $count recipients',
      one: '$received of $count recipient',
    );
    return '$_temp0';
  }

  @override
  String chatGiftRecipients({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipients',
      one: '$count recipient',
    );
    return '$_temp0';
  }

  @override
  String chatGiftRecipientsMore({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more',
      one: '+$count more',
    );
    return '$_temp0';
  }

  @override
  String get chatAnonymousGifter => 'An anonymous gifter';

  @override
  String get chatLinkUntitledClip => 'Untitled clip';

  @override
  String get chatLinkUntitled => 'Untitled';

  @override
  String get chatLinkClip => 'Clip';

  @override
  String get chatLinkVideo => 'Video';

  @override
  String chatLinkViews({required int count, required String views}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$views views',
      one: '$views view',
    );
    return '$_temp0';
  }

  @override
  String chatModBarBanTitle({required String name}) {
    return 'Ban $name?';
  }

  @override
  String get chatModBarBan => 'Ban';

  @override
  String chatModBarWarnTitle({required String name}) {
    return 'Warn $name';
  }

  @override
  String get chatModBarWarn => 'Warn';

  @override
  String get chatModBarPurge => '1 second (purge)';

  @override
  String get chatModBarTimeout => 'Timeout';

  @override
  String get chatModBarTimeoutShort => 'Timeout';

  @override
  String get chatModBarUnban => 'Unban';

  @override
  String get chatModBarReason => 'Reason';

  @override
  String get chatModBarReasonOptional => 'Reason (optional)';

  @override
  String get pointsChannelPoints => 'Channel points';

  @override
  String get pointsLogInForBalance => 'Log in to see your balance.';

  @override
  String get pointsPredictionOpen => 'Prediction — open';

  @override
  String get pointsPredictionLocked => 'Prediction — locked';

  @override
  String get pointsRewards => 'Rewards';

  @override
  String get pointsNoRewards => 'This channel has no rewards set up.';

  @override
  String get pointsStreakNote =>
      'Twitch counts streaks. Watching in this app may not count toward them.';

  @override
  String get pointsBonusBlocked =>
      'Twitch’s anti-bot check blocks collecting the bonus here. Collect it on twitch.tv and your balance updates.';

  @override
  String get pointsCollectBonus => 'Collect bonus';

  @override
  String pointsOutcomeTotals({required String points, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$points · $count viewers',
      one: '$points · $count viewer',
    );
    return '$_temp0';
  }

  @override
  String pointsBetOn({required String title, required String odds}) {
    return 'Bet on $title, pays $odds times';
  }

  @override
  String pointsBetOnUnknown({required String title}) {
    return 'Bet on $title, payout unknown';
  }

  @override
  String get pointsTapToBet => 'Tap an outcome to bet.';

  @override
  String get pointsBetHeading => 'BET ON';

  @override
  String pointsBalance({required String points}) {
    return 'Balance $points';
  }

  @override
  String pointsNeedAtLeast({required int points}) {
    return 'You need at least $points points to bet.';
  }

  @override
  String get pointsStake => 'Stake';

  @override
  String get pointsMax => 'Max';

  @override
  String get pointsField => 'Points';

  @override
  String get pointsNoOdds => 'No odds yet.';

  @override
  String pointsPaysAbout({required String odds}) {
    return 'Pays about $odds× if this wins. Odds change with every bet.';
  }

  @override
  String pointsBetAmount({required String points, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bet $points',
      one: 'Bet $points',
    );
    return '$_temp0';
  }

  @override
  String get pointsBet => 'Bet';

  @override
  String pointsOdds({required String odds}) {
    return '$odds×';
  }

  @override
  String pointsSpend({required String points}) {
    return 'Spend $points points?';
  }

  @override
  String get pointsYourMessage => 'Your message';

  @override
  String get pointsRedeem => 'Redeem';

  @override
  String pointsResult({required String status, required String reason}) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'success': 'Done.',
      'integrityRefused':
          'Twitch’s anti-bot check refused this. ONSET can’t pass it, so try on twitch.tv.',
      'notAuthenticated':
          'Twitch rejected the login. Log in again to spend points.',
      'network': 'Couldn’t reach Twitch. Try again.',
      'other': 'Twitch refused: $reason',
    });
    return '$_temp0';
  }

  @override
  String get pointsBusy => 'Already in progress.';

  @override
  String get pointsNoReason => 'no reason given';

  @override
  String pointsAutomaticReward({required String type}) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'highlight': 'Highlight my message',
      'randomEmote': 'Unlock a random sub emote',
      'chosenEmote': 'Choose an emote to unlock',
      'modifiedEmote': 'Modify a single emote',
      'subOnlyMessage': 'Send a message in sub-only mode',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get streakSaveTitle => 'Keep watching to save your Watch Streak!';

  @override
  String streakSaveLive({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Watch this live stream and you’ll be able to save your current $count-stream streak.',
      one:
          'Watch this live stream and you’ll be able to save your current $count-stream streak.',
    );
    return '$_temp0';
  }

  @override
  String get streakExpiringTitle => 'Watch Streak expiring';

  @override
  String streakExpiring({required String name, required String time}) {
    return 'Watch $name in the next $time to save your streak!';
  }

  @override
  String streakYour({required int value}) {
    return 'Your Watch Streak: $value';
  }

  @override
  String streakOneMore({required int count, required String points}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '1 more stream to earn $points bonus channel points',
      one: '1 more stream to earn $points bonus channel point',
    );
    return '$_temp0';
  }

  @override
  String streakReached({
    required int count,
    required int next,
    required String points,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You reached a $next-stream streak and earned $points bonus channel points',
      one:
          'You reached a $next-stream streak and earned $points bonus channel point',
    );
    return '$_temp0';
  }

  @override
  String streakReach({
    required int count,
    required int next,
    required String points,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Reach a $next-stream streak and earn $points bonus channel points',
      one: 'Reach a $next-stream streak and earn $points bonus channel point',
    );
    return '$_temp0';
  }

  @override
  String emoteUnlockHint({required String how}) {
    String _temp0 = intl.Intl.selectLogic(how, {
      'global': 'Available to everyone on Twitch.',
      'owned': 'You can use it.',
      'follow': 'Follow this channel to use it.',
      'bits': 'Cheer Bits in this channel to unlock it.',
      'subscribe': 'Subscribe to this channel to use it.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String emoteUnlockTier({required int tier}) {
    return 'Subscribe to this channel at Tier $tier to use it.';
  }

  @override
  String emoteTypeName({required String type}) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'twitchBits': 'Twitch Bits emote',
      'twitchFollower': 'Twitch follower emote',
      'twitchSub': 'Twitch sub emote',
      'twitchGlobal': 'Twitch global emote',
      'twitchUnlocked': 'Twitch unlocked emote',
      'twitchChannel': 'Twitch channel emote',
      'ffzGlobal': 'FrankerFaceZ global emote',
      'ffzChannel': 'FrankerFaceZ channel emote',
      'bttvGlobal': 'BetterTTV global emote',
      'bttvChannel': 'BetterTTV channel emote',
      'bttvShared': 'BetterTTV shared emote',
      'sevenTVGlobal': '7TV global emote',
      'sevenTVChannel': '7TV channel emote',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String badgeTypeName({required String type}) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'twitch': 'Twitch badge',
      'bttv': 'BetterTTV badge',
      'ffz': 'FrankerFaceZ badge',
      'sevenTV': '7TV badge',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String noticeSubscribed({
    required String plan,
    required String name,
    required int tier,
  }) {
    String _temp0 = intl.Intl.selectLogic(plan, {
      'prime': '$name subscribed with Prime.',
      'tier': '$name subscribed at Tier $tier.',
      'other': '$name subscribed.',
    });
    return '$_temp0';
  }

  @override
  String noticeResubscribed({
    required String plan,
    required String name,
    required int tier,
  }) {
    String _temp0 = intl.Intl.selectLogic(plan, {
      'prime': '$name subscribed with Prime.',
      'tier': '$name subscribed at Tier $tier.',
      'other': '$name subscribed.',
    });
    return '$_temp0';
  }

  @override
  String noticeSubStreak({required int months, required int streak}) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other:
          'They’ve subscribed for $months months, currently on a $streak-month streak!',
      one:
          'They’ve subscribed for $months month, currently on a $streak-month streak!',
    );
    return '$_temp0';
  }

  @override
  String noticeSubMonths({required int months}) {
    return 'They’ve subscribed for $months months!';
  }

  @override
  String noticeGiftedSub({
    required String tiered,
    required String gifter,
    required int tier,
    required String recipient,
  }) {
    String _temp0 = intl.Intl.selectLogic(tiered, {
      'yes': '$gifter gifted a Tier $tier sub to $recipient!',
      'other': '$gifter gifted a sub to $recipient!',
    });
    return '$_temp0';
  }

  @override
  String noticeGiftedMonthsTier({
    required String gifter,
    required String months,
    required String tier,
    required String recipient,
  }) {
    return '$gifter gifted $months of $tier to $recipient!';
  }

  @override
  String noticeGiftedMonths({
    required String gifter,
    required String months,
    required String recipient,
  }) {
    return '$gifter gifted a $months sub to $recipient!';
  }

  @override
  String noticeGiftMonths({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '$count month',
    );
    return '$_temp0';
  }

  @override
  String noticeGiftMonthsShort({required int count}) {
    return '$count-month';
  }

  @override
  String noticeGiftTier({required int tier}) {
    return 'Tier $tier';
  }

  @override
  String get noticeGiftFirst => 'It’s their first gift sub in the channel!';

  @override
  String noticeGiftCount({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'They’ve given $countString gift subs in the channel!';
  }

  @override
  String noticeCommunityGift({
    required String tiered,
    required int count,
    required String gifter,
    required int tier,
    required String channel,
    required String end,
  }) {
    String _temp0 = intl.Intl.selectLogic(end, {'more': '.', 'other': '!'});
    String _temp1 = intl.Intl.selectLogic(end, {'more': '.', 'other': '!'});
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$gifter is gifting $count Tier $tier subs to $channel’s community$_temp0',
      one:
          '$gifter is gifting $count Tier $tier sub to $channel’s community$_temp1',
    );
    String _temp3 = intl.Intl.selectLogic(end, {'more': '.', 'other': '!'});
    String _temp4 = intl.Intl.selectLogic(end, {'more': '.', 'other': '!'});
    String _temp5 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$gifter is gifting $count subs to $channel’s community$_temp3',
      one: '$gifter is gifting $count sub to $channel’s community$_temp4',
    );
    String _temp6 = intl.Intl.selectLogic(tiered, {
      'yes': '$_temp2',
      'other': '$_temp5',
    });
    return '$_temp6';
  }

  @override
  String get noticeCommunityGiftFirst =>
      'It’s their first gift sub in the channel!';

  @override
  String noticeCommunityGiftTotal({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'They’ve gifted a total of $countString subs in the channel!';
  }

  @override
  String noticeExtendedSub({
    required String tiered,
    required String name,
    required int tier,
    required String month,
  }) {
    String _temp0 = intl.Intl.selectLogic(tiered, {
      'yes': '$name extended their Tier $tier subscription through $month!',
      'other': '$name extended their subscription through $month!',
    });
    return '$_temp0';
  }

  @override
  String noticeRaid({required String name, required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name is raiding with $countString viewers!',
      one: '$name is raiding with $countString viewer!',
    );
    return '$_temp0';
  }

  @override
  String noticeSubMultiMonth({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'They paid for $count months in advance.',
      one: 'They paid for $count month in advance.',
    );
    return '$_temp0';
  }

  @override
  String noticeGiftRedeemed({
    required int month,
    required int total,
    required String gifter,
  }) {
    return 'Month $month of a $total-month gift sub from $gifter.';
  }

  @override
  String noticeGiftRedeemedAnonymous({required int month, required int total}) {
    return 'Month $month of a $total-month gift sub from an anonymous gifter.';
  }

  @override
  String noticeGiftPaidUpgrade({required String name, required String gifter}) {
    return '$name is continuing the gift sub they got from $gifter!';
  }

  @override
  String noticeGiftPaidUpgradeAnonymous({required String name}) {
    return '$name is continuing the gift sub they got from an anonymous gifter!';
  }

  @override
  String noticePayForward({
    required String name,
    required String gifter,
    required String recipient,
  }) {
    return '$name is paying forward the gift sub they got from $gifter to $recipient!';
  }

  @override
  String noticePayForwardCommunity({
    required String name,
    required String gifter,
  }) {
    return '$name is paying forward the gift sub they got from $gifter to the community!';
  }

  @override
  String noticeSponsorBonus({required String sponsor, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$sponsor added $count bonus gift subs!',
      one: '$sponsor added $count bonus gift sub!',
    );
    return '$_temp0';
  }

  @override
  String noticeRewardGift({required String name, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Thanks to $name, $count other viewers get a reward!',
      one: 'Thanks to $name, $count other viewer gets a reward!',
    );
    return '$_temp0';
  }

  @override
  String noticeWatchStreak({required String name, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name reached a $count-stream Watch Streak!',
      one: '$name reached a $count-stream Watch Streak!',
    );
    return '$_temp0';
  }

  @override
  String noticeWatchStreakPoints({required int points}) {
    final intl.NumberFormat pointsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pointsString = pointsNumberFormat.format(points);

    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: 'They earned $pointsString channel points.',
      one: 'They earned $pointsString channel point.',
    );
    return '$_temp0';
  }

  @override
  String noticeCharity({
    required String name,
    required String amount,
    required String charity,
  }) {
    return '$name donated $amount to $charity!';
  }

  @override
  String get vodCopyLinkAtTime => 'Copy link at current time';

  @override
  String get vodKindArchive => 'Past broadcast';

  @override
  String get vodKindHighlight => 'Highlight';

  @override
  String get vodKindUpload => 'Upload';

  @override
  String vodPlaybackRate({required String rate}) {
    return '$rate×';
  }

  @override
  String get vodLinkCopied => 'Link copied';

  @override
  String get vodShare => 'Share';

  @override
  String get vodOpenChannel => 'Open channel';

  @override
  String vodSpeedPill({required String rate}) {
    return 'Speed $rate';
  }

  @override
  String get vodSpeedPillNormal => 'Normal speed';

  @override
  String vodQualityPill({required String quality}) {
    return 'Quality $quality';
  }

  @override
  String get vodQualityPillAuto => 'Auto quality';

  @override
  String get vodQualityPillAudioOnly => 'Audio only';

  @override
  String vodCaptionsState({required String state}) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'on': 'Closed captions, on',
      'other': 'Closed captions, off',
    });
    return '$_temp0';
  }

  @override
  String get vodLegendMuted => 'Muted segments (copyright)';

  @override
  String get vodLegendDoubleTap => 'Double-tap the sides to skip 10 seconds';

  @override
  String get vodLegendUpNext => 'Up next at the end';

  @override
  String vodLegendUpNextWhen({required String autoplay}) {
    return 'Up next at the end · $autoplay';
  }

  @override
  String get vodSeek => 'Seek';

  @override
  String vodSeekValue({required String position, required String duration}) {
    return '$position of $duration';
  }

  @override
  String get vodUpNext => 'Up next';

  @override
  String vodUpNextSeconds({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '$count second',
    );
    return '$_temp0';
  }

  @override
  String vodUpNextSimilar({required String channel}) {
    return '$channel · Similar video';
  }

  @override
  String get vodPlayNow => 'Play now';

  @override
  String get vodReplayTitle => 'Chat replay';

  @override
  String get vodReplaySynced => 'synced to video';

  @override
  String get vodReplayEmotesNote =>
      '7TV, BTTV, and FFZ emotes are the channel’s current sets, which may differ from the ones used during the broadcast.';

  @override
  String get vodReplayEmotesAbout => 'About emotes in replays';

  @override
  String get vodReplayNotForUploads => 'Uploads have no chat replay';

  @override
  String get vodReplayUnavailable =>
      'Chat replay is unavailable for this video';

  @override
  String get vodReplayNoMessages => 'No messages yet';

  @override
  String get vodReplayLoading => 'Loading chat replay…';

  @override
  String get whisperOtherAccount =>
      'This conversation belongs to another account.';

  @override
  String whisperTooLong({required int max}) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'Whispers can be $maxString characters at most.';
  }

  @override
  String get whisperLogInAgain => 'Log in again to whisper from this app.';

  @override
  String get whisperFailedUnexpected => 'Couldn’t whisper (unexpected error).';

  @override
  String notifGoLiveTitle({required String name}) {
    return '$name is live';
  }

  @override
  String notifStreamBody({required String title, required String category}) {
    return '$title · $category';
  }

  @override
  String notifGoLiveMore({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more channels went live',
      one: '$count more channel went live',
    );
    return '$_temp0';
  }

  @override
  String get notifGoLivePaused => 'Go-live notifications paused';

  @override
  String notifMentionTitle({required String sender, required String channel}) {
    return '$sender mentioned you in $channel';
  }

  @override
  String notifReminderTitle({required String name}) {
    return '$name’s stream is starting';
  }

  @override
  String get notifReminderUntitled => 'Untitled stream';

  @override
  String get notifChannelGoLive => 'Go-live notifications';

  @override
  String get notifChannelGoLiveDescription =>
      'When channels you follow go live';

  @override
  String get notifChannelMentions => 'Chat mentions';

  @override
  String get notifChannelMentionsDescription =>
      'When someone mentions you in a chat you’re watching while ONSET is in the background';

  @override
  String get notifChannelReminders => 'Stream reminders';

  @override
  String get notifChannelRemindersDescription =>
      'When a scheduled stream you set a reminder for starts';

  @override
  String get mediaChannel => 'Playback';

  @override
  String get mediaPlay => 'Play';

  @override
  String get mediaPause => 'Pause';

  @override
  String get mediaStop => 'Stop';

  @override
  String get authMissingPermissionsTitle => 'Missing permissions';

  @override
  String get authMissingPermissions =>
      'Your session is missing permissions. Log in again to continue.';

  @override
  String get authSessionExpiredTitle => 'Session expired';

  @override
  String get authSessionExpired =>
      'Your session has expired. Log in again to continue.';

  @override
  String get authLogIn => 'Log in';
}
