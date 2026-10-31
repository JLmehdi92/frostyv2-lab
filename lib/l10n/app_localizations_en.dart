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
    return '“System” follows your device’s language (currently: $language).';
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
      'Theme, stream cards, browsing and links';

  @override
  String get settingsPageVideo => 'Video';

  @override
  String get settingsPageVideoDescription =>
      'The low-latency player, playback, overlay, videos and captions';

  @override
  String get settingsPageChat => 'Chat';

  @override
  String get settingsPageChatDescription =>
      'How chat looks, waits, alerts and filters';

  @override
  String get settingsPageNotifications => 'Notifications';

  @override
  String get settingsPageNotificationsDescription =>
      'Go-live and chat mention notifications';

  @override
  String get settingsPageOther => 'Other';

  @override
  String get settingsPageOtherDescription =>
      'Updates, storage, privacy and about';

  @override
  String get settingsPageAccount => 'Account';

  @override
  String get settingsPageAccountDescription => 'Your Twitch account in ONSET';

  @override
  String get settingsPageBlocked => 'Blocked users';

  @override
  String get settingsPageBlockedDescription => 'People you blocked on Twitch';

  @override
  String get settingsPageChatFilters => 'Edit Chat Filters';

  @override
  String get settingsSummaryGeneral => 'Theme, accent color, browse, links';

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
  String get settingsSummaryOther => 'Updates, cache, privacy, about';

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
  String get settingsUnableToReachTwitch => 'Unable to connect to Twitch';

  @override
  String get settingsCheckConnection => 'Check your connection, then try again';

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
      'Log in to enable the ability to chat, view followed streams, and more.';

  @override
  String get settingsLoginDisclaimer =>
      'ONSET only asks for the necessary permissions through the official Twitch API. You\'ll be able to review them before authorizing.';

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
      'Password, email, phone, two-factor — on twitch.tv';

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
    return 'Are you sure you want to unblock \"$name\"?';
  }

  @override
  String get settingsBlock => 'Block';

  @override
  String settingsBlockMessage({required String name}) {
    return 'Are you sure you want to block \"$name\"? This will remove them from channel lists, search results, and chat messages.';
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
  String get settingsLargeStreamCard => 'Use large stream card';

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
      zero: 'None',
    );
    return '$_temp0';
  }

  @override
  String get settingsHideLabeledNote =>
      'Streams with these labels are left out of Top, categories and tags. Followed channels always show.';

  @override
  String get contentLabelDrugs =>
      'Drugs, Intoxication, or Excessive Tobacco Use';

  @override
  String get contentLabelSexualThemes => 'Sexual Themes';

  @override
  String get contentLabelViolentGraphic => 'Violent and Graphic Depictions';

  @override
  String get contentLabelGambling => 'Gambling';

  @override
  String get contentLabelProfanity => 'Significant Profanity or Vulgarity';

  @override
  String get contentLabelMatureGame => 'Mature-Rated Game';

  @override
  String get contentLabelPolitics => 'Politics and Sensitive Social Issues';

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
      'Keeps the stream close to live by playing very slightly faster when it drifts behind, without reloading it. If Ultra keeps stalling, the next streams use Standard for a while. Applies the next time a stream is opened.';

  @override
  String get settingsLiveCatchUp => 'Live catch-up';

  @override
  String get settingsLiveCatchUpDetail =>
      'Speed up plays slightly faster until it is back at live (Auto latency does it when on). Jump to live skips ahead after a stall. Applies the next time a stream is opened.';

  @override
  String get liveCatchUpSpeedUp => 'Speed up';

  @override
  String get liveCatchUpJumpToLive => 'Jump to live';

  @override
  String get settingsBufferProfile => 'Buffer profile';

  @override
  String get settingsBufferProfileDetail =>
      'Ultra keeps an even smaller buffer for lower latency but may rebuffer more on weak connections. Applies the next time a stream is opened.';

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
      'Uses a faster WebView rendering method. Disable if you experience crashes while watching streams.';

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
      'Replaces Twitch\'s default web overlay with a mobile-friendly version.';

  @override
  String get settingsToggleOverlay => 'Long-press player to toggle overlay';

  @override
  String get settingsToggleOverlayDetail =>
      'Allows switching between Twitch\'s overlay and the custom overlay.';

  @override
  String get settingsShowLatency => 'Show latency';

  @override
  String get settingsShowLatencyDetail =>
      'Displays the stream latency in the video overlay. With the low-latency player, tap it to show live video stats.';

  @override
  String get settingsVideosAndContent => 'Videos and content';

  @override
  String get settingsVodAutoplay => 'Video Autoplaying';

  @override
  String get settingsVodAutoplayDetail =>
      'Choose when videos should play automatically';

  @override
  String get vodAutoplayAlways => 'Mobile data & Wi-Fi';

  @override
  String get vodAutoplayWifiOnly => 'Wi-Fi Only';

  @override
  String get vodAutoplayNever => 'Never';

  @override
  String get settingsWarnMature => 'Warn about mature content';

  @override
  String get settingsWarnMatureDetail =>
      'Shows a warning before a channel labeled for mature content.';

  @override
  String get settingsCaptions => 'Captions';

  @override
  String get settingsClosedCaptions => 'Closed Captions';

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
      'Some streams only offer their 2K (1440p HEVC) quality to a signed-in viewer. This is normally picked up on its own when you log in, and refreshed on each launch — you should never need to touch it. Fill it in by hand only if that fails: paste the value of the \"auth-token\" cookie from twitch.tv in a browser.';

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
  String get settingsChatPreviewText => 'Hello! Here\'s a text preview.';

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

    return '${scaleString}x';
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
      'Restores the original message of deleted messages.';

  @override
  String get settingsAnimateEmotes => 'Animate emotes';

  @override
  String get settingsAnimateEmotesDetail =>
      'Off shows the first frame of animated emotes in chat.';

  @override
  String get settingsAnimatedGifs => 'Animated GIFs';

  @override
  String get settingsAnimatedGifsDetail =>
      'Off shows the first frame of GIFs sent in chat.';

  @override
  String get settingsShowGifs => 'Show GIFs in Chat';

  @override
  String get settingsShowGifsDetail =>
      'Off shows the title of a GIF instead of the GIF.';

  @override
  String get settingsLinkPreviews => 'Preview clips and videos';

  @override
  String get settingsLinkPreviewsDetail =>
      'Shows a card under messages that link a Twitch clip or video.';

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
      'Holds each message for as long as the video is behind live, so chat matches what you see. Your own messages show at once.';

  @override
  String get settingsMessageDelay => 'Message delay';

  @override
  String settingsMessageDelayValue({required int seconds}) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
    );
    return '$_temp0';
  }

  @override
  String get settingsMessageDelayDetail =>
      'Adds a delay before each message is rendered in chat. ';

  @override
  String get settingsMessageDelayDetailIos =>
      'Adds a delay before each message is rendered in chat. 15 seconds is recommended for iOS.';

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
  String get settingsFirstTimeChatters => 'Highlight first time chatters';

  @override
  String get settingsUserNotices => 'Show notices';

  @override
  String get settingsUserNoticesDetail =>
      'Shows notices such as subs and re-subs, announcements, and raids.';

  @override
  String get settingsCollapseGiftBombs => 'Collapse gift bombs';

  @override
  String get settingsCollapseGiftBombsDetail =>
      'Folds a gift bomb of five subs or more into its first line; tap \"recipients\" to see who got one.';

  @override
  String get settingsShowHypeTrains => 'Show Hype Trains';

  @override
  String get settingsShowHypeTrainsDetail =>
      'Shows Hype Train progress, levels and rewards above chat.';

  @override
  String get settingsCommunityHighlights => 'Show community highlights';

  @override
  String get settingsCommunityHighlightsDetail =>
      'Shows polls, predictions, pinned messages, gift bombs and raids above chat.';

  @override
  String get settingsCelebrations => 'Show celebrations';

  @override
  String get settingsCelebrationsDetail =>
      'Plays an animation over the channel when someone gifts subs.';

  @override
  String get settingsCelebrationsOnVideo => 'Celebrations on video';

  @override
  String get settingsCelebrationsOnVideoDetail =>
      'Full plays the animation over the video. Subtle keeps the video clear and says it with a line in chat.';

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
      'Overrides and fills the available space in devices with a display notch.';

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
      'Sets the opacity (transparency) of the overlay chat in fullscreen mode.';

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
      'Only matches whole words instead of partial matches.';

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
      'Select the filters you would like to block in chat across all channels. In channels you moderate, you will still see all messages.';

  @override
  String get chatFiltersGroup => 'Filters';

  @override
  String get chatFilterDiscrimination => 'Discrimination';

  @override
  String get chatFilterDiscriminationDetail =>
      'Negative language about race, gender, orientation, or similar';

  @override
  String get chatFilterSexual => 'Sexually Explicit Language';

  @override
  String get chatFilterSexualDetail =>
      'References to sexual acts, sexual content, and body parts';

  @override
  String get chatFilterHarassment => 'Harassment';

  @override
  String get chatFilterHarassmentDetail =>
      'Aggressive or sexually harassing language towards other people';

  @override
  String get chatFilterProfanity => 'Profanity';

  @override
  String get chatFilterProfanityDetail =>
      'Curse words, expletives, or other obscenities';

  @override
  String get chatFiltersNote =>
      'Twitch\'s AutoMod rates the words of each live chat message; only words it rates are hidden, so a message it did not rate always shows. Hidden words show as stars: tap them to see the message. Chat replays of past broadcasts are not filtered.';

  @override
  String get mutedKeywordsTitle => 'Muted keywords';

  @override
  String mutedKeywordsCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keywords',
      one: '1 keyword',
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
    return 'Removed \'$word\'';
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
      'Checked every 90 seconds while ONSET is open or playing, and about every 15 minutes otherwise, when the system allows. Turn a channel\'s bell off from its menu.';

  @override
  String get goLiveOffDetail => 'Be told when channels you follow go live.';

  @override
  String get goLiveLogInAgain => 'Log in again to get go-live notifications.';

  @override
  String get goLiveReadFailed => 'Couldn\'t read the go-live setting.';

  @override
  String get goLiveTurnOnFailed => 'Couldn\'t turn on go-live notifications.';

  @override
  String get goLiveTurnOffFailed => 'Couldn\'t turn off go-live notifications.';

  @override
  String get notificationsAllowInSystem =>
      'Allow notifications for this app in the system settings.';

  @override
  String get goLiveBellFailed => 'Couldn\'t change the bell.';

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
      'When someone mentions you in a chat you are watching while ONSET is in the background or in picture-in-picture.';

  @override
  String get settingsUpdates => 'Updates';

  @override
  String get settingsReleaseNotes => 'Release notes';

  @override
  String get settingsUpdatesNote =>
      'ONSET looks for a newer build when it starts and when it comes back to the foreground. Release notes open by themselves after an update to a new version.';

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
  String get updatesUpToDate => 'You\'re up to date';

  @override
  String get updatesCheckFailed => 'Couldn\'t check for updates';

  @override
  String get updatesCheck => 'Check for updates';

  @override
  String updatesBuild({required int build}) {
    return 'Build $build';
  }

  @override
  String get updatesChecking => 'Checking';

  @override
  String get followedSortViewers => 'Viewers (High to Low)';

  @override
  String get followedSortRecent => 'Recently Started';

  @override
  String get followedSortName => 'Name (A-Z)';

  @override
  String get followedSortCategory => 'Category';

  @override
  String releaseKindAdded({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new',
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
  String get releaseNotesWhatsNew => 'WHAT\'S NEW';

  @override
  String releaseNotesWhatsNewIn({required String version}) {
    return 'WHAT\'S NEW IN $version';
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
    return 'You were on $version. Here is what changed since then.';
  }

  @override
  String get releaseNotesOtherVersions => 'Other versions';

  @override
  String get releaseNotesGotIt => 'Got it';

  @override
  String get releaseNotesVersions => 'Versions';

  @override
  String get releaseNotesFootnote =>
      'Release notes open by themselves after an update to a new version.';

  @override
  String releaseNotesPoints({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
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
      'What changes in each version of ONSET shows up here, and opens by itself after an update.';

  @override
  String get updateAllowTitle => 'Allow updates';

  @override
  String get updateAllowMessage =>
      'Android asks you to let ONSET install apps. Turn on \"Allow from this source\" on the next screen, then come back.';

  @override
  String get updateOpenSettings => 'Open settings';

  @override
  String get updateNotAllowed => 'ONSET is not allowed to install updates';

  @override
  String get updateCorrupted => 'The download was corrupted — try again';

  @override
  String get updateInstallFailed => 'Android could not install the update';

  @override
  String get updateDownloadFailed => 'Download failed';

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
  String get updateChecked => 'SHA-256 checked before install';

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
  String get updateInstalling => 'Installing update';

  @override
  String get updateDownloading => 'Downloading update';

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
}
