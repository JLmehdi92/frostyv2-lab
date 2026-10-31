import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// English, written in English (an endonym, identical in every language): the language pill of the onboarding Intro, the one-time language prompt and Settings › General › Language.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEnglish;

  /// French, written in French (an endonym, identical in every language): the language pill of the onboarding Intro, the one-time language prompt and Settings › General › Language.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageNameFrench;

  /// What a screen reader calls the language pill (onboarding Intro, one-time language prompt), in both languages on purpose so it is understood whatever language is on screen.
  ///
  /// In en, this message translates to:
  /// **'Language · Langue'**
  String get languageChoiceSemantics;

  /// Settings › General › Language: the option that follows the device's language.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appLanguageSystem;

  /// Button that goes on to the next step (onboarding Intro and Setup).
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// Tooltip of the back chevron (onboarding bar, Twitch login page, sheet sub-views, in-app Twitch pages).
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Button that closes a picker or dialog without keeping the change (accent colour picker).
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Button that closes a picker and keeps the change (accent colour picker).
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// Button or tooltip that closes a dialog or a full-screen view (login help, photo viewer).
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Button that retries what failed (Twitch login page, error states).
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// Default tooltip of the retry icon at the end of an alert message (snackbars, inline errors).
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// The small badge on a live channel's picture (onboarding mosaic and Setup preview). Kept short and in capitals: it sits in a 16-20 dp pill.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get commonLiveBadge;

  /// Tooltip of the cross that hides an in-app notification banner.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// Button that opens the Twitch login (onboarding Log in step, logged-out screens), and the title of the Twitch login page.
  ///
  /// In en, this message translates to:
  /// **'Connect with Twitch'**
  String get commonConnectWithTwitch;

  /// Settings › General: the title of the first group, the app's language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// Settings › General › Language: the line under the options, saying which language the System option gives on this device. The language is named as in a sentence (languageInTextEnglish, languageInTextFrench).
  ///
  /// In en, this message translates to:
  /// **'“System” follows your device’s language (currently: {language}).'**
  String settingsLanguageSystemSubtitle({required String language});

  /// The English language named inside a sentence of the language on screen (lower case in French), as in the System subtitle of Settings › General › Language.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageInTextEnglish;

  /// The French language named inside a sentence of the language on screen (lower case in French), as in the System subtitle of Settings › General › Language.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageInTextFrench;

  /// Title of the one-time sheet that asks the language after the update that added French.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languagePromptTitle;

  /// Text of the one-time language sheet, under its title.
  ///
  /// In en, this message translates to:
  /// **'ONSET is now available in English and French. You can change the language anytime in Settings › General.'**
  String get languagePromptBody;

  /// Button of the one-time language sheet that keeps the language selected.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get languagePromptConfirm;

  /// Onboarding Intro: the app's description under its name (a large heading on a tablet).
  ///
  /// In en, this message translates to:
  /// **'A mobile Twitch client with 7TV, BetterTTV (BTTV), and FrankerFaceZ (FFZ) support.'**
  String get onboardingIntroDescription;

  /// Onboarding Intro on a tablet: the small line above the description (shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'First launch'**
  String get onboardingIntroEyebrow;

  /// What a screen reader calls the onboarding’s four-segment progress bar.
  ///
  /// In en, this message translates to:
  /// **'Onboarding progress'**
  String get onboardingProgressLabel;

  /// Screen-reader value of the onboarding progress bar.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {count}'**
  String onboardingProgressValue({required int step, required int count});

  /// Onboarding: title of the Log in step.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get onboardingLoginTitle;

  /// Onboarding Log in step: the text under the title.
  ///
  /// In en, this message translates to:
  /// **'ONSET needs your permission in order to enable the ability to chat, view followed streams, and more.'**
  String get onboardingLoginLead;

  /// Onboarding Log in step: header of the permission list (shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'What you will authorize'**
  String get onboardingLoginAuthorizeHeader;

  /// Onboarding Log in step, permission list: the chat permission.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get onboardingPermissionChatTitle;

  /// Onboarding Log in step, permission list: what the chat permission allows.
  ///
  /// In en, this message translates to:
  /// **'Read and send messages'**
  String get onboardingPermissionChatDetail;

  /// Onboarding Log in step, permission list: the followed channels permission.
  ///
  /// In en, this message translates to:
  /// **'Followed channels'**
  String get onboardingPermissionFollowsTitle;

  /// Onboarding Log in step, permission list: what the followed channels permission allows.
  ///
  /// In en, this message translates to:
  /// **'See who is live right now'**
  String get onboardingPermissionFollowsDetail;

  /// Onboarding Log in step, permission list: the viewer's own emotes permission.
  ///
  /// In en, this message translates to:
  /// **'Your emotes'**
  String get onboardingPermissionEmotesTitle;

  /// Onboarding Log in step, permission list: what the emotes permission allows.
  ///
  /// In en, this message translates to:
  /// **'Use your sub and follower emotes'**
  String get onboardingPermissionEmotesDetail;

  /// Onboarding Log in step, permission list: the whispers permission.
  ///
  /// In en, this message translates to:
  /// **'Whispers'**
  String get onboardingPermissionWhispersTitle;

  /// Onboarding Log in step, permission list: what the whispers permission allows.
  ///
  /// In en, this message translates to:
  /// **'Read and send whispers'**
  String get onboardingPermissionWhispersDetail;

  /// Onboarding Log in step, permission list: the moderation permissions.
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get onboardingPermissionModerationTitle;

  /// Onboarding Log in step, permission list: what the moderation permissions allow.
  ///
  /// In en, this message translates to:
  /// **'Bans, warnings, messages, chat modes'**
  String get onboardingPermissionModerationDetail;

  /// Onboarding Log in step, permission list: the clips permission.
  ///
  /// In en, this message translates to:
  /// **'Clips'**
  String get onboardingPermissionClipsTitle;

  /// Onboarding Log in step, permission list: what the clips permission allows.
  ///
  /// In en, this message translates to:
  /// **'Create clips from a stream'**
  String get onboardingPermissionClipsDetail;

  /// Onboarding Log in step, permission list: the blocks and chat colour permissions.
  ///
  /// In en, this message translates to:
  /// **'Blocks and name color'**
  String get onboardingPermissionBlocksTitle;

  /// Onboarding Log in step, permission list: what the blocks and chat colour permissions allow.
  ///
  /// In en, this message translates to:
  /// **'Manage blocks, change your chat color'**
  String get onboardingPermissionBlocksDetail;

  /// Onboarding Log in step: the note above the buttons (in the content on a tablet).
  ///
  /// In en, this message translates to:
  /// **'ONSET only asks for the necessary permissions through the official Twitch API. You’ll be able to review them before authorizing.'**
  String get onboardingLoginDisclaimer;

  /// Onboarding Log in step: goes on without an account.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingLoginSkip;

  /// Onboarding: title of the Setup step.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get onboardingSetupTitle;

  /// Onboarding Setup step: the text under the title.
  ///
  /// In en, this message translates to:
  /// **'Let’s tweak some settings before you get started. You can always change these and more later.'**
  String get onboardingSetupLead;

  /// Onboarding Setup step: the pill saying which Twitch account is logged in. The name is shown in bold.
  ///
  /// In en, this message translates to:
  /// **'Logged in as {name}'**
  String onboardingSetupLoggedInAs({required String name});

  /// While Twitch finishes the login (onboarding Setup pill, over the Twitch login page).
  ///
  /// In en, this message translates to:
  /// **'Signing you in…'**
  String get loginSigningIn;

  /// Onboarding Setup step: the pill when the Twitch login did not go through. Profile is the bottom bar section.
  ///
  /// In en, this message translates to:
  /// **'Login failed · go back to try again, or log in later from Profile'**
  String get onboardingSetupLoginFailed;

  /// Onboarding Setup step: the pill when no account is logged in. Profile is the bottom bar section.
  ///
  /// In en, this message translates to:
  /// **'Not logged in · you can log in later from Profile'**
  String get onboardingSetupNotLoggedIn;

  /// Onboarding Setup step, live preview: the stand-in channel name when no live channel could be loaded.
  ///
  /// In en, this message translates to:
  /// **'A live channel'**
  String get onboardingSetupPreviewChannel;

  /// Onboarding Setup step, live preview: the stand-in line under the channel name.
  ///
  /// In en, this message translates to:
  /// **'Category · viewers'**
  String get onboardingSetupPreviewDetail;

  /// What a screen reader says for the onboarding Setup live preview.
  ///
  /// In en, this message translates to:
  /// **'Preview: {name}, {detail}'**
  String onboardingSetupPreviewSemantics({
    required String name,
    required String detail,
  });

  /// Onboarding Setup step, live preview: the small capitals at its end.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get onboardingSetupPreviewBadge;

  /// Onboarding Setup step: the theme row and what a screen reader calls its pill.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get onboardingSetupThemeTitle;

  /// The theme that follows the device (onboarding Setup pill).
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// The light theme (onboarding Setup pill).
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// The dark theme (onboarding Setup pill).
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Onboarding Setup step: the note beside Theme when System is picked.
  ///
  /// In en, this message translates to:
  /// **'Follows your device'**
  String get onboardingSetupThemeSystemNote;

  /// Onboarding Setup step: the note beside Theme when Light is picked.
  ///
  /// In en, this message translates to:
  /// **'Light surfaces everywhere'**
  String get onboardingSetupThemeLightNote;

  /// Onboarding Setup step: the note beside Theme when Dark is picked ("Noir" is the dark theme's name).
  ///
  /// In en, this message translates to:
  /// **'Noir, the ONSET default'**
  String get onboardingSetupThemeDarkNote;

  /// The accent colour row of onboarding Setup, and the title of its colour picker.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColorTitle;

  /// What a screen reader says for the onboarding Setup accent colour row.
  ///
  /// In en, this message translates to:
  /// **'Accent color, {hex}'**
  String accentColorSemantics({required String hex});

  /// Accent colour picker: picks a random colour.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get accentColorRandom;

  /// What a screen reader calls the colour square of the accent colour pickers.
  ///
  /// In en, this message translates to:
  /// **'Saturation and brightness'**
  String get accentSaturationBrightness;

  /// Screen-reader value of the colour square of the accent colour pickers.
  ///
  /// In en, this message translates to:
  /// **'{saturation} %, {brightness} %'**
  String accentSaturationBrightnessValue({
    required int saturation,
    required int brightness,
  });

  /// A screen-reader button on the hue slider of the accent colour pickers (eight named hues, 0 to 315).
  ///
  /// In en, this message translates to:
  /// **'{degrees, plural, other{Hue {degrees} degrees}}'**
  String accentHue({required int degrees});

  /// Onboarding Setup step: the switch that loads recent chat messages from a third party.
  ///
  /// In en, this message translates to:
  /// **'Fallback chat history (third-party)'**
  String get onboardingSetupHistoryTitle;

  /// Onboarding Setup step: the text under the fallback chat history switch. The link is the third party's host, underlined.
  ///
  /// In en, this message translates to:
  /// **'When Twitch\'s own chat history is unavailable, fails or is empty, loads recent messages from {link}, which then receives the channel name.'**
  String onboardingSetupHistoryDetail({required String link});

  /// Onboarding Setup step: the crash logs and analytics consent switch.
  ///
  /// In en, this message translates to:
  /// **'Share crash logs and analytics'**
  String get onboardingSetupCrashTitle;

  /// Onboarding Setup step: the text under the crash logs and analytics switch.
  ///
  /// In en, this message translates to:
  /// **'Help improve ONSET by sending crash logs and analytics through Firebase, without your Twitch account or channels.'**
  String get onboardingSetupCrashDetail;

  /// Onboarding: title of the last step, Welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get onboardingWelcomeTitle;

  /// Onboarding Welcome step: the text under the title, above the three tips.
  ///
  /// In en, this message translates to:
  /// **'Just a few more things…'**
  String get onboardingWelcomeLead;

  /// Onboarding Welcome step: the first tip.
  ///
  /// In en, this message translates to:
  /// **'Check out the GitHub repo at the top-right of the settings page to explore ONSET’s source code, report bugs, make feature requests, and more.'**
  String get onboardingWelcomeTipGitHub;

  /// Onboarding Welcome step: the second tip. "Other" is the name of a settings page.
  ///
  /// In en, this message translates to:
  /// **'Links to the full changelog and FAQ are in the settings page under “Other”.'**
  String get onboardingWelcomeTipChangelog;

  /// Onboarding Welcome step: the third tip.
  ///
  /// In en, this message translates to:
  /// **'Don’t forget to leave a rating and/or review on the app store!'**
  String get onboardingWelcomeTipRating;

  /// Onboarding Welcome step: the button that opens the app.
  ///
  /// In en, this message translates to:
  /// **'Let’s go!'**
  String get onboardingWelcomeGo;

  /// Tooltip of the "?" on the Twitch login page, and what a screen reader calls its dialog.
  ///
  /// In en, this message translates to:
  /// **'Login help'**
  String get loginHelpTooltip;

  /// Title of the login help dialog.
  ///
  /// In en, this message translates to:
  /// **'Workaround for the Twitch cookie banner'**
  String get loginHelpTitle;

  /// Text of the login help dialog, opened from the onboarding.
  ///
  /// In en, this message translates to:
  /// **'If the Twitch cookie banner is still blocking the login, try clicking one of the links in the cookie policy description and navigating until you reach the Twitch home page. From there, you can try logging in on the top right profile icon. Once logged in, go back to the first step of the onboarding and then try again.'**
  String get loginHelpBodyOnboarding;

  /// Text of the login help dialog, opened from the settings (outside the onboarding).
  ///
  /// In en, this message translates to:
  /// **'If the Twitch cookie banner is still blocking the login, try clicking one of the links in the cookie policy description and navigating until you reach the Twitch home page. From there, you can try logging in on the top right profile icon. Once logged in, go back, then open the login again.'**
  String get loginHelpBodyElsewhere;

  /// What a screen reader says for the address strip of the Twitch login page, on an https page.
  ///
  /// In en, this message translates to:
  /// **'Secure page: {host}'**
  String loginHostSecure({required String host});

  /// What a screen reader says for the address strip of the Twitch login page, on a page that is not https.
  ///
  /// In en, this message translates to:
  /// **'Page: {host}'**
  String loginHostPage({required String host});

  /// The line under the address of the Twitch login page when Twitch handed back a token that did not log in.
  ///
  /// In en, this message translates to:
  /// **'Twitch did not sign you in. Try again.'**
  String get loginFailedLine;

  /// Twitch login page: the title when the page could not load.
  ///
  /// In en, this message translates to:
  /// **'Twitch could not be reached'**
  String get loginLoadFailedTitle;

  /// Twitch login page: the text under the title when the page could not load.
  ///
  /// In en, this message translates to:
  /// **'Check your connection, then try again.'**
  String get loginLoadFailedDetail;

  /// The Home section of the bottom bar (tablet: the top pill).
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shellSectionHome;

  /// The Browse section of the bottom bar (tablet: the top pill), and Browse's header title.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get shellSectionBrowse;

  /// The Activity section of the bottom bar (tablet: the top pill), and Activity's header title.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get shellSectionActivity;

  /// The Profile section of the bottom bar (tablet: the avatar's tooltip).
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get shellSectionProfile;

  /// What a screen reader (and the tooltip) says for the Activity section when notifications are unread.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{Activity, {count} new}}'**
  String shellActivityNew({required int count});

  /// Home's top tab of the followed channels that are live.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get shellFeedFollowing;

  /// Home's top tab of the top live streams.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get shellFeedLive;

  /// Home's top tab of the clips feed.
  ///
  /// In en, this message translates to:
  /// **'Clips'**
  String get shellFeedClips;

  /// Browse's tab of the categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get shellBrowseCategories;

  /// Browse's tab of the live channels.
  ///
  /// In en, this message translates to:
  /// **'Live channels'**
  String get shellBrowseLiveChannels;

  /// Activity's tab of the notifications ONSET posted.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get shellActivityNotifications;

  /// Activity's tab of the whispers, and the tooltip of the header's whispers button.
  ///
  /// In en, this message translates to:
  /// **'Whispers'**
  String get shellWhispers;

  /// Tooltip of the header's whispers button when whispers are unread.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{Whispers ({count} unread)}}'**
  String shellWhispersUnread({required int count});

  /// Tooltip of the header's whispers button when Twitch refused them until a new login.
  ///
  /// In en, this message translates to:
  /// **'Whispers (log in again to get them)'**
  String get shellWhispersRefused;

  /// What a screen reader says for a header tab with an unread count (Activity: Notifications, Whispers).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{label}, {count} unread}}'**
  String shellTabUnread({required String label, required int count});

  /// What a screen reader calls the bottom bar (tablet: the top pill) of the main sections.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get shellNavSemantics;

  /// The search button and field of the header, and what a screen reader calls them.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get shellSearch;

  /// Browse's search field on a phone.
  ///
  /// In en, this message translates to:
  /// **'Search channels, categories or videos'**
  String get shellSearchHint;

  /// Tooltip of the header's settings button (on Profile).
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shellSettings;

  /// Snackbar when a channel opened from Activity could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open {login}\'s channel.'**
  String homeOpenChannelFailed({required String login});

  /// Snackbar when a mention notification is tapped while a player or a conversation covers the chat.
  ///
  /// In en, this message translates to:
  /// **'You were mentioned in {login}\'s chat'**
  String mentionNotice({required String login});

  /// Title of the in-app Twitch page opened for a category link Twitch search did not find, when the link has no name.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get deepLinkCategoryFallback;

  /// Snackbar when a link to Twitch cannot be opened in the app.
  ///
  /// In en, this message translates to:
  /// **'Unable to navigate to \'{uri}\''**
  String deepLinkFailed({required String uri});

  /// Tooltip of the button at the end of the link failure snackbar.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get deepLinkOpenInBrowser;

  /// Tooltip of the button that scrolls a list back to its top.
  ///
  /// In en, this message translates to:
  /// **'Scroll to top'**
  String get scrollToTop;

  /// What a screen reader says for the mini player: it opens the channel again.
  ///
  /// In en, this message translates to:
  /// **'Return to stream'**
  String get miniPlayerReturn;

  /// Tooltip of the mini player's close button.
  ///
  /// In en, this message translates to:
  /// **'Close mini player'**
  String get miniPlayerClose;

  /// Channel long-press menu: opens the channel's profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get userActionsProfile;

  /// Channel long-press menu: opens the channel's videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get userActionsVideos;

  /// Channel long-press menu: pins the channel to the top of Following.
  ///
  /// In en, this message translates to:
  /// **'Pin {name}'**
  String userActionsPin({required String name});

  /// Channel long-press menu: unpins the channel.
  ///
  /// In en, this message translates to:
  /// **'Unpin {name}'**
  String userActionsUnpin({required String name});

  /// Channel long-press menu: blocks the channel.
  ///
  /// In en, this message translates to:
  /// **'Block {name}'**
  String userActionsBlock({required String name});

  /// Channel long-press menu: follows the channel on twitch.tv.
  ///
  /// In en, this message translates to:
  /// **'Follow {name} on Twitch'**
  String userActionsFollowOnTwitch({required String name});

  /// Channel long-press menu: the second line under "Follow … on Twitch".
  ///
  /// In en, this message translates to:
  /// **'Opens the channel on twitch.tv'**
  String get userActionsFollowDetail;

  /// Channel long-press menu: copies the channel's link.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get userActionsCopyLink;

  /// Snackbar after the channel's link was copied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get userActionsLinkCopied;

  /// Channel long-press menu: shares the channel's link.
  ///
  /// In en, this message translates to:
  /// **'Share {name}'**
  String userActionsShare({required String name});

  /// Channel long-press menu: reports the channel on twitch.tv, and that page's title.
  ///
  /// In en, this message translates to:
  /// **'Report {name}'**
  String userActionsReport({required String name});

  /// What a screen reader calls the divider that resizes the chat beside the video.
  ///
  /// In en, this message translates to:
  /// **'Chat width'**
  String get draggableDividerChatWidth;

  /// Screen-reader value of the chat width divider: the share of the window the chat takes.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String draggableDividerValue({required int percent});

  /// Full-screen picture viewer: switches back to the small picture.
  ///
  /// In en, this message translates to:
  /// **'View thumbnail'**
  String get photoViewThumbnail;

  /// Full-screen picture viewer: loads the full-size picture.
  ///
  /// In en, this message translates to:
  /// **'View original'**
  String get photoViewOriginal;

  /// The line under an empty list of videos or clips.
  ///
  /// In en, this message translates to:
  /// **'Pull down to check again.'**
  String get videoListEmptyHint;

  /// Release notes on a phone: the heading of the older versions.
  ///
  /// In en, this message translates to:
  /// **'Earlier versions'**
  String get releaseNotesEarlierVersions;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
