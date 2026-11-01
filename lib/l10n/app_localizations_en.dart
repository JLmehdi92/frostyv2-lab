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
    );
    return '$_temp0';
  }

  @override
  String streamWatchingShort({required int count, required String viewers}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$viewers watching',
    );
    return '$_temp0';
  }

  @override
  String streamWatchStreakSemantics({required int value}) {
    return 'Watch streak $value';
  }

  @override
  String streamStreak({required int value}) {
    return 'Streak $value';
  }

  @override
  String get streamNoCategory => 'No Category';

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
  String get apiErrorUnableToConnect => 'Unable to connect to Twitch';

  @override
  String get apiErrorNetwork =>
      'No internet connection. Please check your network.';

  @override
  String get apiErrorConnectionTimeout =>
      'Connection timeout. Please try again.';

  @override
  String get apiErrorSendTimeout => 'Upload timeout. Please try again.';

  @override
  String get apiErrorReceiveTimeout =>
      'Server response timeout. Please try again.';

  @override
  String get apiErrorCancelled => 'Request was cancelled';

  @override
  String get apiErrorCertificate => 'Security certificate error';

  @override
  String get apiErrorUnexpected => 'An unexpected error occurred';

  @override
  String get apiErrorBadRequest => 'Invalid request data';

  @override
  String get apiErrorUnauthorized => 'Please log in to continue';

  @override
  String get apiErrorForbidden => 'Access denied. Insufficient permissions';

  @override
  String get apiErrorNotFound => 'Resource not found';

  @override
  String get apiErrorConflict => 'Conflict with current state. Please refresh';

  @override
  String get apiErrorInvalid => 'Invalid data provided';

  @override
  String get apiErrorRateLimited =>
      'Rate limit exceeded. Please wait before trying again';

  @override
  String get apiErrorServer => 'Server error. Please try again later';

  @override
  String get apiErrorUnavailable => 'Service temporarily unavailable';

  @override
  String get apiErrorMaintenance =>
      'Service maintenance. Please try again later';

  @override
  String get apiErrorServerTimeout => 'Server timeout. Please try again';

  @override
  String apiErrorHttp({required int status}) {
    return 'HTTP Error $status occurred';
  }

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
      'Tag streams are unavailable right now';

  @override
  String streamListSortFailed({
    required String sort,
    required String fallback,
  }) {
    return 'Twitch could not sort by $sort. $fallback still works.';
  }

  @override
  String get streamListLoadFailed => 'Something went wrong loading streams';

  @override
  String get streamListPinnedFailed =>
      'Something went wrong loading pinned streams';

  @override
  String get streamListOfflineFailed =>
      'Something went wrong loading offline channels';

  @override
  String get streamListAllHidden => 'Every stream here has a label you hide';

  @override
  String get streamListShowHidden => 'Show them';

  @override
  String get streamListEmptyFollowed => 'No followed streams';

  @override
  String get streamListEmptyTop => 'No top streams';

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
    return '$name\'s content is intended for certain audiences.';
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
    return 'You won\'t see $name in Live for now';
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
  String get liveFeedSwipeHint => 'SWIPE UP FOR THE NEXT LIVE';

  @override
  String get liveFeedUpNext => 'UP NEXT';

  @override
  String get liveFeedUpNextHelp =>
      'Swipe up on the preview, or tap a live in the list. Previews never start with sound.';

  @override
  String get liveFeedLoadingMore => 'Loading more live channels';

  @override
  String get liveFeedEnd => 'That’s every live channel here for now';

  @override
  String get liveFeedBackToFirst => 'Back to the first';

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
  String get searchHint => 'Search channels, categories or videos';

  @override
  String searchSeeAllSemantics({required String section}) {
    return 'See all $section';
  }

  @override
  String get searchHistory => 'History';

  @override
  String searchRemoveFromHistory({required String query}) {
    return 'Remove $query from history';
  }

  @override
  String get searchNoHistory => 'No recent searches';

  @override
  String get searchCategoriesFailed => 'Unable to load categories';

  @override
  String get searchCategoriesUnavailable => 'Failed to get categories';

  @override
  String get searchNoCategories => 'No matching categories';

  @override
  String get searchChannelNotFound => 'Unable to find channel';

  @override
  String get searchChannelsFailed => 'Unable to load channels';

  @override
  String searchGoToChannel({required String query}) {
    return 'Go to channel \"$query\"';
  }

  @override
  String get searchVideosFailed => 'Unable to load videos';

  @override
  String get searchNoResults => 'No search results found';

  @override
  String browseLiveChannels({required String where}) {
    return 'Live channels $where';
  }

  @override
  String get browseAcrossTwitch => 'across Twitch';

  @override
  String get categoriesEmpty => 'No top categories';

  @override
  String get categoriesLoadFailed => 'Something went wrong loading categories';

  @override
  String get categoriesRailTitle => 'Top categories';

  @override
  String get categoriesRailNote => 'Most watched first';

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
      'The newest videos of the channels you follow';

  @override
  String get followedVideosRefresh => 'Refresh';

  @override
  String get followedVideosLoadFailed => 'Something went wrong loading videos';

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
      other: '$count wk ago',
      one: '$count wk ago',
    );
    return '$_temp0';
  }

  @override
  String savedMonthsAgo({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mo ago',
      one: '$count mo ago',
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
      'Clip player. Double-tap to toggle play/pause';

  @override
  String get clipsCannotPlay => 'This clip can\'t be played here';

  @override
  String get clipsLoadingMore => 'Loading more clips for you';

  @override
  String get clipsLoadFailed => 'Unable to load clips';

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
  String get clipsSwipeHint => 'You can swipe to the next clip';

  @override
  String get clipsLoadMoreFailed => 'Unable to load more clips';

  @override
  String get clipsEnd =>
      'That’s all for now! Check out more clips from previous streams';

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
      other: 'Showing the top $count clips',
      one: 'Showing the top $count clip',
    );
    return '$_temp0';
  }

  @override
  String get clipsCategoryNotFound => 'Category not found';

  @override
  String get clipsChannelNotFound => 'Channel not found';

  @override
  String get clipsListFailed => 'Couldn\'t load clips';

  @override
  String clipsMoreFrom({required String channel}) {
    return 'More clips from $channel';
  }

  @override
  String get clipLinkCopied => 'Link copied';

  @override
  String get clipCopyClipLink => 'Copy clip link';

  @override
  String get clipDetailsFailed => 'Couldn\'t load the clip details';

  @override
  String get clipSyncedToClip => 'synced to the clip';

  @override
  String playbackSubscriberOnly({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'This clip is only available to subscribers.',
      'other': 'This video is only available to subscribers.',
    });
    return '$_temp0';
  }

  @override
  String playbackGeoBlocked({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'This clip is not available in your region',
      'other': 'This video is not available in your region',
    });
    return '$_temp0';
  }

  @override
  String playbackNotFound({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'This clip is no longer available',
      'other': 'This video is no longer available',
    });
    return '$_temp0';
  }

  @override
  String playbackFailed({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'Couldn\'t play this clip',
      'other': 'Couldn\'t play this video',
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
  String get profileRefreshFailed => 'Couldn\'t refresh this channel';

  @override
  String get profileOpenFailed =>
      'Couldn\'t open this channel, check your connection';

  @override
  String get profileShare => 'Share';

  @override
  String get profileMore => 'More';

  @override
  String get profileLoadFailed => 'Couldn\'t load this channel\'s profile';

  @override
  String get profileNoDetails => 'No details';

  @override
  String get profileScheduleFailed => 'Couldn\'t load the schedule';

  @override
  String get profileNotFound => 'Channel not found';

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
  String get profileReminderSet => 'Reminder Set';

  @override
  String get profileRemindMe => 'Remind Me';

  @override
  String get startsNow => 'now';

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
  String get profileReminderFailed => 'Couldn\'t set the reminder.';

  @override
  String get profileStreamUntitled => 'Stream';

  @override
  String get profileNoSchedule => 'No streams scheduled';

  @override
  String profileNextStreamIn({required String when, required String time}) {
    return 'Next stream $when · $time';
  }

  @override
  String get profileCancelled => 'Cancelled';

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
  String get videosListFailed => 'Couldn\'t load videos';

  @override
  String videosShowingMostViewed({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Showing the $count most viewed videos',
      one: 'Showing the $count most viewed video',
    );
    return '$_temp0';
  }

  @override
  String videosShowingMostRecent({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Showing the $count most recent videos',
      one: 'Showing the $count most recent video',
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
  String get activityNote => 'Notifications ONSET posted on this device.';

  @override
  String get activityRemove => 'Remove notification';

  @override
  String get activityEmpty => 'Hooray! You\'re up to date';

  @override
  String get activityEmptyDetail =>
      'Check back soon for alerts about you and the broadcasters you follow.';

  @override
  String get activityMostRecent => 'Most Recent';

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
  String get activityKindMention => 'Chat Mentions';

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
      'Twitch isn\'t sending whispers to this app right now. It tries again when you come back to the app.';

  @override
  String get whisperStatusOff => 'Log in to get whispers.';

  @override
  String get playerBack10 => 'Back 10 seconds';

  @override
  String get playerForward10 => 'Forward 10 seconds';

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
  String get playerCaptions => 'Closed Captions';

  @override
  String get playerCaptionsDetail => 'When the stream has them';

  @override
  String get playerSpeedNormal => 'Normal';

  @override
  String get playerSemantics => 'Video player';

  @override
  String get playerHideControls => 'hide controls';

  @override
  String get playerShowControls => 'show controls';
}
