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

  /// Tooltip of the back chevron (onboarding bar, Twitch login page, sheet sub-views, in-app Twitch pages, settings pages, release notes), and the label of the tablet settings pane's back button.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Button that closes a picker or dialog without keeping the change: accent colour picker, settings confirmations, the Twitch web token and update dialogs, the muted keywords field.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Button that closes a picker or a settings list and keeps the change (accent colour pickers, settings sheets).
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

  /// Button that opens the Twitch login (onboarding Log in step, Profile and other logged-out screens), and the title of the Twitch login page.
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

  /// The theme that follows the device (onboarding Setup pill, Settings › General › Theme).
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// The light theme (onboarding Setup pill, Settings › General › Theme).
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// The dark theme (onboarding Setup pill, Settings › General › Theme).
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

  /// The accent colour row (onboarding Setup, Settings › General), and the title of its colour picker.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColorTitle;

  /// What a screen reader says for the onboarding Setup accent colour row.
  ///
  /// In en, this message translates to:
  /// **'Accent color, {hex}'**
  String accentColorSemantics({required String hex});

  /// Accent colour pickers (onboarding, Settings): picks a random colour.
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

  /// The switch that loads recent chat messages from a third party (onboarding Setup step, Settings › Chat › Recent messages).
  ///
  /// In en, this message translates to:
  /// **'Fallback chat history (third-party)'**
  String get onboardingSetupHistoryTitle;

  /// Onboarding Setup step: the text under the fallback chat history switch. The link is the third party's host, underlined. Also under the same switch in Settings › Chat › Recent messages.
  ///
  /// In en, this message translates to:
  /// **'When Twitch\'s own chat history is unavailable, fails or is empty, loads recent messages from {link}, which then receives the channel name.'**
  String onboardingSetupHistoryDetail({required String link});

  /// The crash logs and analytics consent switch (onboarding Setup step, Settings › Other › Privacy).
  ///
  /// In en, this message translates to:
  /// **'Share crash logs and analytics'**
  String get onboardingSetupCrashTitle;

  /// Onboarding Setup step: the text under the crash logs and analytics switch. Also under the same switch in Settings › Other › Privacy.
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

  /// The Browse section of the bottom bar (tablet: the top pill), and Browse's header title. Also an option of Settings › General › « Open the app on ».
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

  /// Home's top tab of the followed channels that are live. Also an option of Settings › General › « Open the app on ».
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get shellFeedFollowing;

  /// Home's top tab of the top live streams. Also an option of Settings › General › « Open the app on ».
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get shellFeedLive;

  /// Home's top tab of the clips feed. Also an option of Settings › General › « Open the app on ».
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

  /// Release notes on a phone: the heading of the older versions. Opened from Settings, or after an update to the newest entry.
  ///
  /// In en, this message translates to:
  /// **'Earlier versions'**
  String get releaseNotesEarlierVersions;

  /// Title of the settings page, its section label in Profile and on the tablet side column, and the button that opens it on Profile.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Phone settings: the label of the group of sections (General, Video, Chat, Notifications).
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get settingsCustomize;

  /// What a screen reader calls the tablet settings' side column.
  ///
  /// In en, this message translates to:
  /// **'Settings sections'**
  String get settingsSectionsSemantics;

  /// What a screen reader calls the row of chips that scroll a tablet settings page to one of its groups.
  ///
  /// In en, this message translates to:
  /// **'Jump to a group'**
  String get settingsJumpToGroup;

  /// The General settings page: its row, title and side column entry. French: exactly « Général », other messages cite it.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsPageGeneral;

  /// Tablet: the line under the General settings page title.
  ///
  /// In en, this message translates to:
  /// **'Theme, stream cards, browsing and links'**
  String get settingsPageGeneralDescription;

  /// The Video settings page: its row, title and side column entry.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get settingsPageVideo;

  /// Tablet: the line under the Video settings page title.
  ///
  /// In en, this message translates to:
  /// **'The low-latency player, playback, overlay, videos and captions'**
  String get settingsPageVideoDescription;

  /// The Chat settings page: its row, title and side column entry; also a group of Settings › Notifications.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get settingsPageChat;

  /// Tablet: the line under the Chat settings page title.
  ///
  /// In en, this message translates to:
  /// **'How chat looks, waits, alerts and filters'**
  String get settingsPageChatDescription;

  /// The Notifications settings page: its row, title and side column entry.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsPageNotifications;

  /// Tablet: the line under the Notifications settings page title.
  ///
  /// In en, this message translates to:
  /// **'Go-live and chat mention notifications'**
  String get settingsPageNotificationsDescription;

  /// The Other settings page (updates, storage, privacy, about): its row, title and side column entry. French: exactly « Autres », other messages cite it.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get settingsPageOther;

  /// Tablet: the line under the Other settings page title.
  ///
  /// In en, this message translates to:
  /// **'Updates, storage, privacy and about'**
  String get settingsPageOtherDescription;

  /// The Account settings page (the viewer's Twitch account): its title and side column entry, and its group label in Profile and on the tablet side column.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsPageAccount;

  /// Tablet: the line under the Account settings page title.
  ///
  /// In en, this message translates to:
  /// **'Your Twitch account in ONSET'**
  String get settingsPageAccountDescription;

  /// The blocked users page: its title, side column entry and the rows that open it (Profile, Account).
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get settingsPageBlocked;

  /// Tablet: the line under the blocked users page title.
  ///
  /// In en, this message translates to:
  /// **'People you blocked on Twitch'**
  String get settingsPageBlockedDescription;

  /// Settings › Chat: the row that opens the chat filters, and that page's title.
  ///
  /// In en, this message translates to:
  /// **'Edit Chat Filters'**
  String get settingsPageChatFilters;

  /// Profile and phone settings: the line under the General section.
  ///
  /// In en, this message translates to:
  /// **'Theme, accent color, browse, links'**
  String get settingsSummaryGeneral;

  /// Profile and phone settings: the line under the Video section.
  ///
  /// In en, this message translates to:
  /// **'Low-latency player, captions, overlay'**
  String get settingsSummaryVideo;

  /// Profile and phone settings: the line under the Chat section.
  ///
  /// In en, this message translates to:
  /// **'Sizing, alerts, filters, emotes'**
  String get settingsSummaryChat;

  /// Phone settings, logged in: the line under the Notifications section.
  ///
  /// In en, this message translates to:
  /// **'Go-live and chat mentions'**
  String get settingsSummaryNotifications;

  /// Profile and phone settings, logged out: the line under the Notifications section.
  ///
  /// In en, this message translates to:
  /// **'Log in to get go-live and mention notifications'**
  String get settingsSummaryNotificationsLoggedOut;

  /// Profile and phone settings: the line under the Other section.
  ///
  /// In en, this message translates to:
  /// **'Updates, cache, privacy, about'**
  String get settingsSummaryOther;

  /// Profile: the line under the Notifications section where go-live notifications do not exist (not Android). mentions is on or off.
  ///
  /// In en, this message translates to:
  /// **'{mentions, select, on{Mentions on} other{Mentions off}}'**
  String settingsSummaryMentions({required String mentions});

  /// Profile: the line under the Notifications section: whether go-live and chat mention notifications are on. goLive and mentions are on or off.
  ///
  /// In en, this message translates to:
  /// **'{goLive, select, on{Go-live on} other{Go-live off}} · {mentions, select, on{mentions on} other{mentions off}}'**
  String settingsSummaryGoLiveMentions({
    required String goLive,
    required String mentions,
  });

  /// Phone settings account card and Profile, when Twitch cannot be reached (a network problem, not a login).
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to Twitch'**
  String get settingsUnableToReachTwitch;

  /// Under « Unable to connect to Twitch » (phone settings account card, Profile).
  ///
  /// In en, this message translates to:
  /// **'Check your connection, then try again'**
  String get settingsCheckConnection;

  /// Button that tries to reach Twitch again (phone settings account card, Profile).
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get settingsReconnect;

  /// Phone settings account card, logged in: the line under the name (what the account page holds).
  ///
  /// In en, this message translates to:
  /// **'Blocked users, twitch.tv, log out'**
  String get settingsAccountCardDetail;

  /// Phone settings account card and Profile, logged out: the title in place of a name.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get settingsAnonymous;

  /// Profile, logged out: the line under « Anonymous ».
  ///
  /// In en, this message translates to:
  /// **'Watching without an account'**
  String get settingsWatchingWithoutAccount;

  /// Phone settings account card and Profile, logged out: why to log in.
  ///
  /// In en, this message translates to:
  /// **'Log in to enable the ability to chat, view followed streams, and more.'**
  String get settingsLoginPitch;

  /// Profile, logged out: the note under « Connect with Twitch ».
  ///
  /// In en, this message translates to:
  /// **'ONSET only asks for the necessary permissions through the official Twitch API. You\'ll be able to review them before authorizing.'**
  String get settingsLoginDisclaimer;

  /// Profile, logged out: the tip at the end of the login card (a long press logs in with a copied token).
  ///
  /// In en, this message translates to:
  /// **'Have a token copied? Long-press this card to log in with it.'**
  String get settingsTokenLoginTip;

  /// What a screen reader says a long press on the Profile login card does (lower case: it follows « double tap and hold to »).
  ///
  /// In en, this message translates to:
  /// **'log in with a copied token'**
  String get settingsTokenLoginHint;

  /// Settings › Account: the group with « My channel » and « Blocked users ».
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get settingsYourAccount;

  /// Opens the viewer's own channel (Settings › Account, Profile, tablet side column).
  ///
  /// In en, this message translates to:
  /// **'My channel'**
  String get settingsMyChannel;

  /// Settings › Account: the group of Twitch's own account pages.
  ///
  /// In en, this message translates to:
  /// **'On twitch.tv'**
  String get settingsOnTwitch;

  /// Settings › Account and Profile: opens Twitch's security and privacy page, and that page's title.
  ///
  /// In en, this message translates to:
  /// **'Security and privacy'**
  String get settingsTwitchSecurity;

  /// Profile: the line under « Security and privacy ».
  ///
  /// In en, this message translates to:
  /// **'Password, email, phone, two-factor — on twitch.tv'**
  String get settingsTwitchSecurityDetail;

  /// Settings › Account and Profile: opens Twitch's connections page (linked accounts), and that page's title. French: Twitch's own name for that page.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get settingsTwitchConnections;

  /// Profile: the line under « Connections ».
  ///
  /// In en, this message translates to:
  /// **'Linked accounts — on twitch.tv'**
  String get settingsTwitchConnectionsDetail;

  /// The row or button that logs out (Settings › Account, Profile, tablet side column), and the button that confirms it.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogOut;

  /// Title of the dialog that asks before logging out.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogOutTitle;

  /// Text of the dialog that asks before logging out.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get settingsLogOutMessage;

  /// Under the viewer's name (Settings › Account, Profile): when the Twitch account was created, as month and year.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String settingsJoined({required DateTime date});

  /// What a screen reader calls the head of Profile (picture, name, buttons).
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get settingsYourProfile;

  /// The button that unblocks someone (blocked users page), and the title of the dialog that asks first.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get settingsUnblock;

  /// What a screen reader says for the « Unblock » button of a blocked user.
  ///
  /// In en, this message translates to:
  /// **'Unblock {name}'**
  String settingsUnblockName({required String name});

  /// Text of the dialog that asks before unblocking someone.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unblock \"{name}\"?'**
  String settingsUnblockMessage({required String name});

  /// Title of the dialog that asks before blocking someone (from a channel or a chat user card).
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get settingsBlock;

  /// Text of the dialog that asks before blocking someone.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to block \"{name}\"? This will remove them from channel lists, search results, and chat messages.'**
  String settingsBlockMessage({required String name});

  /// The button that confirms a block or an unblock.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// The blocked users page when there are none.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get settingsNoBlockedUsers;

  /// The blocked users page: the label above the list (shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} blocked}}'**
  String settingsBlockedCount({required int count});

  /// The blocked users page: the note under the list.
  ///
  /// In en, this message translates to:
  /// **'Blocked users are removed from channel lists, search results, and chat messages. Pull down to refresh.'**
  String get settingsBlockedNote;

  /// Snackbar shown once when the session's Twitch token belongs to another app.
  ///
  /// In en, this message translates to:
  /// **'This token was created for another app — some features may not work.'**
  String get authForeignTokenNotice;

  /// Snackbar shown once when Twitch refused the stored login at launch.
  ///
  /// In en, this message translates to:
  /// **'Your Twitch session has ended. Log in again from Settings.'**
  String get authSessionEndedNotice;

  /// Settings › General: the theme group, and what a screen reader calls its pill.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// What a screen reader says for the accent colour row of Settings › General (it opens the picker).
  ///
  /// In en, this message translates to:
  /// **'Change accent color'**
  String get settingsAccentColorChange;

  /// Accent colour picker of Settings: the line under the colour code.
  ///
  /// In en, this message translates to:
  /// **'Applies everywhere as you pick'**
  String get settingsAccentColorLive;

  /// Settings › General: the group about the cards of live channels.
  ///
  /// In en, this message translates to:
  /// **'Stream card'**
  String get settingsStreamCard;

  /// Settings › General › Stream card: the switch for the large card.
  ///
  /// In en, this message translates to:
  /// **'Use large stream card'**
  String get settingsLargeStreamCard;

  /// Settings › General › Stream card: the switch that shows the stream picture.
  ///
  /// In en, this message translates to:
  /// **'Show thumbnail'**
  String get settingsShowThumbnail;

  /// Settings › General: the browsing group.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get settingsBrowse;

  /// Settings › General › Browse: the choice of where the app opens (Following, Live, Clips, Browse).
  ///
  /// In en, this message translates to:
  /// **'Open the app on'**
  String get settingsStartTab;

  /// Settings › General: the links group.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get settingsLinks;

  /// Settings › General › Links: the switch that opens links outside the app.
  ///
  /// In en, this message translates to:
  /// **'Open links in external browser'**
  String get settingsExternalBrowser;

  /// Settings › General › Browse: the row that filters live channels by language, its list's title, and what a screen reader calls that list.
  ///
  /// In en, this message translates to:
  /// **'Stream language'**
  String get settingsStreamLanguage;

  /// Stream language filter (Settings › General › Browse): no filter.
  ///
  /// In en, this message translates to:
  /// **'All languages'**
  String get streamLanguageAll;

  /// Stream language filter (Settings › General › Browse): streams in a language not listed.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get streamLanguageOther;

  /// Settings › General › Browse: the row that hides streams with content classification labels, and its list's title.
  ///
  /// In en, this message translates to:
  /// **'Hide labeled streams'**
  String get settingsHideLabeled;

  /// Settings › General › Browse: the value of « Hide labeled streams » when none or several labels are hidden (one label shows its name instead).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None} other{{count} labels}}'**
  String settingsHideLabeledValue({required int count});

  /// The list of content labels to hide: the note under its title.
  ///
  /// In en, this message translates to:
  /// **'Streams with these labels are left out of Top, categories and tags. Followed channels always show.'**
  String get settingsHideLabeledNote;

  /// Twitch's content classification label (Settings › General › Hide labeled streams, the mature content warning).
  ///
  /// In en, this message translates to:
  /// **'Drugs, Intoxication, or Excessive Tobacco Use'**
  String get contentLabelDrugs;

  /// Twitch's content classification label.
  ///
  /// In en, this message translates to:
  /// **'Sexual Themes'**
  String get contentLabelSexualThemes;

  /// Twitch's content classification label.
  ///
  /// In en, this message translates to:
  /// **'Violent and Graphic Depictions'**
  String get contentLabelViolentGraphic;

  /// Twitch's content classification label.
  ///
  /// In en, this message translates to:
  /// **'Gambling'**
  String get contentLabelGambling;

  /// Twitch's content classification label.
  ///
  /// In en, this message translates to:
  /// **'Significant Profanity or Vulgarity'**
  String get contentLabelProfanity;

  /// Twitch's content classification label.
  ///
  /// In en, this message translates to:
  /// **'Mature-Rated Game'**
  String get contentLabelMatureGame;

  /// Twitch's content classification label.
  ///
  /// In en, this message translates to:
  /// **'Politics and Sensitive Social Issues'**
  String get contentLabelPolitics;

  /// Settings › Video (Android): the group of the Amazon IVS player's settings.
  ///
  /// In en, this message translates to:
  /// **'Low-latency player'**
  String get settingsLowLatencyPlayer;

  /// Settings › Video › Low-latency player: the switch between the Amazon IVS player and the Twitch web player.
  ///
  /// In en, this message translates to:
  /// **'Low-latency player (Amazon IVS)'**
  String get settingsLowLatencyPlayerSwitch;

  /// Settings › Video › Low-latency player: what the switch does.
  ///
  /// In en, this message translates to:
  /// **'Plays the stream with the Amazon IVS player, built on the same video technology as Twitch, for low latency. Turn off to use the original Twitch web player.'**
  String get settingsLowLatencyPlayerDetail;

  /// Settings › Video › Low-latency player: the switch that keeps the stream close to live by playing slightly faster.
  ///
  /// In en, this message translates to:
  /// **'Auto latency'**
  String get settingsAutoLatency;

  /// Settings › Video › Low-latency player: what « Auto latency » does. Ultra and Standard are the buffer profiles.
  ///
  /// In en, this message translates to:
  /// **'Keeps the stream close to live by playing very slightly faster when it drifts behind, without reloading it. If Ultra keeps stalling, the next streams use Standard for a while. Applies the next time a stream is opened.'**
  String get settingsAutoLatencyDetail;

  /// Settings › Video › Low-latency player: how the player gets back to live after falling behind.
  ///
  /// In en, this message translates to:
  /// **'Live catch-up'**
  String get settingsLiveCatchUp;

  /// Settings › Video › Low-latency player: what the two « Live catch-up » options do. Starts with the options' names (liveCatchUpSpeedUp, liveCatchUpJumpToLive).
  ///
  /// In en, this message translates to:
  /// **'Speed up plays slightly faster until it is back at live (Auto latency does it when on). Jump to live skips ahead after a stall. Applies the next time a stream is opened.'**
  String get settingsLiveCatchUpDetail;

  /// Live catch-up option (Settings › Video): play slightly faster until back at live. Also in the live video stats.
  ///
  /// In en, this message translates to:
  /// **'Speed up'**
  String get liveCatchUpSpeedUp;

  /// Live catch-up option (Settings › Video): skip to live after a stall. Also in the live video stats.
  ///
  /// In en, this message translates to:
  /// **'Jump to live'**
  String get liveCatchUpJumpToLive;

  /// Settings › Video › Low-latency player: how much video the player keeps ahead.
  ///
  /// In en, this message translates to:
  /// **'Buffer profile'**
  String get settingsBufferProfile;

  /// Settings › Video › Low-latency player: what the « Ultra » buffer profile changes.
  ///
  /// In en, this message translates to:
  /// **'Ultra keeps an even smaller buffer for lower latency but may rebuffer more on weak connections. Applies the next time a stream is opened.'**
  String get settingsBufferProfileDetail;

  /// Buffer profile option (Settings › Video): the player's default buffer. Also in the live video stats.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get bufferProfileStandard;

  /// Buffer profile option (Settings › Video): an even smaller buffer. Also in the live video stats.
  ///
  /// In en, this message translates to:
  /// **'Ultra'**
  String get bufferProfileUltra;

  /// Live video stats, « Mode »: auto latency with « Speed up » catch-up.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get playerConfigAuto;

  /// Live video stats, « Mode »: auto latency with « Jump to live » catch-up.
  ///
  /// In en, this message translates to:
  /// **'Jump to live + auto'**
  String get playerConfigJumpToLiveAuto;

  /// Live video stats, « Mode »: the catch-up and the buffer profile, when the player went back to Standard because Ultra kept stalling.
  ///
  /// In en, this message translates to:
  /// **'{mode} · {buffer} (Ultra stalled)'**
  String playerConfigUltraStalled({
    required String mode,
    required String buffer,
  });

  /// Settings › Video: the playback group.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPlayback;

  /// Settings › Video › Playback: the switch that shows the video above the chat.
  ///
  /// In en, this message translates to:
  /// **'Enable video'**
  String get settingsEnableVideo;

  /// Settings › Video › Playback: the switch that starts streams at their best quality.
  ///
  /// In en, this message translates to:
  /// **'Default to highest quality'**
  String get settingsHighestQuality;

  /// Settings › Video › Playback (Android): the switch for the faster WebView rendering.
  ///
  /// In en, this message translates to:
  /// **'Use fast video rendering'**
  String get settingsFastRendering;

  /// Settings › Video › Playback: what « Use fast video rendering » does.
  ///
  /// In en, this message translates to:
  /// **'Uses a faster WebView rendering method. Disable if you experience crashes while watching streams.'**
  String get settingsFastRenderingDetail;

  /// Settings › Video › Playback: the switch that keeps the screen on.
  ///
  /// In en, this message translates to:
  /// **'Keep screen awake'**
  String get settingsKeepAwake;

  /// Settings › Video › Playback: what « Keep screen awake » does.
  ///
  /// In en, this message translates to:
  /// **'Prevents the screen from sleeping while a channel is open.'**
  String get settingsKeepAwakeDetail;

  /// Settings › Video › Playback (Android): the switch that keeps the sound playing outside the app.
  ///
  /// In en, this message translates to:
  /// **'Background audio'**
  String get settingsBackgroundAudio;

  /// Settings › Video › Playback: what « Background audio » does.
  ///
  /// In en, this message translates to:
  /// **'Keeps a live stream playing when you leave the app or turn off the screen, with media controls in a notification.'**
  String get settingsBackgroundAudioDetail;

  /// Settings › Video: the group about the controls drawn over the video.
  ///
  /// In en, this message translates to:
  /// **'Overlay'**
  String get settingsOverlay;

  /// Settings › Video › Overlay: the switch for ONSET's own controls over the video.
  ///
  /// In en, this message translates to:
  /// **'Use custom video overlay'**
  String get settingsCustomOverlay;

  /// Settings › Video › Overlay: what « Use custom video overlay » does.
  ///
  /// In en, this message translates to:
  /// **'Replaces Twitch\'s default web overlay with a mobile-friendly version.'**
  String get settingsCustomOverlayDetail;

  /// Settings › Video › Overlay: the switch that lets a long press on the player switch overlays.
  ///
  /// In en, this message translates to:
  /// **'Long-press player to toggle overlay'**
  String get settingsToggleOverlay;

  /// Settings › Video › Overlay: what the long-press switch does.
  ///
  /// In en, this message translates to:
  /// **'Allows switching between Twitch\'s overlay and the custom overlay.'**
  String get settingsToggleOverlayDetail;

  /// Settings › Video › Overlay: the switch that shows the delay behind live in the player.
  ///
  /// In en, this message translates to:
  /// **'Show latency'**
  String get settingsShowLatency;

  /// Settings › Video › Overlay: what « Show latency » does.
  ///
  /// In en, this message translates to:
  /// **'Displays the stream latency in the video overlay. With the low-latency player, tap it to show live video stats.'**
  String get settingsShowLatencyDetail;

  /// Settings › Video: the group about past broadcasts and mature content.
  ///
  /// In en, this message translates to:
  /// **'Videos and content'**
  String get settingsVideosAndContent;

  /// Settings › Video › Videos and content: when the next video plays by itself.
  ///
  /// In en, this message translates to:
  /// **'Video Autoplaying'**
  String get settingsVodAutoplay;

  /// Settings › Video › Videos and content: the line under the autoplay options.
  ///
  /// In en, this message translates to:
  /// **'Choose when videos should play automatically'**
  String get settingsVodAutoplayDetail;

  /// Video autoplay option (Settings › Video), with Twitch's wording: always.
  ///
  /// In en, this message translates to:
  /// **'Mobile data & Wi-Fi'**
  String get vodAutoplayAlways;

  /// Video autoplay option (Settings › Video): only on Wi-Fi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Only'**
  String get vodAutoplayWifiOnly;

  /// Video autoplay option (Settings › Video): never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get vodAutoplayNever;

  /// Settings › Video › Videos and content: the switch for the mature content warning.
  ///
  /// In en, this message translates to:
  /// **'Warn about mature content'**
  String get settingsWarnMature;

  /// Settings › Video › Videos and content: what the mature content switch does.
  ///
  /// In en, this message translates to:
  /// **'Shows a warning before a channel labeled for mature content.'**
  String get settingsWarnMatureDetail;

  /// Settings › Video (Android): the captions group.
  ///
  /// In en, this message translates to:
  /// **'Captions'**
  String get settingsCaptions;

  /// Settings › Video › Captions: the switch that shows captions.
  ///
  /// In en, this message translates to:
  /// **'Closed Captions'**
  String get settingsClosedCaptions;

  /// Settings › Video › Captions: what the captions switch does.
  ///
  /// In en, this message translates to:
  /// **'Shows captions over live streams and videos that have them. When there are several, pick one in the player menu.'**
  String get settingsClosedCaptionsDetail;

  /// Settings › Video › Captions: the size options.
  ///
  /// In en, this message translates to:
  /// **'Caption size'**
  String get settingsCaptionSize;

  /// Caption size option (Settings › Video › Captions). French: feminine, it agrees with « taille ».
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get captionSizeSmall;

  /// Caption size option.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get captionSizeMedium;

  /// Caption size option.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get captionSizeLarge;

  /// Caption size option.
  ///
  /// In en, this message translates to:
  /// **'Extra large'**
  String get captionSizeExtraLarge;

  /// Settings › Video › Captions: the background options.
  ///
  /// In en, this message translates to:
  /// **'Caption background'**
  String get settingsCaptionBackground;

  /// Caption background option (Settings › Video › Captions). French: masculine, it agrees with « fond ».
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get captionBackgroundBlack;

  /// Caption background option.
  ///
  /// In en, this message translates to:
  /// **'Translucent'**
  String get captionBackgroundTranslucent;

  /// Caption background option.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get captionBackgroundNone;

  /// Settings › Video › Captions: the sample caption drawn with the chosen style.
  ///
  /// In en, this message translates to:
  /// **'This is how captions look.'**
  String get settingsCaptionSample;

  /// Settings › Video › Low-latency player: the row, and the dialog, of the Twitch token that unlocks 2K streams.
  ///
  /// In en, this message translates to:
  /// **'Twitch web token (2K)'**
  String get webTokenTitle;

  /// Settings › Video: the line under « Twitch web token (2K) » when Twitch refused the token.
  ///
  /// In en, this message translates to:
  /// **'Twitch session expired — log in again to restore 2K'**
  String get webTokenExpired;

  /// Settings › Video: the line under « Twitch web token (2K) » when there is none.
  ///
  /// In en, this message translates to:
  /// **'Not set — log in to pick it up automatically'**
  String get webTokenUnset;

  /// Settings › Video: the line under « Twitch web token (2K) » when it is in use.
  ///
  /// In en, this message translates to:
  /// **'Active — picked up automatically, 2K requested'**
  String get webTokenActive;

  /// Settings › Video: the value of « Twitch web token (2K) » when there is none.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get webTokenNotSet;

  /// The Twitch web token dialog: what the token is for, and how to fill it in by hand. "auth-token" is the cookie's name and stays as is.
  ///
  /// In en, this message translates to:
  /// **'Some streams only offer their 2K (1440p HEVC) quality to a signed-in viewer. This is normally picked up on its own when you log in, and refreshed on each launch — you should never need to touch it. Fill it in by hand only if that fails: paste the value of the \"auth-token\" cookie from twitch.tv in a browser.'**
  String get webTokenExplanation;

  /// The Twitch web token dialog: there is one.
  ///
  /// In en, this message translates to:
  /// **'A token is set.'**
  String get webTokenIsSet;

  /// The Twitch web token dialog: there is none.
  ///
  /// In en, this message translates to:
  /// **'No token set.'**
  String get webTokenNoneSet;

  /// The Twitch web token dialog: removes the token.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get webTokenClear;

  /// The Twitch web token dialog: the field's label when a token is already set. "auth-token" is the cookie's name.
  ///
  /// In en, this message translates to:
  /// **'New auth-token'**
  String get webTokenNewField;

  /// The Twitch web token dialog: the hint in the field.
  ///
  /// In en, this message translates to:
  /// **'Paste to replace — never shown'**
  String get webTokenFieldHint;

  /// The Twitch web token dialog: saves the pasted token over the one set.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get webTokenReplace;

  /// The Twitch web token dialog: saves the pasted token.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get webTokenSave;

  /// Settings › Chat: the group of size sliders, with its preview.
  ///
  /// In en, this message translates to:
  /// **'Message sizing'**
  String get settingsMessageSizing;

  /// Settings › Chat › Message sizing: the row that opens a sample of chat drawn with the chosen sizes.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get settingsChatPreview;

  /// Settings › Chat preview: the first sample message, between a badge and an emote.
  ///
  /// In en, this message translates to:
  /// **'Badge and emote preview.'**
  String get settingsChatPreviewBadgeEmote;

  /// Settings › Chat preview: the second sample message.
  ///
  /// In en, this message translates to:
  /// **'Hello! Here\'s a text preview.'**
  String get settingsChatPreviewText;

  /// Settings › Chat preview: the third sample message.
  ///
  /// In en, this message translates to:
  /// **'And another for spacing without an emote!'**
  String get settingsChatPreviewSpacing;

  /// Settings › Chat › Message sizing: the badge size slider.
  ///
  /// In en, this message translates to:
  /// **'Badge scale'**
  String get settingsBadgeScale;

  /// Settings › Chat › Message sizing: the emote size slider.
  ///
  /// In en, this message translates to:
  /// **'Emote scale'**
  String get settingsEmoteScale;

  /// Settings › Chat › Message sizing: the text size slider, as a factor.
  ///
  /// In en, this message translates to:
  /// **'Message scale'**
  String get settingsMessageScale;

  /// Settings › Chat › Message sizing: the value of a scale slider, as a factor (1.00x).
  ///
  /// In en, this message translates to:
  /// **'{scale}x'**
  String settingsScaleValue({required double scale});

  /// Settings › Chat › Message sizing: the space between messages.
  ///
  /// In en, this message translates to:
  /// **'Message spacing'**
  String get settingsMessageSpacing;

  /// Settings › Chat › Message sizing: the value of the spacing slider, in logical pixels.
  ///
  /// In en, this message translates to:
  /// **'{pixels}px'**
  String settingsSpacingValue({required int pixels});

  /// Settings › Chat › Message sizing: the font size slider.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get settingsFontSize;

  /// Settings › Chat: the group about how messages show.
  ///
  /// In en, this message translates to:
  /// **'Message appearance'**
  String get settingsMessageAppearance;

  /// Settings › Chat › Message appearance: the switch that reveals deleted messages.
  ///
  /// In en, this message translates to:
  /// **'Show deleted messages'**
  String get settingsShowDeleted;

  /// Settings › Chat › Message appearance: what « Show deleted messages » does.
  ///
  /// In en, this message translates to:
  /// **'Restores the original message of deleted messages.'**
  String get settingsShowDeletedDetail;

  /// Settings › Chat › Message appearance: the switch that animates emotes.
  ///
  /// In en, this message translates to:
  /// **'Animate emotes'**
  String get settingsAnimateEmotes;

  /// Settings › Chat › Message appearance: what turning « Animate emotes » off does.
  ///
  /// In en, this message translates to:
  /// **'Off shows the first frame of animated emotes in chat.'**
  String get settingsAnimateEmotesDetail;

  /// Settings › Chat › Message appearance: the switch that animates GIFs.
  ///
  /// In en, this message translates to:
  /// **'Animated GIFs'**
  String get settingsAnimatedGifs;

  /// Settings › Chat › Message appearance: what turning « Animated GIFs » off does.
  ///
  /// In en, this message translates to:
  /// **'Off shows the first frame of GIFs sent in chat.'**
  String get settingsAnimatedGifsDetail;

  /// Settings › Chat › Message appearance: the switch that shows GIFs at all.
  ///
  /// In en, this message translates to:
  /// **'Show GIFs in Chat'**
  String get settingsShowGifs;

  /// Settings › Chat › Message appearance: what turning « Show GIFs in Chat » off does.
  ///
  /// In en, this message translates to:
  /// **'Off shows the title of a GIF instead of the GIF.'**
  String get settingsShowGifsDetail;

  /// Settings › Chat › Message appearance: the switch for link cards.
  ///
  /// In en, this message translates to:
  /// **'Preview clips and videos'**
  String get settingsLinkPreviews;

  /// Settings › Chat › Message appearance: what « Preview clips and videos » does.
  ///
  /// In en, this message translates to:
  /// **'Shows a card under messages that link a Twitch clip or video.'**
  String get settingsLinkPreviewsDetail;

  /// Settings › Chat › Message appearance: the switch for moderation lines.
  ///
  /// In en, this message translates to:
  /// **'Show timeouts and bans'**
  String get settingsModerationNotices;

  /// Settings › Chat › Message appearance: what « Show timeouts and bans » does.
  ///
  /// In en, this message translates to:
  /// **'Adds a line when a moderator times out or bans someone.'**
  String get settingsModerationNoticesDetail;

  /// Settings › Chat › Message appearance: the switch for lines between messages.
  ///
  /// In en, this message translates to:
  /// **'Show message dividers'**
  String get settingsMessageDividers;

  /// Settings › Chat › Message appearance: the timestamp options.
  ///
  /// In en, this message translates to:
  /// **'Message timestamps'**
  String get settingsTimestamps;

  /// Message timestamp option (Settings › Chat): none.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get timestampDisabled;

  /// Message timestamp option (Settings › Chat): the 12-hour clock.
  ///
  /// In en, this message translates to:
  /// **'12-hour'**
  String get timestampTwelve;

  /// Message timestamp option (Settings › Chat): the 24-hour clock.
  ///
  /// In en, this message translates to:
  /// **'24-hour'**
  String get timestampTwentyFour;

  /// Settings › Chat: the group about holding messages back to match the video.
  ///
  /// In en, this message translates to:
  /// **'Delay and latency'**
  String get settingsDelayAndLatency;

  /// Settings › Chat › Delay and latency: the switch that delays chat as much as the video is behind live.
  ///
  /// In en, this message translates to:
  /// **'Sync message delay and stream latency'**
  String get settingsSyncDelay;

  /// Settings › Chat › Delay and latency: what the sync switch does.
  ///
  /// In en, this message translates to:
  /// **'Holds each message for as long as the video is behind live, so chat matches what you see. Your own messages show at once.'**
  String get settingsSyncDelayDetail;

  /// Settings › Chat › Delay and latency: the manual delay slider (when sync is off).
  ///
  /// In en, this message translates to:
  /// **'Message delay'**
  String get settingsMessageDelay;

  /// Settings › Chat › Delay and latency: the value of the delay slider.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, other{{seconds} seconds}}'**
  String settingsMessageDelayValue({required int seconds});

  /// Settings › Chat › Delay and latency: what the delay slider does (Android).
  ///
  /// In en, this message translates to:
  /// **'Adds a delay before each message is rendered in chat. '**
  String get settingsMessageDelayDetail;

  /// Settings › Chat › Delay and latency: what the delay slider does, on iOS.
  ///
  /// In en, this message translates to:
  /// **'Adds a delay before each message is rendered in chat. 15 seconds is recommended for iOS.'**
  String get settingsMessageDelayDetailIos;

  /// Settings › Chat: the layout group.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get settingsLayout;

  /// Settings › Chat › Layout: the switch that moves the emote menu button.
  ///
  /// In en, this message translates to:
  /// **'Move emote menu button left'**
  String get settingsEmoteButtonLeft;

  /// Settings › Chat › Layout: what the emote button switch does.
  ///
  /// In en, this message translates to:
  /// **'Places the emote menu button on the left side to avoid accidental presses.'**
  String get settingsEmoteButtonLeftDetail;

  /// Settings › Chat › Layout: the switch that keeps secondary chat tabs.
  ///
  /// In en, this message translates to:
  /// **'Persist chat tabs'**
  String get settingsPersistTabs;

  /// Settings › Chat › Layout: what « Persist chat tabs » does.
  ///
  /// In en, this message translates to:
  /// **'Secondary chat tabs are remembered when switching channels.'**
  String get settingsPersistTabsDetail;

  /// Settings › Chat: the group about highlighted messages and events.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get settingsAlerts;

  /// Settings › Chat › Alerts: the switch that highlights a viewer's first message in a channel.
  ///
  /// In en, this message translates to:
  /// **'Highlight first time chatters'**
  String get settingsFirstTimeChatters;

  /// Settings › Chat › Alerts: the switch for sub, resub, announcement and raid lines.
  ///
  /// In en, this message translates to:
  /// **'Show notices'**
  String get settingsUserNotices;

  /// Settings › Chat › Alerts: what « Show notices » does.
  ///
  /// In en, this message translates to:
  /// **'Shows notices such as subs and re-subs, announcements, and raids.'**
  String get settingsUserNoticesDetail;

  /// Settings › Chat › Alerts: the switch that folds a gift bomb (many gifted subs at once) into one line.
  ///
  /// In en, this message translates to:
  /// **'Collapse gift bombs'**
  String get settingsCollapseGiftBombs;

  /// Settings › Chat › Alerts: what « Collapse gift bombs » does. "recipients" is the link the folded line shows.
  ///
  /// In en, this message translates to:
  /// **'Folds a gift bomb of five subs or more into its first line; tap \"recipients\" to see who got one.'**
  String get settingsCollapseGiftBombsDetail;

  /// Settings › Chat › Alerts: the switch for the Hype Train above chat.
  ///
  /// In en, this message translates to:
  /// **'Show Hype Trains'**
  String get settingsShowHypeTrains;

  /// Settings › Chat › Alerts: what « Show Hype Trains » does.
  ///
  /// In en, this message translates to:
  /// **'Shows Hype Train progress, levels and rewards above chat.'**
  String get settingsShowHypeTrainsDetail;

  /// Settings › Chat › Alerts: the switch for pinned polls, predictions and so on above chat.
  ///
  /// In en, this message translates to:
  /// **'Show community highlights'**
  String get settingsCommunityHighlights;

  /// Settings › Chat › Alerts: what « Show community highlights » does.
  ///
  /// In en, this message translates to:
  /// **'Shows polls, predictions, pinned messages, gift bombs and raids above chat.'**
  String get settingsCommunityHighlightsDetail;

  /// Settings › Chat › Alerts: the switch for the animation when someone gifts subs.
  ///
  /// In en, this message translates to:
  /// **'Show celebrations'**
  String get settingsCelebrations;

  /// Settings › Chat › Alerts: what « Show celebrations » does.
  ///
  /// In en, this message translates to:
  /// **'Plays an animation over the channel when someone gifts subs.'**
  String get settingsCelebrationsDetail;

  /// Settings › Chat › Alerts: how celebrations show (Full or Subtle). Cited by the release notes.
  ///
  /// In en, this message translates to:
  /// **'Celebrations on video'**
  String get settingsCelebrationsOnVideo;

  /// Settings › Chat › Alerts: what the two « Celebrations on video » options do, starting with their names (celebrationsFull, celebrationsSubtle).
  ///
  /// In en, this message translates to:
  /// **'Full plays the animation over the video. Subtle keeps the video clear and says it with a line in chat.'**
  String get settingsCelebrationsOnVideoDetail;

  /// Celebrations on video option (Settings › Chat): the animation plays over the video. French: feminine plural, it agrees with « célébrations ».
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get celebrationsFull;

  /// Celebrations on video option (Settings › Chat): a line in chat instead.
  ///
  /// In en, this message translates to:
  /// **'Subtle'**
  String get celebrationsSubtle;

  /// Settings › Chat: the autocomplete group.
  ///
  /// In en, this message translates to:
  /// **'Autocomplete'**
  String get settingsAutocomplete;

  /// Settings › Chat › Autocomplete: the switch for the suggestion bar.
  ///
  /// In en, this message translates to:
  /// **'Show autocomplete bar'**
  String get settingsAutocompleteBar;

  /// Settings › Chat › Autocomplete: what the suggestion bar switch does.
  ///
  /// In en, this message translates to:
  /// **'Shows a bar containing matching emotes and mentions while typing.'**
  String get settingsAutocompleteBarDetail;

  /// Settings › Chat: the group about the chat beside the video in landscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape mode'**
  String get settingsLandscape;

  /// Settings › Chat › Landscape mode: the switch that puts the chat on the left.
  ///
  /// In en, this message translates to:
  /// **'Move chat left'**
  String get settingsChatLeft;

  /// Settings › Chat › Landscape mode: the switch that keeps the chat under the video.
  ///
  /// In en, this message translates to:
  /// **'Force vertical chat'**
  String get settingsVerticalChat;

  /// Settings › Chat › Landscape mode: what « Force vertical chat » is for.
  ///
  /// In en, this message translates to:
  /// **'Intended for tablets and other larger displays.'**
  String get settingsVerticalChatDetail;

  /// Settings › Chat › Landscape mode: which side of a display notch the app draws into.
  ///
  /// In en, this message translates to:
  /// **'Fill notch side'**
  String get settingsNotchSide;

  /// Settings › Chat › Landscape mode: what « Fill notch side » does.
  ///
  /// In en, this message translates to:
  /// **'Overrides and fills the available space in devices with a display notch.'**
  String get settingsNotchSideDetail;

  /// Fill notch side option (Settings › Chat). French: masculine, it agrees with « côté ».
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get notchSideNone;

  /// Fill notch side option.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get notchSideLeft;

  /// Fill notch side option.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get notchSideRight;

  /// Fill notch side option.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get notchSideBoth;

  /// Settings › Chat › Landscape mode: how opaque the chat drawn over the video is in fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Chat overlay opacity'**
  String get settingsOverlayOpacity;

  /// Settings › Chat › Landscape mode: the value of the chat overlay opacity slider.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String settingsOverlayOpacityValue({required int percent});

  /// Settings › Chat › Landscape mode: what the chat overlay opacity slider does.
  ///
  /// In en, this message translates to:
  /// **'Sets the opacity (transparency) of the overlay chat in fullscreen mode.'**
  String get settingsOverlayOpacityDetail;

  /// Settings › Chat: the group of the chat filters and muted keywords.
  ///
  /// In en, this message translates to:
  /// **'Chat filters and muted keywords'**
  String get settingsFiltersGroup;

  /// Settings › Chat: the value of « Edit Chat Filters » when filtering is on. French: plural, it agrees with « filtres ».
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settingsFiltersOn;

  /// Settings › Chat: the value of « Edit Chat Filters » when filtering is off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsFiltersOff;

  /// Settings › Chat › Chat filters and muted keywords: the switch that only mutes whole words.
  ///
  /// In en, this message translates to:
  /// **'Match whole words'**
  String get settingsWholeWords;

  /// Settings › Chat: what « Match whole words » does.
  ///
  /// In en, this message translates to:
  /// **'Only matches whole words instead of partial matches.'**
  String get settingsWholeWordsDetail;

  /// Settings › Chat: the group of emote and badge providers.
  ///
  /// In en, this message translates to:
  /// **'Emotes and badges'**
  String get settingsEmotesAndBadges;

  /// Settings › Chat › Emotes and badges: a provider switch.
  ///
  /// In en, this message translates to:
  /// **'Show Twitch emotes'**
  String get settingsShowTwitchEmotes;

  /// Settings › Chat › Emotes and badges: a provider switch.
  ///
  /// In en, this message translates to:
  /// **'Show Twitch badges'**
  String get settingsShowTwitchBadges;

  /// Settings › Chat › Emotes and badges: a provider switch.
  ///
  /// In en, this message translates to:
  /// **'Show 7TV emotes'**
  String get settingsShow7tvEmotes;

  /// Settings › Chat › Emotes and badges: a provider switch.
  ///
  /// In en, this message translates to:
  /// **'Show BTTV emotes'**
  String get settingsShowBttvEmotes;

  /// Settings › Chat › Emotes and badges: a provider switch.
  ///
  /// In en, this message translates to:
  /// **'Show BTTV badges'**
  String get settingsShowBttvBadges;

  /// Settings › Chat › Emotes and badges: a provider switch.
  ///
  /// In en, this message translates to:
  /// **'Show FFZ emotes'**
  String get settingsShowFfzEmotes;

  /// Settings › Chat › Emotes and badges: a provider switch.
  ///
  /// In en, this message translates to:
  /// **'Show FFZ badges'**
  String get settingsShowFfzBadges;

  /// Settings › Chat: the group of the fallback chat history.
  ///
  /// In en, this message translates to:
  /// **'Recent messages'**
  String get settingsRecentMessages;

  /// Settings › Chat › Edit Chat Filters: the main switch.
  ///
  /// In en, this message translates to:
  /// **'Enable filtering in chat'**
  String get chatFiltersEnable;

  /// Settings › Chat › Edit Chat Filters: what filtering does.
  ///
  /// In en, this message translates to:
  /// **'Select the filters you would like to block in chat across all channels. In channels you moderate, you will still see all messages.'**
  String get chatFiltersExplanation;

  /// Settings › Chat › Edit Chat Filters: the group of the four filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get chatFiltersGroup;

  /// A chat filter (Twitch's AutoMod category).
  ///
  /// In en, this message translates to:
  /// **'Discrimination'**
  String get chatFilterDiscrimination;

  /// What the Discrimination chat filter hides.
  ///
  /// In en, this message translates to:
  /// **'Negative language about race, gender, orientation, or similar'**
  String get chatFilterDiscriminationDetail;

  /// A chat filter (Twitch's AutoMod category).
  ///
  /// In en, this message translates to:
  /// **'Sexually Explicit Language'**
  String get chatFilterSexual;

  /// What the sexually explicit language chat filter hides.
  ///
  /// In en, this message translates to:
  /// **'References to sexual acts, sexual content, and body parts'**
  String get chatFilterSexualDetail;

  /// A chat filter (Twitch's AutoMod category).
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get chatFilterHarassment;

  /// What the harassment chat filter hides.
  ///
  /// In en, this message translates to:
  /// **'Aggressive or sexually harassing language towards other people'**
  String get chatFilterHarassmentDetail;

  /// A chat filter (Twitch's AutoMod category).
  ///
  /// In en, this message translates to:
  /// **'Profanity'**
  String get chatFilterProfanity;

  /// What the profanity chat filter hides.
  ///
  /// In en, this message translates to:
  /// **'Curse words, expletives, or other obscenities'**
  String get chatFilterProfanityDetail;

  /// Settings › Chat › Edit Chat Filters: the note under the filters.
  ///
  /// In en, this message translates to:
  /// **'Twitch\'s AutoMod rates the words of each live chat message; only words it rates are hidden, so a message it did not rate always shows. Hidden words show as stars: tap them to see the message. Chat replays of past broadcasts are not filtered.'**
  String get chatFiltersNote;

  /// Settings › Chat: the row of the muted keywords, and its list's title.
  ///
  /// In en, this message translates to:
  /// **'Muted keywords'**
  String get mutedKeywordsTitle;

  /// Settings › Chat: the value of « Muted keywords ».
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None} =1{1 keyword} other{{count} keywords}}'**
  String mutedKeywordsCount({required int count});

  /// The muted keywords list: the hint in the field.
  ///
  /// In en, this message translates to:
  /// **'Enter keywords to mute'**
  String get mutedKeywordsHint;

  /// The muted keywords list: the button (and its tooltip) that adds what is typed.
  ///
  /// In en, this message translates to:
  /// **'Add keyword'**
  String get mutedKeywordsAdd;

  /// The muted keywords list when there are none.
  ///
  /// In en, this message translates to:
  /// **'No muted keywords'**
  String get mutedKeywordsEmpty;

  /// The muted keywords list: the tooltip of the cross after a keyword.
  ///
  /// In en, this message translates to:
  /// **'Remove {word}'**
  String mutedKeywordsRemove({required String word});

  /// Snackbar after a muted keyword was removed (with « Undo »).
  ///
  /// In en, this message translates to:
  /// **'Removed \'{word}\''**
  String mutedKeywordsRemoved({required String word});

  /// Snackbar button that undoes what was just done (a muted keyword removed).
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// Settings › Notifications: the go-live group.
  ///
  /// In en, this message translates to:
  /// **'Channels you follow'**
  String get settingsChannelsYouFollow;

  /// Settings › Notifications: the switch that notifies when followed channels go live.
  ///
  /// In en, this message translates to:
  /// **'Go-live notifications'**
  String get goLiveTitle;

  /// Settings › Notifications: the line under « Go-live notifications » where they do not exist.
  ///
  /// In en, this message translates to:
  /// **'Android only.'**
  String get goLiveAndroidOnly;

  /// Settings › Notifications, logged out: the line under « Go-live notifications ».
  ///
  /// In en, this message translates to:
  /// **'Log in to be told when channels you follow go live.'**
  String get goLiveLoggedOut;

  /// Settings › Notifications: the line under « Go-live notifications » when the system blocks them.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked for this app. Allow them in the system settings.'**
  String get goLiveBlocked;

  /// Settings › Notifications: the line under « Go-live notifications » when they are on.
  ///
  /// In en, this message translates to:
  /// **'Checked every 90 seconds while ONSET is open or playing, and about every 15 minutes otherwise, when the system allows. Turn a channel\'s bell off from its menu.'**
  String get goLiveOnDetail;

  /// Settings › Notifications: the line under « Go-live notifications » when they are off.
  ///
  /// In en, this message translates to:
  /// **'Be told when channels you follow go live.'**
  String get goLiveOffDetail;

  /// Settings › Notifications: the line under « Go-live notifications » when Twitch refused the login the background check uses.
  ///
  /// In en, this message translates to:
  /// **'Log in again to get go-live notifications.'**
  String get goLiveLogInAgain;

  /// Settings › Notifications: the line under « Go-live notifications » when its state could not be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the go-live setting.'**
  String get goLiveReadFailed;

  /// Settings › Notifications: the line under « Go-live notifications » when turning them on failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t turn on go-live notifications.'**
  String get goLiveTurnOnFailed;

  /// Settings › Notifications: the line under « Go-live notifications » when turning them off failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t turn off go-live notifications.'**
  String get goLiveTurnOffFailed;

  /// Settings › Notifications: the line under a notification switch when the system permission was refused.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications for this app in the system settings.'**
  String get notificationsAllowInSystem;

  /// Snackbar when a channel's go-live bell could not be changed (the channel's menu).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change the bell.'**
  String get goLiveBellFailed;

  /// A channel's menu (chat user card « More »): the switch for that channel's go-live notifications.
  ///
  /// In en, this message translates to:
  /// **'Notify when {name} goes live'**
  String goLiveBell({required String name});

  /// Settings › Notifications › Chat: the switch for mention notifications.
  ///
  /// In en, this message translates to:
  /// **'Chat mention notifications'**
  String get mentionTitle;

  /// Settings › Notifications › Chat, logged out: the line under the mention switch.
  ///
  /// In en, this message translates to:
  /// **'Log in to be told when someone mentions you in chat.'**
  String get mentionLoggedOut;

  /// Settings › Notifications › Chat: the line under the mention switch when the system blocks notifications (with « Allow »).
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked for this app.'**
  String get mentionBlocked;

  /// Settings › Notifications › Chat: the button that asks the system for the notification permission.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get mentionAllow;

  /// Settings › Notifications › Chat: when mention notifications come.
  ///
  /// In en, this message translates to:
  /// **'When someone mentions you in a chat you are watching while ONSET is in the background or in picture-in-picture.'**
  String get mentionDetail;

  /// Settings › Other: the updates group.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get settingsUpdates;

  /// Settings › Other › Updates: the row that opens the release notes, and their page title.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get settingsReleaseNotes;

  /// Settings › Other › Updates: the note under the rows (builds with in-app updates).
  ///
  /// In en, this message translates to:
  /// **'ONSET looks for a newer build when it starts and when it comes back to the foreground. Release notes open by themselves after an update to a new version.'**
  String get settingsUpdatesNote;

  /// Settings › Other: the storage group.
  ///
  /// In en, this message translates to:
  /// **'Storage and reset'**
  String get settingsStorage;

  /// Settings › Other › Storage and reset: empties the image cache.
  ///
  /// In en, this message translates to:
  /// **'Clear image cache'**
  String get settingsClearCache;

  /// Snackbar after the image cache was emptied.
  ///
  /// In en, this message translates to:
  /// **'Image cache cleared'**
  String get settingsCacheCleared;

  /// Settings › Other › Storage and reset: puts every setting back to its default.
  ///
  /// In en, this message translates to:
  /// **'Reset settings'**
  String get settingsReset;

  /// Title of the dialog that asks before resetting the settings.
  ///
  /// In en, this message translates to:
  /// **'Reset all settings'**
  String get settingsResetTitle;

  /// Text of the dialog that asks before resetting the settings.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all settings?'**
  String get settingsResetMessage;

  /// The button that confirms resetting the settings.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsResetConfirm;

  /// Snackbar after the settings were reset.
  ///
  /// In en, this message translates to:
  /// **'All settings reset'**
  String get settingsResetDone;

  /// Settings › Other: the privacy group.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// Settings › Other: the group with the source code and the licences.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Settings › Other › About: opens ONSET's source code.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get settingsSourceCode;

  /// Settings › Other › About: opens the licences page.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get settingsLicenses;

  /// The notice at the top of the licences page: ONSET's licence, its lack of warranty and where its source is. GNU AGPL-3.0-or-later is the licence's name and stays as is.
  ///
  /// In en, this message translates to:
  /// **'ONSET is free software under the GNU AGPL-3.0-or-later, with NO WARRANTY. Source code: {url}'**
  String settingsLegalese({required String url});

  /// Snackbar after « Check for updates » found nothing newer.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get updatesUpToDate;

  /// Snackbar when « Check for updates » failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates'**
  String get updatesCheckFailed;

  /// Settings › Other › Updates: looks for a newer build now.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updatesCheck;

  /// Settings › Other › Updates: the line under « Check for updates », the installed build number.
  ///
  /// In en, this message translates to:
  /// **'Build {build}'**
  String updatesBuild({required int build});

  /// What a screen reader says for the spinner while looking for updates.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get updatesChecking;

  /// How Following orders its live channels (the sort button): most viewers first.
  ///
  /// In en, this message translates to:
  /// **'Viewers (High to Low)'**
  String get followedSortViewers;

  /// How Following orders its live channels: the most recently started lives first.
  ///
  /// In en, this message translates to:
  /// **'Recently Started'**
  String get followedSortRecent;

  /// How Following orders its live channels: by name.
  ///
  /// In en, this message translates to:
  /// **'Name (A-Z)'**
  String get followedSortName;

  /// How Following orders its live channels: grouped by category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get followedSortCategory;

  /// Release notes: in the line summing up a version (« 2 new · 3 improvements · 1 fix »), its new features.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} new}}'**
  String releaseKindAdded({required int count});

  /// Release notes: in the line summing up a version, its improvements.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} improvement} other{{count} improvements}}'**
  String releaseKindImproved({required int count});

  /// Release notes: in the line summing up a version, its fixes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} fix} other{{count} fixes}}'**
  String releaseKindFixed({required int count});

  /// Release notes: in the line summing up a version, its other changes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} change} other{{count} changes}}'**
  String releaseKindOther({required int count});

  /// Release notes: the small capitals above the latest version (and the title on a tablet when opened from Settings).
  ///
  /// In en, this message translates to:
  /// **'WHAT\'S NEW'**
  String get releaseNotesWhatsNew;

  /// Release notes opened after an update: the small capitals above « Updated to … ». The version is a number such as 1.1.0 (« la » stands for « la version »).
  ///
  /// In en, this message translates to:
  /// **'WHAT\'S NEW IN {version}'**
  String releaseNotesWhatsNewIn({required String version});

  /// Release notes opened after an update: the title. The version is a number such as 1.1.0 (« la » stands for « la version »).
  ///
  /// In en, this message translates to:
  /// **'Updated to {version}'**
  String releaseNotesUpdatedTo({required String version});

  /// Release notes opened after an update (tablet): the version installed before. The version is shown in figures of even width.
  ///
  /// In en, this message translates to:
  /// **'You were on {version}'**
  String releaseNotesWasOn({required String version});

  /// Release notes opened after an update (phone): the version installed before, and what follows. The version is shown in figures of even width.
  ///
  /// In en, this message translates to:
  /// **'You were on {version}. Here is what changed since then.'**
  String releaseNotesWasOnSince({required String version});

  /// Release notes on a phone, opened after an update to an older entry: the heading of the other versions.
  ///
  /// In en, this message translates to:
  /// **'Other versions'**
  String get releaseNotesOtherVersions;

  /// Release notes opened after an update: the button that closes them.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get releaseNotesGotIt;

  /// Release notes on a tablet: the label of the version list.
  ///
  /// In en, this message translates to:
  /// **'Versions'**
  String get releaseNotesVersions;

  /// Release notes: the note at the end of the page.
  ///
  /// In en, this message translates to:
  /// **'Release notes open by themselves after an update to a new version.'**
  String get releaseNotesFootnote;

  /// Release notes: what a screen reader says for the count beside a section's name.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 point} other{{count} points}}'**
  String releaseNotesPoints({required int count});

  /// Release notes: marks the newest version in the list (and what a screen reader says for it). French: feminine, it agrees with « version ».
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get releaseNotesLatest;

  /// Release notes on a tablet: the small badge on the newest version.
  ///
  /// In en, this message translates to:
  /// **'LATEST'**
  String get releaseNotesLatestBadge;

  /// Release notes on a tablet: the button to the next newer version.
  ///
  /// In en, this message translates to:
  /// **'Newer'**
  String get releaseNotesNewer;

  /// Release notes on a tablet: the button to the next older version.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get releaseNotesOlder;

  /// Release notes when there are none.
  ///
  /// In en, this message translates to:
  /// **'No release notes yet'**
  String get releaseNotesEmpty;

  /// Release notes when there are none: the line under « No release notes yet ».
  ///
  /// In en, this message translates to:
  /// **'What changes in each version of ONSET shows up here, and opens by itself after an update.'**
  String get releaseNotesEmptyDetail;

  /// Title of the dialog that asks to let ONSET install its updates (Android).
  ///
  /// In en, this message translates to:
  /// **'Allow updates'**
  String get updateAllowTitle;

  /// Text of the dialog that asks to let ONSET install its updates. "Allow from this source" is the name of the Android switch, in Android's own words.
  ///
  /// In en, this message translates to:
  /// **'Android asks you to let ONSET install apps. Turn on \"Allow from this source\" on the next screen, then come back.'**
  String get updateAllowMessage;

  /// The button that opens the Android setting that lets ONSET install apps.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get updateOpenSettings;

  /// Snackbar when the Android setting was left off.
  ///
  /// In en, this message translates to:
  /// **'ONSET is not allowed to install updates'**
  String get updateNotAllowed;

  /// Snackbar when the downloaded update failed its integrity check.
  ///
  /// In en, this message translates to:
  /// **'The download was corrupted — try again'**
  String get updateCorrupted;

  /// Snackbar when Android refused the update.
  ///
  /// In en, this message translates to:
  /// **'Android could not install the update'**
  String get updateInstallFailed;

  /// Snackbar when the update could not be downloaded.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get updateDownloadFailed;

  /// Update dialog: the build installed now (in a line with the size and the check).
  ///
  /// In en, this message translates to:
  /// **'Installed: build {build}'**
  String updateInstalledBuild({required int build});

  /// Update dialog: the download size, in megabytes.
  ///
  /// In en, this message translates to:
  /// **'{megabytes} MB'**
  String updateSize({required double megabytes});

  /// Update dialog: the download is checked before it is installed.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 checked before install'**
  String get updateChecked;

  /// Update dialog: its title, and what a screen reader calls it.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailable;

  /// Update dialog: the small capitals above the title.
  ///
  /// In en, this message translates to:
  /// **'NEW BUILD'**
  String get updateNewBuild;

  /// Update dialog: the build that can be installed.
  ///
  /// In en, this message translates to:
  /// **'ONSET build {build} is ready.'**
  String updateReady({required int build});

  /// Update dialog: downloads and installs the update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// Update dialog: asks again later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// Title of the update progress dialog while Android installs it.
  ///
  /// In en, this message translates to:
  /// **'Installing update'**
  String get updateInstalling;

  /// Title of the update progress dialog while it downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloading update'**
  String get updateDownloading;

  /// Update progress dialog: how much is downloaded, in megabytes.
  ///
  /// In en, this message translates to:
  /// **'{received} / {total} MB'**
  String updateProgress({required double received, required double total});
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
