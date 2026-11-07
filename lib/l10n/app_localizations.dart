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
  /// **'Log in with Twitch'**
  String get commonConnectWithTwitch;

  /// Settings › General: the title of the first group, the app's language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// Settings › General › Language: the line under the options, saying which language the System option gives on this device. The language is named as in a sentence (languageInTextEnglish, languageInTextFrench).
  ///
  /// In en, this message translates to:
  /// **'“System” follows your device’s language (currently {language}).'**
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
  /// **'ONSET needs your permission to let you chat, see followed streams, and more.'**
  String get onboardingLoginLead;

  /// Onboarding Log in step: header of the permission list (shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'What you’ll authorize'**
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
  /// **'See who’s live right now'**
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
  /// **'Manage blocks and change your name color'**
  String get onboardingPermissionBlocksDetail;

  /// Onboarding Log in step: the note above the buttons (in the content on a tablet).
  ///
  /// In en, this message translates to:
  /// **'ONSET asks only for the permissions it needs, through the official Twitch API. You’ll be able to review them before authorizing.'**
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
  /// **'Logging you in…'**
  String get loginSigningIn;

  /// Onboarding Setup step: the pill when the Twitch login did not go through. Profile is the bottom bar section.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t log in · go back to try again, or log in later from Profile'**
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
  /// **'The ONSET default'**
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
  /// **'{saturation}%, {brightness}%'**
  String accentSaturationBrightnessValue({
    required int saturation,
    required int brightness,
  });

  /// A screen-reader button on the hue slider of the accent colour pickers (eight named hues, 0 to 315).
  ///
  /// In en, this message translates to:
  /// **'{degrees, plural, one{Hue {degrees} degree} other{Hue {degrees} degrees}}'**
  String accentHue({required int degrees});

  /// The switch that loads recent chat messages from a third party (onboarding Setup step, Settings › Chat › Recent messages).
  ///
  /// In en, this message translates to:
  /// **'Fallback chat history (third-party)'**
  String get onboardingSetupHistoryTitle;

  /// Onboarding Setup step: the text under the fallback chat history switch. The link is the third party's host, underlined. Also under the same switch in Settings › Chat › Recent messages.
  ///
  /// In en, this message translates to:
  /// **'When Twitch’s own chat history is unavailable, fails, or is empty, ONSET loads recent messages from {link}, which then receives the channel name.'**
  String onboardingSetupHistoryDetail({required String link});

  /// The crash logs and analytics consent switch (onboarding Setup step, Settings › Other › Privacy).
  ///
  /// In en, this message translates to:
  /// **'Share crash logs and analytics'**
  String get onboardingSetupCrashTitle;

  /// Onboarding Setup step: the text under the crash logs and analytics switch. Also under the same switch in Settings › Other › Privacy.
  ///
  /// In en, this message translates to:
  /// **'Help improve ONSET by sending crash logs and analytics through Firebase. Neither your Twitch account nor your channels are sent.'**
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
  /// **'Check out the GitHub repo (top-right corner of Settings) to explore ONSET’s source code, report bugs, request features, and more.'**
  String get onboardingWelcomeTipGitHub;

  /// Onboarding Welcome step: the second tip. "Other" is the name of a settings page.
  ///
  /// In en, this message translates to:
  /// **'Links to the full changelog and the FAQ are in Settings › Other.'**
  String get onboardingWelcomeTipChangelog;

  /// Onboarding Welcome step: the third tip.
  ///
  /// In en, this message translates to:
  /// **'ONSET checks for new builds by itself, and the release notes open after each update.'**
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
  /// **'If the Twitch cookie banner still blocks the login, tap one of the links in the cookie policy text and keep going until you reach the Twitch home page. From there, log in with the profile icon in the top-right corner. Once you’re logged in, go back to the first step of setup and try again.'**
  String get loginHelpBodyOnboarding;

  /// Text of the login help dialog, opened from the settings (outside the onboarding).
  ///
  /// In en, this message translates to:
  /// **'If the Twitch cookie banner still blocks the login, tap one of the links in the cookie policy text and keep going until you reach the Twitch home page. From there, log in with the profile icon in the top-right corner. Once you’re logged in, go back and open the login page again.'**
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
  /// **'Twitch didn’t log you in. Try again.'**
  String get loginFailedLine;

  /// Error message. Twitch login page: the title when the page could not load.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t reach Twitch.'**
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
  /// **'{count, plural, one{Activity, {count} new} other{Activity, {count} new}}'**
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
  /// **'{count, plural, one{Whispers ({count} unread)} other{Whispers ({count} unread)}}'**
  String shellWhispersUnread({required int count});

  /// Tooltip of the header's whispers button when Twitch refused them until a new login.
  ///
  /// In en, this message translates to:
  /// **'Whispers (log in again to get them)'**
  String get shellWhispersRefused;

  /// What a screen reader says for a header tab with an unread count (Activity: Notifications, Whispers).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{label}, {count} unread} other{{label}, {count} unread}}'**
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
  /// **'Search channels, categories, or videos'**
  String get shellSearchHint;

  /// Tooltip of the header's settings button (on Profile).
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shellSettings;

  /// Error message. Snackbar when a channel opened from Activity could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open {login}’s channel.'**
  String homeOpenChannelFailed({required String login});

  /// Snackbar when a mention notification is tapped while a player or a conversation covers the chat.
  ///
  /// In en, this message translates to:
  /// **'You were mentioned in {login}’s chat.'**
  String mentionNotice({required String login});

  /// Title of the in-app Twitch page opened for a category link Twitch search did not find, when the link has no name.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get deepLinkCategoryFallback;

  /// Error message. Snackbar when a link to Twitch cannot be opened in the app.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open “{uri}”.'**
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
  /// **'Close miniplayer'**
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
  /// **'Theme, stream cards, browsing, and links'**
  String get settingsPageGeneralDescription;

  /// The Video settings page: its row, title and side column entry.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get settingsPageVideo;

  /// Tablet: the line under the Video settings page title.
  ///
  /// In en, this message translates to:
  /// **'Low-latency player, playback, overlay, videos, and captions'**
  String get settingsPageVideoDescription;

  /// The Chat settings page: its row, title and side column entry; also a group of Settings › Notifications.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get settingsPageChat;

  /// Tablet: the line under the Chat settings page title.
  ///
  /// In en, this message translates to:
  /// **'Appearance, delay, alerts, and filters'**
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
  /// **'Updates, storage, privacy, and about'**
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
  /// **'Edit chat filters'**
  String get settingsPageChatFilters;

  /// Profile and phone settings: the line under the General section.
  ///
  /// In en, this message translates to:
  /// **'Theme, accent color, browsing, links'**
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
  /// **'Updates, storage, privacy, about'**
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

  /// Error message. Phone settings account card and Profile, when Twitch cannot be reached (a network problem, not a login).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t connect to Twitch.'**
  String get settingsUnableToReachTwitch;

  /// Under « Unable to connect to Twitch » (phone settings account card, Profile).
  ///
  /// In en, this message translates to:
  /// **'Check your connection, then try again.'**
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
  /// **'Log in to chat, see followed streams, and more.'**
  String get settingsLoginPitch;

  /// Profile, logged out: the note under « Connect with Twitch ».
  ///
  /// In en, this message translates to:
  /// **'ONSET asks only for the permissions it needs, through the official Twitch API. You’ll be able to review them before authorizing.'**
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
  /// **'Password, email, phone, two-factor authentication — on twitch.tv'**
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
  /// **'Are you sure you want to unblock {name}?'**
  String settingsUnblockMessage({required String name});

  /// Title of the dialog that asks before blocking someone (from a channel or a chat user card).
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get settingsBlock;

  /// Text of the dialog that asks before blocking someone.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to block {name}? This removes them from channel lists, search results, and chat messages.'**
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
  /// **'{count, plural, one{{count} blocked} other{{count} blocked}}'**
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
  /// **'Use large stream cards'**
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
  /// **'{count, plural, =0{None} one{{count} label} other{{count} labels}}'**
  String settingsHideLabeledValue({required int count});

  /// The list of content labels to hide: the note under its title.
  ///
  /// In en, this message translates to:
  /// **'Streams with these labels are left out of Live, Live channels, categories, and tags. Followed channels always show.'**
  String get settingsHideLabeledNote;

  /// Twitch's content classification label (Settings › General › Hide labeled streams, the mature content warning).
  ///
  /// In en, this message translates to:
  /// **'Drugs, intoxication, or excessive tobacco use'**
  String get contentLabelDrugs;

  /// Twitch's content classification label.
  ///
  /// In en, this message translates to:
  /// **'Sexual themes'**
  String get contentLabelSexualThemes;

  /// Twitch's content classification label.
  ///
  /// In en, this message translates to:
  /// **'Violent and graphic depictions'**
  String get contentLabelViolentGraphic;

  /// Twitch's content classification label.
  ///
  /// In en, this message translates to:
  /// **'Gambling'**
  String get contentLabelGambling;

  /// Twitch's content classification label.
  ///
  /// In en, this message translates to:
  /// **'Significant profanity or vulgarity'**
  String get contentLabelProfanity;

  /// Twitch's content classification label.
  ///
  /// In en, this message translates to:
  /// **'Mature-rated game'**
  String get contentLabelMatureGame;

  /// Twitch's content classification label.
  ///
  /// In en, this message translates to:
  /// **'Politics and sensitive social issues'**
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
  /// **'Keeps the stream close to live by playing very slightly faster when it falls behind, without reloading it. If Ultra keeps stalling, the next few streams use Standard. Applies the next time you open a stream.'**
  String get settingsAutoLatencyDetail;

  /// Settings › Video › Low-latency player: how the player gets back to live after falling behind.
  ///
  /// In en, this message translates to:
  /// **'Live catch-up'**
  String get settingsLiveCatchUp;

  /// Settings › Video › Low-latency player: what the two « Live catch-up » options do. Starts with the options' names (liveCatchUpSpeedUp, liveCatchUpJumpToLive).
  ///
  /// In en, this message translates to:
  /// **'“Speed up” plays slightly faster until the stream is back to live (Auto latency already does this when it’s on). “Jump to live” skips ahead after a stall. Applies the next time you open a stream.'**
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
  /// **'Ultra keeps a smaller buffer than Standard for lower latency, but may rebuffer more on weak connections. Applies the next time you open a stream.'**
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
  /// **'Uses a faster WebView rendering method. Turn it off if streams crash while you watch.'**
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
  /// **'Replaces Twitch’s default web overlay with a mobile-friendly version.'**
  String get settingsCustomOverlayDetail;

  /// Settings › Video › Overlay: the switch that lets a long press on the player switch overlays.
  ///
  /// In en, this message translates to:
  /// **'Long-press the player to toggle the overlay'**
  String get settingsToggleOverlay;

  /// Settings › Video › Overlay: what the long-press switch does.
  ///
  /// In en, this message translates to:
  /// **'Lets you switch between Twitch’s overlay and the custom overlay.'**
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
  /// **'Autoplay videos'**
  String get settingsVodAutoplay;

  /// Settings › Video › Videos and content: the line under the autoplay options.
  ///
  /// In en, this message translates to:
  /// **'Choose when videos play automatically.'**
  String get settingsVodAutoplayDetail;

  /// Video autoplay option (Settings › Video), with Twitch's wording: always.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi and mobile data'**
  String get vodAutoplayAlways;

  /// Video autoplay option (Settings › Video): only on Wi-Fi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only'**
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
  /// **'Shows a warning before opening a channel labeled for mature content.'**
  String get settingsWarnMatureDetail;

  /// Settings › Video (Android): the captions group.
  ///
  /// In en, this message translates to:
  /// **'Captions'**
  String get settingsCaptions;

  /// Settings › Video › Captions: the switch that shows captions.
  ///
  /// In en, this message translates to:
  /// **'Closed captions'**
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
  /// **'Some streams offer 2K (1440p HEVC) only to logged-in viewers. ONSET normally picks up this token by itself when you log in and refreshes it on each launch, so you should never need to touch it. Fill it in by hand only if that fails: paste the value of the “auth-token” cookie from twitch.tv in a browser.'**
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
  /// **'Hello! Here’s a text preview.'**
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
  /// **'{scale}×'**
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
  /// **'Shows the original text of deleted messages.'**
  String get settingsShowDeletedDetail;

  /// Settings › Chat › Message appearance: the switch that animates emotes.
  ///
  /// In en, this message translates to:
  /// **'Animate emotes'**
  String get settingsAnimateEmotes;

  /// Settings › Chat › Message appearance: what turning « Animate emotes » off does.
  ///
  /// In en, this message translates to:
  /// **'When off, shows only the first frame of animated emotes in chat.'**
  String get settingsAnimateEmotesDetail;

  /// Settings › Chat › Message appearance: the switch that animates GIFs.
  ///
  /// In en, this message translates to:
  /// **'Animated GIFs'**
  String get settingsAnimatedGifs;

  /// Settings › Chat › Message appearance: what turning « Animated GIFs » off does.
  ///
  /// In en, this message translates to:
  /// **'When off, shows only the first frame of GIFs sent in chat.'**
  String get settingsAnimatedGifsDetail;

  /// Settings › Chat › Message appearance: the switch that shows GIFs at all.
  ///
  /// In en, this message translates to:
  /// **'Show GIFs in chat'**
  String get settingsShowGifs;

  /// Settings › Chat › Message appearance: what turning « Show GIFs in chat » off does.
  ///
  /// In en, this message translates to:
  /// **'When off, shows the GIF’s title instead.'**
  String get settingsShowGifsDetail;

  /// Settings › Chat › Message appearance: the switch for link cards.
  ///
  /// In en, this message translates to:
  /// **'Preview clips and videos'**
  String get settingsLinkPreviews;

  /// Settings › Chat › Message appearance: what « Preview clips and videos » does.
  ///
  /// In en, this message translates to:
  /// **'Shows a card under messages that link to a Twitch clip or video.'**
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
  /// **'Holds each message for as long as the video is behind live, so chat matches what you see. Your own messages show right away.'**
  String get settingsSyncDelayDetail;

  /// Settings › Chat › Delay and latency: the manual delay slider (when sync is off).
  ///
  /// In en, this message translates to:
  /// **'Message delay'**
  String get settingsMessageDelay;

  /// Settings › Chat › Delay and latency: the value of the delay slider.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, one{{seconds} second} other{{seconds} seconds}}'**
  String settingsMessageDelayValue({required int seconds});

  /// Settings › Chat › Delay and latency: what the delay slider does (Android).
  ///
  /// In en, this message translates to:
  /// **'Adds a delay before each message appears in chat.'**
  String get settingsMessageDelayDetail;

  /// Settings › Chat › Delay and latency: what the delay slider does, on iOS.
  ///
  /// In en, this message translates to:
  /// **'Adds a delay before each message appears in chat. 15 seconds is recommended on iOS.'**
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
  /// **'Highlight first-time chatters'**
  String get settingsFirstTimeChatters;

  /// Settings › Chat › Alerts: the switch for sub, resub, announcement and raid lines.
  ///
  /// In en, this message translates to:
  /// **'Show notices'**
  String get settingsUserNotices;

  /// Settings › Chat › Alerts: what « Show notices » does.
  ///
  /// In en, this message translates to:
  /// **'Shows notices such as subs, resubs, announcements, and raids.'**
  String get settingsUserNoticesDetail;

  /// Settings › Chat › Alerts: the switch that folds a gift bomb (many gifted subs at once) into one line.
  ///
  /// In en, this message translates to:
  /// **'Collapse gift bombs'**
  String get settingsCollapseGiftBombs;

  /// Settings › Chat › Alerts: what « Collapse gift bombs » does. "recipients" is the link the folded line shows.
  ///
  /// In en, this message translates to:
  /// **'Folds a gift bomb of five subs or more into its first line; tap “recipients” to see who got one.'**
  String get settingsCollapseGiftBombsDetail;

  /// Chat settings switch: hides gift sub lines in chat.
  ///
  /// In en, this message translates to:
  /// **'Hide gift subs'**
  String get settingsHideGiftSubNotices;

  /// Under settingsHideGiftSubNotices.
  ///
  /// In en, this message translates to:
  /// **'Gift subs, community gifts, and sponsored bonus subs no longer show in chat.'**
  String get settingsHideGiftSubNoticesDetail;

  /// Chat settings switch: leaves the gifter’s total out of gift lines.
  ///
  /// In en, this message translates to:
  /// **'Hide gift totals'**
  String get settingsHideGiftCount;

  /// Under settingsHideGiftCount.
  ///
  /// In en, this message translates to:
  /// **'Leaves out how many subs a viewer has gifted in the channel.'**
  String get settingsHideGiftCountDetail;

  /// Settings › Chat › Alerts: the switch for the Hype Train above chat.
  ///
  /// In en, this message translates to:
  /// **'Show Hype Trains'**
  String get settingsShowHypeTrains;

  /// Settings › Chat › Alerts: what « Show Hype Trains » does.
  ///
  /// In en, this message translates to:
  /// **'Shows Hype Train progress, levels, and rewards above chat.'**
  String get settingsShowHypeTrainsDetail;

  /// Settings › Chat › Alerts: the switch for pinned polls, predictions and so on above chat.
  ///
  /// In en, this message translates to:
  /// **'Show community highlights'**
  String get settingsCommunityHighlights;

  /// Settings › Chat › Alerts: what « Show community highlights » does.
  ///
  /// In en, this message translates to:
  /// **'Shows polls, predictions, pinned messages, gift bombs, and raids above chat.'**
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
  /// **'“Full” plays the animation over the video. “Subtle” keeps the video clear and posts a line in chat instead.'**
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
  /// **'Fills the space beside the display notch on devices that have one.'**
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
  /// **'Sets the opacity of the chat overlay in full-screen mode.'**
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
  /// **'Matches whole words only, not parts of words.'**
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
  /// **'Choose what to filter out of chat in every channel. In channels you moderate, you’ll still see every message.'**
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
  /// **'Negative language about race, gender, sexual orientation, or similar'**
  String get chatFilterDiscriminationDetail;

  /// A chat filter (Twitch's AutoMod category).
  ///
  /// In en, this message translates to:
  /// **'Sexually explicit language'**
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
  /// **'Aggressive or sexually harassing language toward other people'**
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
  /// **'Twitch’s AutoMod checks the words of each live chat message and hides only the ones it flags, so a message with no flagged words always shows. Hidden words show as stars: tap them to see the message. Chat replays of past broadcasts aren’t filtered.'**
  String get chatFiltersNote;

  /// Settings › Chat: the row of the muted keywords, and its list's title.
  ///
  /// In en, this message translates to:
  /// **'Muted keywords'**
  String get mutedKeywordsTitle;

  /// Settings › Chat: the value of « Muted keywords ».
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None} one{{count} keyword} other{{count} keywords}}'**
  String mutedKeywordsCount({required int count});

  /// The muted keywords list: the hint in the field, beside its add button on one line (French keeps it short).
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
  /// **'Removed “{word}”'**
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
  /// **'Checked every 90 seconds while ONSET is open or playing, and about every 15 minutes otherwise, when the system allows. Turn a channel’s bell off from its menu.'**
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

  /// Error message. Settings › Notifications: the line under « Go-live notifications » when its state could not be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t read the go-live setting.'**
  String get goLiveReadFailed;

  /// Error message. Settings › Notifications: the line under « Go-live notifications » when turning them on failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t turn on go-live notifications.'**
  String get goLiveTurnOnFailed;

  /// Error message. Settings › Notifications: the line under « Go-live notifications » when turning them off failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t turn off go-live notifications.'**
  String get goLiveTurnOffFailed;

  /// Settings › Notifications: the line under a notification switch when the system permission was refused.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications for this app in the system settings.'**
  String get notificationsAllowInSystem;

  /// Error message. Snackbar when a channel's go-live bell could not be changed (the channel's menu).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t change the bell.'**
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
  /// **'When someone mentions you in a chat you’re watching while ONSET is in the background or in picture-in-picture.'**
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
  /// **'ONSET looks for a newer build when it starts and when it comes back to the foreground. Release notes open automatically after an update.'**
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
  /// **'You’re up to date'**
  String get updatesUpToDate;

  /// Error message. Snackbar when « Check for updates » failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t check for updates.'**
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
  /// **'Checking…'**
  String get updatesChecking;

  /// How Following orders its live channels (the sort button): most viewers first.
  ///
  /// In en, this message translates to:
  /// **'Viewers (high to low)'**
  String get followedSortViewers;

  /// How Following orders its live channels: the most recently started lives first.
  ///
  /// In en, this message translates to:
  /// **'Recently started'**
  String get followedSortRecent;

  /// How Following orders its live channels: by name.
  ///
  /// In en, this message translates to:
  /// **'Name (A–Z)'**
  String get followedSortName;

  /// How Following orders its live channels: grouped by category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get followedSortCategory;

  /// Release notes: in the line summing up a version (« 2 new · 3 improvements · 1 fix »), its new features.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} new} other{{count} new}}'**
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
  /// **'WHAT’S NEW'**
  String get releaseNotesWhatsNew;

  /// Release notes opened after an update: the small capitals above « Updated to … ». The version is a number such as 1.1.0 (« la » stands for « la version »).
  ///
  /// In en, this message translates to:
  /// **'WHAT’S NEW IN {version}'**
  String releaseNotesWhatsNewIn({required String version});

  /// Release notes opened after an update: the title, a fact (the version now installed), never an action. The version is a number such as 1.1.0.
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
  /// **'You were on {version}. Here’s what’s changed since.'**
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
  /// **'Release notes open automatically after an update.'**
  String get releaseNotesFootnote;

  /// Release notes: what a screen reader says for the count beside a section's name.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} point} other{{count} points}}'**
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
  /// **'Changes in each ONSET version appear here and open automatically after an update.'**
  String get releaseNotesEmptyDetail;

  /// Title of the dialog that asks to let ONSET install its updates (Android).
  ///
  /// In en, this message translates to:
  /// **'Allow updates'**
  String get updateAllowTitle;

  /// Text of the dialog that asks to let ONSET install its updates. "Allow from this source" is the name of the Android switch, in Android's own words.
  ///
  /// In en, this message translates to:
  /// **'Android asks you to let ONSET install apps. Turn on “Allow from this source” on the next screen, then come back.'**
  String get updateAllowMessage;

  /// The button that opens the Android setting that lets ONSET install apps.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get updateOpenSettings;

  /// Error message. Snackbar when the Android setting was left off.
  ///
  /// In en, this message translates to:
  /// **'ONSET isn’t allowed to install updates.'**
  String get updateNotAllowed;

  /// Error message. Snackbar when the downloaded update failed its integrity check.
  ///
  /// In en, this message translates to:
  /// **'The download was corrupted. Try again.'**
  String get updateCorrupted;

  /// Error message. Snackbar when Android refused the update.
  ///
  /// In en, this message translates to:
  /// **'Android couldn’t install the update.'**
  String get updateInstallFailed;

  /// Error message. Snackbar when the update could not be downloaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t download the update.'**
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
  /// **'Verified with SHA-256 before installing'**
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
  /// **'Installing update…'**
  String get updateInstalling;

  /// Title of the update progress dialog while it downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get updateDownloading;

  /// Update progress dialog: how much is downloaded, in megabytes.
  ///
  /// In en, this message translates to:
  /// **'{received} / {total} MB'**
  String updateProgress({required double received, required double total});

  /// What a screen reader says for a stream card's preview picture. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'{name} stream preview'**
  String streamPreviewSemantics({required String name});

  /// What a screen reader says a long press does on a stream picture: shows it larger. Lower case (it follows « long press to »).
  ///
  /// In en, this message translates to:
  /// **'enlarge'**
  String get streamEnlargeHint;

  /// A stream's viewers, the number in full (2,445): the cards' line and what a screen reader says for the viewers pill.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} viewer} other{{count} viewers}}'**
  String streamViewers({required int count});

  /// A followed category's viewers, the number short (1.2K): under its box art, and what a screen reader says for its pill.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} viewer} other{{count} viewers}}'**
  String streamViewersCompact({required int count});

  /// How many watch a live, the number in full (2,445 watching): the live preview's line and the large stream card. English has one form.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} watching} other{{count} watching}}'**
  String streamWatching({required int count});

  /// How many watch a live, the number short (2.4k watching), on a channel profile's live card. count chooses the form; viewers is the number as shown.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{viewers} watching} other{{viewers} watching}}'**
  String streamWatchingShort({required int count, required String viewers});

  /// What a screen reader says for the watch streak pill: how many streams in a row the viewer watched.
  ///
  /// In en, this message translates to:
  /// **'Watch Streak {value}'**
  String streamWatchStreakSemantics({required int value});

  /// The watch streak pill on a stream card (and in the large card's line): how many streams in a row the viewer watched. Kept short.
  ///
  /// In en, this message translates to:
  /// **'Streak {value}'**
  String streamStreak({required int value});

  /// A stream card's category line when the stream has none.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get streamNoCategory;

  /// What a screen reader says for a stream's row of tags. tags is the tags, comma-separated (Twitch's data).
  ///
  /// In en, this message translates to:
  /// **'Tags: {tags}'**
  String streamTagsSemantics({required String tags});

  /// What a screen reader says for one tag pill that opens the tag's streams. tag is Twitch's data.
  ///
  /// In en, this message translates to:
  /// **'Tag {tag}'**
  String streamTagSemantics({required String tag});

  /// The large stream card's button that opens the stream.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get streamWatch;

  /// A channel that is not live: the offline channel card's status and the Offline section of Following.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get streamOffline;

  /// Offline channel card: how long the viewer has followed the channel (« Suivie » agrees with « chaîne »).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Following for {count} year} other{Following for {count} years}}'**
  String streamFollowingForYears({required int count});

  /// Offline channel card: how long the viewer has followed the channel, in months.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Following for {count} month} other{Following for {count} months}}'**
  String streamFollowingForMonths({required int count});

  /// Offline channel card: how long the viewer has followed the channel, in days.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Following for {count} day} other{Following for {count} days}}'**
  String streamFollowingForDays({required int count});

  /// Offline channel card: how long the viewer has followed the channel, in hours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Following for {count} hour} other{Following for {count} hours}}'**
  String streamFollowingForHours({required int count});

  /// Offline channel card: how long the viewer has followed the channel, in minutes (0 included).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Following for {count} minute} other{Following for {count} minutes}}'**
  String streamFollowingForMinutes({required int count});

  /// Following: the title of the row of followed categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get followedCategoriesTitle;

  /// Error message. A list could not load because the device has no network: the error shown in its place (Following, Live, categories, followed videos).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t connect to Twitch.'**
  String get apiErrorUnableToConnect;

  /// Error message. A request to Twitch failed: no connection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network.'**
  String get apiErrorNetwork;

  /// Error message. A request to Twitch failed: connecting took too long.
  ///
  /// In en, this message translates to:
  /// **'The connection timed out. Try again.'**
  String get apiErrorConnectionTimeout;

  /// Error message. A request to Twitch failed: sending it took too long.
  ///
  /// In en, this message translates to:
  /// **'Sending took too long. Try again.'**
  String get apiErrorSendTimeout;

  /// Error message. A request to Twitch failed: the answer took too long.
  ///
  /// In en, this message translates to:
  /// **'Twitch took too long to respond. Try again.'**
  String get apiErrorReceiveTimeout;

  /// Error message. A request to Twitch was cancelled.
  ///
  /// In en, this message translates to:
  /// **'The request was canceled.'**
  String get apiErrorCancelled;

  /// Error message. A request to Twitch failed: the server's certificate was refused.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t verify Twitch’s security certificate.'**
  String get apiErrorCertificate;

  /// Error message. A request to Twitch failed for an unknown reason.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get apiErrorUnexpected;

  /// Error message. A request to Twitch was refused as malformed (HTTP 400) and Twitch said nothing more.
  ///
  /// In en, this message translates to:
  /// **'The request wasn’t valid.'**
  String get apiErrorBadRequest;

  /// Error message. A request to Twitch needs the viewer to log in (HTTP 401).
  ///
  /// In en, this message translates to:
  /// **'Log in to continue.'**
  String get apiErrorUnauthorized;

  /// Error message. A request to Twitch was refused for lack of permissions (HTTP 403) and Twitch said nothing more.
  ///
  /// In en, this message translates to:
  /// **'Access denied: missing permissions.'**
  String get apiErrorForbidden;

  /// Error message. What a request to Twitch asked for does not exist (HTTP 404) and Twitch said nothing more.
  ///
  /// In en, this message translates to:
  /// **'This content couldn’t be found.'**
  String get apiErrorNotFound;

  /// Error message. A request to Twitch conflicts with what changed meanwhile (HTTP 409).
  ///
  /// In en, this message translates to:
  /// **'This changed in the meantime. Refresh and try again.'**
  String get apiErrorConflict;

  /// Error message. A request to Twitch carried data it refused (HTTP 422).
  ///
  /// In en, this message translates to:
  /// **'The data sent wasn’t valid.'**
  String get apiErrorInvalid;

  /// Error message. Twitch refused a request: too many in a short time (HTTP 429).
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Wait a moment, then try again.'**
  String get apiErrorRateLimited;

  /// Error message. Twitch's server failed (HTTP 500).
  ///
  /// In en, this message translates to:
  /// **'Twitch had a server error. Try again later.'**
  String get apiErrorServer;

  /// Error message. Twitch's service is down for now (HTTP 502).
  ///
  /// In en, this message translates to:
  /// **'Twitch is temporarily unavailable.'**
  String get apiErrorUnavailable;

  /// Error message. Twitch's service is in maintenance (HTTP 503).
  ///
  /// In en, this message translates to:
  /// **'Twitch is under maintenance. Try again later.'**
  String get apiErrorMaintenance;

  /// Error message. Twitch's server did not answer in time (HTTP 504).
  ///
  /// In en, this message translates to:
  /// **'Twitch’s server didn’t respond. Try again.'**
  String get apiErrorServerTimeout;

  /// Error message. A request to Twitch failed with another HTTP status. status is its number (404, 418...).
  ///
  /// In en, this message translates to:
  /// **'HTTP error {status}.'**
  String apiErrorHttp({required int status});

  /// Error message. No Twitch user has the login asked for: Search › « Go to channel », and other places that open a channel by its name.
  ///
  /// In en, this message translates to:
  /// **'This user doesn’t exist.'**
  String get apiErrorUserNotFound;

  /// Error message. The Twitch user asked for has no channel: Search › « Go to channel ».
  ///
  /// In en, this message translates to:
  /// **'This channel doesn’t exist.'**
  String get apiErrorChannelNotFound;

  /// Error message. A category page whose category Twitch no longer has.
  ///
  /// In en, this message translates to:
  /// **'Category not found.'**
  String get apiErrorCategoryNotFound;

  /// Error message. A list could not load for a viewer not logged in: ONSET's token proxy (its server that gives the app a Twitch token) did not answer in time. French names it « le serveur d’ONSET », plainer than a token proxy.
  ///
  /// In en, this message translates to:
  /// **'The ONSET token service didn’t respond in time.'**
  String get apiErrorTokenProxyTimeout;

  /// A category's or a tag's live streams sorted by viewers, most first (an option of « Sorted by »).
  ///
  /// In en, this message translates to:
  /// **'Viewers (high to low)'**
  String get streamSortViewersHigh;

  /// A category's or a tag's live streams in Twitch's recommended order (an option of « Sorted by »; « Recommandés » agrees with « lives »).
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get streamSortRecommended;

  /// A category's or a tag's live streams sorted by viewers, fewest first (an option of « Sorted by »).
  ///
  /// In en, this message translates to:
  /// **'Viewers (low to high)'**
  String get streamSortViewersLow;

  /// A category's or a tag's live streams, the latest started first (an option of « Sorted by »).
  ///
  /// In en, this message translates to:
  /// **'Recently started'**
  String get streamSortRecent;

  /// Tooltip of the « Sorted by » button above a category's or a tag's live streams.
  ///
  /// In en, this message translates to:
  /// **'Sort streams'**
  String get streamSortTooltip;

  /// Tooltip of the « Sorted by » button beside Following's « Live now ».
  ///
  /// In en, this message translates to:
  /// **'Sort live channels'**
  String get followedSortTooltip;

  /// The button that opens the orders of a live list: the current one. sort is an order's name (streamSortViewersHigh…, followedSortViewers…), shown in bold.
  ///
  /// In en, this message translates to:
  /// **'Sorted by {sort}'**
  String streamSortedBy({required String sort});

  /// Error message. A tag's list of live streams could not load (Twitch's directory failed).
  ///
  /// In en, this message translates to:
  /// **'Streams for this tag aren’t available right now.'**
  String get streamListTagUnavailable;

  /// Error message. A category's live streams could not load in the order picked. sort is that order's name (streamSortRecent…), fallback the order that still works (streamSortViewersHigh).
  ///
  /// In en, this message translates to:
  /// **'Twitch couldn’t sort by {sort}. {fallback} still works.'**
  String streamListSortFailed({required String sort, required String fallback});

  /// Error message. A list of live streams could not load, for an unexpected reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load streams.'**
  String get streamListLoadFailed;

  /// Error message. Following's pinned channels' streams could not load, for an unexpected reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load pinned streams.'**
  String get streamListPinnedFailed;

  /// Error message. Following's offline channels could not load, for an unexpected reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load offline channels.'**
  String get streamListOfflineFailed;

  /// A live list (Live, a category, a tag) left empty because every stream has a content classification the viewer hides (Settings › General).
  ///
  /// In en, this message translates to:
  /// **'Every stream here has a label you hide'**
  String get streamListAllHidden;

  /// Button under « Every stream here has a label you hide » that shows those streams this once.
  ///
  /// In en, this message translates to:
  /// **'Show them'**
  String get streamListShowHidden;

  /// Following, when no followed channel is live.
  ///
  /// In en, this message translates to:
  /// **'No followed streams'**
  String get streamListEmptyFollowed;

  /// Home › Live (Twitch's most watched streams), when it is empty.
  ///
  /// In en, this message translates to:
  /// **'No live streams right now'**
  String get streamListEmptyTop;

  /// A category's or a tag's live streams, when none is live.
  ///
  /// In en, this message translates to:
  /// **'No live streams'**
  String get streamListEmptyLive;

  /// Following: the small capitals above the pinned channels (« Épinglées » agrees with « chaînes »).
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get streamListPinned;

  /// Following: the small capitals above the other live channels, under the pinned ones (« Toutes » agrees with « chaînes »).
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get streamListAll;

  /// Following: the title above the followed channels that are live, with their number.
  ///
  /// In en, this message translates to:
  /// **'Live now'**
  String get streamListLiveNow;

  /// Under a live list: how many streams the viewer's hidden content classifications leave out.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} stream hidden by your content preferences} other{{count} streams hidden by your content preferences}}'**
  String streamListHiddenCount({required int count});

  /// Button beside « 3 streams hidden by your content preferences » that shows them.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get streamListShow;

  /// The newest videos of the followed channels: the tile on Following that opens them, and that page's title.
  ///
  /// In en, this message translates to:
  /// **'Followed videos'**
  String get followedVideosTitle;

  /// Twitch's mature-content warning over a live preview or a player: its title.
  ///
  /// In en, this message translates to:
  /// **'Just one second…'**
  String get contentWarningTitle;

  /// Mature-content warning: the line under its title when the channel's name is not known.
  ///
  /// In en, this message translates to:
  /// **'This content is intended for certain audiences.'**
  String get contentWarningAudience;

  /// Mature-content warning: the line under its title. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'{name}’s content is intended for certain audiences.'**
  String contentWarningAudienceOf({required String name});

  /// Mature-content warning: the channel's content classifications (contentLabel… names, comma-separated).
  ///
  /// In en, this message translates to:
  /// **'It may contain: {labels}'**
  String contentWarningMayContain({required String labels});

  /// Mature-content warning: the button that accepts it and plays.
  ///
  /// In en, this message translates to:
  /// **'Start watching'**
  String get contentWarningStart;

  /// Mature-content warning: the button that declines it and leaves.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get contentWarningBack;

  /// Snackbar after « Not interested » on a live preview (Home › Live). name is the channel's display name; « En direct » is the tab's name (shellFeedLive).
  ///
  /// In en, this message translates to:
  /// **'You won’t see {name} in Live for now.'**
  String liveFeedHidden({required String name});

  /// The snackbar's action that brings back a channel hidden with « Not interested ».
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get liveFeedUndo;

  /// Home › Live: the first chip of the row of categories, every category (« Toutes » agrees with « catégories »).
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get liveFeedAllCategories;

  /// Home › Live: over a channel's picture when its live preview cannot play.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get liveFeedPreviewUnavailable;

  /// What a screen reader says for the pill over a classified channel's picture (Home › Live): a tap shows the warning, then the preview.
  ///
  /// In en, this message translates to:
  /// **'Content warning. Play preview'**
  String get liveFeedContentWarningSemantics;

  /// The pill over a classified channel's picture (Home › Live): a tap shows the content warning, then the preview. One line, ellipsised if long.
  ///
  /// In en, this message translates to:
  /// **'Content warning · Play preview'**
  String get liveFeedContentWarning;

  /// Home › Live: the round button that plays a channel's preview by hand (autoplay off).
  ///
  /// In en, this message translates to:
  /// **'Play preview'**
  String get liveFeedPlayPreview;

  /// Home › Live: the round button that turns a preview's sound on.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get liveFeedUnmute;

  /// Home › Live: the round button that turns a preview's sound off.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get liveFeedMute;

  /// Home › Live: beside the viewers, the preview plays with sound.
  ///
  /// In en, this message translates to:
  /// **'Sound on'**
  String get liveFeedSoundOn;

  /// Home › Live: beside the viewers, the preview plays muted (« Son coupé » pairs with liveFeedSoundOn, « Son activé »).
  ///
  /// In en, this message translates to:
  /// **'Muted preview'**
  String get liveFeedMuted;

  /// Home › Live: the main button that opens the channel (video and chat).
  ///
  /// In en, this message translates to:
  /// **'Watch with chat'**
  String get liveFeedWatchWithChat;

  /// Home › Live: the tooltip of « Follow », which opens the channel on twitch.tv. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'Follow {name} on Twitch'**
  String liveFeedFollowOnTwitch({required String name});

  /// Home › Live: the button that opens the channel on twitch.tv to follow it.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get liveFeedFollow;

  /// What a screen reader says for a channel's preview in Home › Live. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'{name} live preview. Opens the channel'**
  String liveFeedPreviewSemantics({required String name});

  /// What a screen reader says a long press on a preview does (Home › Live, thumbnails off): opens the channel's actions.
  ///
  /// In en, this message translates to:
  /// **'Channel actions'**
  String get liveFeedChannelActions;

  /// Home › Live: the round button that hides a channel from the feed for this session.
  ///
  /// In en, this message translates to:
  /// **'Not interested'**
  String get liveFeedNotInterested;

  /// Home › Live: the round button that shares the channel's link.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get liveFeedShare;

  /// Home › Live, phone: the hint at the bottom of the first preview, in small capitals (written in capitals).
  ///
  /// In en, this message translates to:
  /// **'SWIPE UP FOR THE NEXT STREAM'**
  String get liveFeedSwipeHint;

  /// Home › Live, tablet: the small capitals above the next channels (written in capitals).
  ///
  /// In en, this message translates to:
  /// **'UP NEXT'**
  String get liveFeedUpNext;

  /// Home › Live, tablet: the note under the next channels.
  ///
  /// In en, this message translates to:
  /// **'Swipe up on the preview, or tap a stream in the list. Previews never start with sound.'**
  String get liveFeedUpNextHelp;

  /// Home › Live: the page after the last channel while more load.
  ///
  /// In en, this message translates to:
  /// **'Loading more live channels…'**
  String get liveFeedLoadingMore;

  /// Home › Live: the page after the last channel when there are no more.
  ///
  /// In en, this message translates to:
  /// **'That’s every live channel here for now'**
  String get liveFeedEnd;

  /// Home › Live: the button on the last page that goes back to the first channel.
  ///
  /// In en, this message translates to:
  /// **'Back to the top'**
  String get liveFeedBackToFirst;

  /// Button beside a section's title that opens all of it (search results, continue watching, a channel profile's section, whispers).
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get commonSeeAll;

  /// Search: the first results tab, the best channels and categories (and videos) together. French: « Tout », as in Google's and Android's tabs.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get searchTabTop;

  /// Search: the channels tab, and the title of the channels under « Top ».
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get searchTabChannels;

  /// Search: the categories tab, and the title of the categories under « Top ».
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get searchTabCategories;

  /// Search: the videos tab, and the title of the videos under « Top ».
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get searchTabVideos;

  /// Search: the button that empties the search field, and the one that forgets the search history.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClear;

  /// Search: the field's hint, one line beside the search glyph, about 150 dp wide on a phone beside the Cancel button. The verb alone, whole at every size: the tabs under the field name channels, categories and videos.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// What a screen reader says for « See all » beside a search section. section is its title (searchTabChannels…).
  ///
  /// In en, this message translates to:
  /// **'See all {section}'**
  String searchSeeAllSemantics({required String section});

  /// Search: the title of the past searches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchHistory;

  /// Search: the tooltip of the cross after a past search. query is what was searched.
  ///
  /// In en, this message translates to:
  /// **'Remove {query} from history'**
  String searchRemoveFromHistory({required String query});

  /// Search, before typing: there is no past search.
  ///
  /// In en, this message translates to:
  /// **'No recent searches'**
  String get searchNoHistory;

  /// Error message. Search: the categories could not load (with « Try again »).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load categories.'**
  String get searchCategoriesFailed;

  /// Error message. Search: Twitch answered without categories (with « Try again »).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t get categories.'**
  String get searchCategoriesUnavailable;

  /// Search: no category matches what was typed.
  ///
  /// In en, this message translates to:
  /// **'No matching categories'**
  String get searchNoCategories;

  /// Error message. Snackbar when the channel picked in search results cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t find that channel.'**
  String get searchChannelNotFound;

  /// Error message. Search: the channels could not load (with « Try again »).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load channels.'**
  String get searchChannelsFailed;

  /// Search: the row that opens the channel whose login is exactly what was typed. query is what was typed.
  ///
  /// In en, this message translates to:
  /// **'Go to channel “{query}”'**
  String searchGoToChannel({required String query});

  /// Error message. Search: the videos could not load (with « Try again »).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load videos.'**
  String get searchVideosFailed;

  /// Search: no video matches what was typed.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// Browse: the title above the live channels of all Twitch (Browse › Live channels). where is browseAcrossTwitch, shown lighter.
  ///
  /// In en, this message translates to:
  /// **'Live channels {where}'**
  String browseLiveChannels({required String where});

  /// The lighter end of « Live channels across Twitch » (browseLiveChannels).
  ///
  /// In en, this message translates to:
  /// **'across Twitch'**
  String get browseAcrossTwitch;

  /// Browse › Categories, when Twitch lists none.
  ///
  /// In en, this message translates to:
  /// **'No top categories'**
  String get categoriesEmpty;

  /// Error message. Browse › Categories could not load, for an unexpected reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load categories.'**
  String get categoriesLoadFailed;

  /// Tablet Browse: the title above the rail of Twitch's most watched categories (« Most watched first » follows).
  ///
  /// In en, this message translates to:
  /// **'Top categories'**
  String get categoriesRailTitle;

  /// Tablet Browse: beside « Top categories », how they are ordered (« regardées » agrees with « catégories »).
  ///
  /// In en, this message translates to:
  /// **'Most-watched first'**
  String get categoriesRailNote;

  /// A category's page: the tab of its live streams.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get categorySectionLive;

  /// A category's page: the tab of its videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get categorySectionVideos;

  /// A category's page: the tab of its clips.
  ///
  /// In en, this message translates to:
  /// **'Clips'**
  String get categorySectionClips;

  /// A category's Videos tab, when it has none.
  ///
  /// In en, this message translates to:
  /// **'No videos in this category'**
  String get categoryNoVideos;

  /// A category's page: the small capitals above its name (written in capitals).
  ///
  /// In en, this message translates to:
  /// **'CATEGORY'**
  String get categoryEyebrow;

  /// A category's page: the button that opens the category on twitch.tv to follow it.
  ///
  /// In en, this message translates to:
  /// **'Follow on Twitch'**
  String get categoryFollowOnTwitch;

  /// Followed videos: the section of the videos made today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get followedVideosToday;

  /// Followed videos: the section of the videos made yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get followedVideosYesterday;

  /// Followed videos: the section of the videos made earlier this week.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get followedVideosThisWeek;

  /// Followed videos: the section of the older videos (« anciennes » agrees with « vidéos »).
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get followedVideosOlder;

  /// Followed videos, when the followed channels made none lately.
  ///
  /// In en, this message translates to:
  /// **'No recent videos'**
  String get followedVideosEmpty;

  /// Followed videos: the line under the page's title. One line, ellipsised if long.
  ///
  /// In en, this message translates to:
  /// **'The newest videos from channels you follow'**
  String get followedVideosSubtitle;

  /// Followed videos: the button that loads the list again.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get followedVideosRefresh;

  /// Error message. Followed videos could not load, for an unexpected reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load videos.'**
  String get followedVideosLoadFailed;

  /// Following: the title of the shelf of videos left part-way, and of its full page.
  ///
  /// In en, this message translates to:
  /// **'Continue watching'**
  String get continueWatchingTitle;

  /// Continue watching: where a video was left. time is a position such as 1:02:15.
  ///
  /// In en, this message translates to:
  /// **'Resume at {time}'**
  String continueWatchingResumeAt({required String time});

  /// Continue watching's page, when no video was left part-way.
  ///
  /// In en, this message translates to:
  /// **'Nothing to resume'**
  String get continueWatchingEmpty;

  /// Continue watching: when a video was left, today. Lower case (it follows the channel's name and « · »).
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get savedToday;

  /// Continue watching: when a video was left, yesterday. Lower case.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get savedYesterday;

  /// Continue watching: when a video was left, 2 to 6 days ago. Lower case.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day ago} other{{count} days ago}}'**
  String savedDaysAgo({required int count});

  /// Continue watching: when a video was left, in weeks (abbreviated). Lower case.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} week ago} other{{count} weeks ago}}'**
  String savedWeeksAgo({required int count});

  /// Continue watching: when a video was left, in months (abbreviated in English). Lower case.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} month ago} other{{count} months ago}}'**
  String savedMonthsAgo({required int count});

  /// When a video, clip or notification was made: less than a minute ago. Starts with a capital (lowered inside a sentence, as in « Last live just now »).
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeAgoJustNow;

  /// When a video, clip or notification was made, in minutes. Starts with a capital (lowered inside a sentence).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} minute ago} other{{count} minutes ago}}'**
  String timeAgoMinutes({required int count});

  /// When a video, clip or notification was made, in hours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} hour ago} other{{count} hours ago}}'**
  String timeAgoHours({required int count});

  /// When a video, clip or notification was made: yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get timeAgoYesterday;

  /// When a video, clip or notification was made, in days (2 to 6).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day ago} other{{count} days ago}}'**
  String timeAgoDays({required int count});

  /// When a video, clip or notification was made, in weeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} week ago} other{{count} weeks ago}}'**
  String timeAgoWeeks({required int count});

  /// When a video, clip or notification was made, in months.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} month ago} other{{count} months ago}}'**
  String timeAgoMonths({required int count});

  /// When a video, clip or notification was made, in years.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} year ago} other{{count} years ago}}'**
  String timeAgoYears({required int count});

  /// How many times a video or clip was watched, the number in full (3,104 views).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} view} other{{count} views}}'**
  String videoViews({required int count});

  /// How many times a clip was watched, the number short (248K views).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} view} other{{count} views}}'**
  String videoViewsCompact({required int count});

  /// How many times a video or clip was watched, on a channel profile's Home tab: count chooses the form, views is the number as shown (248k).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{views} view} other{{views} views}}'**
  String videoViewsShort({required int count, required String views});

  /// A clip's title when it has none (clip cards, the clips feed, a clip's page).
  ///
  /// In en, this message translates to:
  /// **'Untitled clip'**
  String get clipUntitled;

  /// What a screen reader says for a clip's video in the clips feed.
  ///
  /// In en, this message translates to:
  /// **'Clip player. Double-tap to play or pause.'**
  String get clipsPlayerSemantics;

  /// Error message. The clips feed: over a clip that cannot play in the app.
  ///
  /// In en, this message translates to:
  /// **'This clip can’t be played here.'**
  String get clipsCannotPlay;

  /// The clips feed: while the next clips load.
  ///
  /// In en, this message translates to:
  /// **'Loading more clips…'**
  String get clipsLoadingMore;

  /// Error message. The clips feed could not load (with « Try again »).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load clips.'**
  String get clipsLoadFailed;

  /// The clips feed, when Twitch has none to show.
  ///
  /// In en, this message translates to:
  /// **'No clips right now'**
  String get clipsEmpty;

  /// The clips feed: the button (and its tooltip) that opens the clip's own page.
  ///
  /// In en, this message translates to:
  /// **'Open clip'**
  String get clipsOpen;

  /// What a screen reader says for the card of the next clip. channel is its channel's name, title its title.
  ///
  /// In en, this message translates to:
  /// **'Next clip, {channel}, {title}'**
  String clipsNextSemantics({required String channel, required String title});

  /// The clips feed: the small capitals above the next clip's title (written in capitals).
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get clipsNext;

  /// The clips feed: the hint shown on the first clip.
  ///
  /// In en, this message translates to:
  /// **'Swipe for the next clip'**
  String get clipsSwipeHint;

  /// Error message. The clips feed: the next clips could not load (with « Try again »).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load more clips.'**
  String get clipsLoadMoreFailed;

  /// The clips feed: after the last clip (Twitch's words).
  ///
  /// In en, this message translates to:
  /// **'That’s all for now! Check out more clips from previous streams.'**
  String get clipsEnd;

  /// Tablet clips feed: the title above the next clips (« Clips » is Home's tab).
  ///
  /// In en, this message translates to:
  /// **'Up next in Clips'**
  String get clipsUpNext;

  /// Tablet clips feed: beside « Up next in Clips ».
  ///
  /// In en, this message translates to:
  /// **'Swipe the video or pick one'**
  String get clipsUpNextHelp;

  /// What a screen reader says for the channel row under a clip: it opens the channel. channel is its name.
  ///
  /// In en, this message translates to:
  /// **'Open {channel}'**
  String clipOpenChannel({required String channel});

  /// What a screen reader says for the channel row under a clip. channel is its name, curator the name of who made the clip.
  ///
  /// In en, this message translates to:
  /// **'Open {channel}, clipped by {curator}'**
  String clipOpenChannelClippedBy({
    required String channel,
    required String curator,
  });

  /// Who made a clip (clip cards, a clip's page). curator is their name; « Créé » agrees with « clip ».
  ///
  /// In en, this message translates to:
  /// **'Clipped by {curator}'**
  String clipClippedBy({required String curator});

  /// A clip's page: the button that opens the whole video at the clip's moment.
  ///
  /// In en, this message translates to:
  /// **'Watch full video'**
  String get clipWatchFullVideo;

  /// A clip's page: the button that copies its link.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get clipCopyLink;

  /// A clip's page: the tooltip of the button that shares its link.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get clipShare;

  /// A channel's or a category's clips, when the period picked has none.
  ///
  /// In en, this message translates to:
  /// **'No clips for this period'**
  String get clipsNoneForPeriod;

  /// Under a channel's or a category's clips when Twitch has more than it lists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Showing the first clip} other{Showing the first {count} clips}}'**
  String clipsShowingTop({required int count});

  /// Error message. A category's clips: the category is not on Twitch.
  ///
  /// In en, this message translates to:
  /// **'Category not found.'**
  String get clipsCategoryNotFound;

  /// Error message. A channel's clips: the channel is not on Twitch.
  ///
  /// In en, this message translates to:
  /// **'Channel not found.'**
  String get clipsChannelNotFound;

  /// Error message. A channel's or a category's clips could not load (with « Try again »).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load clips.'**
  String get clipsListFailed;

  /// A clip's page: the title above the channel's other clips. channel is its name.
  ///
  /// In en, this message translates to:
  /// **'More clips from {channel}'**
  String clipsMoreFrom({required String channel});

  /// Snackbar after copying a clip's link.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get clipLinkCopied;

  /// A clip's player: the label of the action that copies its link.
  ///
  /// In en, this message translates to:
  /// **'Copy clip link'**
  String get clipCopyClipLink;

  /// Error message. A clip's page: its title, channel and views could not load (with « Try again »).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load the clip details.'**
  String get clipDetailsFailed;

  /// A clip's chat replay: the pill saying the messages follow the clip's time. Lower case.
  ///
  /// In en, this message translates to:
  /// **'synced to the clip'**
  String get clipSyncedToClip;

  /// Error message. Over a video's or a clip's player: only the channel's subscribers may watch it. subject is clip or video.
  ///
  /// In en, this message translates to:
  /// **'{subject, select, clip{This clip is available only to subscribers.} other{This video is available only to subscribers.}}'**
  String playbackSubscriberOnly({required String subject});

  /// Error message. Over a video's or a clip's player: it cannot be watched in the viewer's country. subject is clip or video.
  ///
  /// In en, this message translates to:
  /// **'{subject, select, clip{This clip isn’t available in your region.} other{This video isn’t available in your region.}}'**
  String playbackGeoBlocked({required String subject});

  /// Error message. Over a video's or a clip's player: it was deleted. subject is clip or video.
  ///
  /// In en, this message translates to:
  /// **'{subject, select, clip{This clip is no longer available.} other{This video is no longer available.}}'**
  String playbackNotFound({required String subject});

  /// Error message. Over a video's or a clip's player: it could not play (with « Try again »). subject is clip or video.
  ///
  /// In en, this message translates to:
  /// **'{subject, select, clip{Couldn’t play this clip.} other{Couldn’t play this video.}}'**
  String playbackFailed({required String subject});

  /// Under « This video is only available to subscribers. » (the official app's words).
  ///
  /// In en, this message translates to:
  /// **'Subscribe now to watch and support this channel.'**
  String get playbackSubscribeDetail;

  /// A channel's or a category's clips: the chip for the clips of the last 24 hours.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get clipPeriodLastDay;

  /// A channel's or a category's clips: the chip for the clips of the last 7 days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get clipPeriodLastWeek;

  /// A channel's or a category's clips: the chip for the clips of the last 30 days.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get clipPeriodLastMonth;

  /// A channel's or a category's clips: the chip for all the clips ever made.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get clipPeriodAllTime;

  /// A channel's or a category's clips: the chip that orders them by views, most first (« vus » agrees with « clips »).
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get clipSortTop;

  /// A channel's or a category's clips: the chip that orders them by Twitch's trend.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get clipSortTrending;

  /// A channel's profile: the Home tab (its live, next stream, recent broadcasts and clips).
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get profileTabHome;

  /// A channel's profile: the Videos tab.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get profileTabVideos;

  /// A channel's profile: the Clips tab.
  ///
  /// In en, this message translates to:
  /// **'Clips'**
  String get profileTabClips;

  /// A channel's profile: the Schedule tab (Twitch's French word).
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get profileTabSchedule;

  /// A channel's profile: the About tab.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileTabAbout;

  /// Error message. Snackbar when pulling to refresh a channel's profile failed (what was shown stays).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t refresh this channel.'**
  String get profileRefreshFailed;

  /// Error message. Snackbar when a channel's profile cannot open its channel page (its id is not known yet).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open this channel. Check your connection.'**
  String get profileOpenFailed;

  /// A channel's profile: the tooltip of the button that shares its link.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get profileShare;

  /// A channel's profile: the tooltip of the button that opens more actions (block, report…).
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get profileMore;

  /// Error message. A channel's profile could not load (with « Try again »).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load this channel’s profile.'**
  String get profileLoadFailed;

  /// A channel's About tab, when Twitch gave nothing about it.
  ///
  /// In en, this message translates to:
  /// **'No details'**
  String get profileNoDetails;

  /// Error message. A channel's Schedule tab could not load (with « Try again »).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load the schedule.'**
  String get profileScheduleFailed;

  /// Error message. A channel's profile, when the channel is not on Twitch.
  ///
  /// In en, this message translates to:
  /// **'Channel not found.'**
  String get profileNotFound;

  /// A channel's About tab: its followers, the number in full (48,213 followers). Twitch's French word is « followers ».
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} follower} other{{count} followers}}'**
  String profileFollowers({required int count});

  /// A channel's profile header: its followers, the number short (48.2k). count chooses the form; followers is the number as shown.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{followers} follower} other{{followers} followers}}'**
  String profileFollowersShort({required int count, required String followers});

  /// A channel's About tab: when the channel was created, as month and year.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String profileJoined({required DateTime date});

  /// A channel's profile: the channel is a Twitch partner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get profilePartner;

  /// A channel's profile: the channel is a Twitch affiliate (« Affilié », Twitch's French name of the role).
  ///
  /// In en, this message translates to:
  /// **'Affiliate'**
  String get profileAffiliate;

  /// A channel's About tab: its title. name is the channel's display name (French: « de la chaîne » avoids elision before the name).
  ///
  /// In en, this message translates to:
  /// **'About {name}'**
  String profileAboutTitle({required String name});

  /// A channel's About tab, when it has no description.
  ///
  /// In en, this message translates to:
  /// **'No bio yet.'**
  String get profileNoBio;

  /// What a screen reader says for a channel's panel picture when it has no description of its own.
  ///
  /// In en, this message translates to:
  /// **'Panel image'**
  String get profilePanelImage;

  /// Tablet channel profile: the button that opens the live channel.
  ///
  /// In en, this message translates to:
  /// **'Watch live'**
  String get profileWatchLive;

  /// A channel's profile when it is not live: the button that opens the channel's chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get profileChat;

  /// A channel's Home tab, phone: the next scheduled stream's card. time is its start time (14:05).
  ///
  /// In en, this message translates to:
  /// **'Next stream · {time}'**
  String profileNextStreamAt({required String time});

  /// Tablet channel profile: the small capitals above the next scheduled streams.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get profileComingUp;

  /// A channel's Home tab: the title above its latest past broadcasts.
  ///
  /// In en, this message translates to:
  /// **'Recent broadcasts'**
  String get profileRecentBroadcasts;

  /// A channel's Home tab: the title above its most viewed clips.
  ///
  /// In en, this message translates to:
  /// **'Popular clips'**
  String get profilePopularClips;

  /// What a screen reader says for a video's or a clip's picture on a channel's Home tab.
  ///
  /// In en, this message translates to:
  /// **'Thumbnail'**
  String get profileThumbnail;

  /// A video's title when it has none.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get videoUntitled;

  /// A channel's Home tab: the chip on a broadcast still being recorded (the channel is live). Kept short.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get profileRecording;

  /// A channel's Home tab: the chip on a video the viewer watched to the end (« Regardée » agrees with « vidéo »; « Vue » would read as the noun of « 1 vue »). Kept short.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get profileWatched;

  /// A channel's Home tab: before a video's details when only subscribers may watch it.
  ///
  /// In en, this message translates to:
  /// **'Subscribers only'**
  String get profileSubscribersOnly;

  /// A channel's live card when it is offline: when it last streamed. when is a time ago inside a sentence (« 3 days ago », « il y a 3 jours », « just now »).
  ///
  /// In en, this message translates to:
  /// **'Last live {when}'**
  String profileLastLive({required String when});

  /// A channel's live card: the stream is a rerun of a past broadcast.
  ///
  /// In en, this message translates to:
  /// **'Rerun'**
  String get profileRerun;

  /// A channel's live card: the small badge on a rerun's picture, in capitals. Kept short (an 18 dp pill).
  ///
  /// In en, this message translates to:
  /// **'RERUN'**
  String get profileRerunBadge;

  /// What a screen reader says first for a channel's live card while it is live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get profileLive;

  /// A scheduled stream: the button (and tooltip) once a reminder is set; a tap removes it.
  ///
  /// In en, this message translates to:
  /// **'Reminder set'**
  String get profileReminderSet;

  /// A scheduled stream: the button (and tooltip) that sets a notification when it starts (Twitch's « Remind Me »).
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get profileRemindMe;

  /// When a scheduled stream starts: now. Lower case (inside « Next stream now · 14:05 »; French « Prochain live imminent », agreeing with « live »).
  ///
  /// In en, this message translates to:
  /// **'starting now'**
  String get startsNow;

  /// When a scheduled stream starts, in minutes. Lower case (inside « Next stream in 5 minutes · 14:05 »).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{in {count} minute} other{in {count} minutes}}'**
  String startsInMinutes({required int count});

  /// When a scheduled stream starts, in hours. Lower case.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{in {count} hour} other{in {count} hours}}'**
  String startsInHours({required int count});

  /// When a scheduled stream starts, in days. Lower case.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{in {count} day} other{in {count} days}}'**
  String startsInDays({required int count});

  /// Snackbar when a stream reminder cannot be set because the app may not post notifications.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications for this app in the system settings.'**
  String get profileReminderRefused;

  /// Error message. Snackbar when a stream reminder could not be set.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t set the reminder.'**
  String get profileReminderFailed;

  /// A scheduled stream's title when the channel gave none.
  ///
  /// In en, this message translates to:
  /// **'Untitled stream'**
  String get profileStreamUntitled;

  /// A channel's Schedule tab, when it plans none.
  ///
  /// In en, this message translates to:
  /// **'No streams scheduled'**
  String get profileNoSchedule;

  /// A channel's Schedule tab: the next stream. when says how soon (startsInHours…: « in 3 hours », « dans 3 heures »), time when it starts.
  ///
  /// In en, this message translates to:
  /// **'Next stream {when} · {time}'**
  String profileNextStreamIn({required String when, required String time});

  /// A channel's Schedule tab: a scheduled stream the channel cancelled (« Annulé » agrees with « live »).
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get profileCancelled;

  /// A channel's Videos tab: the pill of its past broadcasts.
  ///
  /// In en, this message translates to:
  /// **'Past broadcasts'**
  String get profilePastBroadcasts;

  /// A channel's Videos tab, past broadcasts, when there are none.
  ///
  /// In en, this message translates to:
  /// **'No past broadcasts'**
  String get profileNoPastBroadcasts;

  /// A channel's Videos tab: the pill of its highlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get profileHighlights;

  /// A channel's Videos tab, highlights, when there are none.
  ///
  /// In en, this message translates to:
  /// **'No highlights'**
  String get profileNoHighlights;

  /// A channel's Videos tab: the pill of its uploaded videos.
  ///
  /// In en, this message translates to:
  /// **'Uploads'**
  String get profileUploads;

  /// A channel's Videos tab, uploads, when there are none.
  ///
  /// In en, this message translates to:
  /// **'No uploads'**
  String get profileNoUploads;

  /// Error message. A channel's or a category's videos could not load (with « Try again »).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load videos.'**
  String get videosListFailed;

  /// Under a category's videos when Twitch has more than it lists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Showing the most-viewed video} other{Showing the {count} most-viewed videos}}'**
  String videosShowingMostViewed({required int count});

  /// Under a channel's videos when Twitch has more than it lists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Showing the most recent video} other{Showing the {count} most recent videos}}'**
  String videosShowingMostRecent({required int count});

  /// A video card without a picture yet: Twitch is still processing the video.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get videoProcessing;

  /// A past broadcast's title when it has none (under its player).
  ///
  /// In en, this message translates to:
  /// **'Untitled broadcast'**
  String get videoUntitledBroadcast;

  /// Tablet Activity: the page's title.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityTitle;

  /// Activity: the line saying what the list holds (under the title on a tablet, at the end of the list on a phone).
  ///
  /// In en, this message translates to:
  /// **'Notifications ONSET has shown on this device.'**
  String get activityNote;

  /// Activity: swiping a notification away, and the action of its menu.
  ///
  /// In en, this message translates to:
  /// **'Remove notification'**
  String get activityRemove;

  /// Activity, when there is no notification (Twitch's words).
  ///
  /// In en, this message translates to:
  /// **'Hooray! You’re up to date'**
  String get activityEmpty;

  /// Activity, under « Hooray! You're up to date ».
  ///
  /// In en, this message translates to:
  /// **'Check back soon for alerts about you and the broadcasters you follow.'**
  String get activityEmptyDetail;

  /// Activity: the title of the latest notifications (« Récentes » agrees with « notifications », and pairs with « Plus anciennes »).
  ///
  /// In en, this message translates to:
  /// **'Most recent'**
  String get activityMostRecent;

  /// Activity: the title of the older notifications.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get activityEarlier;

  /// Activity and tablet whispers: the button that marks every item read.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get activityMarkAllRead;

  /// What a screen reader says a long press on a notification does: opens its options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get activityOptions;

  /// What a screen reader says for the dot of an unread notification (« lue » agrees with « notification »).
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get activityUnread;

  /// Tablet Activity: the whispers card, when there are none.
  ///
  /// In en, this message translates to:
  /// **'No whispers yet. Whispers you get while the app is open show up here.'**
  String get activityNoWhispers;

  /// Activity: the category under a go-live notification, like Twitch's.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get activityKindLive;

  /// Activity: the category under a chat mention notification, like Twitch's.
  ///
  /// In en, this message translates to:
  /// **'Chat mentions'**
  String get activityKindMention;

  /// Activity: the category under a stream reminder notification, like Twitch's.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get activityKindReminder;

  /// The whispers page's title, and its card in tablet Activity.
  ///
  /// In en, this message translates to:
  /// **'Whispers'**
  String get whispersTitle;

  /// Whispers: how many are unread (beside the title, and what a screen reader says for the count pill).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} unread} other{{count} unread}}'**
  String whispersUnreadCount({required int count});

  /// Whispers: beside the title when none is unread.
  ///
  /// In en, this message translates to:
  /// **'All read'**
  String get whispersAllRead;

  /// Tablet whispers: the pane before a conversation is opened.
  ///
  /// In en, this message translates to:
  /// **'Choose a conversation'**
  String get whispersChoose;

  /// Whispers, when there are none.
  ///
  /// In en, this message translates to:
  /// **'No whispers yet'**
  String get whispersEmpty;

  /// Whispers, under « No whispers yet ».
  ///
  /// In en, this message translates to:
  /// **'Whispers you get while the app is open show up here.'**
  String get whispersEmptyDetail;

  /// A whisper conversation: the note at its top.
  ///
  /// In en, this message translates to:
  /// **'Twitch keeps no history the app can show, so only this session’s whispers appear here.'**
  String get whisperSessionNote;

  /// A whisper conversation: the hint of the message field. name is the other person's display name.
  ///
  /// In en, this message translates to:
  /// **'Whisper {name}'**
  String whisperHint({required String name});

  /// A whisper conversation: the tooltip of the send button.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get whisperSend;

  /// What a screen reader says for the arrow before the last whisper when the viewer sent it.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get whisperYou;

  /// The action of the banner announcing a new whisper: opens the conversation.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get whisperOpen;

  /// Whispers: the note above the conversations when Twitch refused the app's access to whispers.
  ///
  /// In en, this message translates to:
  /// **'Twitch refused to send your whispers to this app. Log out and log in again to allow them.'**
  String get whisperStatusRefused;

  /// Whispers: the note while the connection that brings them is being restored.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting… whispers will arrive again soon.'**
  String get whisperStatusInterrupted;

  /// Whispers: the note when Twitch is not sending them for now.
  ///
  /// In en, this message translates to:
  /// **'Twitch isn’t sending whispers to this app right now. ONSET will try again when you come back to the app.'**
  String get whisperStatusUnavailable;

  /// Whispers, logged out.
  ///
  /// In en, this message translates to:
  /// **'Log in to get whispers.'**
  String get whisperStatusOff;

  /// A clip's or a video's player: the button (and screen reader action) that goes back 10 seconds.
  ///
  /// In en, this message translates to:
  /// **'Rewind 10 seconds'**
  String get playerBack10;

  /// A clip's or a video's player: the button (and screen reader action) that skips 10 seconds ahead.
  ///
  /// In en, this message translates to:
  /// **'Skip ahead 10 seconds'**
  String get playerForward10;

  /// A video's player: the screen reader action that cycles where the chat replay sits.
  ///
  /// In en, this message translates to:
  /// **'Change chat layout'**
  String get playerChangeChatLayout;

  /// A video's player in full screen: the tooltip of the button that hides the chat over the video.
  ///
  /// In en, this message translates to:
  /// **'Hide chat overlay'**
  String get playerHideChatOverlay;

  /// A video's player in full screen: the tooltip of the button that shows the chat over the video.
  ///
  /// In en, this message translates to:
  /// **'Show chat overlay'**
  String get playerShowChatOverlay;

  /// A clip's player: the tooltip of the loop button while the clip loops.
  ///
  /// In en, this message translates to:
  /// **'Stop looping'**
  String get playerStopLooping;

  /// A clip's player: the tooltip of the button that makes the clip loop.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get playerLoop;

  /// A clip's or a video's player: the tooltip of the button that opens its settings sheet (quality, volume, speed).
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get playerSettings;

  /// A clip's or a video's player: the big button once it ended, which plays it again.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get playerReplay;

  /// A clip's or a video's player: the big button while paused.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerPlay;

  /// A clip's or a video's player: the big button while playing.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerPause;

  /// What a screen reader says for the player's time (1:02 / 3:30). elapsed and total are times such as 1:02.
  ///
  /// In en, this message translates to:
  /// **'Elapsed time {elapsed} of {total}'**
  String playerElapsed({required String elapsed, required String total});

  /// A clip's or a video's player: the tooltip of the button that opens the floating window (Android's French name).
  ///
  /// In en, this message translates to:
  /// **'Picture-in-picture'**
  String get playerPictureInPicture;

  /// A video's player in landscape: the tooltip of the button that shows the whole video.
  ///
  /// In en, this message translates to:
  /// **'Fit to screen'**
  String get playerFitScreen;

  /// A video's player in landscape: the tooltip of the button that fills the screen, cropping the video.
  ///
  /// In en, this message translates to:
  /// **'Fill screen'**
  String get playerFillScreen;

  /// A clip's or a video's player: the tooltip of the full screen button while in full screen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get playerExitFullScreen;

  /// A clip's or a video's player: the tooltip of the button that goes full screen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get playerFullScreen;

  /// A clip's or a video's player: the speed pill's tooltip, and its group in the settings sheet.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playerSpeed;

  /// A video's player settings sheet: the group of qualities.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get playerQuality;

  /// A clip's or a video's player settings sheet: the volume group.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get playerVolume;

  /// A video's player settings sheet: the captions switch's title.
  ///
  /// In en, this message translates to:
  /// **'Closed captions'**
  String get playerCaptions;

  /// A video's player settings sheet: under « Closed Captions ».
  ///
  /// In en, this message translates to:
  /// **'When the video has them'**
  String get playerCaptionsDetail;

  /// A clip's or a video's player: the normal playback speed (« Normale » agrees with « vitesse »).
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get playerSpeedNormal;

  /// What a screen reader calls the surface of a player (live, clip or video).
  ///
  /// In en, this message translates to:
  /// **'Video player'**
  String get playerSemantics;

  /// What a screen reader says a tap on the player does while its controls show. Lower case.
  ///
  /// In en, this message translates to:
  /// **'hide controls'**
  String get playerHideControls;

  /// What a screen reader says a tap on the player does while its controls are hidden. Lower case.
  ///
  /// In en, this message translates to:
  /// **'show controls'**
  String get playerShowControls;

  /// Button that follows the channel on twitch.tv (channel profile header, the video's info bar on a tablet).
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get channelFollow;

  /// The same button once the viewer follows the channel; it opens the channel on twitch.tv. « Suivie » agrees with « chaîne ».
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get channelFollowing;

  /// Tooltip of the Follow button. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'Follow {name} on Twitch'**
  String channelFollowTooltip({required String name});

  /// Tooltip of the Following button: the viewer follows the channel; it opens twitch.tv. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'Following {name} · opens twitch.tv'**
  String channelFollowingTooltip({required String name});

  /// Button that opens the channel's subscription page on twitch.tv (channel profile header, the video's info bar on a tablet), and the title of that page.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get channelSubscribe;

  /// Tooltip of the Subscribe button. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to {name} · opens twitch.tv'**
  String channelSubscribeTooltip({required String name});

  /// What a screen reader says for the channel's picture or name over and under the live video (opens the channel profile), and its tooltip.
  ///
  /// In en, this message translates to:
  /// **'Channel profile'**
  String get channelProfile;

  /// Tooltip of the button over the live video (and in the channel bar) that opens the channel's videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get channelVideos;

  /// Snackbar when the app's player gives up on a stream Twitch refuses and the web player takes over. notice says why (liveRefused…), a full sentence; French puts it after « Passage au lecteur web. ».
  ///
  /// In en, this message translates to:
  /// **'{notice} Switching to the web player.'**
  String channelWebFallback({required String notice});

  /// Over the video while the viewer drags it down: letting go enters picture-in-picture (Android's floating window, « Picture-in-picture » as Android names it in French).
  ///
  /// In en, this message translates to:
  /// **'Swipe down to enter picture-in-picture'**
  String get channelSwipeDownForPip;

  /// What a screen reader calls the handle between the video and the chat in portrait.
  ///
  /// In en, this message translates to:
  /// **'Resize video'**
  String get channelResizeVideo;

  /// What a screen reader says the handle between the video and the chat does.
  ///
  /// In en, this message translates to:
  /// **'Drag to resize the video. Double-tap for full width.'**
  String get channelResizeVideoHint;

  /// How long a live has run, under an hour, in the info row under the video and on a channel profile's live card. Short unit, no plural.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String channelUptimeMinutes({required int minutes});

  /// How long a live has run, from an hour (3 h 12), in the info row under the video and on a channel profile's live card. minutes is two digits.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String channelUptimeHours({required int hours, required String minutes});

  /// A chip under a tablet's video: how many streams in a row the viewer watched on this channel. French keeps the short « Série {value} » of the stream cards (streamStreak), so the number always shows; the screen reader hears the full name (streamWatchStreakSemantics).
  ///
  /// In en, this message translates to:
  /// **'Watch Streak {value}'**
  String channelWatchStreak({required int value});

  /// Tablet channel page, under the video: the heading of the row of other followed channels that are live. Written in capitals.
  ///
  /// In en, this message translates to:
  /// **'ALSO LIVE FROM CHANNELS YOU FOLLOW'**
  String get channelAlsoLive;

  /// The title of the chat column's bar on a tablet's channel page.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get channelChat;

  /// Beside « Chat » on a tablet: the chat is delayed to match the video automatically. Lower case.
  ///
  /// In en, this message translates to:
  /// **'synced to video'**
  String get channelChatSynced;

  /// Beside « Chat » on a tablet: the chat is held back by that many seconds (Settings › Chat › Message delay, « Délai des messages »).
  ///
  /// In en, this message translates to:
  /// **'{seconds}s delay'**
  String channelChatDelay({required int seconds});

  /// Tooltip of the button that opens the chat's settings sheet, in the chat column's bar on a tablet.
  ///
  /// In en, this message translates to:
  /// **'Chat settings'**
  String get channelChatSettings;

  /// Tooltip of the gear over the live video: opens the sheet with the quality, volume, captions and stats.
  ///
  /// In en, this message translates to:
  /// **'Quality and settings'**
  String get livePlayerQualityAndSettings;

  /// Tooltip of the live player's sound button while the sound is on.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get livePlayerMute;

  /// Tooltip of the live player's sound button while it is muted.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get livePlayerUnmute;

  /// Tooltip of the live player's button that reloads the stream.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get livePlayerRefresh;

  /// Tooltip of the live player's full-screen button.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get livePlayerEnterFullScreen;

  /// Tooltip of the live player's full-screen button while in full screen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get livePlayerExitFullScreen;

  /// Tooltip of a tablet's button over the live video that brings the side chat back.
  ///
  /// In en, this message translates to:
  /// **'Show chat'**
  String get livePlayerShowChat;

  /// Tooltip of a tablet's button over the live video that hides the side chat.
  ///
  /// In en, this message translates to:
  /// **'Hide chat'**
  String get livePlayerHideChat;

  /// Tooltip of the live player's rotate button in portrait.
  ///
  /// In en, this message translates to:
  /// **'Enter landscape mode'**
  String get livePlayerEnterLandscape;

  /// Tooltip of the live player's rotate button in landscape.
  ///
  /// In en, this message translates to:
  /// **'Exit landscape mode'**
  String get livePlayerExitLandscape;

  /// Tooltip of the live player's picture-in-picture button (Android's floating window, « Picture-in-picture » in French).
  ///
  /// In en, this message translates to:
  /// **'Enter picture-in-picture'**
  String get livePlayerEnterPip;

  /// Tooltip of the same button on iOS while the video floats.
  ///
  /// In en, this message translates to:
  /// **'Exit picture-in-picture'**
  String get livePlayerExitPip;

  /// The live player's settings sheet: the heading over the list of qualities.
  ///
  /// In en, this message translates to:
  /// **'Stream quality'**
  String get livePlayerStreamQuality;

  /// The quality that plays the sound alone (in the quality list), and the badge over the video while it plays.
  ///
  /// In en, this message translates to:
  /// **'Audio only'**
  String get livePlayerAudioOnly;

  /// The live player's settings sheet: the heading over the stats entries.
  ///
  /// In en, this message translates to:
  /// **'Measurement'**
  String get livePlayerMeasurement;

  /// The live player's settings sheet: shows or hides the stats panel over the video.
  ///
  /// In en, this message translates to:
  /// **'Video stats'**
  String get livePlayerVideoStats;

  /// Under « Video stats »: what the panel shows.
  ///
  /// In en, this message translates to:
  /// **'Latency, buffer, bitrate, and frames over the video'**
  String get livePlayerVideoStatsDetail;

  /// The live player's settings sheet: starts the stats over.
  ///
  /// In en, this message translates to:
  /// **'Reset stats'**
  String get livePlayerResetStats;

  /// Under « Reset stats », one line in the player's settings sheet (French keeps it short).
  ///
  /// In en, this message translates to:
  /// **'Start a new latency measurement'**
  String get livePlayerResetStatsDetail;

  /// Over the live video, before the stream's title, while several channels share one chat. title is the stream's title (Twitch's data).
  ///
  /// In en, this message translates to:
  /// **'Shared chat · {title}'**
  String livePlayerSharedChatTitle({required String title});

  /// Tooltip of how long the live has run, over the video.
  ///
  /// In en, this message translates to:
  /// **'Stream uptime'**
  String get livePlayerUptime;

  /// Tooltip of the viewer count over the video (a tap opens the chatters).
  ///
  /// In en, this message translates to:
  /// **'Viewer count'**
  String get livePlayerViewerCount;

  /// The live player's settings sheet: under « Closed Captions » (playerCaptions).
  ///
  /// In en, this message translates to:
  /// **'When the stream has them'**
  String get liveCaptionsDetail;

  /// A caption track the stream names neither by label nor by language, in the caption list: its place in the list.
  ///
  /// In en, this message translates to:
  /// **'Captions {number}'**
  String liveCaptionsTrack({required int number});

  /// Error message. Why the app's player cannot play a stream (then the web player tries): Twitch keeps it for subscribers. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'{name} is streaming for subscribers only.'**
  String liveRefusedSubscribersOnly({required String name});

  /// Error message. Why the app's player cannot play a stream: Twitch blocks it in the viewer's country.
  ///
  /// In en, this message translates to:
  /// **'This stream is not available in your region.'**
  String get liveRefusedGeoblocked;

  /// Error message. Why the app's player cannot play a stream: the viewer is banned from the channel. name is the channel's display name. French says « votre compte » (masculine) so « banni » never agrees with the viewer.
  ///
  /// In en, this message translates to:
  /// **'You’re banned from {name}’s channel.'**
  String liveRefusedBanned({required String name});

  /// Error message. Why the app's player cannot play a stream: Twitch refused its token, without saying why.
  ///
  /// In en, this message translates to:
  /// **'Twitch won’t play this stream in the low-latency player.'**
  String get liveRefusedUnauthorized;

  /// Error message. Why the app's player cannot play a stream, on a screen whose language is not English: Twitch explained in English (its words stay in the logs).
  ///
  /// In en, this message translates to:
  /// **'Twitch refused this stream.'**
  String get liveRefused;

  /// Error message. Why the app's player cannot play a stream, in English only: Twitch's own explanation follows (a full stop is added when it has none).
  ///
  /// In en, this message translates to:
  /// **'Twitch refused this stream: {reason}'**
  String liveRefusedBecause({required String reason});

  /// A latency in seconds, as the latency pill and the stats panel show it (2.3s). value is the number, with its decimal separator.
  ///
  /// In en, this message translates to:
  /// **'{value}s'**
  String latencySeconds({required String value});

  /// Tooltip of the latency pill over the video (the web player).
  ///
  /// In en, this message translates to:
  /// **'Latency to broadcaster'**
  String get latencyPillTooltip;

  /// Tooltip of the latency pill over the video with the app's player: a tap opens the stats panel.
  ///
  /// In en, this message translates to:
  /// **'Latency to broadcaster · tap for video stats'**
  String get latencyPillTooltipStats;

  /// What a screen reader says for the latency pill. latency is the pill's text (2.3s, or the reconnect progress ↻ 2/5).
  ///
  /// In en, this message translates to:
  /// **'Latency {latency}'**
  String latencyPillSemantics({required String latency});

  /// A bitrate from a million bits per second, in the stats panel. value has one decimal.
  ///
  /// In en, this message translates to:
  /// **'{value} Mbps'**
  String latencyMegabits({required String value});

  /// A bitrate under a million bits per second, in the stats panel.
  ///
  /// In en, this message translates to:
  /// **'{value} kbps'**
  String latencyKilobits({required int value});

  /// Stats panel over the video: the row of the latency to the broadcaster.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get latencyStatsLatency;

  /// Stats panel: the row of the latency's median, 90th percentile and maximum over the last minutes. Kept short.
  ///
  /// In en, this message translates to:
  /// **'Med / p90 / max'**
  String get latencyStatsSpread;

  /// Stats panel: the row of how much video is buffered.
  ///
  /// In en, this message translates to:
  /// **'Buffer'**
  String get latencyStatsBuffer;

  /// Stats panel: the row of the video's bitrate and the network's.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get latencyStatsBitrate;

  /// Stats panel, Bitrate row: the video's bitrate, then the network's measured bandwidth.
  ///
  /// In en, this message translates to:
  /// **'{bitrate} · net {network}'**
  String latencyStatsBitrateValue({
    required String bitrate,
    required String network,
  });

  /// Stats panel: the row of the frame rate and dropped frames.
  ///
  /// In en, this message translates to:
  /// **'Frames'**
  String get latencyStatsFrames;

  /// Stats panel, Frames row: frames per second, then frames dropped out of those decoded (« i/s », images par seconde).
  ///
  /// In en, this message translates to:
  /// **'{fps} fps · {dropped} dropped / {decoded}'**
  String latencyStatsFramesValue({
    required String fps,
    required String dropped,
    required String decoded,
  });

  /// Stats panel: whether the stream has Twitch's low latency.
  ///
  /// In en, this message translates to:
  /// **'Low latency'**
  String get latencyStatsLowLatency;

  /// Stats panel, Low latency row: it is on (« activée » agrees with « latence »). Lower case.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get latencyStatsOn;

  /// Stats panel, Low latency row: it is off. Lower case.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get latencyStatsOff;

  /// Stats panel: the row of the playback rate.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get latencyStatsSpeed;

  /// Stats panel: a playback rate (1.05x). rate has two decimals.
  ///
  /// In en, this message translates to:
  /// **'{rate}×'**
  String latencyStatsRate({required String rate});

  /// Stats panel: the row of the player's setting (Settings › Video), e.g. « Standard · Auto ».
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get latencyStatsMode;

  /// Stats panel: the row of what auto latency (keeping the stream close to live) is doing.
  ///
  /// In en, this message translates to:
  /// **'Auto latency'**
  String get latencyStatsAutoLatency;

  /// Stats panel: the row of the buffer the next streams open with, while Ultra is set aside after stalls.
  ///
  /// In en, this message translates to:
  /// **'Next streams'**
  String get latencyStatsNextStreams;

  /// Stats panel: the row of how long the stream took to start.
  ///
  /// In en, this message translates to:
  /// **'Startup'**
  String get latencyStatsStartup;

  /// Stats panel: the row of how many times playback stopped to buffer.
  ///
  /// In en, this message translates to:
  /// **'Rebuffers'**
  String get latencyStatsRebuffers;

  /// Stats panel: the row of how many times the player jumped back to live.
  ///
  /// In en, this message translates to:
  /// **'Jumps to live'**
  String get latencyStatsLiveJumps;

  /// Stats panel, Auto latency row: off for this stream (« désactivée » agrees with « latence »). Lower case.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get latencyAutoOff;

  /// Stats panel, Auto latency row: what it does (status, a latencyAuto… text), then the latency it aims at.
  ///
  /// In en, this message translates to:
  /// **'{status} · target {latency}'**
  String latencyAutoWithTarget({
    required String status,
    required String latency,
  });

  /// Stats panel, Auto latency row: it gave up for this stream, and why (latencyReason…).
  ///
  /// In en, this message translates to:
  /// **'stopped: {reason}'**
  String latencyAutoStopped({required String reason});

  /// Stats panel, Auto latency row: it may not act now, and why (latencyReason…).
  ///
  /// In en, this message translates to:
  /// **'held: {reason}'**
  String latencyAutoHeld({required String reason});

  /// Stats panel, Auto latency row: it waits for the connection to stay calm.
  ///
  /// In en, this message translates to:
  /// **'waiting for calm'**
  String get latencyAutoSettling;

  /// Stats panel, Auto latency row: the same, with the seconds of calm still needed.
  ///
  /// In en, this message translates to:
  /// **'waiting for calm {seconds}s'**
  String latencyAutoSettlingSeconds({required int seconds});

  /// Stats panel, Auto latency row: close enough to live, playing at normal speed.
  ///
  /// In en, this message translates to:
  /// **'at target'**
  String get latencyAutoSteady;

  /// Stats panel, Auto latency row: playing faster to get back to the target. rate has two decimals.
  ///
  /// In en, this message translates to:
  /// **'catching up {rate}×'**
  String latencyAutoCatchingUp({required String rate});

  /// Stats panel, Auto latency row: playing slightly faster to drain an excessive buffer (« résorption » du tampon). rate has two decimals.
  ///
  /// In en, this message translates to:
  /// **'draining {rate}×'**
  String latencyAutoDraining({required String rate});

  /// The same, with why the normal catch-up does not run (latencyReason…).
  ///
  /// In en, this message translates to:
  /// **'draining {rate}× ({reason})'**
  String latencyAutoDrainingBecause({
    required String rate,
    required String reason,
  });

  /// Stats panel, Auto latency row: why it stopped, when there is no other reason.
  ///
  /// In en, this message translates to:
  /// **'gave up'**
  String get latencyReasonGaveUp;

  /// Stats panel, Auto latency row: why it holds, when there is no other reason.
  ///
  /// In en, this message translates to:
  /// **'waiting'**
  String get latencyReasonHeld;

  /// Why auto latency holds: an ad plays. Lower case.
  ///
  /// In en, this message translates to:
  /// **'ad'**
  String get latencyReasonAd;

  /// Why auto latency holds: the player gave no buffer length. Lower case.
  ///
  /// In en, this message translates to:
  /// **'no buffer reading'**
  String get latencyReasonNoBufferReading;

  /// Why auto latency holds: no latency came with the last tick. Lower case.
  ///
  /// In en, this message translates to:
  /// **'no latency reading'**
  String get latencyReasonNoLatencyReading;

  /// Why auto latency holds: the latency stopped coming during a catch-up. Lower case.
  ///
  /// In en, this message translates to:
  /// **'no latency ticks'**
  String get latencyReasonNoLatencyTicks;

  /// Why auto latency holds or drains: the stream has no low latency. Lower case.
  ///
  /// In en, this message translates to:
  /// **'not a low-latency stream'**
  String get latencyReasonNotLowLatency;

  /// Why auto latency holds: the viewer paused, or a page covers the player. Lower case.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get latencyReasonPaused;

  /// Why auto latency holds: the player reconnects or jumps to live. Lower case.
  ///
  /// In en, this message translates to:
  /// **'reconnecting'**
  String get latencyReasonReconnecting;

  /// Why auto latency holds: the player waits for data. Lower case.
  ///
  /// In en, this message translates to:
  /// **'buffering'**
  String get latencyReasonBuffering;

  /// Why auto latency stopped: the player refused to play faster. Lower case.
  ///
  /// In en, this message translates to:
  /// **'the player refused the rate'**
  String get latencyReasonRateRefused;

  /// Why auto latency stopped: the player did not play at the rate asked for. Lower case.
  ///
  /// In en, this message translates to:
  /// **'the player didn’t keep the rate'**
  String get latencyReasonRateNotKept;

  /// Why auto latency stopped: playing faster kept causing stalls. Lower case.
  ///
  /// In en, this message translates to:
  /// **'stalls after catching up'**
  String get latencyReasonStalls;

  /// Why auto latency stopped: the player stayed fast after normal speed was asked for. rate has two decimals.
  ///
  /// In en, this message translates to:
  /// **'the player stayed at {rate}×'**
  String latencyReasonStuckFast({required String rate});

  /// Why auto latency stopped: the player refused to go back to normal speed. rate is 1.0, with its decimal separator.
  ///
  /// In en, this message translates to:
  /// **'the player didn’t return to {rate}×'**
  String latencyReasonNotBackToNormal({required String rate});

  /// Stats panel, Next streams row: the buffer profile streams open with until that time, because Ultra kept stalling (« Standard », « Ultra » are the profiles' names, Settings › Video).
  ///
  /// In en, this message translates to:
  /// **'Standard until {time} (Ultra stalled)'**
  String latencyBufferFallback({required String time});

  /// The title of the sheet that makes a clip of the live stream.
  ///
  /// In en, this message translates to:
  /// **'Create clip'**
  String get clipCreateTitle;

  /// Tooltip of the clip button under the live video (opens the Create clip sheet). « Clip » is also a verb in English; French names the action, as the sheet's title does.
  ///
  /// In en, this message translates to:
  /// **'Clip'**
  String get clipCreateButton;

  /// Create clip sheet: Twitch is making the clip (« Clipperino » is Twitch's playful word, kept).
  ///
  /// In en, this message translates to:
  /// **'Creating clip…'**
  String get clipCreateGenerating;

  /// Create clip sheet: Twitch is rendering the clip.
  ///
  /// In en, this message translates to:
  /// **'Rendering clip…'**
  String get clipCreateRendering;

  /// Create clip sheet, signed out.
  ///
  /// In en, this message translates to:
  /// **'Log in to create clips.'**
  String get clipCreateLogIn;

  /// Create clip sheet, signed out: the button that opens the Twitch login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get clipCreateLogInAction;

  /// Create clip sheet: the login lacks the clips permission.
  ///
  /// In en, this message translates to:
  /// **'Creating clips needs a permission your Twitch login doesn’t have yet. Reconnect to Twitch to allow it.'**
  String get clipCreateMissingScope;

  /// Create clip sheet: the button that opens the Twitch login again, to grant the clips permission.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to Twitch'**
  String get clipCreateReconnect;

  /// Create clip sheet, once the clip is made: shares its link (French « Partager » alone: the button sits beside « Copier le lien », in half the sheet).
  ///
  /// In en, this message translates to:
  /// **'Share clip'**
  String get clipCreateShare;

  /// Snackbar after « Copy link » in the Create clip sheet.
  ///
  /// In en, this message translates to:
  /// **'Clip link copied'**
  String get clipCreateLinkCopied;

  /// What a screen reader calls the made clip's picture.
  ///
  /// In en, this message translates to:
  /// **'Clip thumbnail'**
  String get clipCreateThumbnail;

  /// Create clip sheet: the row that opens the clip in twitch.tv's clip editor.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get clipCreateEdit;

  /// Under « Edit »: what can be changed there.
  ///
  /// In en, this message translates to:
  /// **'Title and moment, in the twitch.tv clip editor'**
  String get clipCreateEditDetail;

  /// The title of the in-app twitch.tv page of the clip editor.
  ///
  /// In en, this message translates to:
  /// **'Edit clip'**
  String get clipCreateEditorTitle;

  /// Error message. Create clip sheet, failed: the login lacks the permission.
  ///
  /// In en, this message translates to:
  /// **'Your Twitch login doesn’t allow creating clips.'**
  String get clipCreateFailedMissingScope;

  /// Error message. Create clip sheet, failed: Twitch refused for this channel. French says « votre compte » so nothing agrees with the viewer.
  ///
  /// In en, this message translates to:
  /// **'You can’t clip this channel right now: clips may be off or limited to followers or subscribers, or you’re banned or timed out here.'**
  String get clipCreateFailedRestricted;

  /// Error message. Create clip sheet, failed: the channel is offline.
  ///
  /// In en, this message translates to:
  /// **'Only live streams can be clipped.'**
  String get clipCreateFailedOffline;

  /// Error message. Create clip sheet, failed: the channel forbids clips of the current category.
  ///
  /// In en, this message translates to:
  /// **'This channel doesn’t allow clips of this category.'**
  String get clipCreateFailedNotClippable;

  /// Error message. Create clip sheet, failed: too many clips made in a short time.
  ///
  /// In en, this message translates to:
  /// **'Too many clips at once. Try again in a moment.'**
  String get clipCreateFailedRateLimited;

  /// Error message. Create clip sheet, failed for another reason.
  ///
  /// In en, this message translates to:
  /// **'Hmm… something went wrong.'**
  String get clipCreateFailedUnknown;

  /// Tooltip of the cross that hides a card over the video or the chat (community highlights, raids, gift subs).
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get commonHide;

  /// A percentage (50%): a poll's or a prediction's share, the hype train's progress. French puts a narrow no-break space before %.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String commonPercent({required int value});

  /// The name of a celebration's effect (Twitch's channel celebrations), in the chat line it becomes when celebrations on video are Subtle.
  ///
  /// In en, this message translates to:
  /// **'{effect, select, fireworks{Fireworks} rain{Rain} float{Float} flamethrower{Flamethrower} extinctionEvent{Extinction event} other{Sparkles}}'**
  String celebrationEffect({required String effect});

  /// The chat line a celebration becomes when celebrations on video are Subtle (Settings › Chat). effect is celebrationEffect.
  ///
  /// In en, this message translates to:
  /// **'Celebration: {effect}'**
  String celebrationChatLine({required String effect});

  /// The same line for the celebration Twitch plays after gifted subs. effect is celebrationEffect.
  ///
  /// In en, this message translates to:
  /// **'Gifted subs celebration: {effect}'**
  String celebrationChatLineGiftedSubs({required String effect});

  /// The name of a community highlight over the video or the chat: its card's title and the pill that shows the highlights.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, poll{Poll} prediction{Prediction} pinned{Pinned} raid{Raid} giftBomb{Gift subs} incomingRaid{Incoming raid} other{Highlight}}'**
  String highlightKind({required String kind});

  /// What a screen reader says for the pill that announces a new community highlight.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, poll{New poll} prediction{New prediction} pinned{New pinned} raid{New raid} giftBomb{New gift subs} incomingRaid{New incoming raid} other{New highlight}}'**
  String highlightNew({required String kind});

  /// What a screen reader says for the pill that opens the community highlights when there are several. label is the shown one's name (highlightKind).
  ///
  /// In en, this message translates to:
  /// **'{label} and {count, plural, one{{count} more} other{{count} more}}'**
  String highlightAndMore({required String label, required int count});

  /// Tooltip of the arrow that shows the previous community highlight.
  ///
  /// In en, this message translates to:
  /// **'Previous highlight'**
  String get highlightPrevious;

  /// Tooltip of the arrow that shows the next community highlight.
  ///
  /// In en, this message translates to:
  /// **'Next highlight'**
  String get highlightNext;

  /// What a screen reader says for « 2 / 3 » between the arrows of the community highlights.
  ///
  /// In en, this message translates to:
  /// **'Highlight {index} of {count}'**
  String highlightPosition({required int index, required int count});

  /// The title of the in-app twitch.tv chat page opened to vote or predict.
  ///
  /// In en, this message translates to:
  /// **'Twitch chat'**
  String get highlightTwitchChat;

  /// A raid card's channel when its name is not known yet.
  ///
  /// In en, this message translates to:
  /// **'This channel'**
  String get highlightThisChannel;

  /// A poll's or a pinned message's time left (time is m:ss).
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String highlightTimeLeft({required String time});

  /// A poll's total votes, the number short (1.2K).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} vote} other{{count} votes}}'**
  String highlightVotes({required int count});

  /// An ended poll's status.
  ///
  /// In en, this message translates to:
  /// **'Final results'**
  String get highlightFinalResults;

  /// An ended poll, inside what a screen reader says for its card. Lower case.
  ///
  /// In en, this message translates to:
  /// **'final results'**
  String get highlightFinalResultsLower;

  /// What a screen reader says for a poll's leading choice. choice is Twitch's data.
  ///
  /// In en, this message translates to:
  /// **'{choice} leads with {percent} percent'**
  String highlightPollLeads({required String choice, required int percent});

  /// A live poll's button: opens the channel's twitch.tv chat to vote there.
  ///
  /// In en, this message translates to:
  /// **'Vote on Twitch'**
  String get highlightVote;

  /// A prediction's status: viewers can predict.
  ///
  /// In en, this message translates to:
  /// **'Predictions open'**
  String get highlightPredictionsOpen;

  /// A prediction's status: locked, waiting for the outcome.
  ///
  /// In en, this message translates to:
  /// **'Predictions closed'**
  String get highlightPredictionsClosed;

  /// A prediction's status: the broadcaster is choosing the outcome.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the result'**
  String get highlightPredictionWaiting;

  /// A resolved prediction's status.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get highlightPredictionResult;

  /// A canceled prediction's status (« Annulée » agrees with « prédiction »).
  ///
  /// In en, this message translates to:
  /// **'Canceled · points refunded'**
  String get highlightPredictionCanceled;

  /// Inside what a screen reader says for a prediction's card: the winning outcome (Twitch's data). Lower case.
  ///
  /// In en, this message translates to:
  /// **'winner {outcome}'**
  String highlightWinnerLower({required String outcome});

  /// Inside what a screen reader says for a prediction's card: an outcome and its share of the points.
  ///
  /// In en, this message translates to:
  /// **'{outcome} {percent} percent'**
  String highlightOutcomeShare({required String outcome, required int percent});

  /// A live prediction's time left to predict (time is m:ss).
  ///
  /// In en, this message translates to:
  /// **'{time} to predict'**
  String highlightTimeToPredict({required String time});

  /// A resolved prediction's status: the winning outcome (Twitch's data).
  ///
  /// In en, this message translates to:
  /// **'Winner: {outcome}'**
  String highlightWinner({required String outcome});

  /// A live prediction's button: opens the channel's twitch.tv chat to predict there.
  ///
  /// In en, this message translates to:
  /// **'Predict on Twitch'**
  String get highlightPredict;

  /// What a screen reader says for the check beside a prediction's winning outcome.
  ///
  /// In en, this message translates to:
  /// **'Winner'**
  String get highlightWinnerMark;

  /// The channel points on a prediction's outcome, the number short (1.2K).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} point} other{{count} points}}'**
  String highlightPoints({required int count});

  /// How many viewers predicted an outcome, the number short.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} predictor} other{{count} predictors}}'**
  String highlightPredictors({required int count});

  /// The viewer who put the most points on an outcome. name is a display name.
  ///
  /// In en, this message translates to:
  /// **'Top: {name}'**
  String highlightTopPredictor({required String name});

  /// What a screen reader says for a pinned message's card. sender and text are Twitch's data.
  ///
  /// In en, this message translates to:
  /// **'Pinned message from {sender}: {text}'**
  String highlightPinnedFrom({required String sender, required String text});

  /// A pinned message's card: who pinned it. name is a display name.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String highlightPinnedBy({required String name});

  /// A raid's viewers, the number in full, on the raid cards.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} viewer} other{{count} viewers}}'**
  String raidViewers({required int count});

  /// Raid card, after « Stay here »: the viewer stays on the channel. source is its display name.
  ///
  /// In en, this message translates to:
  /// **'You’re staying on {source}'**
  String raidStay({required String source});

  /// Raid card, after « Stay here »: under raidStay. target is the raided channel's name.
  ///
  /// In en, this message translates to:
  /// **'The raid goes to {target} without you'**
  String raidStayDetail({required String target});

  /// Raid card once the raid left (the viewer stayed). target is the raided channel's name.
  ///
  /// In en, this message translates to:
  /// **'The raid left for {target}'**
  String raidLeftFor({required String target});

  /// Raid card once the raid left: how many viewers went. viewers is raidViewers; count chooses the French verb's number.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{viewers} went along} other{{viewers} went along}}'**
  String raidWentAlong({required int count, required String viewers});

  /// Raid card when the broadcaster cancels the raid.
  ///
  /// In en, this message translates to:
  /// **'Raid canceled'**
  String get raidCancelled;

  /// Raid card when the raid is cancelled. source is the channel's name.
  ///
  /// In en, this message translates to:
  /// **'{source} stays live'**
  String raidStaysLive({required String source});

  /// What a screen reader says for a raid card while it counts down. viewers is raidViewers.
  ///
  /// In en, this message translates to:
  /// **'{source} is raiding {target} with {viewers}'**
  String raidRaidingWith({
    required String source,
    required String target,
    required String viewers,
  });

  /// The raid card's line while it counts down; target is drawn bold.
  ///
  /// In en, this message translates to:
  /// **'{source} is raiding {target}'**
  String raidRaiding({required String source, required String target});

  /// Raid card and the overlay over the video while the viewer goes with the raid. target is the raided channel's name.
  ///
  /// In en, this message translates to:
  /// **'Heading to {target}'**
  String raidHeadingTo({required String target});

  /// What a screen reader says for the raid card once the raid left.
  ///
  /// In en, this message translates to:
  /// **'The raid to {target} has left'**
  String raidToHasLeft({required String target});

  /// What a screen reader says for the raid card's « Watch » button.
  ///
  /// In en, this message translates to:
  /// **'Watch {target}'**
  String raidWatchTarget({required String target});

  /// The small label over a raid card's line, in capitals.
  ///
  /// In en, this message translates to:
  /// **'RAID'**
  String get raidBadge;

  /// Raid card while it counts down, when the app follows raids: viewers is raidViewers.
  ///
  /// In en, this message translates to:
  /// **'{viewers} · you go along automatically'**
  String raidGoAlong({required String viewers});

  /// What a screen reader says for the raid card's countdown ring (time is m:ss).
  ///
  /// In en, this message translates to:
  /// **'Leaves in {time}'**
  String raidLeavesIn({required String time});

  /// Raid card: joins the raided channel at once.
  ///
  /// In en, this message translates to:
  /// **'Go now'**
  String get raidGoNow;

  /// What a screen reader says for « Go now ».
  ///
  /// In en, this message translates to:
  /// **'Go to {target} now'**
  String raidGoNowTarget({required String target});

  /// Raid card: stays on this channel instead of following the raid.
  ///
  /// In en, this message translates to:
  /// **'Stay here'**
  String get raidStayHere;

  /// Raid card while the app leaves for the raided channel.
  ///
  /// In en, this message translates to:
  /// **'Heading out…'**
  String get raidHeadingOut;

  /// The pin of an incoming raid over the chat: who raids this channel, with how many viewers (viewers is the number in full); the name is drawn bold.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{name} is raiding with {viewers} viewer} other{{name} is raiding with {viewers} viewers}}'**
  String raidIncoming({
    required int count,
    required String name,
    required String viewers,
  });

  /// The pin of an incoming raid: under who raids.
  ///
  /// In en, this message translates to:
  /// **'Say hi in chat'**
  String get raidSayHi;

  /// The overlay over the video while the viewer goes with a raid: how many viewers go too.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} viewer coming with you} other{{count} viewers coming with you}}'**
  String raidComingWithYou({required int count});

  /// The gift subs pin over the chat: after the gifter's name (drawn apart, bold), what they gift to the community.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{is gifting {count} sub} other{is gifting {count} subs}}'**
  String giftBombGifting({required int count});

  /// What a screen reader says for the gift subs pin. name is the gifter's display name.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{name} is gifting {count} sub} other{{name} is gifting {count} subs}}'**
  String giftBombSemantics({required int count, required String name});

  /// What a screen reader reads as the gift subs pin's value once every sub reached a viewer.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{all {count} handed out} other{all {count} handed out}}'**
  String giftBombAllHandedOut({required int count});

  /// What a screen reader reads as the gift subs pin's value: how many subs reached a viewer so far.
  ///
  /// In en, this message translates to:
  /// **'{received, plural, one{{received} of {count} handed out} other{{received} of {count} handed out}}'**
  String giftBombHandedOutSemantics({
    required int received,
    required int count,
  });

  /// The gift subs pin: how many subs reached a viewer so far. received is that number as shown (it rolls), receivedCount the same number choosing the form.
  ///
  /// In en, this message translates to:
  /// **'{receivedCount, plural, one{{received} of {total} handed out} other{{received} of {total} handed out}}'**
  String giftBombProgress({
    required int receivedCount,
    required String received,
    required int total,
  });

  /// The gift subs pin once every sub reached a viewer.
  ///
  /// In en, this message translates to:
  /// **'{count} of {count} · thanks!'**
  String giftBombDone({required int count});

  /// The Hype Train (Twitch's name, kept in French too): the banner's and the sheet's title.
  ///
  /// In en, this message translates to:
  /// **'Hype Train'**
  String get htTitle;

  /// A hype train's name by its variant (« collectif » for Community: it fits the banner's title, where « communautaire » is cut) (banner, sheet, approaching banner). variant is the train's variant (regular, goldenKappa, treasure, community, mythic).
  ///
  /// In en, this message translates to:
  /// **'{variant, select, goldenKappa{Golden Kappa Train} treasure{Treasure Train} community{Community Train} mythic{Mythic Train} other{Hype Train}}'**
  String htTrainTitle({required String variant});

  /// A hype train's name when several channels run it together. variant is the train's variant (regular, goldenKappa, treasure, community, mythic).
  ///
  /// In en, this message translates to:
  /// **'{variant, select, goldenKappa{Shared Golden Kappa Train} community{Shared Community Train} mythic{Shared Mythic Train} other{Shared Hype Train}}'**
  String htSharedTrainTitle({required String variant});

  /// The hype train's level in its pill (banner, video pill). Kept short.
  ///
  /// In en, this message translates to:
  /// **'LVL {level}'**
  String htLevelShort({required int level});

  /// The hype train banner's default line under its title: subs, gifted subs (« cadeaux ») or Bits. Kept to one line on a phone, as short as the English.
  ///
  /// In en, this message translates to:
  /// **'Sub, gift, or use Bits!'**
  String get htSubtitle;

  /// The hype train banner's line (and the sheet's) at the last level.
  ///
  /// In en, this message translates to:
  /// **'Final level!'**
  String get htFinalLevel;

  /// The hype train banner's line when the train nears the channel's all-time record.
  ///
  /// In en, this message translates to:
  /// **'About to beat the channel’s record. Keep up the support.'**
  String get htAthApproaching;

  /// The same line where little room is left.
  ///
  /// In en, this message translates to:
  /// **'About to beat the channel’s record.'**
  String get htAthApproachingCompact;

  /// The hype train banner's line once the train beats the channel's record.
  ///
  /// In en, this message translates to:
  /// **'Setting a new record! Keep going until the clock runs out.'**
  String get htAthReached;

  /// The same line for a shared train.
  ///
  /// In en, this message translates to:
  /// **'Setting a new shared record! Keep going until the clock runs out.'**
  String get htAthReachedShared;

  /// A treasure train's banner line before its discount unlocks (the banner has room for one line: as short as the English).
  ///
  /// In en, this message translates to:
  /// **'Reach level {level} to unlock {discount}% off gift subs!'**
  String htTreasureLocked({required int level, required int discount});

  /// A treasure train's banner line once its discount is unlocked (as short as the English).
  ///
  /// In en, this message translates to:
  /// **'{discount}% off 5+ gift subs for the rest of this Hype Train'**
  String htTreasureUnlockedSubtitle({required int discount});

  /// A community train's banner line (and step) before chat's emotes unlock.
  ///
  /// In en, this message translates to:
  /// **'Hit level {level} and chat will receive emotes too!'**
  String htCommunityLocked({required int level});

  /// A community train's banner line once emotes for chat are unlocked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} emote for chat} other{{count} emotes for chat}}'**
  String htCommunityUnlockedSubtitle({required int count});

  /// The hype train banner's announcement when a level completes.
  ///
  /// In en, this message translates to:
  /// **'Level {level} complete!'**
  String htLevelComplete({required int level});

  /// The marquee when a hype train starts (three emotes follow it). variant is the train's variant (regular, goldenKappa, treasure, community, mythic).
  ///
  /// In en, this message translates to:
  /// **'{variant, select, goldenKappa{Golden Kappa Train starting!} treasure{Treasure Train incoming!} community{Community Train incoming!} mythic{Mythic Train incoming!} other{Hype Train starting!}}'**
  String htStarted({required String variant});

  /// The marquee when a shared hype train starts. variant is the train's variant (regular, goldenKappa, treasure, community, mythic).
  ///
  /// In en, this message translates to:
  /// **'{variant, select, goldenKappa{Shared Golden Kappa Train starting!} other{Shared Hype Train starting!}}'**
  String htSharedStarted({required String variant});

  /// The marquee when the hype train levels up: a cheer, the same in French.
  ///
  /// In en, this message translates to:
  /// **'hyyyyypeeee'**
  String get htLevelUp;

  /// The marquee when a hype train ends with a level completed. variant is the train's variant (regular, goldenKappa, treasure, community, mythic).
  ///
  /// In en, this message translates to:
  /// **'{variant, select, goldenKappa{Golden Kappa Train success!} treasure{Treasure Train success!} community{Community Train success!} mythic{Mythic Train success!} other{Hype Train success!}}'**
  String htCompleted({required String variant});

  /// The same marquee for a shared train. variant is the train's variant (regular, goldenKappa, treasure, community, mythic).
  ///
  /// In en, this message translates to:
  /// **'{variant, select, goldenKappa{Shared Golden Kappa Train success!} other{Shared Hype Train success!}}'**
  String htSharedCompleted({required String variant});

  /// The marquee when a treasure train's discount unlocks. Written in capitals.
  ///
  /// In en, this message translates to:
  /// **'TREASURE TRAIN UNLOCKED!'**
  String get htTreasureUnlockedMarquee;

  /// The marquee when a community train's emotes for chat unlock. Written in capitals.
  ///
  /// In en, this message translates to:
  /// **'COMMUNITY REWARDS UNLOCKED!'**
  String get htCommunityUnlockedMarquee;

  /// The announcement when two channels' hype trains merge into a shared one.
  ///
  /// In en, this message translates to:
  /// **'Get excited! Your powers are combining and levels are getting a boost!'**
  String get htMerging;

  /// The hype train's summary at its end, after beating the channel's record: two lines (keep the line break).
  ///
  /// In en, this message translates to:
  /// **'All-time record shattered!\nYou’ve reached new levels of support!'**
  String get htSummaryRecord;

  /// The hype train's summary at its end: two lines (keep the line break), the cheer then the last level completed. variant is the train's variant (regular, goldenKappa, treasure, community, mythic).
  ///
  /// In en, this message translates to:
  /// **'{variant, select, treasure{Such strong support!\nTreasure Train level {level} completed!} community{Such strong support!\nCommunity Train level {level} completed!} mythic{Such strong support!\nMythic Train level {level} completed!} other{Such strong support!\nLevel {level} completed!}}'**
  String htSummary({required String variant, required int level});

  /// The hype train banner's announcement when the channel's record is beaten.
  ///
  /// In en, this message translates to:
  /// **'All-time record shattered!'**
  String get htAthReachedTitle;

  /// Who contributed to the hype train when Twitch does not say (anonymous).
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get htSomeone;

  /// The hype train banner's announcement of a cheer. name is a display name (or htSomeone).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{name} just used {count} Bit!} other{{name} just used {count} Bits!}}'**
  String htContributionBits({required int count, required String name});

  /// The hype train banner's announcement of gifted subs. tier is the sub tier (1, 2 or 3).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{name} just gifted {count} Tier {tier} sub!} other{{name} just gifted {count} Tier {tier} subs!}}'**
  String htContributionGift({
    required int count,
    required String name,
    required int tier,
  });

  /// The hype train banner's announcement of a sub. tier is the sub tier (1, 2 or 3).
  ///
  /// In en, this message translates to:
  /// **'{name} just subscribed at Tier {tier}!'**
  String htContributionSub({required String name, required int tier});

  /// The hype train banner's announcement of another contribution.
  ///
  /// In en, this message translates to:
  /// **'{name} just boosted the train!'**
  String htContributionOther({required String name});

  /// A number of subs: a shared train's totals, the conductor's, the level target.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} sub} other{{count} subs}}'**
  String htSubs({required int count});

  /// A number of Bits (Twitch's name, kept): a shared train's totals, the conductor's, the level target.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} Bit} other{{count} Bits}}'**
  String htBits({required int count});

  /// The hype train banner's first step after it starts (and the golden Kappa card of the sheet). variant is the train's variant (regular, goldenKappa, treasure, community, mythic).
  ///
  /// In en, this message translates to:
  /// **'{variant, select, goldenKappa{You’ll have a limited time to earn an exclusive Golden Kappa emote, valid for 24 hours} community{Whoa, this is a rare Community Train!} mythic{Whoa, this is a rare Mythic Train!} other{You’ll have a limited time to earn exclusive emotes}}'**
  String htInstructionStart({required String variant});

  /// A treasure train's step: the level that unlocks its discount.
  ///
  /// In en, this message translates to:
  /// **'Reach level {level} during this train to unlock {discount}% off gift subs!'**
  String htInstructionTreasureReachLevel({
    required int level,
    required int discount,
  });

  /// A treasure train's step one level before the discount.
  ///
  /// In en, this message translates to:
  /// **'One more level unlocks a discount for the rest of this train. Keep going!'**
  String get htInstructionTreasureOneAway;

  /// A treasure train's step once its discount unlocks.
  ///
  /// In en, this message translates to:
  /// **'You’ve unlocked {discount}% off 5+ gift subs! Don’t miss out!'**
  String htInstructionTreasureUnlocked({required int discount});

  /// A community train's step (and sheet card) once emotes for chat are unlocked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{You unlocked {count} emote for chat! Level up to give away more emotes.} other{You unlocked {count} emotes for chat! Level up to give away more emotes.}}'**
  String htCommunityUnlocked({required int count});

  /// A community train's step at its end.
  ///
  /// In en, this message translates to:
  /// **'Emotes for chat are on their way!'**
  String get htInstructionCommunityRewards;

  /// A shared train's last step.
  ///
  /// In en, this message translates to:
  /// **'See you next time in a Shared Hype Train!'**
  String get htInstructionSeeYouNextTime;

  /// A shared train's level and progress, in its strip and pill.
  ///
  /// In en, this message translates to:
  /// **'LVL {level}, {percent}%'**
  String htSharedLevel({required int level, required int percent});

  /// A shared train's strip when its level is reached.
  ///
  /// In en, this message translates to:
  /// **'Shared Train level reached'**
  String get htSharedLevelReached;

  /// Between two shared trains: the countdown follows (m:ss).
  ///
  /// In en, this message translates to:
  /// **'LVL {level} train continues in'**
  String htContinuesIn({required int level});

  /// A shared train's strip when another channel of it beats its record. name is that channel's display name.
  ///
  /// In en, this message translates to:
  /// **'{name}’s new all-time shared record!'**
  String htOtherChannelRecord({required String name});

  /// A shared train's announcement when it beats its record.
  ///
  /// In en, this message translates to:
  /// **'Shared Train record broken!'**
  String get htSharedRecordReached;

  /// The announcement when a shared hype train starts.
  ///
  /// In en, this message translates to:
  /// **'New Shared Hype Train'**
  String get htSharedNew;

  /// The approaching banner's title, before a hype train starts. variant is the train's variant (regular, goldenKappa, treasure, community, mythic).
  ///
  /// In en, this message translates to:
  /// **'{variant, select, goldenKappa{Golden Kappa Train approaching!} treasure{A Treasure Train is close!} community{A Community Train is close!} mythic{A Mythic Train is close!} other{A Hype Train is approaching!}}'**
  String htApproachingTitle({required String variant});

  /// The approaching banner's line. train is the train's name (htTrainTitle). French words it as htSubtitle, kept as short as the English.
  ///
  /// In en, this message translates to:
  /// **'Sub, gift, or use Bits now to start a {train}'**
  String htApproachingSubtitle({required String train});

  /// The approaching banner's line once the viewer took part: how many others are needed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} more person needs to sub, gift, or use Bits} other{{count} more people need to sub, gift, or use Bits}}'**
  String htApproachingMore({required int count});

  /// The landscape pill of an approaching hype train (« Imminent » agrees with « Hype Train »). Kept short.
  ///
  /// In en, this message translates to:
  /// **'Approaching'**
  String get htApproachingShort;

  /// The approaching sheet's heading. variant is the train's variant (regular, goldenKappa, treasure, community, mythic).
  ///
  /// In en, this message translates to:
  /// **'{variant, select, goldenKappa{What is a Golden Kappa Train?} other{What is a Hype Train?}}'**
  String htApproachingQuestion({required String variant});

  /// The approaching sheet's first paragraph. variant is the train's variant (regular, goldenKappa, treasure, community, mythic).
  ///
  /// In en, this message translates to:
  /// **'{variant, select, goldenKappa{A Golden Kappa Train starts when multiple people subscribe, use Bits, or gift subscriptions to the community.} other{A Hype Train starts when multiple people subscribe, use Bits, or gift subscriptions to the community.}}'**
  String htApproachingExplanationFirst({required String variant});

  /// The approaching sheet's second paragraph. variant is the train's variant (regular, goldenKappa, treasure, community, mythic).
  ///
  /// In en, this message translates to:
  /// **'{variant, select, goldenKappa{Once a Golden Kappa Train is underway, the community fills up the Hype Meter with more subs, gifts, or Bits. Everyone who contributes enough to be eligible for rewards will receive the Golden Kappa emote for 24 hours in addition to the regular emote rewards.} other{Once a Hype Train is underway, the community fills up the Hype Meter with more subs, gifts, or Bits. Everyone who contributes receives one unique emote based on the highest level completed.}}'**
  String htApproachingExplanationSecond({required String variant});

  /// The end strip of a hype train with rewards.
  ///
  /// In en, this message translates to:
  /// **'Great work! Emotes are being delivered to supporters'**
  String get htRewards;

  /// The end strip of a golden Kappa train.
  ///
  /// In en, this message translates to:
  /// **'Great work! Supporters can enjoy the exclusive Golden Kappa emote for 24 hours'**
  String get htGoldenRewards;

  /// The end strip of a hype train that expired without completing a level.
  ///
  /// In en, this message translates to:
  /// **'You missed the train. Better luck next time!'**
  String get htExpired;

  /// The end strip of a golden Kappa train that expired.
  ///
  /// In en, this message translates to:
  /// **'The Golden Kappa Train is long gone. Better luck next time!'**
  String get htGoldenExpired;

  /// The hype train sheet's heading over its top supporters. Written in capitals.
  ///
  /// In en, this message translates to:
  /// **'HYPE CONDUCTORS'**
  String get htConductorsHeader;

  /// Under « Hype conductors ».
  ///
  /// In en, this message translates to:
  /// **'Current Hype Train top supporters.'**
  String get htConductorsDescription;

  /// The hype train sheet's heading over the level's emotes. Written in capitals.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE REWARDS'**
  String get htRewardsHeader;

  /// Under « Available rewards » (a link to learn more follows).
  ///
  /// In en, this message translates to:
  /// **'You can earn one emote per train by subbing, gifting, or using more than 100 Bits in total during the event. Exclusive emotes are given out at the end of the Hype Train event and will stick around until the end of the current season.'**
  String get htRewardsDescription;

  /// Under « Available rewards » for a golden Kappa train.
  ///
  /// In en, this message translates to:
  /// **'Contribute by subbing, gifting, or using more than 100 Bits in total during the event to earn an exclusive Golden Kappa emote for 24 hours in addition to the regular emote rewards.'**
  String get htGoldenRewardsDescription;

  /// The shared train sheet's heading over each channel's share. Written in capitals.
  ///
  /// In en, this message translates to:
  /// **'CONTRIBUTIONS'**
  String get htContributionsHeader;

  /// The hype train sheet's heading over a level's emotes.
  ///
  /// In en, this message translates to:
  /// **'Level {level} emotes'**
  String htLevelEmotes({required int level});

  /// The hype train sheet's button that opens Twitch's hype train guide.
  ///
  /// In en, this message translates to:
  /// **'More info'**
  String get htMoreInfo;

  /// The link after the hype train sheet's rewards description (opens Twitch's guide). English writes it in lower case after the sentence; French starts it with a capital, a new sentence.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get htLearnMore;

  /// The hype train sheet's heading over the emotes already unlocked (« débloquées » agrees with « emotes »).
  ///
  /// In en, this message translates to:
  /// **'Unlocked so far'**
  String get htUnlockedSoFar;

  /// The hype train sheet's heading over the next trains.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get htComingUp;

  /// The hype train sheet when nothing more is coming.
  ///
  /// In en, this message translates to:
  /// **'Nothing more to show yet'**
  String get htNothingMore;

  /// The hype train sheet's line: what the level needs.
  ///
  /// In en, this message translates to:
  /// **'Level {level} needs {subs, plural, one{{subs} Tier 1 sub} other{{subs} Tier 1 subs}} or {bits, plural, one{{bits} Bit} other{{bits} Bits}} in total'**
  String htLevelTarget({
    required int level,
    required int subs,
    required int bits,
  });

  /// The hype train sheet: the top subs supporter (name drawn bold) and their subs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{name} has contributed {count} sub!} other{{name} has contributed {count} subs!}}'**
  String htSubsConductor({required int count, required String name});

  /// The hype train sheet: the top Bits supporter (name drawn bold) and their Bits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{name} has used {count} Bit} other{{name} has used {count} Bits}}'**
  String htBitsConductor({required int count, required String name});

  /// The hype train sheet when no one has subbed yet.
  ///
  /// In en, this message translates to:
  /// **'Sub or gift to take over this spot!'**
  String get htNoSubsConductor;

  /// The hype train sheet when no one has used Bits yet.
  ///
  /// In en, this message translates to:
  /// **'Use Bits to take over this spot!'**
  String get htNoBitsConductor;

  /// The hype train sheet, after a trophy: the channel's all-time record.
  ///
  /// In en, this message translates to:
  /// **'Channel all-time record! Level {level} at {percent}%'**
  String htChannelRecord({required int percent, required int level});

  /// The hype train sheet's treasure card once the discount is unlocked.
  ///
  /// In en, this message translates to:
  /// **'Save {discount}% on 5 or more gift subs, only during this train. All aboard!'**
  String htTreasureCardUnlocked({required int discount});

  /// The hype train sheet's treasure card before the discount unlocks.
  ///
  /// In en, this message translates to:
  /// **'Unlock a limited-time {discount}% discount on gift subs at level {level} during this train!'**
  String htTreasureCardLocked({required int level, required int discount});

  /// A mythic train's step and sheet card: one emote out of its pool.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Unlock 1 of {count} exclusive emote for 24 hours!} other{Unlock 1 of {count} exclusive emotes for 24 hours!}}'**
  String htMythicCard({required int count});

  /// The pill on a followed stream's card while its hype train beats the channel's record.
  ///
  /// In en, this message translates to:
  /// **'All-time record · Level {level}'**
  String htCardLevelRecord({required int level});

  /// The pill on a followed stream's card while a hype train runs. train is its name (htTrainTitle).
  ///
  /// In en, this message translates to:
  /// **'{train} level {level}'**
  String htCardLevel({required String train, required int level});

  /// What a screen reader offers on the expanded hype train banner.
  ///
  /// In en, this message translates to:
  /// **'Collapse Hype Train'**
  String get htCollapse;

  /// What a screen reader says a tap on the collapsed hype train pill does.
  ///
  /// In en, this message translates to:
  /// **'Show Hype Train'**
  String get htExpand;

  /// What a screen reader says a tap on the hype train banner does (opens its sheet), after its own « Double-tap to »: a verb in lower case.
  ///
  /// In en, this message translates to:
  /// **'show details'**
  String get htDetailsHint;

  /// What a screen reader says for the approaching hype train.
  ///
  /// In en, this message translates to:
  /// **'Hype Train approaching'**
  String get htSemanticsApproaching;

  /// Inside htSemanticsOngoing: the minutes left (short unit).
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String htSemanticsMinutes({required int minutes});

  /// Inside htSemanticsOngoing: the seconds left, under a minute.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} second} other{{count} seconds}}'**
  String htSemanticsSeconds({required int count});

  /// What a screen reader says for the running hype train. time is htSemanticsMinutes or htSemanticsSeconds.
  ///
  /// In en, this message translates to:
  /// **'Hype Train level {level}, {percent} percent, {time} left'**
  String htSemanticsOngoing({
    required int level,
    required int percent,
    required String time,
  });

  /// What a screen reader says for the hype train once it ended.
  ///
  /// In en, this message translates to:
  /// **'Hype Train ended at level {level}'**
  String htSemanticsEnded({required int level});

  /// What a screen reader says for a hype train that expired.
  ///
  /// In en, this message translates to:
  /// **'Hype Train expired'**
  String get htSemanticsExpired;

  /// What a screen reader says for a level's emote not unlocked yet. name is the emote's code (Twitch's data).
  ///
  /// In en, this message translates to:
  /// **'Locked reward {name}'**
  String htRewardLocked({required String name});

  /// What a screen reader says for an unlocked emote. name is the emote's code (Twitch's data).
  ///
  /// In en, this message translates to:
  /// **'Unlocked reward {name}'**
  String htRewardUnlocked({required String name});

  /// A length in seconds, as the chat words a timeout, a slow-mode wait, a follow age or a sleep timer (« 10 minutes », « 2 semaines »).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} second} other{{count} seconds}}'**
  String chatDurationSeconds({required int count});

  /// A length in minutes, as the chat words a timeout, a slow-mode wait, a follow age or a sleep timer (« 10 minutes », « 2 semaines »).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} minute} other{{count} minutes}}'**
  String chatDurationMinutes({required int count});

  /// A length in hours, as the chat words a timeout, a slow-mode wait, a follow age or a sleep timer (« 10 minutes », « 2 semaines »).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} hour} other{{count} hours}}'**
  String chatDurationHours({required int count});

  /// A length in days, as the chat words a timeout, a slow-mode wait, a follow age or a sleep timer (« 10 minutes », « 2 semaines »).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day} other{{count} days}}'**
  String chatDurationDays({required int count});

  /// A length in weeks, as the chat words a timeout, a slow-mode wait, a follow age or a sleep timer (« 10 minutes », « 2 semaines »).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} week} other{{count} weeks}}'**
  String chatDurationWeeks({required int count});

  /// A follow age in months, in the moderator's followers-only menu (« 3 mois »).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} month} other{{count} months}}'**
  String chatDurationMonths({required int count});

  /// A short wait in seconds: the slow mode's wait in the chat's pills and above the input, a sleep timer's last minute.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String chatShortSeconds({required int seconds});

  /// A short length in whole minutes, in the chat modes' pills (followers-only age, slow mode).
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String chatShortMinutes({required int minutes});

  /// A short length in minutes and seconds: the slow mode's pill, a sleep timer under an hour.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String chatShortMinutesSeconds({required int minutes, required int seconds});

  /// A short length in whole hours, in the chat modes' pills (followers-only age).
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String chatShortHours({required int hours});

  /// A short length in hours and minutes: the followers-only pill, a sleep timer.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String chatShortHoursMinutes({required int hours, required int minutes});

  /// The first line of a chat, while it connects.
  ///
  /// In en, this message translates to:
  /// **'Connecting to chat…'**
  String get chatConnecting;

  /// The line once the chat is connected. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {name}’s chat!'**
  String chatWelcome({required String name});

  /// The line that replaces the reconnecting line once the chat is back: how many tries and seconds it took.
  ///
  /// In en, this message translates to:
  /// **'{attempts, plural, one{Reconnected ({attempts} attempt, {seconds}s)} other{Reconnected ({attempts} attempts, {seconds}s)}}'**
  String chatReconnected({required int attempts, required int seconds});

  /// The chat lost its connection: the countdown before the next try.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting in {seconds}s… (attempt {attempt} of {max})'**
  String chatReconnectingIn({
    required int seconds,
    required int attempt,
    required int max,
  });

  /// The chat lost its connection: a try is running.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting… (attempt {attempt} of {max})'**
  String chatReconnecting({required int attempt, required int max});

  /// Error message. The line once every try to reconnect failed; a Reconnect button follows (chatReconnect).
  ///
  /// In en, this message translates to:
  /// **'Chat disconnected. Check your connection.'**
  String get chatDisconnected;

  /// The button on the « chat disconnected » line, and the row of the chat's details sheet that reconnects the chat.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get chatReconnect;

  /// The note above the input after the viewer asked to reconnect (chat details › Reconnect).
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to chat…'**
  String get chatReconnectingNotice;

  /// The chat is delayed to match the video (Settings › Chat › Message delay): the countdown until it catches up.
  ///
  /// In en, this message translates to:
  /// **'Chat will sync in {seconds}s…'**
  String chatSyncIn({required int seconds});

  /// A line when an editor of the channel adds a 7TV emote. name is the editor's name, emote the emote's code.
  ///
  /// In en, this message translates to:
  /// **'{name} added the 7TV emote “{emote}” to chat.'**
  String chatSevenTvEmoteAdded({required String name, required String emote});

  /// A line when an editor of the channel removes a 7TV emote. name is the editor's name, emote the emote's code.
  ///
  /// In en, this message translates to:
  /// **'{name} removed the 7TV emote “{emote}” from chat.'**
  String chatSevenTvEmoteRemoved({required String name, required String emote});

  /// Error message. The note above the input when a message is too long for Twitch.
  ///
  /// In en, this message translates to:
  /// **'Messages can be {max} characters at most.'**
  String chatMessageTooLong({required int max});

  /// The note above the input when a command is sent while the last one still runs.
  ///
  /// In en, this message translates to:
  /// **'Running the previous command…'**
  String get chatWaitCommand;

  /// The note above the input when a message is sent before Twitch confirmed the last one.
  ///
  /// In en, this message translates to:
  /// **'Sending the previous message…'**
  String get chatWaitMessage;

  /// Error message. A line in chat when a message is sent while the chat is disconnected.
  ///
  /// In en, this message translates to:
  /// **'Can’t send: chat is disconnected. Reconnecting…'**
  String get chatCannotSendDisconnected;

  /// Error message. The note above the input when Twitch did not confirm a message in time.
  ///
  /// In en, this message translates to:
  /// **'Your message may not have been sent. Try again.'**
  String get chatMaybeNotSent;

  /// The line left when a moderator clears the whole chat.
  ///
  /// In en, this message translates to:
  /// **'Chat was cleared by a moderator.'**
  String get chatClearedByModerator;

  /// The line /help writes in chat: every command's usage (chatCommandUsage…), joined with commas. The commands themselves are never translated.
  ///
  /// In en, this message translates to:
  /// **'Commands: {commands}'**
  String chatHelpCommands({required String commands});

  /// A line in chat: /w needs the viewer logged in.
  ///
  /// In en, this message translates to:
  /// **'Log in to whisper.'**
  String get chatLogInToWhisper;

  /// A line in chat once /w sent the whisper. name is the recipient's display name.
  ///
  /// In en, this message translates to:
  /// **'Whisper sent to {name}.'**
  String chatWhisperSent({required String name});

  /// The same, while Twitch refuses the app's whisper connection until the viewer logs in again.
  ///
  /// In en, this message translates to:
  /// **'Whisper sent to {name}. Replies can’t reach this app until you log in again.'**
  String chatWhisperSentNoReplies({required String name});

  /// Error message. A line in chat: /w names nobody. login is what the viewer typed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t whisper: no user named {login}.'**
  String chatWhisperNoUser({required String login});

  /// Error message. A line in chat after /user names nobody. login is the name as typed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the user card: no user named {login}.'**
  String chatUserCardNoUser({required String login});

  /// Error message. A line in chat when /user could not reach Twitch. login is the name as typed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the user card for {login}.'**
  String chatUserCardFailed({required String login});

  /// Error message. A line in chat: the whisper failed; reason is the error, worded (a sentence; French puts a full stop before it).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t whisper: {reason}'**
  String chatWhisperFailedBecause({required String reason});

  /// Error message. A line in chat: the whisper failed for an unexpected reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t whisper.'**
  String get chatWhisperFailed;

  /// A line in chat: /color needs the viewer logged in.
  ///
  /// In en, this message translates to:
  /// **'Log in to change your name color.'**
  String get chatLogInToChangeColor;

  /// A line in chat once /color changed the viewer's name colour.
  ///
  /// In en, this message translates to:
  /// **'Your name color was changed.'**
  String get chatColorChanged;

  /// Error message. A line in chat: Twitch refused the colour (#RRGGBB colours need Turbo or Prime).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t change your name color (hex colors need Turbo or Prime).'**
  String get chatColorFailedHex;

  /// A line in chat: /block names someone already blocked. French puts the name last so nothing agrees with it.
  ///
  /// In en, this message translates to:
  /// **'{name} is already blocked.'**
  String chatAlreadyBlocked({required String name});

  /// A line in chat once /block blocked someone. French puts the name last so nothing agrees with it.
  ///
  /// In en, this message translates to:
  /// **'Blocked {name}.'**
  String chatBlockedUser({required String name});

  /// A line in chat once /unblock unblocked someone.
  ///
  /// In en, this message translates to:
  /// **'Unblocked {name}.'**
  String chatUnblockedUser({required String name});

  /// Error message. A line in chat: /block failed. login is what the viewer typed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t block {login}.'**
  String chatBlockFailed({required String login});

  /// Error message. A line in chat: /unblock failed. login is what the viewer typed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t unblock {login}.'**
  String chatUnblockFailed({required String login});

  /// A line in chat: a moderation command needs the viewer logged in.
  ///
  /// In en, this message translates to:
  /// **'Log in to moderate.'**
  String get chatLogInToModerate;

  /// A word in a chat command's usage, between < > (required) or [ ] (optional): what to type there. The command itself and its syntax are never translated. Here: someone's name.
  ///
  /// In en, this message translates to:
  /// **'user'**
  String get chatCommandArgUser;

  /// A word in a chat command's usage, between < > (required) or [ ] (optional): what to type there. The command itself and its syntax are never translated. Here: the text to send.
  ///
  /// In en, this message translates to:
  /// **'message'**
  String get chatCommandArgMessage;

  /// A word in a chat command's usage, between < > (required) or [ ] (optional): what to type there. The command itself and its syntax are never translated. Here: a colour name or #RRGGBB.
  ///
  /// In en, this message translates to:
  /// **'color'**
  String get chatCommandArgColor;

  /// A word in a chat command's usage, between < > (required) or [ ] (optional): what to type there. The command itself and its syntax are never translated. Here: why (a ban, a warning).
  ///
  /// In en, this message translates to:
  /// **'reason'**
  String get chatCommandArgReason;

  /// A word in a chat command's usage, between < > (required) or [ ] (optional): what to type there. The command itself and its syntax are never translated. Here: a length such as 10m.
  ///
  /// In en, this message translates to:
  /// **'length'**
  String get chatCommandArgLength;

  /// A word in a chat command's usage, between < > (required) or [ ] (optional): what to type there. The command itself and its syntax are never translated. Here: the slow mode's wait.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get chatCommandArgSeconds;

  /// A word in a chat command's usage, between < > (required) or [ ] (optional): what to type there. The command itself and its syntax are never translated. Here: the id of the message to delete. French joins its words with no-break spaces, so the argument never breaks inside its brackets.
  ///
  /// In en, this message translates to:
  /// **'message id'**
  String get chatCommandArgMessageId;

  /// What a chat command does, beside its usage in the input's suggestions. command is the command's name (never translated, nor are the lengths « 10m », « 30s » and their units « s, m, h, d, w, mo » that Twitch reads).
  ///
  /// In en, this message translates to:
  /// **'{command, select, me{Speak in the third person} color{Change your name color} block{Block a user} unblock{Unblock a user} w{Whisper a user} user{Open a user’s card} disconnect{Reconnect to chat} help{List the commands} ban{Ban a user} unban{Lift a ban} timeout{Time out a user (default 10m; s, m, h, d, w)} untimeout{Lift a timeout} warn{Warn a user} delete{Delete a message} clear{Delete every message} slow{Turn slow mode on (default 30s)} slowoff{Turn slow mode off} followers{Turn followers-only mode on (m, h, d, w, mo)} followersoff{Turn followers-only mode off} subscribers{Turn subscribers-only mode on} subscribersoff{Turn subscribers-only mode off} emoteonly{Turn emote-only mode on} emoteonlyoff{Turn emote-only mode off} uniquechat{Turn unique chat mode on (no repeated messages)} uniquechatoff{Turn unique chat mode off} other{}}'**
  String chatCommandDescription({required String command});

  /// A line in chat when a command is typed wrong: how to type it. usage is the command and its words (/ban <user> [reason]).
  ///
  /// In en, this message translates to:
  /// **'Usage: {usage}'**
  String chatCommandUsage({required String usage});

  /// Error message. A line in chat: /timeout got a length it cannot read. length is what the viewer typed; the examples are what Twitch reads (never translated).
  ///
  /// In en, this message translates to:
  /// **'Unknown length “{length}”. Try 30, 10m, 2h, 1d, or 1w.'**
  String chatCommandBadLength({required String length});

  /// Error message. A line in chat: /timeout got a length out of range.
  ///
  /// In en, this message translates to:
  /// **'Timeouts must be between 1 second and 2 weeks.'**
  String get chatCommandTimeoutRange;

  /// Error message. A line in chat: /slow got a wait out of range.
  ///
  /// In en, this message translates to:
  /// **'Slow mode must be between 3 and 120 seconds.'**
  String get chatCommandSlowRange;

  /// Error message. A line in chat: /followers got a follow age out of range. The examples are what Twitch reads (never translated).
  ///
  /// In en, this message translates to:
  /// **'Follow age must be between 0 minutes and 3 months (e.g., 10m, 1w, 3mo).'**
  String get chatCommandFollowAgeRange;

  /// Error message. A line in chat: /color got a colour it does not know. Blue, Coral, HotPink are what /color reads (never translated; French writes them in lower case, which /color reads the same).
  ///
  /// In en, this message translates to:
  /// **'Unknown color. Try Blue, Coral, HotPink, or #RRGGBB (Turbo or Prime).'**
  String get chatCommandUnknownColor;

  /// Error message. A line in chat: a Twitch command this app does not run. command is its name.
  ///
  /// In en, this message translates to:
  /// **'/{command} is not available in this app.'**
  String chatCommandNotInApp({required String command});

  /// Error message. A line in chat: a command nobody knows. command is what the viewer typed; /help is the command (never translated).
  ///
  /// In en, this message translates to:
  /// **'Unknown command /{command}. Type /help for the commands you can use.'**
  String chatCommandUnknown({required String command});

  /// A room mode's name: the moderator's switches (Chat modes sheet) and their outcome lines. mode is ChatMode.name.
  ///
  /// In en, this message translates to:
  /// **'{mode, select, slow{Slow mode} followers{Followers-only mode} subscribers{Subscribers-only mode} emoteOnly{Emote-only mode} uniqueChat{Unique chat mode} other{}}'**
  String chatModeName({required String mode});

  /// A line in chat once a moderator turned a room mode on or off. mode is ChatMode.name; state is on or off. « activé » agrees with « mode ».
  ///
  /// In en, this message translates to:
  /// **'{mode, select, slow{Slow mode} followers{Followers-only mode} subscribers{Subscribers-only mode} emoteOnly{Emote-only mode} uniqueChat{Unique chat mode} other{}} {state, select, on{on} other{off}}.'**
  String chatModeChanged({required String mode, required String state});

  /// A line in chat once a moderator turned slow mode on. duration is the wait (chatDuration…).
  ///
  /// In en, this message translates to:
  /// **'Slow mode on ({duration}).'**
  String chatModeSlowOn({required String duration});

  /// A line in chat once a moderator turned followers-only mode on with a follow age. duration is the age (chatDuration…).
  ///
  /// In en, this message translates to:
  /// **'Followers-only mode on (must follow for {duration}).'**
  String chatModeFollowersOn({required String duration});

  /// Error message. A moderation action failed (in chat, under the moderation bar): what, then why. command is what failed: ban, timeout, untimeout, unban, warn, delete, clear, or a room mode turned on or off (slowOn, slowOff, followersOn, followersOff, subscribersOn, subscribersOff, emoteOnlyOn, emoteOnlyOff, uniqueChatOn, uniqueChatOff). French carries « de » / « d’ » in each branch. reason is a sentence or a phrase (chatModCannotModerate, chatModNoUser, an error); French makes it a sentence after a full stop (« Impossible de bannir. … »).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t {command, select, ban{ban the user} timeout{time out the user} untimeout{lift the timeout} unban{unban the user} warn{warn the user} delete{delete the message} clear{clear the chat} slowOn{turn slow mode on} slowOff{turn slow mode off} followersOn{turn followers-only mode on} followersOff{turn followers-only mode off} subscribersOn{turn subscribers-only mode on} subscribersOff{turn subscribers-only mode off} emoteOnlyOn{turn emote-only mode on} emoteOnlyOff{turn emote-only mode off} uniqueChatOn{turn unique chat mode on} uniqueChatOff{turn unique chat mode off} other{do that}}: {reason}'**
  String chatModFailed({required String command, required String reason});

  /// Error message. A moderation action failed for an unexpected reason. command is what failed: ban, timeout, untimeout, unban, warn, delete, clear, or a room mode turned on or off (slowOn, slowOff, followersOn, followersOff, subscribersOn, subscribersOff, emoteOnlyOn, emoteOnlyOff, uniqueChatOn, uniqueChatOff). French carries « de » / « d’ » in each branch.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t {command, select, ban{ban the user} timeout{time out the user} untimeout{lift the timeout} unban{unban the user} warn{warn the user} delete{delete the message} clear{clear the chat} slowOn{turn slow mode on} slowOff{turn slow mode off} followersOn{turn followers-only mode on} followersOff{turn followers-only mode off} subscribersOn{turn subscribers-only mode on} subscribersOff{turn subscribers-only mode off} emoteOnlyOn{turn emote-only mode on} emoteOnlyOff{turn emote-only mode off} uniqueChatOn{turn unique chat mode on} uniqueChatOff{turn unique chat mode off} other{do that}} (unexpected error).'**
  String chatModFailedUnexpected({required String command});

  /// Error message. Why a moderation action failed (after chatModFailed's colon): the viewer is not a moderator here.
  ///
  /// In en, this message translates to:
  /// **'Twitch says you can’t moderate this chat.'**
  String get chatModCannotModerate;

  /// After « Couldn't … » in chat, on a screen in another language than English: a sentence after the failure's kind worded in that language, quoting Twitch's own short explanation as Twitch wrote it (English). An English screen shows Twitch's words alone instead, as it always has.
  ///
  /// In en, this message translates to:
  /// **'Twitch’s reason: “{reason}”'**
  String chatTwitchReason({required String reason});

  /// Error message. Why a moderation action failed (after chatModFailed's colon; French: a sentence after its full stop): nobody has that login. English starts in lower case after the colon and ends the line with a full stop.
  ///
  /// In en, this message translates to:
  /// **'no user named {login}.'**
  String chatModNoUser({required String login});

  /// Error message. A moderation action failed: the viewer's login predates the moderator permissions.
  ///
  /// In en, this message translates to:
  /// **'Log in again to moderate from this app.'**
  String get chatModLogInAgain;

  /// Error message. A moderation action failed without an answer (under the moderation bar or the chat modes).
  ///
  /// In en, this message translates to:
  /// **'That didn’t go through. Try again.'**
  String get chatModNotThrough;

  /// A line in chat once the viewer banned someone. name is their display name.
  ///
  /// In en, this message translates to:
  /// **'You banned {name}.'**
  String chatModBanned({required String name});

  /// A line in chat once the viewer timed someone out. duration is chatDuration….
  ///
  /// In en, this message translates to:
  /// **'You timed out {name} for {duration}.'**
  String chatModTimedOut({required String name, required String duration});

  /// A line in chat once the viewer lifted a timeout. French puts the name last (no elision before it).
  ///
  /// In en, this message translates to:
  /// **'You lifted {name}’s timeout.'**
  String chatModUntimedOut({required String name});

  /// A line in chat once the viewer lifted a ban.
  ///
  /// In en, this message translates to:
  /// **'You unbanned {name}.'**
  String chatModUnbanned({required String name});

  /// A line in chat once the viewer warned someone.
  ///
  /// In en, this message translates to:
  /// **'You warned {name}.'**
  String chatModWarned({required String name});

  /// A line in chat once the viewer deleted a message (/delete).
  ///
  /// In en, this message translates to:
  /// **'Message deleted.'**
  String get chatModMessageDeleted;

  /// A line in chat once the viewer cleared the chat (/clear).
  ///
  /// In en, this message translates to:
  /// **'You cleared the chat.'**
  String get chatModCleared;

  /// A line in chat when a moderator bans someone. French puts the name last so nothing agrees with it.
  ///
  /// In en, this message translates to:
  /// **'{name} has been permanently banned.'**
  String chatNoticeBanned({required String name});

  /// A line in chat when a moderator times someone out, for a length Twitch did not give.
  ///
  /// In en, this message translates to:
  /// **'{name} has been timed out.'**
  String chatNoticeTimedOut({required String name});

  /// A line in chat when a moderator times someone out. duration is chatDuration….
  ///
  /// In en, this message translates to:
  /// **'{name} has been timed out for {duration}.'**
  String chatNoticeTimedOutFor({
    required String name,
    required String duration,
  });

  /// A chat server notice (IRC NOTICE) worded by the app instead of Twitch’s English: a refused message, or the answer to a command. notice names it.
  ///
  /// In en, this message translates to:
  /// **'{notice, select, rateLimit{Couldn’t send your message. You’re sending messages too quickly.} duplicate{Couldn’t send your message. It’s the same as one you sent less than 30 seconds ago.} subsOnly{Couldn’t send your message. This chat is in subscribers-only mode: subscribe to the channel to chat.} emoteOnly{Couldn’t send your message. This chat is in emote-only mode.} uniqueChat{Couldn’t send your message. This chat is in unique chat mode, and your message isn’t original.} followRequired{Couldn’t send your message. This chat is in followers-only mode: follow the channel to chat.} followedTooRecently{Couldn’t send your message. You haven’t followed this channel long enough to chat yet.} verifiedEmail{Couldn’t send your message. This channel requires a verified email address: verify yours in your Twitch security settings.} verifiedPhone{Couldn’t send your message. This channel requires a verified phone number: verify yours in your Twitch security settings.} emailAliasBanned{Couldn’t send your message. Your email address is banned from this channel.} phoneAliasBanned{Couldn’t send your message. Your phone number is banned from this channel.} channelSuspended{This channel doesn’t exist or is suspended.} accountSuspended{Couldn’t send your message. Your account is suspended.} channelBlocked{Couldn’t send your message. Your account isn’t in good standing in this channel.} userRestricted{Couldn’t send your message. Your account can’t send chat messages for now. Learn more at appeals.twitch.tv.} channelRestricted{Couldn’t send your message. This channel can’t receive chat messages for now.} invalidReply{Couldn’t send your reply. That message can’t be replied to.} unexpected{Couldn’t send your message. Try again.} badCharacters{Couldn’t send your message. It contains too many characters Twitch can’t process.} rejectedBySettings{Couldn’t send your message. It conflicts with the channel’s moderation settings.} tooManyChats{Too many chats are open at once. Leave one to join this one.} warned{Couldn’t send your message. A moderator warned you: acknowledge the warning on twitch.tv to chat again.} banned{You’re permanently banned from this chat.} followersOnNow{This chat is now in followers-only mode.} noPermission{You don’t have permission to do that.} other{}}'**
  String chatServerNotice({required String notice});

  /// A chat server notice when the viewer, timed out, tries to chat. wait is the time left, worded like chatDuration….
  ///
  /// In en, this message translates to:
  /// **'You’re timed out: you can chat again in {wait}.'**
  String chatServerNoticeTimedOut({required String wait});

  /// A chat server notice when a message is refused by slow mode. wait is the time left, worded like chatDuration….
  ///
  /// In en, this message translates to:
  /// **'Couldn’t send your message. This chat is in slow mode: you can chat again in {wait}.'**
  String chatServerNoticeSlowMode({required String wait});

  /// A chat server notice when Twitch does not know a command. command is the command as typed, with its slash.
  ///
  /// In en, this message translates to:
  /// **'Unknown command: {command}.'**
  String chatServerNoticeUnknownCommand({required String command});

  /// A line in chat when one of the viewer’s own messages is deleted (Twitch does not say by whom: a moderator, or the viewer as a moderator). message is the deleted text, as the viewer wrote it.
  ///
  /// In en, this message translates to:
  /// **'Your message was deleted: “{message}”.'**
  String chatNoticeOwnMessageDeleted({required String message});

  /// Above the chat input (and as its placeholder, one line each): the viewer is banned. French uses the noun, so nothing agrees with the viewer and the key word comes first.
  ///
  /// In en, this message translates to:
  /// **'Permanently banned'**
  String get chatRestrictionBanned;

  /// The chat input's placeholder while the viewer is timed out (one line): French uses the noun, as on the bar above the input (chatRestrictionTimedOutFor).
  ///
  /// In en, this message translates to:
  /// **'You’re timed out'**
  String get chatRestrictionTimedOut;

  /// Above the chat input while the viewer is timed out (one line at 12 dp). wait is the time left (« 4:05 », « 12 s »), the line's point: French keeps it short so it never falls under the ellipsis.
  ///
  /// In en, this message translates to:
  /// **'You’re timed out · {wait}'**
  String chatRestrictionTimedOutFor({required String wait});

  /// Above the chat input in slow mode, after a message (one line at 12 dp). wait is the time left: French keeps the line short (« encore 29 s ») so it never falls under the ellipsis on a phone at large text.
  ///
  /// In en, this message translates to:
  /// **'Slow mode · you can chat again in {wait}'**
  String chatRestrictionSlow({required String wait});

  /// The chat input's placeholder in emote-only mode.
  ///
  /// In en, this message translates to:
  /// **'Emote-only chat'**
  String get chatRestrictionEmoteOnly;

  /// The chat input's placeholder in subscribers-only mode.
  ///
  /// In en, this message translates to:
  /// **'Subscribers-only chat'**
  String get chatRestrictionSubscribersOnly;

  /// The chat input's placeholder in followers-only mode.
  ///
  /// In en, this message translates to:
  /// **'Followers-only chat'**
  String get chatRestrictionFollowersOnly;

  /// The input's one-line placeholder when followers must have followed for a while: what it takes to chat. duration is that follow age, short so it stays in sight on a phone at large text (chatShortMinutes, chatShortHours, else whole days or months: « 10m », « 3h », « 7 days », « 10 min », « 7 jours »).
  ///
  /// In en, this message translates to:
  /// **'Followers-only · {duration}'**
  String chatRestrictionFollowersFor({required String duration});

  /// The one-line bar above the chat input (and its placeholder) after Twitch refused a message for a reason tied to the account or the channel. One line at 360 dp ×1.3.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, verifiedEmail{Verified email required} verifiedPhone{Verified phone required} emailAliasBanned{Email banned here} phoneAliasBanned{Phone banned here} accountRestricted{Account restricted} channelRestricted{Chat suspended here} followRequired{Follow to chat} other{}}'**
  String chatRestrictionAccount({required String reason});

  /// The button over a paused chat: how many messages arrived since; tapping it scrolls back down.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} new message} other{{count} new messages}}'**
  String chatNewMessages({required int count});

  /// The same button when no message arrived: back to the newest messages.
  ///
  /// In en, this message translates to:
  /// **'Resume scroll'**
  String get chatResumeScroll;

  /// Tooltip of the clock before a message loaded from the chat's history (sent before the viewer joined).
  ///
  /// In en, this message translates to:
  /// **'Historical message'**
  String get chatHistoricalMessage;

  /// Tooltip of a channel's picture before a message in a shared chat: sent from this channel.
  ///
  /// In en, this message translates to:
  /// **'Sent from {name} (current channel)'**
  String chatSentFromCurrent({required String name});

  /// Tooltip of a channel's picture before a message in a shared chat: sent from another channel of it.
  ///
  /// In en, this message translates to:
  /// **'Sent from {name}'**
  String chatSentFrom({required String name});

  /// Shown in place of a deleted message's text, after the name; tapping it shows the message.
  ///
  /// In en, this message translates to:
  /// **'<message deleted>'**
  String get chatMessageDeletedInline;

  /// The name shown for a message (from the chat's history, a replay, a pin) whose sender's account no longer exists.
  ///
  /// In en, this message translates to:
  /// **'Deleted user'**
  String get chatDeletedUser;

  /// What a screen reader says for a word the chat filters hide (drawn as stars).
  ///
  /// In en, this message translates to:
  /// **'Filtered word'**
  String get chatFilteredWord;

  /// What a screen reader says for a cheer in a message. prefix is the cheermote's name (Cheer, Kappa…), never translated. Bits is Twitch's word, after an ordinary space as in htBits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{prefix} {count} Bit} other{{prefix} {count} Bits}}'**
  String chatCheerSemantics({required String prefix, required int count});

  /// The details of a stack of emotes (a zero-width emote over another): the emotes on top, joined with « + ».
  ///
  /// In en, this message translates to:
  /// **'with {emotes}'**
  String chatEmoteStackWith({required String emotes});

  /// The details of an emote: who made or owns it.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String chatEmoteBy({required String name});

  /// A row of an emote's, badge's or GIF's details: copies its name.
  ///
  /// In en, this message translates to:
  /// **'Copy name'**
  String get chatCopyName;

  /// A row of an emote's, badge's or GIF's details: copies its picture's address.
  ///
  /// In en, this message translates to:
  /// **'Copy image URL'**
  String get chatCopyImageUrl;

  /// A row of an emote's, badge's or GIF's details: opens its picture in the browser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get chatOpenInBrowser;

  /// The note above the input once a message was copied.
  ///
  /// In en, this message translates to:
  /// **'Message copied'**
  String get chatMessageCopied;

  /// A row of a message's options (long press).
  ///
  /// In en, this message translates to:
  /// **'Copy message'**
  String get chatCopyMessage;

  /// A row of a message's options: copies the message into the input.
  ///
  /// In en, this message translates to:
  /// **'Copy into message box'**
  String get chatCopyMessageAndPaste;

  /// A row of a message's options.
  ///
  /// In en, this message translates to:
  /// **'Reply to message'**
  String get chatReplyToMessage;

  /// A row of a message's options, for moderators.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get chatDeleteMessage;

  /// Above a viewer's first message in the channel, highlighted.
  ///
  /// In en, this message translates to:
  /// **'First message'**
  String get chatFirstMessage;

  /// Above a message highlighted with channel points.
  ///
  /// In en, this message translates to:
  /// **'Highlighted message'**
  String get chatHighlightedMessage;

  /// Header above a Bits message sent in another channel of a shared chat. channel is that channel’s display name.
  ///
  /// In en, this message translates to:
  /// **'Cheered in {channel}'**
  String chatCheeredIn({required String channel});

  /// Header above a message sent in subscribers-only chat with the channel points reward that allows it.
  ///
  /// In en, this message translates to:
  /// **'Sent with channel points in subscribers-only chat'**
  String get chatSubsOnlyRedemption;

  /// Header above a message sent with the animated message power-up.
  ///
  /// In en, this message translates to:
  /// **'Animated message'**
  String get chatAnimatedMessage;

  /// Above a message a moderator deleted.
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get chatMessageDeleted;

  /// Above the messages of someone banned.
  ///
  /// In en, this message translates to:
  /// **'Permanently banned'**
  String get chatPermanentlyBanned;

  /// Above the messages of someone timed out: for how long, worded like the timeout notices (chatDuration…: « 10 minutes »).
  ///
  /// In en, this message translates to:
  /// **'Timed out for {duration}'**
  String chatTimedOutForLength({required String duration});

  /// Above a moderator's announcement.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get chatAnnouncement;

  /// What a screen reader says a long press on a chat message does, after its own « Double-tap and hold to »: a verb in lower case.
  ///
  /// In en, this message translates to:
  /// **'open message options'**
  String get chatMessageOptionsHint;

  /// What a screen reader says a long press on a notice does (it copies it). Lower case.
  ///
  /// In en, this message translates to:
  /// **'copy message'**
  String get chatCopyMessageHint;

  /// The heading of a reply thread's sheet.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get chatReplies;

  /// Tooltip of the button beside the chat input that opens the emote menu, and the menu's name for screen readers.
  ///
  /// In en, this message translates to:
  /// **'Emote menu'**
  String get chatEmoteMenu;

  /// The chat input's placeholder (and its note) when the viewer is not logged in.
  ///
  /// In en, this message translates to:
  /// **'Log in to chat'**
  String get chatLogInToChat;

  /// Tooltip of the cross on the « replying to » bar above the input.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get chatCancelReply;

  /// Tooltip of the collapsed chat input's button that opens the keyboard.
  ///
  /// In en, this message translates to:
  /// **'Send a message'**
  String get chatEnterMessage;

  /// The chat input's placeholder while the viewer cannot send (rules not accepted yet, a restriction); one line, so French keeps it short (the bar above says why).
  ///
  /// In en, this message translates to:
  /// **'You can’t chat right now'**
  String get chatCannotChatNow;

  /// The chat input's placeholder while the chat is disconnected.
  ///
  /// In en, this message translates to:
  /// **'Chat disconnected'**
  String get chatInputDisconnected;

  /// The chat input's placeholder while the chat connects.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get chatInputConnecting;

  /// The chat input's placeholder, and the send button's tooltip, while Twitch confirms a message.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get chatSending;

  /// Tooltip of the chat input's send button.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// The chat input's placeholder while replying (one line). name is the channel's display name; French keeps the words before it short so the name shows.
  ///
  /// In en, this message translates to:
  /// **'Reply in {name}'**
  String chatReplyIn({required String name});

  /// The chat input's placeholder while replying when the channel is not named, and the user card's reply button.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatReply;

  /// The chat input's placeholder while the chat is delayed to match the video (one line). name is the channel's display name; « délai » is the setting's word (Délai des messages). French puts the name first and keeps the line short, so the name and the delay both show on a phone at large text.
  ///
  /// In en, this message translates to:
  /// **'{name} · {seconds}s delay'**
  String chatInChannelDelayed({required String name, required int seconds});

  /// The same, when the channel is not named.
  ///
  /// In en, this message translates to:
  /// **'Chat · {seconds}s delay'**
  String chatDelayed({required int seconds});

  /// The chat input's placeholder (one line). name is the channel's display name; French keeps the words before it short so the name shows.
  ///
  /// In en, this message translates to:
  /// **'Chat in {name}'**
  String chatInChannel({required String name});

  /// The chat input's placeholder when the channel is not named.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatInputPlaceholder;

  /// Tooltip of the « ⋯ » button beside the chat input (the chat's details), and of the user card's « ⋯ ».
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chatMoreOptions;

  /// What a screen reader says for the counter beside the chat input near the length limit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} character left} other{{count} characters left}}'**
  String chatCharactersLeft({required int count});

  /// Snackbar once the name colour picked in the chat details was saved.
  ///
  /// In en, this message translates to:
  /// **'Name color updated'**
  String get chatColorUpdated;

  /// Error message. Snackbar when the name colour could not be saved.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t update your name color. Try again.'**
  String get chatColorUpdateFailed;

  /// A row of the chat's details sheet: hides the video.
  ///
  /// In en, this message translates to:
  /// **'Chat only'**
  String get chatDetailsChatOnly;

  /// A row of the chat's details sheet: shows the video again.
  ///
  /// In en, this message translates to:
  /// **'Show video'**
  String get chatDetailsShowVideo;

  /// A row of the chat's details sheet.
  ///
  /// In en, this message translates to:
  /// **'Refresh emotes and badges'**
  String get chatDetailsRefreshAssets;

  /// A row of the chat's details sheet, and the title of the colour picker it opens.
  ///
  /// In en, this message translates to:
  /// **'Name color'**
  String get chatDetailsUsernameColor;

  /// A row of the chat's details sheet: opens the chat on twitch.tv.
  ///
  /// In en, this message translates to:
  /// **'Channel points, polls, and predictions'**
  String get chatDetailsPointsPollsPredictions;

  /// The line under the « Channel points, polls and predictions » row.
  ///
  /// In en, this message translates to:
  /// **'Opens the chat on twitch.tv'**
  String get chatDetailsOpensTwitchChat;

  /// The title of the in-app page showing the chat on twitch.tv.
  ///
  /// In en, this message translates to:
  /// **'Twitch chat'**
  String get chatDetailsTwitchChat;

  /// The line under the Subscribe and Gift a Sub rows of the chat's details sheet.
  ///
  /// In en, this message translates to:
  /// **'Opens twitch.tv'**
  String get chatDetailsOpensTwitch;

  /// A row of the chat's details sheet (opens the channel's subscription page on twitch.tv), and that page's title.
  ///
  /// In en, this message translates to:
  /// **'Gift a sub'**
  String get chatDetailsGiftSub;

  /// A row of the chat's details sheet for moderators, and the title of the sheet it opens.
  ///
  /// In en, this message translates to:
  /// **'Chat modes'**
  String get chatDetailsModes;

  /// The line under the « Chat modes » row, one line on a phone: a short list of what the page holds.
  ///
  /// In en, this message translates to:
  /// **'Slow, followers-only, clear chat…'**
  String get chatDetailsModesDetail;

  /// A row of the chat's details sheet: the list of who is in the chat.
  ///
  /// In en, this message translates to:
  /// **'Chatters'**
  String get chatDetailsChatters;

  /// A row of the chat's details sheet: opens another channel's chat in a new tab.
  ///
  /// In en, this message translates to:
  /// **'Add chat'**
  String get chatDetailsAddChat;

  /// A row of the chat's details sheet (the time left while it runs), and the title of its view.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get chatDetailsSleepTimer;

  /// The colour picker's button that saves the picked name colour.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get chatSave;

  /// The colour picker's preview: a fake message from the viewer, in the picked colour.
  ///
  /// In en, this message translates to:
  /// **'How it will look in chat'**
  String get chatColorPreview;

  /// A Twitch name colour in the colour picker. color is Twitch's id for it (blue_violet). /color still takes the English names.
  ///
  /// In en, this message translates to:
  /// **'{color, select, blue{Blue} blue_violet{Blue violet} cadet_blue{Cadet blue} chocolate{Chocolate} coral{Coral} dodger_blue{Dodger blue} firebrick{Firebrick} golden_rod{Goldenrod} green{Green} hot_pink{Hot pink} orange_red{Orange red} red{Red} sea_green{Sea green} spring_green{Spring green} yellow_green{Yellow green} other{}}'**
  String chatColorName({required String color});

  /// The followers-only mode's shortest follow age: anyone following.
  ///
  /// In en, this message translates to:
  /// **'Any follower'**
  String get chatModesAnyFollower;

  /// The title of the dialog that confirms clearing the chat.
  ///
  /// In en, this message translates to:
  /// **'Clear chat?'**
  String get chatModesClearTitle;

  /// The text of the dialog that confirms clearing the chat.
  ///
  /// In en, this message translates to:
  /// **'Every message is deleted for everyone.'**
  String get chatModesClearMessage;

  /// The button that confirms clearing the chat, and the clear button of the chatters' and channels' search fields.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get chatClear;

  /// Beside the Chat modes sheet's title: these are a moderator's tools.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get chatModesModerator;

  /// A chat badge's name for a moderator who is a bot (FrankerFaceZ's bot badge drawn in place of the moderator's): its sheet and tooltip. moderator is Twitch's own name of the moderator badge.
  ///
  /// In en, this message translates to:
  /// **'{moderator} (bot)'**
  String chatBadgeModeratorBot({required String moderator});

  /// The slow mode's wait in its picker.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s between messages'**
  String chatModesSlowWait({required int seconds});

  /// The Chat modes sheet's row that clears the chat.
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get chatModesClearChat;

  /// A pill at the top of the chat's details sheet: a room mode that is on. mode is ChatMode.name.
  ///
  /// In en, this message translates to:
  /// **'{mode, select, emoteOnly{Emote-only} followers{Followers-only} slow{Slow mode} subscribers{Subscribers-only} uniqueChat{Unique chat} other{}}'**
  String chatModePill({required String mode});

  /// The placeholder of the chatters list's search field.
  ///
  /// In en, this message translates to:
  /// **'Filter chatters'**
  String get chatChattersFilter;

  /// Above the chatters list: how many it holds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} chatter found} other{{count} chatters found}}'**
  String chatChattersFound({required int count});

  /// The chatters list when Twitch gives nobody.
  ///
  /// In en, this message translates to:
  /// **'No chatters found'**
  String get chatChattersNone;

  /// The chatters list when nobody matches the filter.
  ///
  /// In en, this message translates to:
  /// **'No matching chatters'**
  String get chatChattersNoMatch;

  /// The emote menu's first tab: the emotes the viewer used lately (« emotes » is feminine).
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get emoteMenuRecent;

  /// Tooltip of the button on the emote menu's Recent tab.
  ///
  /// In en, this message translates to:
  /// **'Clear recent emotes'**
  String get emoteMenuClearRecent;

  /// The note above the input once the recent emotes were cleared.
  ///
  /// In en, this message translates to:
  /// **'Recent emotes cleared'**
  String get emoteMenuRecentCleared;

  /// The emote menu's Recent tab when it is empty.
  ///
  /// In en, this message translates to:
  /// **'No recent emotes'**
  String get emoteMenuNoRecent;

  /// What a screen reader says for an emote the viewer cannot use yet. name is the emote's code; « verrouillée » agrees with « emote ».
  ///
  /// In en, this message translates to:
  /// **'{name}, locked'**
  String emoteMenuLocked({required String name});

  /// A tab of the emote menu: the channel's emotes.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get emoteMenuChannel;

  /// A tab of the emote menu: the global emotes (« emotes » is feminine).
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get emoteMenuGlobal;

  /// A tab of the emote menu's Twitch section: emotes the viewer unlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get emoteMenuUnlocked;

  /// A tab of the emote menu's Twitch section: other channels' emotes the viewer can use.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get emoteMenuOther;

  /// A line in chat when the viewer's message held by AutoMod was decided. decision is approved, denied or invalid; a full stop or the quoted message follows (chatHeldQuoted).
  ///
  /// In en, this message translates to:
  /// **'{decision, select, approved{Moderators approved your held message} denied{Moderators denied your held message} other{Your held message can no longer be reviewed}}'**
  String chatHeldDecision({required String decision});

  /// The same line with the held message quoted. decision is chatHeldDecision.
  ///
  /// In en, this message translates to:
  /// **'{decision}: “{quote}”'**
  String chatHeldQuoted({required String decision, required String quote});

  /// Error message. The Add chat sheet when the search failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t search channels.'**
  String get chatAddChatSearchFailed;

  /// The title of the sheet that opens another channel's chat in a new tab.
  ///
  /// In en, this message translates to:
  /// **'Add chat'**
  String get chatAddChatTitle;

  /// The placeholder of the Add chat sheet's search field.
  ///
  /// In en, this message translates to:
  /// **'Search for a channel'**
  String get chatAddChatSearch;

  /// The Add chat sheet before anything is typed.
  ///
  /// In en, this message translates to:
  /// **'Search for a channel to add'**
  String get chatAddChatPrompt;

  /// The Add chat sheet when the search found nobody.
  ///
  /// In en, this message translates to:
  /// **'No channels found'**
  String get chatAddChatNoChannels;

  /// Tooltip of the merge button while the chats are merged.
  ///
  /// In en, this message translates to:
  /// **'Split chats'**
  String get chatTabsSplit;

  /// Tooltip of the button that shows every open chat in one list.
  ///
  /// In en, this message translates to:
  /// **'Merge loaded chats'**
  String get chatTabsMerge;

  /// An item of a chat tab's menu: disconnects that chat.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get chatTabsDisconnect;

  /// An item of a chat tab's menu: closes that tab.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get chatTabsRemove;

  /// Tooltip of a chat tab's menu button.
  ///
  /// In en, this message translates to:
  /// **'Tab options'**
  String get chatTabsOptions;

  /// Snackbar when the viewer adds an 11th chat.
  ///
  /// In en, this message translates to:
  /// **'Maximum 10 chats open'**
  String get chatTabsMaximum;

  /// Snackbar when the viewer adds a chat already open: the app shows it.
  ///
  /// In en, this message translates to:
  /// **'Channel already open — switched to it'**
  String get chatTabsAlreadyOpen;

  /// Tooltip of the user card's whisper button.
  ///
  /// In en, this message translates to:
  /// **'Whisper'**
  String get chatUserWhisper;

  /// Tooltip of the user card's button that opens the channel's profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get chatUserProfile;

  /// The user card when the viewer saw no message from that user.
  ///
  /// In en, this message translates to:
  /// **'No recent messages'**
  String get chatUserNoRecentMessages;

  /// The heading of the user card's list of that user's messages.
  ///
  /// In en, this message translates to:
  /// **'Recent messages'**
  String get chatUserRecentMessages;

  /// A subscriber or founder badge on the user card, with how many months. name is the badge's title from Twitch.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{name} · {count} month} other{{name} · {count} months}}'**
  String chatUserBadgeMonths({required String name, required int count});

  /// On the user card: when the account was made. date is a date (« 1 nov. 2026 »).
  ///
  /// In en, this message translates to:
  /// **'Account created {date}'**
  String chatUserAccountCreated({required String date});

  /// On the user card, for a moderator: since when the user follows the channel. No agreement with the user.
  ///
  /// In en, this message translates to:
  /// **'Following since {date}'**
  String chatUserFollowingSince({required String date});

  /// The title of the sheet over a message hidden by the chat filters.
  ///
  /// In en, this message translates to:
  /// **'Message hidden'**
  String get chatFilteredTitle;

  /// The text of the same sheet.
  ///
  /// In en, this message translates to:
  /// **'This message was hidden by your chat filters. Show it anyway?'**
  String get chatFilteredBody;

  /// The same sheet's button that shows the message.
  ///
  /// In en, this message translates to:
  /// **'Show message'**
  String get chatFilteredShow;

  /// The chat details' row that opens the channel's chat rules, and the back header over them.
  ///
  /// In en, this message translates to:
  /// **'Chat rules'**
  String get chatRulesTitle;

  /// The heading of the channel's chat rules sheet.
  ///
  /// In en, this message translates to:
  /// **'Chat rules'**
  String get chatRulesHeading;

  /// The button that accepts a channel's chat rules.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get chatRulesAccept;

  /// What a screen reader says for the card at the top of a chat the viewer joined with a raid. from is the raiding channel, target this one.
  ///
  /// In en, this message translates to:
  /// **'You followed {from}’s raid. Welcome to {target}’s chat'**
  String chatRaidWelcomeSemantics({
    required String from,
    required String target,
  });

  /// The card at the top of a chat the viewer joined with a raid; name (the raiding channel) is drawn bold. Also the line it stands for in chat.
  ///
  /// In en, this message translates to:
  /// **'You followed {name}’s raid'**
  String chatRaidWelcomeFrom({required String name});

  /// The same card's second line. name is this channel.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {name}’s chat'**
  String chatRaidWelcomeTo({required String name});

  /// Above the list of a gift bomb's recipients: how many got their sub so far.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{received} of {count} recipient} other{{received} of {count} recipients}}'**
  String chatGiftRecipientsReceived({
    required int received,
    required int count,
  });

  /// The same once every recipient got their sub.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} recipient} other{{count} recipients}}'**
  String chatGiftRecipients({required int count});

  /// The last pill of a gift bomb's recipients: how many are not shown.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{+{count} more} other{+{count} more}}'**
  String chatGiftRecipientsMore({required int count});

  /// Who gave anonymous gift subs, in the gift sub lines and pins, in place of the name of Twitch's anonymous gifter account. French says « Anonyme » (no gender).
  ///
  /// In en, this message translates to:
  /// **'An anonymous gifter'**
  String get chatAnonymousGifter;

  /// The preview card of a clip link posted in chat, when the clip has no title.
  ///
  /// In en, this message translates to:
  /// **'Untitled clip'**
  String get chatLinkUntitledClip;

  /// The preview card of a video link posted in chat, when the video has no title.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get chatLinkUntitled;

  /// The kind on a clip link's preview card in chat, before its length and views (« Clip · 0:30 · 1,5 k vues »).
  ///
  /// In en, this message translates to:
  /// **'Clip'**
  String get chatLinkClip;

  /// The kind on a video link's preview card in chat, before its length and views.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get chatLinkVideo;

  /// The views on a link's preview card in chat. views is the number, short (1.5K); count chooses the form.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{views} view} other{{views} views}}'**
  String chatLinkViews({required int count, required String views});

  /// The title of the dialog that asks a moderator for a ban's reason.
  ///
  /// In en, this message translates to:
  /// **'Ban {name}?'**
  String chatModBarBanTitle({required String name});

  /// The moderation bar's ban button, and the button of the dialog it opens.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get chatModBarBan;

  /// The title of the dialog that asks a moderator for a warning's reason.
  ///
  /// In en, this message translates to:
  /// **'Warn {name}'**
  String chatModBarWarnTitle({required String name});

  /// The moderation bar's warn button, and the button of the dialog it opens.
  ///
  /// In en, this message translates to:
  /// **'Warn'**
  String get chatModBarWarn;

  /// The shortest timeout of the moderation bar's menu: it removes the user's messages.
  ///
  /// In en, this message translates to:
  /// **'1 second (purge)'**
  String get chatModBarPurge;

  /// What a screen reader says for the moderation bar's button that opens the timeout lengths, in full (the button shows chatModBarTimeoutShort).
  ///
  /// In en, this message translates to:
  /// **'Timeout'**
  String get chatModBarTimeout;

  /// The label shown on the moderation bar's timeout button (chatModBarTimeout is what a screen reader says): short, so the bar's four buttons fit a phone. Its chevron and the lengths menu say the exclusion is temporary.
  ///
  /// In en, this message translates to:
  /// **'Timeout'**
  String get chatModBarTimeoutShort;

  /// The moderation bar's unban button (lifts a ban or a timeout).
  ///
  /// In en, this message translates to:
  /// **'Unban'**
  String get chatModBarUnban;

  /// The reason field of the warn dialog (required).
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get chatModBarReason;

  /// The reason field of the ban dialog.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get chatModBarReasonOptional;

  /// The name of channel points when the channel gave none of its own: the button beside the chat input and the sheet's heading (in capitals).
  ///
  /// In en, this message translates to:
  /// **'Channel points'**
  String get pointsChannelPoints;

  /// The channel points sheet when the viewer is not logged in.
  ///
  /// In en, this message translates to:
  /// **'Log in to see your balance.'**
  String get pointsLogInForBalance;

  /// The heading of the prediction in the channel points sheet, while it takes bets.
  ///
  /// In en, this message translates to:
  /// **'Prediction — open'**
  String get pointsPredictionOpen;

  /// The same, once it no longer takes bets.
  ///
  /// In en, this message translates to:
  /// **'Prediction — locked'**
  String get pointsPredictionLocked;

  /// The heading of the channel's rewards in the channel points sheet.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get pointsRewards;

  /// The channel points sheet when the channel has neither rewards nor a prediction.
  ///
  /// In en, this message translates to:
  /// **'This channel has no rewards set up.'**
  String get pointsNoRewards;

  /// Under the watch streak in the channel points sheet.
  ///
  /// In en, this message translates to:
  /// **'Twitch counts streaks. Watching in this app may not count toward them.'**
  String get pointsStreakNote;

  /// Error message. The channel points sheet when Twitch refuses the bonus to the app.
  ///
  /// In en, this message translates to:
  /// **'Twitch’s anti-bot check blocks collecting the bonus here. Collect it on twitch.tv and your balance updates.'**
  String get pointsBonusBlocked;

  /// The channel points sheet's button that collects the bonus chest.
  ///
  /// In en, this message translates to:
  /// **'Collect bonus'**
  String get pointsCollectBonus;

  /// Under a prediction's outcome: the points bet on it, then how many bet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{points} · {count} viewer} other{{points} · {count} viewers}}'**
  String pointsOutcomeTotals({required String points, required int count});

  /// What a screen reader says for an outcome of an open prediction. title is the outcome (Twitch's text), odds the payout (1.85).
  ///
  /// In en, this message translates to:
  /// **'Bet on {title}, pays {odds} times'**
  String pointsBetOn({required String title, required String odds});

  /// The same before anyone bet on it.
  ///
  /// In en, this message translates to:
  /// **'Bet on {title}, payout unknown'**
  String pointsBetOnUnknown({required String title});

  /// Under an open prediction in the channel points sheet.
  ///
  /// In en, this message translates to:
  /// **'Tap an outcome to bet.'**
  String get pointsTapToBet;

  /// The heading of the bet view, above the outcome (written in capitals).
  ///
  /// In en, this message translates to:
  /// **'BET ON'**
  String get pointsBetHeading;

  /// The bet view: the viewer's points.
  ///
  /// In en, this message translates to:
  /// **'Balance {points}'**
  String pointsBalance({required String points});

  /// The bet view when the viewer has too few points.
  ///
  /// In en, this message translates to:
  /// **'You need at least {points} points to bet.'**
  String pointsNeedAtLeast({required int points});

  /// What a screen reader calls the bet view's amount pills.
  ///
  /// In en, this message translates to:
  /// **'Stake'**
  String get pointsStake;

  /// The bet view's pill that bets every point.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get pointsMax;

  /// The label of the bet view's amount field.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get pointsField;

  /// The bet view before anyone bet on the outcome.
  ///
  /// In en, this message translates to:
  /// **'No odds yet.'**
  String get pointsNoOdds;

  /// The bet view: the payout for the stake typed. odds has two decimals.
  ///
  /// In en, this message translates to:
  /// **'Pays about {odds}× if this wins. Odds change with every bet.'**
  String pointsPaysAbout({required String odds});

  /// The bet view's button once an amount is typed. points is the amount, written with the language's digits; count is the same amount as a number, for the plural.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Bet {points}} other{Bet {points}}}'**
  String pointsBetAmount({required String points, required int count});

  /// The bet view's button before an amount is typed.
  ///
  /// In en, this message translates to:
  /// **'Bet'**
  String get pointsBet;

  /// The payout beside a prediction's outcome (1.85 ×).
  ///
  /// In en, this message translates to:
  /// **'{odds}×'**
  String pointsOdds({required String odds});

  /// The title of the dialog that confirms redeeming a reward.
  ///
  /// In en, this message translates to:
  /// **'Spend {points} points?'**
  String pointsSpend({required String points});

  /// The field of a reward that asks for a message.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get pointsYourMessage;

  /// The button that redeems a reward.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get pointsRedeem;

  /// Snackbar after spending channel points (a reward, a bet, the bonus). status is PointsActionStatus.name; reason is Twitch's own code for an unknown refusal (never translated), or pointsNoReason.
  ///
  /// In en, this message translates to:
  /// **'{status, select, success{Done.} integrityRefused{Twitch’s anti-bot check refused this. ONSET can’t pass it, so try on twitch.tv.} notAuthenticated{Twitch rejected the login. Log in again to spend points.} network{Couldn’t reach Twitch. Try again.} other{Twitch refused: {reason}}}'**
  String pointsResult({required String status, required String reason});

  /// Snackbar when the viewer spends channel points while the last spend still runs.
  ///
  /// In en, this message translates to:
  /// **'Already in progress.'**
  String get pointsBusy;

  /// After « Twitch refused: » when Twitch gave no reason.
  ///
  /// In en, this message translates to:
  /// **'no reason given'**
  String get pointsNoReason;

  /// The name of one of Twitch's built-in rewards (Twitch sends none for them).
  ///
  /// In en, this message translates to:
  /// **'{type, select, highlight{Highlight my message} randomEmote{Unlock a random sub emote} chosenEmote{Choose an emote to unlock} modifiedEmote{Modify a single emote} subOnlyMessage{Send a message in sub-only mode} other{}}'**
  String pointsAutomaticReward({required String type});

  /// The watch streak card when the streak is suspended and the channel is live.
  ///
  /// In en, this message translates to:
  /// **'Keep watching to save your Watch Streak!'**
  String get streakSaveTitle;

  /// Under the same title: how long the streak is (in streams).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Watch this live stream and you’ll be able to save your current {count}-stream streak.} other{Watch this live stream and you’ll be able to save your current {count}-stream streak.}}'**
  String streakSaveLive({required int count});

  /// The watch streak card when the streak is suspended and the channel is offline.
  ///
  /// In en, this message translates to:
  /// **'Watch Streak expiring'**
  String get streakExpiringTitle;

  /// Under the same title: the time left to save the streak. name is the channel's display name; time is the time left, short (chatShort…: « 5h 12m », « 4m 30s », « 12s »).
  ///
  /// In en, this message translates to:
  /// **'Watch {name} in the next {time} to save your streak!'**
  String streakExpiring({required String name, required String time});

  /// The watch streak card's title: how many streams in a row.
  ///
  /// In en, this message translates to:
  /// **'Your Watch Streak: {value}'**
  String streakYour({required int value});

  /// Under the watch streak's title: one stream before the bonus. points is the bonus (« 1 200 »); count chooses the form.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 more stream to earn {points} bonus channel point} other{1 more stream to earn {points} bonus channel points}}'**
  String streakOneMore({required int count, required String points});

  /// Under the watch streak's title once the bonus was earned. next is the streak's length in streams.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{You reached a {next}-stream streak and earned {points} bonus channel point} other{You reached a {next}-stream streak and earned {points} bonus channel points}}'**
  String streakReached({
    required int count,
    required int next,
    required String points,
  });

  /// Under the watch streak's title: the next bonus.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Reach a {next}-stream streak and earn {points} bonus channel point} other{Reach a {next}-stream streak and earn {points} bonus channel points}}'**
  String streakReach({
    required int count,
    required int next,
    required String points,
  });

  /// An emote's details: how the viewer gets to use it, like Twitch's emote card. « la » / « l’ » stand for the emote (feminine).
  ///
  /// In en, this message translates to:
  /// **'{how, select, global{Available to everyone on Twitch.} owned{You can use it.} follow{Follow this channel to use it.} bits{Cheer Bits in this channel to unlock it.} subscribe{Subscribe to this channel to use it.} other{}}'**
  String emoteUnlockHint({required String how});

  /// The same, for an emote of a higher sub tier.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to this channel at Tier {tier} to use it.'**
  String emoteUnlockTier({required int tier});

  /// An emote's kind, in its details. type is EmoteType.name.
  ///
  /// In en, this message translates to:
  /// **'{type, select, twitchBits{Twitch Bits emote} twitchFollower{Twitch follower emote} twitchSub{Twitch sub emote} twitchGlobal{Twitch global emote} twitchUnlocked{Twitch unlocked emote} twitchChannel{Twitch channel emote} ffzGlobal{FrankerFaceZ global emote} ffzChannel{FrankerFaceZ channel emote} bttvGlobal{BetterTTV global emote} bttvChannel{BetterTTV channel emote} bttvShared{BetterTTV shared emote} sevenTVGlobal{7TV global emote} sevenTVChannel{7TV channel emote} other{}}'**
  String emoteTypeName({required String type});

  /// A chat badge's source, in its details. type is BadgeType.name.
  ///
  /// In en, this message translates to:
  /// **'{type, select, twitch{Twitch badge} bttv{BetterTTV badge} ffz{FrankerFaceZ badge} sevenTV{7TV badge} other{}}'**
  String badgeTypeName({required String type});

  /// A sub line in chat: who subscribed, and how (plan: prime, tier, or other when Twitch did not say). Names are drawn bold where their placeholder is; French puts them where no word agrees with them.
  ///
  /// In en, this message translates to:
  /// **'{plan, select, prime{{name} subscribed with Prime.} tier{{name} subscribed at Tier {tier}.} other{{name} subscribed.}}'**
  String noticeSubscribed({
    required String plan,
    required String name,
    required int tier,
  });

  /// The same line for a resub (Twitch words both alike in English; French says « Réabonnement »). Names are drawn bold where their placeholder is; French puts them where no word agrees with them.
  ///
  /// In en, this message translates to:
  /// **'{plan, select, prime{{name} subscribed with Prime.} tier{{name} subscribed at Tier {tier}.} other{{name} subscribed.}}'**
  String noticeResubscribed({
    required String plan,
    required String name,
    required int tier,
  });

  /// The sentence after a sub line: how long in all, and the streak the subscriber shares.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, one{They’ve subscribed for {months} month, currently on a {streak}-month streak!} other{They’ve subscribed for {months} months, currently on a {streak}-month streak!}}'**
  String noticeSubStreak({required int months, required int streak});

  /// The sentence after a sub line: how long in all (2 months or more).
  ///
  /// In en, this message translates to:
  /// **'They’ve subscribed for {months} months!'**
  String noticeSubMonths({required int months});

  /// A gift sub line in chat. tiered is yes when Twitch named the tier. Names are drawn bold where their placeholder is; French puts them where no word agrees with them.
  ///
  /// In en, this message translates to:
  /// **'{tiered, select, yes{{gifter} gifted a Tier {tier} sub to {recipient}!} other{{gifter} gifted a sub to {recipient}!}}'**
  String noticeGiftedSub({
    required String tiered,
    required String gifter,
    required int tier,
    required String recipient,
  });

  /// A gift of several months of sub. months is noticeGiftMonths, tier noticeGiftTier, both drawn bold. Names are drawn bold where their placeholder is; French puts them where no word agrees with them.
  ///
  /// In en, this message translates to:
  /// **'{gifter} gifted {months} of {tier} to {recipient}!'**
  String noticeGiftedMonthsTier({
    required String gifter,
    required String months,
    required String tier,
    required String recipient,
  });

  /// The same when Twitch did not name the tier. months is noticeGiftMonthsShort, drawn bold. Names are drawn bold where their placeholder is; French puts them where no word agrees with them.
  ///
  /// In en, this message translates to:
  /// **'{gifter} gifted a {months} sub to {recipient}!'**
  String noticeGiftedMonths({
    required String gifter,
    required String months,
    required String recipient,
  });

  /// Inside noticeGiftedMonthsTier: how many months were gifted (drawn bold).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} month} other{{count} months}}'**
  String noticeGiftMonths({required int count});

  /// Inside noticeGiftedMonths: how many months were gifted, as English writes it before « Sub » (drawn bold).
  ///
  /// In en, this message translates to:
  /// **'{count}-month'**
  String noticeGiftMonthsShort({required int count});

  /// Inside noticeGiftedMonthsTier: the sub tier (drawn bold).
  ///
  /// In en, this message translates to:
  /// **'Tier {tier}'**
  String noticeGiftTier({required int tier});

  /// The sentence after a gift sub line: the gifter's first. « son » agrees with « abonnement ».
  ///
  /// In en, this message translates to:
  /// **'It’s their first gift sub in the channel!'**
  String get noticeGiftFirst;

  /// The sentence after a gift sub line: how many the gifter gave in all (2 or more), with the language's thousands separator. French opens with « Son total » (the gifter's, after the sentence naming them), so it never reads as the channel's total.
  ///
  /// In en, this message translates to:
  /// **'They’ve given {count} gift subs in the channel!'**
  String noticeGiftCount({required int count});

  /// A gift bomb's line in chat: who gifts how many subs to the channel's community (gifter bold). tiered is yes when Twitch named the tier; end is more when another sentence follows (a full stop), else last (an exclamation mark). Names are drawn bold where their placeholder is; French puts them where no word agrees with them.
  ///
  /// In en, this message translates to:
  /// **'{tiered, select, yes{{count, plural, one{{gifter} is gifting {count} Tier {tier} sub to {channel}’s community{end, select, more{.} other{!}}} other{{gifter} is gifting {count} Tier {tier} subs to {channel}’s community{end, select, more{.} other{!}}}}} other{{count, plural, one{{gifter} is gifting {count} sub to {channel}’s community{end, select, more{.} other{!}}} other{{gifter} is gifting {count} subs to {channel}’s community{end, select, more{.} other{!}}}}}}'**
  String noticeCommunityGift({
    required String tiered,
    required int count,
    required String gifter,
    required int tier,
    required String channel,
    required String end,
  });

  /// The sentence after a gift bomb's line: the gifter's first gift.
  ///
  /// In en, this message translates to:
  /// **'It’s their first gift sub in the channel!'**
  String get noticeCommunityGiftFirst;

  /// The sentence after a gift bomb's line: how many subs the gifter gave in all, with the language's thousands separator. French opens with « Son total » (the gifter's).
  ///
  /// In en, this message translates to:
  /// **'They’ve gifted a total of {count} subs in the channel!'**
  String noticeCommunityGiftTotal({required int count});

  /// A line when a subscriber extended their sub. month is a month's name (« mai »); « son » agrees with « abonnement ». Names are drawn bold where their placeholder is; French puts them where no word agrees with them.
  ///
  /// In en, this message translates to:
  /// **'{tiered, select, yes{{name} extended their Tier {tier} subscription through {month}!} other{{name} extended their subscription through {month}!}}'**
  String noticeExtendedSub({
    required String tiered,
    required String name,
    required int tier,
    required String month,
  });

  /// The line when another channel raids this one: who (drawn bold) and how many viewers they bring. Shown on screens in another language than English only: an English screen shows Twitch's own sentence (system-msg), as it always has. Names are drawn bold where their placeholder is; French puts them where no word agrees with them.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{name} is raiding with {count} viewer!} other{{name} is raiding with {count} viewers!}}'**
  String noticeRaid({required String name, required int count});

  /// The sentence after a sub line when the subscriber paid for several months at once.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{They paid for {count} month in advance.} other{They paid for {count} months in advance.}}'**
  String noticeSubMultiMonth({required int count});

  /// The sentence after a resub line when the sub is a multi-month gift. month is the month reached, total the gift’s length, gifter the gifter’s name.
  ///
  /// In en, this message translates to:
  /// **'Month {month} of a {total}-month gift sub from {gifter}.'**
  String noticeGiftRedeemed({
    required int month,
    required int total,
    required String gifter,
  });

  /// The same, from an anonymous gifter.
  ///
  /// In en, this message translates to:
  /// **'Month {month} of a {total}-month gift sub from an anonymous gifter.'**
  String noticeGiftRedeemedAnonymous({required int month, required int total});

  /// A line in chat when a viewer keeps paying for a gift sub. Names are drawn bold where their placeholder is.
  ///
  /// In en, this message translates to:
  /// **'{name} is continuing the gift sub they got from {gifter}!'**
  String noticeGiftPaidUpgrade({required String name, required String gifter});

  /// The same, when the gift was anonymous.
  ///
  /// In en, this message translates to:
  /// **'{name} is continuing the gift sub they got from an anonymous gifter!'**
  String noticeGiftPaidUpgradeAnonymous({required String name});

  /// A line in chat when a viewer who got a gift sub gifts one to someone. Names are drawn bold where their placeholder is.
  ///
  /// In en, this message translates to:
  /// **'{name} is paying forward the gift sub they got from {gifter} to {recipient}!'**
  String noticePayForward({
    required String name,
    required String gifter,
    required String recipient,
  });

  /// The same, gifted to the community.
  ///
  /// In en, this message translates to:
  /// **'{name} is paying forward the gift sub they got from {gifter} to the community!'**
  String noticePayForwardCommunity({
    required String name,
    required String gifter,
  });

  /// A line in chat when a sponsor adds gift subs. sponsor is the sponsor’s name, drawn bold.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{sponsor} added {count} bonus gift sub!} other{{sponsor} added {count} bonus gift subs!}}'**
  String noticeSponsorBonus({required String sponsor, required int count});

  /// A line in chat when a purchase shares rewards with other viewers. name is the buyer, drawn bold.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Thanks to {name}, {count} other viewer gets a reward!} other{Thanks to {name}, {count} other viewers get a reward!}}'**
  String noticeRewardGift({required String name, required int count});

  /// A line in chat when a viewer shares a watch streak. name is drawn bold.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{name} reached a {count}-stream Watch Streak!} other{{name} reached a {count}-stream Watch Streak!}}'**
  String noticeWatchStreak({required String name, required int count});

  /// The sentence after a watch streak line: the channel points it earned.
  ///
  /// In en, this message translates to:
  /// **'{points, plural, one{They earned {points} channel point.} other{They earned {points} channel points.}}'**
  String noticeWatchStreakPoints({required int points});

  /// A line in chat when a viewer donates to the channel’s charity. amount is formatted with its currency; name and charity are drawn bold.
  ///
  /// In en, this message translates to:
  /// **'{name} donated {amount} to {charity}!'**
  String noticeCharity({
    required String name,
    required String amount,
    required String charity,
  });

  /// Copies the video's link at the playback position: the player settings sheet's tile and a tablet's action pill.
  ///
  /// In en, this message translates to:
  /// **'Copy link at current time'**
  String get vodCopyLinkAtTime;

  /// What kind of video it is, in a tablet's top row over the player: a stream kept after it ended.
  ///
  /// In en, this message translates to:
  /// **'Past broadcast'**
  String get vodKindArchive;

  /// The same: a part of a stream the streamer kept.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get vodKindHighlight;

  /// The same: a video the streamer uploaded.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get vodKindUpload;

  /// A playback speed other than normal, in the player's speed pills and its speed button. rate is the speed written with the language's decimal separator (« 1,25 »).
  ///
  /// In en, this message translates to:
  /// **'{rate}×'**
  String vodPlaybackRate({required String rate});

  /// The note once a link was copied (a video's link at the current time, or a link the system could not share).
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get vodLinkCopied;

  /// A tablet's action pill beside the video: shares its link at the current time.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get vodShare;

  /// Opens the channel of the video (a tablet's channel card) or of a chat replay message's author (the sheet that opens on their name).
  ///
  /// In en, this message translates to:
  /// **'Open channel'**
  String get vodOpenChannel;

  /// A tablet's action pill: the playback speed, other than normal (vodSpeedPillNormal); tapping opens the settings. rate is a speed (vodPlaybackRate, « 1,25 × »).
  ///
  /// In en, this message translates to:
  /// **'Speed {rate}'**
  String vodSpeedPill({required String rate});

  /// The same pill at the normal speed. French: « normale » in lower case, inside the pill's words.
  ///
  /// In en, this message translates to:
  /// **'Normal speed'**
  String get vodSpeedPillNormal;

  /// A tablet's action pill: the video quality; tapping opens the settings. quality is the rendition's name (1080p60); Auto and Audio only have their own messages.
  ///
  /// In en, this message translates to:
  /// **'Quality {quality}'**
  String vodQualityPill({required String quality});

  /// The same pill on the adaptive quality. French: « auto » in lower case, inside the pill's words.
  ///
  /// In en, this message translates to:
  /// **'Auto quality'**
  String get vodQualityPillAuto;

  /// The same pill when only the sound plays. French: in lower case, inside the pill's words.
  ///
  /// In en, this message translates to:
  /// **'Audio only'**
  String get vodQualityPillAudioOnly;

  /// What a screen reader says for a tablet's captions pill: whether captions show. state is on or off.
  ///
  /// In en, this message translates to:
  /// **'{state, select, on{Closed captions, on} other{Closed captions, off}}'**
  String vodCaptionsState({required String state});

  /// A tablet's legend under the video, beside a short grey bar: the marks on the seek bar are parts Twitch muted for copyright.
  ///
  /// In en, this message translates to:
  /// **'Muted segments (copyright)'**
  String get vodLegendMuted;

  /// A tablet's legend under the video: double-tapping the left or right of the video goes back or forward 10 seconds.
  ///
  /// In en, this message translates to:
  /// **'Double-tap the sides to skip 10 seconds'**
  String get vodLegendDoubleTap;

  /// A tablet's legend under the video: another video plays when this one ends.
  ///
  /// In en, this message translates to:
  /// **'Up next at the end'**
  String get vodLegendUpNext;

  /// The same, with when it plays by itself. autoplay is the setting's value (« Wi-Fi uniquement », « Données mobiles et Wi-Fi »).
  ///
  /// In en, this message translates to:
  /// **'Up next at the end · {autoplay}'**
  String vodLegendUpNextWhen({required String autoplay});

  /// What a screen reader calls the video's seek bar (a slider).
  ///
  /// In en, this message translates to:
  /// **'Seek'**
  String get vodSeek;

  /// What a screen reader says the seek bar is at. position and duration are times (« 1:02:15 »).
  ///
  /// In en, this message translates to:
  /// **'{position} of {duration}'**
  String vodSeekValue({required String position, required String duration});

  /// The heading of the card shown at the end of a video with the video that plays next (shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get vodUpNext;

  /// Beside « Up Next »: the seconds before the next video plays by itself. French reads as a countdown with the unit's symbol (« dans 10 s »), which fits beside « À SUIVRE » and the Cancel button on a phone at large text.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} second} other{{count} seconds}}'**
  String vodUpNextSeconds({required int count});

  /// Under the next video's title when it is from another channel, picked as similar. channel is its channel's name.
  ///
  /// In en, this message translates to:
  /// **'{channel} · Similar video'**
  String vodUpNextSimilar({required String channel});

  /// Tooltip of the round button on the up next card: plays the next video at once.
  ///
  /// In en, this message translates to:
  /// **'Play now'**
  String get vodPlayNow;

  /// The title of the pane showing the chat as it was during the broadcast, under or beside the video.
  ///
  /// In en, this message translates to:
  /// **'Chat replay'**
  String get vodReplayTitle;

  /// The pill beside « Chat replay »: the replay follows the video. Lower case; French keeps one word, the title says what it follows (a tablet's live chat says it in full: channelChatSynced).
  ///
  /// In en, this message translates to:
  /// **'synced to video'**
  String get vodReplaySynced;

  /// The note under the chat replay's info button: why some emotes may look different from the broadcast.
  ///
  /// In en, this message translates to:
  /// **'7TV, BTTV, and FFZ emotes are the channel’s current sets, which may differ from the ones used during the broadcast.'**
  String get vodReplayEmotesNote;

  /// Tooltip of the chat replay's info button (it shows vodReplayEmotesNote).
  ///
  /// In en, this message translates to:
  /// **'About emotes in replays'**
  String get vodReplayEmotesAbout;

  /// Shown in the chat replay pane for an uploaded video (it never had a chat).
  ///
  /// In en, this message translates to:
  /// **'Uploads have no chat replay'**
  String get vodReplayNotForUploads;

  /// Shown in the chat replay pane when Twitch gives no chat for this video, with Retry.
  ///
  /// In en, this message translates to:
  /// **'Chat replay is unavailable for this video'**
  String get vodReplayUnavailable;

  /// Shown in the chat replay pane when no one wrote yet at this point of the video.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get vodReplayNoMessages;

  /// Under the placeholder rows while the chat replay loads.
  ///
  /// In en, this message translates to:
  /// **'Loading chat replay…'**
  String get vodReplayLoading;

  /// Error message. A whisper could not be sent: the conversation on screen was opened with another Twitch account than the one logged in now.
  ///
  /// In en, this message translates to:
  /// **'This conversation belongs to another account.'**
  String get whisperOtherAccount;

  /// Error message. A whisper could not be sent: it is too long for Twitch. max is the limit, with the language's thousands separator (10,000).
  ///
  /// In en, this message translates to:
  /// **'Whispers can be {max} characters at most.'**
  String whisperTooLong({required int max});

  /// Error message. A whisper could not be sent: the viewer's login predates the whisper permission.
  ///
  /// In en, this message translates to:
  /// **'Log in again to whisper from this app.'**
  String get whisperLogInAgain;

  /// Error message. A whisper could not be sent for an unexpected reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t whisper (unexpected error).'**
  String get whisperFailedUnexpected;

  /// The title of the notification when a followed channel goes live. name is the channel's display name. Shown in the system's notification and in the Activity list.
  ///
  /// In en, this message translates to:
  /// **'{name} is live'**
  String notifGoLiveTitle({required String name});

  /// The text of a go-live or reminder notification: the stream's title (as the streamer wrote it) and its category. French puts the category first. Shown in the system's notification and in the Activity list.
  ///
  /// In en, this message translates to:
  /// **'{title} · {category}'**
  String notifStreamBody({required String title, required String category});

  /// The notification summing up the channels that went live beyond the first five at once. count is how many.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} more channel went live} other{{count} more channels went live}}'**
  String notifGoLiveMore({required int count});

  /// The title of the notification saying the background check stopped (its text: goLiveLogInAgain, Twitch refused the login).
  ///
  /// In en, this message translates to:
  /// **'Go-live notifications paused'**
  String get notifGoLivePaused;

  /// The title of the notification when someone mentions the viewer in a chat open in the background. sender is who wrote, channel the channel's display name; the message follows as the text. Shown in the system's notification and in the Activity list.
  ///
  /// In en, this message translates to:
  /// **'{sender} mentioned you in {channel}'**
  String notifMentionTitle({required String sender, required String channel});

  /// The title of the reminder notification set with « Remind me » on a channel's schedule. name is the channel's display name. Shown in the system's notification and in the Activity list.
  ///
  /// In en, this message translates to:
  /// **'{name}’s stream is starting'**
  String notifReminderTitle({required String name});

  /// The text of a reminder notification when the scheduled stream has no title nor category. Shown in the system's notification and in the Activity list.
  ///
  /// In en, this message translates to:
  /// **'Untitled stream'**
  String get notifReminderUntitled;

  /// The go-live notifications. An Android notification channel's name, listed in the system's settings for the app: short, plural, sentence case.
  ///
  /// In en, this message translates to:
  /// **'Go-live notifications'**
  String get notifChannelGoLive;

  /// The go-live notifications. An Android notification channel's description, under its name in the system's settings: one sentence, no final full stop.
  ///
  /// In en, this message translates to:
  /// **'When channels you follow go live'**
  String get notifChannelGoLiveDescription;

  /// The mention notifications. An Android notification channel's name, listed in the system's settings for the app: short, plural, sentence case.
  ///
  /// In en, this message translates to:
  /// **'Chat mentions'**
  String get notifChannelMentions;

  /// The mention notifications. An Android notification channel's description, under its name in the system's settings: one sentence, no final full stop.
  ///
  /// In en, this message translates to:
  /// **'When someone mentions you in a chat you’re watching while ONSET is in the background'**
  String get notifChannelMentionsDescription;

  /// The reminders set on channels' schedules. An Android notification channel's name, listed in the system's settings for the app: short, plural, sentence case.
  ///
  /// In en, this message translates to:
  /// **'Stream reminders'**
  String get notifChannelReminders;

  /// The reminders set on channels' schedules. An Android notification channel's description, under its name in the system's settings: one sentence, no final full stop.
  ///
  /// In en, this message translates to:
  /// **'When a scheduled stream you set a reminder for starts'**
  String get notifChannelRemindersDescription;

  /// The notification of a stream or video playing in the background (its controls). An Android notification channel's name, listed in the system's settings for the app: short, plural, sentence case.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get mediaChannel;

  /// The media notification's button that resumes the stream.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get mediaPlay;

  /// The media notification's button that pauses the stream.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get mediaPause;

  /// The media notification's button that stops the stream and removes the notification.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get mediaStop;

  /// The title of the dialog shown when Twitch refuses a request because the logged-in session lacks a permission this version needs.
  ///
  /// In en, this message translates to:
  /// **'Missing permissions'**
  String get authMissingPermissionsTitle;

  /// Error message. The text of the same dialog; « Log in » follows.
  ///
  /// In en, this message translates to:
  /// **'Your session is missing permissions. Log in again to continue.'**
  String get authMissingPermissions;

  /// The title of the dialog shown when Twitch refuses a request because the session ended.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get authSessionExpiredTitle;

  /// Error message. The text of the same dialog; « Log in » follows.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Log in again to continue.'**
  String get authSessionExpired;

  /// The dialog's button that opens the Twitch login page.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLogIn;
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
