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

  /// Onboarding Log in step, permission list: what the moderation permissions allow in chats the viewer moderates (the channel tools are asked for later, only by a broadcaster who turns them on).
  ///
  /// In en, this message translates to:
  /// **'Bans, AutoMod, terms, shield mode, chat modes'**
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

  /// Settings › General › Links: a switch; when on, a link from chat or a channel’s profile that leaves Twitch asks first. On by default.
  ///
  /// In en, this message translates to:
  /// **'Ask before opening links'**
  String get settingsConfirmLinks;

  /// Settings › General › Links: under “Ask before opening links”.
  ///
  /// In en, this message translates to:
  /// **'Shows where a link from chat or a channel’s profile leads before opening it.'**
  String get settingsConfirmLinksDetail;

  /// Dialog title before opening a link from chat or a channel’s profile that leaves Twitch.
  ///
  /// In en, this message translates to:
  /// **'Open this link?'**
  String get linkConfirmTitle;

  /// Dialog body before opening an outside link. host is the website's address (example.com), in bold; the full link shows under it.
  ///
  /// In en, this message translates to:
  /// **'This link leads to {host}, outside ONSET.'**
  String linkConfirmBody({required String host});

  /// Outside-link dialog: a switch; when on, opening the link turns off “Ask before opening links”.
  ///
  /// In en, this message translates to:
  /// **'Don’t ask again'**
  String get linkConfirmDontAsk;

  /// Outside-link dialog: the button that opens the link.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get linkConfirmOpen;

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

  /// Settings › Video › Playback (Android), under « Background audio » while it is on: the switch that keeps the sound playing outside the app only when headphones are connected.
  ///
  /// In en, this message translates to:
  /// **'Only with headphones'**
  String get settingsBackgroundAudioHeadphonesOnly;

  /// Settings › Video › Playback: what « Only with headphones » does.
  ///
  /// In en, this message translates to:
  /// **'Pauses the live stream when you leave the app with no headphones connected.'**
  String get settingsBackgroundAudioHeadphonesOnlyDetail;

  /// Settings › Video › Playback: switch that lets a playing video move to the floating window when you leave the app (Android).
  ///
  /// In en, this message translates to:
  /// **'Automatic picture-in-picture'**
  String get settingsAutoPip;

  /// Settings › Video › Playback: what « Automatic picture-in-picture » does.
  ///
  /// In en, this message translates to:
  /// **'Keeps a playing video in a floating window when you leave the app.'**
  String get settingsAutoPipDetail;

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

  /// Settings › Chat › Message appearance, and the chat menu: a switch that adjusts viewers’ name colors that are hard to read on the background. On by default.
  ///
  /// In en, this message translates to:
  /// **'Readable name colors'**
  String get settingsReadableNameColors;

  /// Settings › Chat › Message appearance: under “Readable name colors”.
  ///
  /// In en, this message translates to:
  /// **'Lightens or darkens name colors that would be hard to read on the background.'**
  String get settingsReadableNameColorsDetail;

  /// Settings › Chat and the chat menu: under “Readable name colors”, greyed out, while “Increase chat contrast” is on (which keeps names readable).
  ///
  /// In en, this message translates to:
  /// **'Always on while chat contrast is increased.'**
  String get settingsReadableNameColorsLocked;

  /// Settings › Chat › Message appearance, and the chat menu: a switch that gives name colors a stronger contrast. Off by default.
  ///
  /// In en, this message translates to:
  /// **'Increase chat contrast'**
  String get settingsIncreaseChatContrast;

  /// Settings › Chat › Message appearance: under “Increase chat contrast”.
  ///
  /// In en, this message translates to:
  /// **'Gives name colors a stronger contrast with the background.'**
  String get settingsIncreaseChatContrastDetail;

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

  /// Settings › Chat › Layout: the title of the three chat heights under the video in portrait (Low, Medium, High).
  ///
  /// In en, this message translates to:
  /// **'Chat height in portrait'**
  String get settingsPortraitChatHeight;

  /// Settings › Chat › Layout: under “Chat height in portrait”, the bar between the video and chat sets any height.
  ///
  /// In en, this message translates to:
  /// **'You can also drag the bar under the video.'**
  String get settingsPortraitChatHeightDetail;

  /// Settings › Chat › Layout, “Chat height in portrait”: the least room for chat (the video takes the full width). One segment of a three-part pill.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get portraitChatHeightLow;

  /// Settings › Chat › Layout, “Chat height in portrait”: halfway. One segment of a three-part pill.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get portraitChatHeightMedium;

  /// Settings › Chat › Layout, “Chat height in portrait”: the most room for chat (the smallest video). One segment of a three-part pill.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get portraitChatHeightHigh;

  /// Settings › Chat › Layout, “Chat height in portrait”: a height set by dragging the bar under the video (feminine in French: la hauteur).
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get portraitChatHeightCustom;

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

  /// Settings › Chat › Landscape mode: a switch; when on, tapping the chat drawn over the full-screen video hides it. Off by default.
  ///
  /// In en, this message translates to:
  /// **'Tap to close chat overlay'**
  String get settingsTapToCloseOverlay;

  /// Settings › Chat › Landscape mode: under “Tap to close chat overlay”.
  ///
  /// In en, this message translates to:
  /// **'Tapping an empty part of the chat over the video hides the chat.'**
  String get settingsTapToCloseOverlayDetail;

  /// Settings › Chat: the title of the group choosing which chat layouts a double tap on the landscape video moves through. Shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Double-tap the video in landscape'**
  String get settingsChatSwitching;

  /// Settings › Chat › Double-tap the video in landscape: a switch for the layout with chat drawn over the full-screen video.
  ///
  /// In en, this message translates to:
  /// **'Chat over the video'**
  String get settingsChatSwitchingOverlay;

  /// Settings › Chat › Double-tap the video in landscape: under the first switch, how the three switches work.
  ///
  /// In en, this message translates to:
  /// **'Double-tapping the video moves to the next layout turned on here. Keep at least two on.'**
  String get settingsChatSwitchingDetail;

  /// Settings › Chat › Double-tap the video in landscape: a switch for the layout with chat in a column beside the video.
  ///
  /// In en, this message translates to:
  /// **'Chat beside the video'**
  String get settingsChatSwitchingColumn;

  /// Settings › Chat › Double-tap the video in landscape: a switch for the layout with the video alone, chat hidden.
  ///
  /// In en, this message translates to:
  /// **'No chat'**
  String get settingsChatSwitchingHidden;

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

  /// The dialog shown before the system asks for the right to notify (turning on go-live or mention notifications, or a stream reminder): its title.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications?'**
  String get notificationPermissionTitle;

  /// The dialog shown before the system asks for the right to notify: what the notifications are for, and that the system's own prompt follows.
  ///
  /// In en, this message translates to:
  /// **'ONSET can tell you when a channel you follow goes live, when someone mentions you in chat, and when a stream you set a reminder for starts. Your device asks for permission next.'**
  String get notificationPermissionMessage;

  /// The dialog shown before the system asks for the right to notify: the button that closes it without asking.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notificationPermissionNotNow;

  /// The dialog shown before the system asks for the right to notify: the button that goes on to the system's prompt.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get notificationPermissionContinue;

  /// Error message. Snackbar when a channel's go-live bell could not be changed (the channel's menu).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t change the bell.'**
  String get goLiveBellFailed;

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

  /// The offline live player: the button that opens the channel's most recent past broadcast.
  ///
  /// In en, this message translates to:
  /// **'Watch latest broadcast'**
  String get streamWatchLatestBroadcast;

  /// Snackbar when the live stream being watched ends and the app opens the past broadcast of that stream.
  ///
  /// In en, this message translates to:
  /// **'The stream ended. Playing its past broadcast.'**
  String get streamEndedPlayingBroadcast;

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

  /// Player: the label left on the video after the viewer accepted the content warning, with the channel’s content classification labels.
  ///
  /// In en, this message translates to:
  /// **'For certain audiences: {labels}'**
  String audienceLabelMature({required String labels});

  /// Player: the label on a stream or video whose creator disclosed paid promotion.
  ///
  /// In en, this message translates to:
  /// **'Includes paid promotion'**
  String get audienceLabelPaidPromotion;

  /// Tooltip of the button that hides the audience and paid promotion labels on the player.
  ///
  /// In en, this message translates to:
  /// **'Hide labels'**
  String get audienceLabelHide;

  /// Snackbar after « Not interested » on a live preview (Home › Live). name is the channel's display name; « En direct » is the tab's name (shellFeedLive).
  ///
  /// In en, this message translates to:
  /// **'You won’t see {name} in Live anymore.'**
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

  /// A clip's screen, under its details: shown when the clip's video and its chat are gone or never existed.
  ///
  /// In en, this message translates to:
  /// **'This clip has no recorded chat.'**
  String get clipNoRecordedChat;

  /// Error message. Over a video's or a clip's player: only the channel's subscribers may watch it. subject is clip or video.
  ///
  /// In en, this message translates to:
  /// **'{subject, select, clip{This clip is available only to subscribers.} other{This video is available only to subscribers.}}'**
  String playbackSubscriberOnly({required String subject});

  /// Error message. Over a video's or a clip's player: Twitch detected a VPN, a proxy or an unblocker. subject is clip or video.
  ///
  /// In en, this message translates to:
  /// **'{subject, select, clip{Twitch blocks this clip while a VPN or proxy is in use.} other{Twitch blocks this video while a VPN or proxy is in use.}}'**
  String playbackProxy({required String subject});

  /// Error message. Over a video's or a clip's player: Twitch only serves it over Wi-Fi, not mobile data. subject is clip or video.
  ///
  /// In en, this message translates to:
  /// **'{subject, select, clip{Connect to Wi-Fi to watch this clip.} other{Connect to Wi-Fi to watch this video.}}'**
  String playbackWifiRequired({required String subject});

  /// Error message. Over a video's or a clip's player: the device lacks the protected playback Twitch requires for it. subject is clip or video.
  ///
  /// In en, this message translates to:
  /// **'{subject, select, clip{Your device can’t play this clip.} other{Your device can’t play this video.}}'**
  String playbackUnsupportedDevice({required String subject});

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

  /// Landscape overlay chat: the handle at the top of the chat that moves it up, down, or to the other side of the screen.
  ///
  /// In en, this message translates to:
  /// **'Move chat'**
  String get overlayChatMove;

  /// Landscape overlay chat: the handle at the bottom of the chat that changes its height.
  ///
  /// In en, this message translates to:
  /// **'Resize chat'**
  String get overlayChatResize;

  /// The title of the drawer of followed channels in the live player, and the tooltip of the player button that opens it.
  ///
  /// In en, this message translates to:
  /// **'Followed channels'**
  String get followedDrawerTitle;

  /// The drawer of followed channels in the live player: the section of channels that are live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get followedDrawerLive;

  /// The drawer of followed channels in the live player, when the viewer follows no channel.
  ///
  /// In en, this message translates to:
  /// **'You don’t follow any channels yet.'**
  String get followedDrawerEmpty;

  /// Error message. The drawer of followed channels in the live player, when the list can’t be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your followed channels.'**
  String get followedDrawerFailed;

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

  /// A video's player: the tooltip of the button that locks the screen, hiding the controls and ignoring touches until unlocked.
  ///
  /// In en, this message translates to:
  /// **'Lock screen'**
  String get vodLockScreen;

  /// A video's player, while the screen is locked: the tooltip of the button that unlocks it and brings the controls back.
  ///
  /// In en, this message translates to:
  /// **'Unlock screen'**
  String get vodUnlockScreen;

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

  /// Button that follows the channel (from ONSET, else on twitch.tv) in the channel profile header and the video's info bar, and that follows a category.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get channelFollow;

  /// The same button once the viewer follows the channel or the category; a tap offers to unfollow. « Suivie » agrees with « chaîne » and « catégorie ».
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get channelFollowing;

  /// Tooltip of the Follow button. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'Follow {name}'**
  String channelFollowTooltip({required String name});

  /// Tooltip of the Following button: the viewer follows the channel. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'You follow {name}'**
  String channelFollowingTooltip({required String name});

  /// Snack bar after following a channel or a category from ONSET. name is its display name.
  ///
  /// In en, this message translates to:
  /// **'You now follow {name}.'**
  String followDone({required String name});

  /// Snack bar after unfollowing a channel or a category from ONSET.
  ///
  /// In en, this message translates to:
  /// **'You no longer follow {name}.'**
  String unfollowDone({required String name});

  /// Snack bar when a follow or an unfollow sent from ONSET fails. status is FollowResult.name (Twitch’s error codes).
  ///
  /// In en, this message translates to:
  /// **'{status, select, tooManyFollows{You follow too many channels. Unfollow one, then try again.} unverifiedEmail{Verify your email address on Twitch to follow.} unverifiedPhone{Verify your phone number on Twitch to follow.} unverifiedPhoneAndEmail{Verify your email address and phone number on Twitch to follow.} forbidden{Twitch doesn’t let you follow this.} refused{Twitch declined this follow.} integrityRefused{Twitch’s anti-bot check refused this. ONSET opens twitch.tv so you can do it there.} signedOut{Log in again to follow from ONSET.} other{Couldn’t reach Twitch. Try again.}}'**
  String followError({required String status});

  /// Dialog title before unfollowing a channel or a category.
  ///
  /// In en, this message translates to:
  /// **'Unfollow {name}?'**
  String unfollowConfirmTitle({required String name});

  /// Dialog text before unfollowing: the change is made on the Twitch account.
  ///
  /// In en, this message translates to:
  /// **'This changes what your Twitch account follows.'**
  String get unfollowConfirmBody;

  /// Confirm button of the unfollow dialog.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get unfollowAction;

  /// Dialog title when a link with followChannel=true opens a channel.
  ///
  /// In en, this message translates to:
  /// **'Follow {name}?'**
  String followConfirmTitle({required String name});

  /// Dialog text when a link with followChannel=true opens a channel.
  ///
  /// In en, this message translates to:
  /// **'A link asked ONSET to follow this channel with your Twitch account.'**
  String get followDeepLinkBody;

  /// Title of the sheet of suggested channels shown after following a channel.
  ///
  /// In en, this message translates to:
  /// **'You follow {name}'**
  String followSuggestionsTitle({required String name});

  /// Under the suggestions sheet title: the suggested channels are live in the followed channel’s category.
  ///
  /// In en, this message translates to:
  /// **'Also live in the same category'**
  String get followSuggestionsSubtitle;

  /// Button that follows every suggested channel (after a confirmation).
  ///
  /// In en, this message translates to:
  /// **'Follow all'**
  String get followAll;

  /// Dialog title before following every suggested channel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Follow this channel?} other{Follow these {count} channels?}}'**
  String followAllConfirmTitle({required int count});

  /// Dialog text before following every suggested channel.
  ///
  /// In en, this message translates to:
  /// **'Each one is added to what your Twitch account follows.'**
  String get followAllConfirmBody;

  /// Snack bar after following the suggested channels.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{You now follow {count} more channel.} other{You now follow {count} more channels.}}'**
  String followAllDone({required int count});

  /// Chat line ONSET adds after a while of watching a channel the viewer doesn’t follow; its action button is “Follow”.
  ///
  /// In en, this message translates to:
  /// **'Enjoying the stream? Follow {name} to know when the channel goes live.'**
  String followCalloutLine({required String name});

  /// Settings › Account: the group of the Twitch account’s gifted sub settings.
  ///
  /// In en, this message translates to:
  /// **'Gifted subs'**
  String get giftSettingsTitle;

  /// Switch of the Twitch account setting that refuses gifted subs in channels the viewer doesn’t follow.
  ///
  /// In en, this message translates to:
  /// **'Block gifted subs in channels you don’t follow'**
  String get giftFollowedOnly;

  /// Under the “block gifted subs” switch.
  ///
  /// In en, this message translates to:
  /// **'Nobody can gift you a sub in a channel you don’t follow.'**
  String get giftFollowedOnlyDetail;

  /// Switch of the Twitch account setting that hides how many subs the viewer gifted.
  ///
  /// In en, this message translates to:
  /// **'Hide your gift count'**
  String get giftHideCount;

  /// Under the “hide your gift count” switch.
  ///
  /// In en, this message translates to:
  /// **'Others won’t see how many subs you’ve gifted.'**
  String get giftHideCountDetail;

  /// Dialog title before changing a gifted sub setting of the Twitch account.
  ///
  /// In en, this message translates to:
  /// **'Change this Twitch setting?'**
  String get giftSettingsConfirmTitle;

  /// Dialog text before changing a gifted sub setting: the change is made on the Twitch account.
  ///
  /// In en, this message translates to:
  /// **'It changes on your Twitch account, not only in ONSET.'**
  String get giftSettingsConfirmBody;

  /// Confirm button of the gifted sub setting dialog.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get giftSettingsChange;

  /// Shown in the gifted subs group when Twitch doesn’t give the settings (no web session, an API change).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your gifted sub settings. Log in again, or try again later.'**
  String get giftSettingsUnavailable;

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

  /// The live player's quality list: the line under a quality Twitch withholds from this viewer (greyed out, not selectable).
  ///
  /// In en, this message translates to:
  /// **'Not available to you'**
  String get livePlayerQualityUnavailable;

  /// The live player's quality list: the line under a quality Twitch withholds from this viewer, with its bitrate first.
  ///
  /// In en, this message translates to:
  /// **'{bitrate} · Not available to you'**
  String livePlayerQualityUnavailableBitrate({required String bitrate});

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

  /// The live player's settings sheet: the heading over the picture-in-picture and background audio switches.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get livePlayerPlayback;

  /// The live player: the button and the settings sheet entry that share the channel's link.
  ///
  /// In en, this message translates to:
  /// **'Share channel'**
  String get livePlayerShareChannel;

  /// Over the live video, before the stream's title, while several channels share one chat. title is the stream's title (Twitch's data).
  ///
  /// In en, this message translates to:
  /// **'Shared chat · {title}'**
  String livePlayerSharedChatTitle({required String title});

  /// Banner above chat when several channels start sharing one chat (one line, title of the banner); also what a screen reader announces.
  ///
  /// In en, this message translates to:
  /// **'Shared chat started'**
  String get sharedChatStarted;

  /// Banner above chat, instead of “Shared chat started”, when the chat was already shared with other channels before the viewer joined (one line, title of the banner); also what a screen reader announces.
  ///
  /// In en, this message translates to:
  /// **'This chat is shared'**
  String get sharedChatOngoing;

  /// Shared chat banner: under its title. count is the number of other channels in the shared chat (at least 1).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Messages from another channel show here too.} other{Messages from {count} other channels show here too.}}'**
  String sharedChatStartedBody({required int count});

  /// Shared chat banner and chat menu: the label before the avatars and names of the channels sharing this chat.
  ///
  /// In en, this message translates to:
  /// **'Sharing chat with'**
  String get sharedChatWith;

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

  /// Error message. Why the app's player cannot play a stream: Twitch detected a VPN, a proxy or an unblocker.
  ///
  /// In en, this message translates to:
  /// **'Twitch blocks this stream while a VPN or proxy is in use.'**
  String get liveRefusedProxy;

  /// Error message. Why the app's player cannot play a stream: Twitch only serves it over Wi-Fi, not mobile data.
  ///
  /// In en, this message translates to:
  /// **'Connect to Wi-Fi to watch this stream.'**
  String get liveRefusedWifiRequired;

  /// Error message. Why the app's player cannot play a stream: the device lacks the protected playback Twitch requires for it.
  ///
  /// In en, this message translates to:
  /// **'Your device can’t play this stream.'**
  String get liveRefusedUnsupportedDevice;

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

  /// Pinned message card above chat: the tooltip and screen-reader label of its close button, which hides this pinned message for the viewer only, for good (others still see it).
  ///
  /// In en, this message translates to:
  /// **'Hide for me'**
  String get highlightHideForMe;

  /// A line ONSET adds to chat when a moderator pins a new message. name is who pinned it (Twitch's data).
  ///
  /// In en, this message translates to:
  /// **'{name} pinned a message.'**
  String chatPinnedBy({required String name});

  /// A line ONSET adds to chat when a new message is pinned and Twitch does not say who pinned it.
  ///
  /// In en, this message translates to:
  /// **'A message was pinned.'**
  String get chatPinnedNew;

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

  /// What a screen reader announces when the chat grows to take more of the screen (typing in landscape).
  ///
  /// In en, this message translates to:
  /// **'Chat expanded'**
  String get chatExpandedAnnouncement;

  /// What a screen reader announces when the chat goes back to its normal size.
  ///
  /// In en, this message translates to:
  /// **'Chat collapsed'**
  String get chatCollapsedAnnouncement;

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
  /// **'{command, select, me{Speak in the third person} color{Change your name color} block{Block a user} unblock{Unblock a user} w{Whisper a user} user{Open a user’s card} disconnect{Reconnect to chat} help{List the commands} ban{Ban a user} unban{Lift a ban} timeout{Time out a user (default 10m; s, m, h, d, w)} untimeout{Lift a timeout} warn{Warn a user} delete{Delete a message} clear{Delete every message} slow{Turn slow mode on (default 30s)} slowoff{Turn slow mode off} followers{Turn followers-only mode on (m, h, d, w, mo)} followersoff{Turn followers-only mode off} subscribers{Turn subscribers-only mode on} subscribersoff{Turn subscribers-only mode off} emoteonly{Turn emote-only mode on} emoteonlyoff{Turn emote-only mode off} uniquechat{Turn unique chat mode on (no repeated messages)} uniquechatoff{Turn unique chat mode off} announce{Send an announcement} announceblue{Send a blue announcement} announcegreen{Send a green announcement} announceorange{Send an orange announcement} announcepurple{Send a purple announcement} shoutout{Give a shoutout to a channel} shield{Turn shield mode on} shieldoff{Turn shield mode off} monitor{Monitor a user’s messages} unmonitor{Stop monitoring a user} restrict{Restrict a user (only moderators see their messages)} unrestrict{Lift a user’s restriction} mods{List the moderators} vips{List the VIPs} mod{Make a user a moderator} unmod{Remove a moderator} vip{Make a user a VIP} unvip{Remove a VIP} marker{Add a stream marker} commercial{Run an ad break (30, 60, 90, 120, 150, or 180 seconds)} raid{Raid a channel} unraid{Cancel the raid} other{}}'**
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
  /// **'Couldn’t {command, select, ban{ban the user} timeout{time out the user} untimeout{lift the timeout} unban{unban the user} warn{warn the user} delete{delete the message} clear{clear the chat} slowOn{turn slow mode on} slowOff{turn slow mode off} followersOn{turn followers-only mode on} followersOff{turn followers-only mode off} subscribersOn{turn subscribers-only mode on} subscribersOff{turn subscribers-only mode off} emoteOnlyOn{turn emote-only mode on} emoteOnlyOff{turn emote-only mode off} uniqueChatOn{turn unique chat mode on} uniqueChatOff{turn unique chat mode off} announce{send the announcement} shoutout{send the shoutout} mods{list the moderators} vips{list the VIPs} mod{add the moderator} unmod{remove the moderator} vip{add the VIP} unvip{remove the VIP} shieldOn{turn shield mode on} shieldOff{turn shield mode off} marker{add the stream marker} commercial{start the ad break} raid{start the raid} unraid{cancel the raid} monitor{monitor the user} unmonitor{stop monitoring the user} restrict{restrict the user} unrestrict{lift the restriction} blockTerm{add the blocked term} unblockTerm{remove the blocked term} allowMessage{allow the message} denyMessage{deny the message} approveUnban{approve the unban request} denyUnban{deny the unban request} createPoll{start the poll} endPoll{end the poll} createPrediction{start the prediction} lockPrediction{lock the prediction} resolvePrediction{confirm the result} cancelPrediction{cancel the prediction} fulfil{complete the request} refund{refund the request} updateStream{save the stream info} load{load the list} loadStream{load the stream info} other{do that}}: {reason}'**
  String chatModFailed({required String command, required String reason});

  /// Error message. A moderation action failed for an unexpected reason. command is what failed: ban, timeout, untimeout, unban, warn, delete, clear, or a room mode turned on or off (slowOn, slowOff, followersOn, followersOff, subscribersOn, subscribersOff, emoteOnlyOn, emoteOnlyOff, uniqueChatOn, uniqueChatOff). French carries « de » / « d’ » in each branch.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t {command, select, ban{ban the user} timeout{time out the user} untimeout{lift the timeout} unban{unban the user} warn{warn the user} delete{delete the message} clear{clear the chat} slowOn{turn slow mode on} slowOff{turn slow mode off} followersOn{turn followers-only mode on} followersOff{turn followers-only mode off} subscribersOn{turn subscribers-only mode on} subscribersOff{turn subscribers-only mode off} emoteOnlyOn{turn emote-only mode on} emoteOnlyOff{turn emote-only mode off} uniqueChatOn{turn unique chat mode on} uniqueChatOff{turn unique chat mode off} announce{send the announcement} shoutout{send the shoutout} mods{list the moderators} vips{list the VIPs} mod{add the moderator} unmod{remove the moderator} vip{add the VIP} unvip{remove the VIP} shieldOn{turn shield mode on} shieldOff{turn shield mode off} marker{add the stream marker} commercial{start the ad break} raid{start the raid} unraid{cancel the raid} monitor{monitor the user} unmonitor{stop monitoring the user} restrict{restrict the user} unrestrict{lift the restriction} blockTerm{add the blocked term} unblockTerm{remove the blocked term} allowMessage{allow the message} denyMessage{deny the message} approveUnban{approve the unban request} denyUnban{deny the unban request} createPoll{start the poll} endPoll{end the poll} createPrediction{start the prediction} lockPrediction{lock the prediction} resolvePrediction{confirm the result} cancelPrediction{cancel the prediction} fulfil{complete the request} refund{refund the request} updateStream{save the stream info} load{load the list} loadStream{load the stream info} other{do that}} (unexpected error).'**
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

  /// A chat line shown to moderators when AutoMod holds a message for review (Review opens the AutoMod queue).
  ///
  /// In en, this message translates to:
  /// **'AutoMod is holding a message from {name}.'**
  String chatAutoModHeld({required String name});

  /// The link at the end of chatAutoModHeld, opening the AutoMod queue.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get chatAutoModReview;

  /// A command argument in a usage line: a channel's name (/raid <channel>).
  ///
  /// In en, this message translates to:
  /// **'channel'**
  String get chatCommandArgChannel;

  /// A command argument in a usage line: the optional text of a stream marker (/marker [description]).
  ///
  /// In en, this message translates to:
  /// **'description'**
  String get chatCommandArgDescription;

  /// A chat line shown to moderators for an action another moderator (or the viewer) took, from Twitch's live moderation feed. action is the action (ban, timeout, mod, slow…); moderator and user are display names; duration is a timeout's length worded like the timeout notices.
  ///
  /// In en, this message translates to:
  /// **'{action, select, ban{{moderator} banned {user}.} timeout{{moderator} timed out {user} for {duration}.} timeoutUnknown{{moderator} timed out {user}.} unban{{moderator} unbanned {user}.} untimeout{{moderator} lifted the timeout on {user}.} warn{{moderator} warned {user}.} delete{{moderator} deleted a message from {user}.} clear{{moderator} cleared the chat.} mod{{moderator} made {user} a moderator.} unmod{{moderator} removed {user} as a moderator.} vip{{moderator} made {user} a VIP.} unvip{{moderator} removed {user} as a VIP.} raid{{moderator} started a raid on {user}.} unraid{{moderator} canceled the raid on {user}.} addBlockedTerm{{moderator} added a blocked term.} removeBlockedTerm{{moderator} removed a blocked term.} addPermittedTerm{{moderator} added a permitted term.} removePermittedTerm{{moderator} removed a permitted term.} approveUnbanRequest{{moderator} approved the unban request from {user}.} denyUnbanRequest{{moderator} denied the unban request from {user}.} emoteonly{{moderator} turned emote-only mode on.} emoteonlyoff{{moderator} turned emote-only mode off.} followers{{moderator} turned followers-only mode on.} followersoff{{moderator} turned followers-only mode off.} slow{{moderator} turned slow mode on.} slowoff{{moderator} turned slow mode off.} subscribers{{moderator} turned subscribers-only mode on.} subscribersoff{{moderator} turned subscribers-only mode off.} uniquechat{{moderator} turned unique chat mode on.} uniquechatoff{{moderator} turned unique chat mode off.} other{{moderator} took a moderation action.}}'**
  String chatModAction({
    required String action,
    required String moderator,
    required String user,
    required String duration,
  });

  /// chatModAction followed by the reason the moderator typed (their own words, quoted as written).
  ///
  /// In en, this message translates to:
  /// **'{line} Reason: “{reason}”.'**
  String chatModActionWithReason({
    required String line,
    required String reason,
  });

  /// A chat line after /announce (or the mod tools) sent an announcement.
  ///
  /// In en, this message translates to:
  /// **'Announcement sent.'**
  String get chatModAnnounced;

  /// A chat line when a moderator types a command only the channel's owner can run through Twitch (/mod, /vip, /raid, /commercial…). command is the command with its slash.
  ///
  /// In en, this message translates to:
  /// **'{command} only works in your own channel.'**
  String chatModBroadcasterOnly({required String command});

  /// A chat line after /commercial started an ad break; duration is its length ("30 seconds").
  ///
  /// In en, this message translates to:
  /// **'Ad break started ({duration}).'**
  String chatModCommercialStarted({required String duration});

  /// A chat line after /marker added a stream marker.
  ///
  /// In en, this message translates to:
  /// **'Stream marker added.'**
  String get chatModMarkerAdded;

  /// The chat line answering /mods: how many moderators and their names, comma-separated (shortened with an ellipsis past 30).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Moderator ({count}): {names}} other{Moderators ({count}): {names}}}'**
  String chatModModeratorList({required int count, required String names});

  /// A chat line after /unraid canceled the outgoing raid.
  ///
  /// In en, this message translates to:
  /// **'Raid canceled.'**
  String get chatModRaidCanceled;

  /// A chat line after /raid started the countdown of a raid on the channel name.
  ///
  /// In en, this message translates to:
  /// **'Preparing the raid on {name}.'**
  String chatModRaidStarted({required String name});

  /// A chat line after /mod, /unmod, /vip or /unvip worked; name is the user's display name.
  ///
  /// In en, this message translates to:
  /// **'{change, select, moderatorAdded{{name} is now a moderator.} moderatorRemoved{{name} is no longer a moderator.} vipAdded{{name} is now a VIP.} vipRemoved{{name} is no longer a VIP.} other{{name}’s role changed.}}'**
  String chatModRoleChanged({required String change, required String name});

  /// The answer to /mods or /vips, and the empty list in the mod tools, when nobody has the role.
  ///
  /// In en, this message translates to:
  /// **'{role, select, moderator{This channel has no moderators.} vip{This channel has no VIPs.} other{Nobody has this role.}}'**
  String chatModRoleListEmpty({required String role});

  /// A chat line (and the mod tools' status) after shield mode was turned on or off.
  ///
  /// In en, this message translates to:
  /// **'{state, select, on{Shield mode is on.} other{Shield mode is off.}}'**
  String chatModShield({required String state});

  /// A chat line after /shoutout (or the mod tools) gave a shoutout to the channel name.
  ///
  /// In en, this message translates to:
  /// **'Shoutout sent to {name}.'**
  String chatModShoutoutSent({required String name});

  /// A chat line after /monitor, /unmonitor, /restrict or /unrestrict worked (a restricted user's messages show to moderators only).
  ///
  /// In en, this message translates to:
  /// **'{change, select, monitor{{name} is now monitored.} unmonitor{{name} is no longer monitored.} restrict{{name} is now restricted.} unrestrict{{name} is no longer restricted.} other{{name}’s status changed.}}'**
  String chatModSuspicion({required String change, required String name});

  /// The link at the end of the /mods and /vips answers, opening the list in the mod tools.
  ///
  /// In en, this message translates to:
  /// **'View list'**
  String get chatModViewList;

  /// The chat line answering /vips: how many VIPs and their names, comma-separated (shortened with an ellipsis past 30).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{VIP ({count}): {names}} other{VIPs ({count}): {names}}}'**
  String chatModVipList({required int count, required String names});

  /// A chat line shown to moderators when a moderator turned shield mode on or off.
  ///
  /// In en, this message translates to:
  /// **'{state, select, on{{moderator} turned shield mode on.} other{{moderator} turned shield mode off.}}'**
  String chatShieldModeChangedBy({
    required String state,
    required String moderator,
  });

  /// A chat line when the broadcaster or a moderator gives a shoutout to another channel (View opens that user's card).
  ///
  /// In en, this message translates to:
  /// **'Shoutout to {name}! Check out their channel.'**
  String chatShoutoutNotice({required String name});

  /// The link at the end of chatShoutoutNotice, opening the user card of the channel.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get chatShoutoutView;

  /// A mod tools row and the title of the list of moderation actions taken in this chat.
  ///
  /// In en, this message translates to:
  /// **'Mod actions'**
  String get modToolsActionLog;

  /// Under the title of the moderation actions list.
  ///
  /// In en, this message translates to:
  /// **'Actions taken in this chat since you opened it.'**
  String get modToolsActionLogCaption;

  /// The second line of the Mod actions row.
  ///
  /// In en, this message translates to:
  /// **'Who did what, live'**
  String get modToolsActionLogDetail;

  /// The moderation actions list when nothing happened yet.
  ///
  /// In en, this message translates to:
  /// **'No mod actions yet'**
  String get modToolsActionLogEmpty;

  /// The button next to a field that adds what was typed (a moderator, a blocked term, a tag).
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get modToolsAdd;

  /// Adds another answer field to a new poll.
  ///
  /// In en, this message translates to:
  /// **'Add a choice'**
  String get modToolsAddChoice;

  /// Adds another outcome field to a new prediction.
  ///
  /// In en, this message translates to:
  /// **'Add an outcome'**
  String get modToolsAddOutcome;

  /// Lets a message AutoMod held into chat.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get modToolsAllow;

  /// A mod tools row and the title of the announcement sheet.
  ///
  /// In en, this message translates to:
  /// **'Send an announcement'**
  String get modToolsAnnounce;

  /// Under the title of the announcement sheet.
  ///
  /// In en, this message translates to:
  /// **'Highlighted in chat for everyone.'**
  String get modToolsAnnounceCaption;

  /// The section label above an announcement's color choices.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get modToolsAnnounceColor;

  /// An announcement color choice (primary is the channel's own accent color).
  ///
  /// In en, this message translates to:
  /// **'{color, select, primary{Channel color} blue{Blue} green{Green} orange{Orange} purple{Purple} other{Channel color}}'**
  String modToolsAnnounceColorName({required String color});

  /// The label above the announcement's text field.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get modToolsAnnounceLabel;

  /// Sends the announcement.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get modToolsAnnounceSend;

  /// Approves an unban request.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get modToolsApprove;

  /// Under the title of the AutoMod queue.
  ///
  /// In en, this message translates to:
  /// **'Messages AutoMod is holding for review.'**
  String get modToolsAutoModCaption;

  /// The AutoMod queue when it is empty.
  ///
  /// In en, this message translates to:
  /// **'No messages are waiting'**
  String get modToolsAutoModEmpty;

  /// The second line of the AutoMod queue row when nothing waits.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review'**
  String get modToolsAutoModEmptyDetail;

  /// The second line of the AutoMod queue row: how many held messages wait for a decision.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} message waiting} other{{count} messages waiting}}'**
  String modToolsAutoModPending({required int count});

  /// A mod tools row and the title of the list of messages AutoMod holds.
  ///
  /// In en, this message translates to:
  /// **'AutoMod queue'**
  String get modToolsAutoModQueue;

  /// The status after a blocked term was added.
  ///
  /// In en, this message translates to:
  /// **'Blocked term added.'**
  String get modToolsBlockedTermAdded;

  /// The status after a blocked term was removed.
  ///
  /// In en, this message translates to:
  /// **'Blocked term removed.'**
  String get modToolsBlockedTermRemoved;

  /// Error message. A blocked term typed was too short (Twitch needs 2 characters).
  ///
  /// In en, this message translates to:
  /// **'A blocked term needs at least 2 characters.'**
  String get modToolsBlockedTermTooShort;

  /// A mod tools row and the title of the channel's blocked terms list.
  ///
  /// In en, this message translates to:
  /// **'Blocked terms'**
  String get modToolsBlockedTerms;

  /// Under the title of the blocked terms list.
  ///
  /// In en, this message translates to:
  /// **'Messages with these terms never reach chat.'**
  String get modToolsBlockedTermsCaption;

  /// The blocked terms list when it is empty.
  ///
  /// In en, this message translates to:
  /// **'No blocked terms'**
  String get modToolsBlockedTermsEmpty;

  /// Under the mod tools title for the channel's owner.
  ///
  /// In en, this message translates to:
  /// **'You own this channel'**
  String get modToolsCaptionBroadcaster;

  /// Under the mod tools title for a moderator.
  ///
  /// In en, this message translates to:
  /// **'You moderate this channel'**
  String get modToolsCaptionModerator;

  /// The label above the category search field of the stream info sheet.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get modToolsCategoryLabel;

  /// The category field's hint when the stream has none.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get modToolsCategoryNone;

  /// The label above the field naming a channel (shoutout, raid).
  ///
  /// In en, this message translates to:
  /// **'Channel name'**
  String get modToolsChannelLabel;

  /// The label above an answer field of a new poll.
  ///
  /// In en, this message translates to:
  /// **'Choice {number}'**
  String modToolsChoiceLabel({required int number});

  /// Removes the allowed, denied and expired messages from the AutoMod queue.
  ///
  /// In en, this message translates to:
  /// **'Clear resolved'**
  String get modToolsClearResolved;

  /// A mod tools row (the channel's owner) starting an ad break.
  ///
  /// In en, this message translates to:
  /// **'Run an ad'**
  String get modToolsCommercial;

  /// The body of the dialog confirming an ad break.
  ///
  /// In en, this message translates to:
  /// **'Every viewer sees the ad. Pick its length.'**
  String get modToolsCommercialMessage;

  /// Confirms the ad break.
  ///
  /// In en, this message translates to:
  /// **'Run ad'**
  String get modToolsCommercialStart;

  /// The title of the dialog confirming an ad break.
  ///
  /// In en, this message translates to:
  /// **'Run an ad?'**
  String get modToolsCommercialTitle;

  /// Confirms a role change.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get modToolsConfirm;

  /// Denies a held message or an unban request.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get modToolsDeny;

  /// The second line of the Mod tools row in the chat menu.
  ///
  /// In en, this message translates to:
  /// **'AutoMod, terms, shield mode, and more'**
  String get modToolsEntryDetail;

  /// Marks a channel points reward request as done.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get modToolsFulfil;

  /// The status after a reward request was marked as done.
  ///
  /// In en, this message translates to:
  /// **'Request completed.'**
  String get modToolsFulfilled;

  /// Why AutoMod held a message, with its severity level (1 to 4).
  ///
  /// In en, this message translates to:
  /// **'{reason} · level {level}'**
  String modToolsHeldLevel({required String reason, required int level});

  /// Why a message was held: AutoMod, a blocked term, or a blocked link.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, automod{AutoMod} blockedTerm{Blocked term} blockedLink{Blocked link} other{AutoMod}}'**
  String modToolsHeldReason({required String reason});

  /// The state of a held message in the AutoMod queue.
  ///
  /// In en, this message translates to:
  /// **'{status, select, pending{Waiting} approved{Allowed} denied{Denied} expired{Expired} other{Waiting}}'**
  String modToolsHeldStatus({required String status});

  /// The second line of a mod tools row whose permission the login does not have yet; a tap opens the login.
  ///
  /// In en, this message translates to:
  /// **'Log in again to use this'**
  String get modToolsLogInToEnable;

  /// A user card action (the channel's owner) giving the moderator role.
  ///
  /// In en, this message translates to:
  /// **'Make moderator'**
  String get modToolsMakeModerator;

  /// A user card action (the channel's owner) giving the VIP role.
  ///
  /// In en, this message translates to:
  /// **'Make VIP'**
  String get modToolsMakeVip;

  /// A mod tools row adding a stream marker.
  ///
  /// In en, this message translates to:
  /// **'Add a stream marker'**
  String get modToolsMarker;

  /// Confirms the stream marker.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get modToolsMarkerAdd;

  /// The label above the stream marker's text field.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get modToolsMarkerLabel;

  /// The title of the stream marker dialog.
  ///
  /// In en, this message translates to:
  /// **'Add a stream marker'**
  String get modToolsMarkerTitle;

  /// Under the title of the moderators list.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} moderator} other{{count} moderators}}'**
  String modToolsModeratorCount({required int count});

  /// A mod tools row and the title of the channel's moderators list.
  ///
  /// In en, this message translates to:
  /// **'Moderators'**
  String get modToolsModerators;

  /// A user card action: flags the user so moderators see their messages marked.
  ///
  /// In en, this message translates to:
  /// **'Monitor messages'**
  String get modToolsMonitor;

  /// The user card button opening shoutout, monitor, restrict and role actions.
  ///
  /// In en, this message translates to:
  /// **'More mod actions'**
  String get modToolsMoreActions;

  /// The label above an outcome field of a new prediction.
  ///
  /// In en, this message translates to:
  /// **'Outcome {number}'**
  String modToolsOutcomeLabel({required int number});

  /// A mod tools row opening the channel's permitted terms on twitch.tv (no app API for them).
  ///
  /// In en, this message translates to:
  /// **'Permitted terms'**
  String get modToolsPermittedTerms;

  /// The section label above a new poll's length choices.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get modToolsPollDuration;

  /// Ends the poll in progress.
  ///
  /// In en, this message translates to:
  /// **'End poll'**
  String get modToolsPollEnd;

  /// The body of the dialog confirming the end of a poll.
  ///
  /// In en, this message translates to:
  /// **'Voting stops now and the results show.'**
  String get modToolsPollEndMessage;

  /// The title of the dialog confirming the end of a poll.
  ///
  /// In en, this message translates to:
  /// **'End the poll?'**
  String get modToolsPollEndTitle;

  /// The status after the poll ended.
  ///
  /// In en, this message translates to:
  /// **'Poll ended.'**
  String get modToolsPollEnded;

  /// The section label above the poll in progress.
  ///
  /// In en, this message translates to:
  /// **'Poll in progress'**
  String get modToolsPollLive;

  /// Starts the new poll.
  ///
  /// In en, this message translates to:
  /// **'Start poll'**
  String get modToolsPollStart;

  /// The status after a poll started.
  ///
  /// In en, this message translates to:
  /// **'Poll started.'**
  String get modToolsPollStarted;

  /// A mod tools row and the title of the poll sheet.
  ///
  /// In en, this message translates to:
  /// **'Polls'**
  String get modToolsPolls;

  /// Under the title of the poll sheet.
  ///
  /// In en, this message translates to:
  /// **'Ask chat a question.'**
  String get modToolsPollsCaption;

  /// Cancels the prediction in progress and refunds everyone.
  ///
  /// In en, this message translates to:
  /// **'Cancel prediction'**
  String get modToolsPredictionCancel;

  /// The body of the dialog confirming a canceled prediction.
  ///
  /// In en, this message translates to:
  /// **'Everyone gets their channel points back.'**
  String get modToolsPredictionCancelMessage;

  /// The title of the dialog confirming a canceled prediction.
  ///
  /// In en, this message translates to:
  /// **'Cancel the prediction?'**
  String get modToolsPredictionCancelTitle;

  /// The section label above the prediction in progress.
  ///
  /// In en, this message translates to:
  /// **'Prediction in progress'**
  String get modToolsPredictionLive;

  /// Stops new predictions on the prediction in progress.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get modToolsPredictionLock;

  /// The body of the dialog confirming that the prediction is locked.
  ///
  /// In en, this message translates to:
  /// **'No one can predict after this, and it can’t be undone.'**
  String get modToolsPredictionLockMessage;

  /// The title of the dialog confirming that the prediction is locked.
  ///
  /// In en, this message translates to:
  /// **'Lock the prediction?'**
  String get modToolsPredictionLockTitle;

  /// The section label above a locked prediction.
  ///
  /// In en, this message translates to:
  /// **'Prediction locked'**
  String get modToolsPredictionLocked;

  /// Under a prediction outcome: makes it the result.
  ///
  /// In en, this message translates to:
  /// **'Pick as result'**
  String get modToolsPredictionPickWinner;

  /// The channel points bet on a prediction outcome.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} point} other{{count} points}}'**
  String modToolsPredictionPoints({required int count});

  /// Confirms the prediction's result.
  ///
  /// In en, this message translates to:
  /// **'Confirm result'**
  String get modToolsPredictionResolve;

  /// The body of the dialog confirming a prediction's result; outcome is the outcome's title.
  ///
  /// In en, this message translates to:
  /// **'“{outcome}” wins. Channel points go to the people who picked it.'**
  String modToolsPredictionResolveMessage({required String outcome});

  /// The title of the dialog confirming a prediction's result.
  ///
  /// In en, this message translates to:
  /// **'Confirm the result?'**
  String get modToolsPredictionResolveTitle;

  /// Starts the new prediction.
  ///
  /// In en, this message translates to:
  /// **'Start prediction'**
  String get modToolsPredictionStart;

  /// The status after a prediction started.
  ///
  /// In en, this message translates to:
  /// **'Prediction started.'**
  String get modToolsPredictionStarted;

  /// The status after a prediction was locked, resolved or canceled.
  ///
  /// In en, this message translates to:
  /// **'{state, select, locked{Prediction locked.} resolved{Result confirmed.} canceled{Prediction canceled.} other{Prediction updated.}}'**
  String modToolsPredictionUpdated({required String state});

  /// How many viewers picked a prediction outcome.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} predictor} other{{count} predictors}}'**
  String modToolsPredictionUsers({required int count});

  /// The section label above a new prediction's window choices.
  ///
  /// In en, this message translates to:
  /// **'Time to predict'**
  String get modToolsPredictionWindow;

  /// A mod tools row and the title of the prediction sheet.
  ///
  /// In en, this message translates to:
  /// **'Predictions'**
  String get modToolsPredictions;

  /// Under the title of the prediction sheet.
  ///
  /// In en, this message translates to:
  /// **'Let chat bet channel points.'**
  String get modToolsPredictionsCaption;

  /// The label above the question field of a new poll or prediction.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get modToolsQuestionLabel;

  /// A mod tools row (the channel's owner) starting a raid.
  ///
  /// In en, this message translates to:
  /// **'Raid a channel'**
  String get modToolsRaid;

  /// A mod tools row, and the confirming button, canceling the outgoing raid.
  ///
  /// In en, this message translates to:
  /// **'Cancel the raid'**
  String get modToolsRaidCancel;

  /// The body of the dialog confirming a canceled raid.
  ///
  /// In en, this message translates to:
  /// **'Your viewers stay here.'**
  String get modToolsRaidCancelMessage;

  /// The title of the dialog confirming a canceled raid.
  ///
  /// In en, this message translates to:
  /// **'Cancel the raid?'**
  String get modToolsRaidCancelTitle;

  /// The body of the raid dialog.
  ///
  /// In en, this message translates to:
  /// **'Your viewers leave for this channel once the countdown ends.'**
  String get modToolsRaidMessage;

  /// Starts the raid on the channel typed.
  ///
  /// In en, this message translates to:
  /// **'Start raid'**
  String get modToolsRaidStart;

  /// The title of the raid dialog.
  ///
  /// In en, this message translates to:
  /// **'Raid a channel'**
  String get modToolsRaidTitle;

  /// A reward request's reward and its cost in channel points.
  ///
  /// In en, this message translates to:
  /// **'{reward} · {cost, plural, one{{cost} point} other{{cost} points}}'**
  String modToolsRedemptionReward({required String reward, required int cost});

  /// Refunds a channel points reward request.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get modToolsRefund;

  /// The body of the dialog confirming a refund; name is the viewer, reward the reward's title.
  ///
  /// In en, this message translates to:
  /// **'{name} gets back the points spent on “{reward}”.'**
  String modToolsRefundMessage({required String name, required String reward});

  /// The title of the dialog confirming a refund.
  ///
  /// In en, this message translates to:
  /// **'Refund this request?'**
  String get modToolsRefundTitle;

  /// The status after a reward request was refunded.
  ///
  /// In en, this message translates to:
  /// **'Request refunded.'**
  String get modToolsRefunded;

  /// Removes a moderator, a VIP or a blocked term.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get modToolsRemove;

  /// A user card action (the channel's owner) removing the moderator role.
  ///
  /// In en, this message translates to:
  /// **'Remove moderator'**
  String get modToolsRemoveModerator;

  /// The tooltip of a stream tag's delete button.
  ///
  /// In en, this message translates to:
  /// **'Remove {tag}'**
  String modToolsRemoveTag({required String tag});

  /// The body of the dialog confirming a blocked term's removal; term is the term.
  ///
  /// In en, this message translates to:
  /// **'Messages with “{term}” will reach chat again.'**
  String modToolsRemoveTermMessage({required String term});

  /// The title of the dialog confirming a blocked term's removal.
  ///
  /// In en, this message translates to:
  /// **'Remove this blocked term?'**
  String get modToolsRemoveTermTitle;

  /// A user card action (the channel's owner) removing the VIP role.
  ///
  /// In en, this message translates to:
  /// **'Remove VIP'**
  String get modToolsRemoveVip;

  /// When an unban request was sent (date: a medium date).
  ///
  /// In en, this message translates to:
  /// **'Sent {date}'**
  String modToolsRequestedOn({required String date});

  /// A user card action, and its confirming button: only moderators will see the user's messages.
  ///
  /// In en, this message translates to:
  /// **'Restrict'**
  String get modToolsRestrict;

  /// The body of the dialog confirming a restriction.
  ///
  /// In en, this message translates to:
  /// **'Only moderators will see messages from {name}.'**
  String modToolsRestrictMessage({required String name});

  /// The title of the dialog confirming a restriction.
  ///
  /// In en, this message translates to:
  /// **'Restrict this user?'**
  String get modToolsRestrictTitle;

  /// A row opening the channel's complete reward queue on twitch.tv.
  ///
  /// In en, this message translates to:
  /// **'Full reward queue'**
  String get modToolsRewardQueueWeb;

  /// A mod tools row and the title of the channel points reward requests list.
  ///
  /// In en, this message translates to:
  /// **'Reward requests'**
  String get modToolsRewardRequests;

  /// Under the title of the reward requests list (a Twitch API limit).
  ///
  /// In en, this message translates to:
  /// **'Twitch only lets this app manage rewards created in ONSET. The full queue is on twitch.tv.'**
  String get modToolsRewardRequestsCaption;

  /// The reward requests list when it is empty.
  ///
  /// In en, this message translates to:
  /// **'No requests waiting'**
  String get modToolsRewardRequestsEmpty;

  /// The body of the dialog confirming a role change; name is the user's display name.
  ///
  /// In en, this message translates to:
  /// **'{change, select, addModerator{{name} will be able to moderate this chat.} removeModerator{{name} will no longer be able to moderate this chat.} addVip{{name} will get the VIP badge.} removeVip{{name} will lose the VIP badge.} other{{name}’s role will change.}}'**
  String modToolsRoleConfirmMessage({
    required String change,
    required String name,
  });

  /// The title of the dialog confirming a role change.
  ///
  /// In en, this message translates to:
  /// **'{change, select, addModerator{Make moderator?} removeModerator{Remove moderator?} addVip{Make VIP?} removeVip{Remove VIP?} other{Change role?}}'**
  String modToolsRoleConfirmTitle({required String change});

  /// Saves the stream info.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get modToolsSave;

  /// An ad break length choice in seconds (compact).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count}s} other{{count}s}}'**
  String modToolsSeconds({required int count});

  /// The mod tools section label of the owner's channel tools.
  ///
  /// In en, this message translates to:
  /// **'Your channel'**
  String get modToolsSectionChannel;

  /// The mod tools section label of the chat tools.
  ///
  /// In en, this message translates to:
  /// **'Chat tools'**
  String get modToolsSectionChat;

  /// The mod tools section label of the live tools (shield mode, AutoMod queue, mod actions).
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get modToolsSectionLive;

  /// A mod tools row with a switch turning shield mode on or off.
  ///
  /// In en, this message translates to:
  /// **'Shield mode'**
  String get modToolsShieldMode;

  /// The second line of the shield mode row.
  ///
  /// In en, this message translates to:
  /// **'Your preset protections, in one tap'**
  String get modToolsShieldModeDetail;

  /// The pill in the chat while shield mode is on (moderators only; a tap opens the mod tools).
  ///
  /// In en, this message translates to:
  /// **'Shield mode on'**
  String get modToolsShieldModeOn;

  /// A mod tools row giving a shoutout to a channel.
  ///
  /// In en, this message translates to:
  /// **'Give a shoutout'**
  String get modToolsShoutout;

  /// The second line of the shoutout row.
  ///
  /// In en, this message translates to:
  /// **'Point chat to another channel'**
  String get modToolsShoutoutDetail;

  /// Sends the shoutout.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get modToolsShoutoutSend;

  /// The title of the shoutout dialog.
  ///
  /// In en, this message translates to:
  /// **'Give a shoutout'**
  String get modToolsShoutoutTitle;

  /// A user card action giving a shoutout to that user's channel.
  ///
  /// In en, this message translates to:
  /// **'Give a shoutout'**
  String get modToolsShoutoutUser;

  /// A mod tools switch: show the live moderation actions as chat lines.
  ///
  /// In en, this message translates to:
  /// **'Show mod actions in chat'**
  String get modToolsShowActionsInChat;

  /// A mod tools row and the title of the stream info sheet (title, category, tags).
  ///
  /// In en, this message translates to:
  /// **'Edit stream info'**
  String get modToolsStreamInfo;

  /// Under the title of the stream info sheet.
  ///
  /// In en, this message translates to:
  /// **'Title, category, and tags'**
  String get modToolsStreamInfoCaption;

  /// The status after the stream info was saved.
  ///
  /// In en, this message translates to:
  /// **'Stream info saved.'**
  String get modToolsStreamInfoSaved;

  /// The label above the stream title field.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get modToolsStreamTitleLabel;

  /// Error message. The tag typed has spaces, symbols or more than 25 characters.
  ///
  /// In en, this message translates to:
  /// **'Tags can only contain letters and numbers, up to 25 characters.'**
  String get modToolsTagInvalid;

  /// The label above the field adding a stream tag.
  ///
  /// In en, this message translates to:
  /// **'Add a tag'**
  String get modToolsTagLabel;

  /// Error message. The stream already has as many tags as Twitch allows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{A stream can have up to {count} tag.} other{A stream can have up to {count} tags.}}'**
  String modToolsTagLimit({required int count});

  /// The section label above the stream's tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get modToolsTags;

  /// The label above the field adding a blocked term.
  ///
  /// In en, this message translates to:
  /// **'Term or phrase'**
  String get modToolsTermLabel;

  /// Under a blocked term that expires.
  ///
  /// In en, this message translates to:
  /// **'Temporary'**
  String get modToolsTermTemporary;

  /// The chat menu row and the title of the moderation tools sheet.
  ///
  /// In en, this message translates to:
  /// **'Mod tools'**
  String get modToolsTitle;

  /// Under the title of the unban requests list.
  ///
  /// In en, this message translates to:
  /// **'Banned users asking to come back.'**
  String get modToolsUnbanCaption;

  /// The body of the dialog approving or denying an unban request; name is the banned user.
  ///
  /// In en, this message translates to:
  /// **'{decision, select, approved{{name} will be unbanned. You can add a note for them.} denied{{name} stays banned. You can add a note for them.} other{You can add a note for {name}.}}'**
  String modToolsUnbanDialogMessage({
    required String decision,
    required String name,
  });

  /// The title of the dialog approving or denying an unban request.
  ///
  /// In en, this message translates to:
  /// **'{decision, select, approved{Approve the request?} denied{Deny the request?} other{Answer the request?}}'**
  String modToolsUnbanDialogTitle({required String decision});

  /// The unban requests list when it is empty.
  ///
  /// In en, this message translates to:
  /// **'No unban requests'**
  String get modToolsUnbanEmpty;

  /// The label above the note sent with an unban decision.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get modToolsUnbanNoteLabel;

  /// A mod tools row and the title of the pending unban requests list.
  ///
  /// In en, this message translates to:
  /// **'Unban requests'**
  String get modToolsUnbanRequests;

  /// The status after an unban request was approved or denied.
  ///
  /// In en, this message translates to:
  /// **'{decision, select, approved{Request from {name} approved.} denied{Request from {name} denied.} other{Request from {name} answered.}}'**
  String modToolsUnbanResolved({
    required String decision,
    required String name,
  });

  /// A user card action lifting the monitoring of the user.
  ///
  /// In en, this message translates to:
  /// **'Stop monitoring'**
  String get modToolsUnmonitor;

  /// A user card action lifting the user's restriction.
  ///
  /// In en, this message translates to:
  /// **'Lift restriction'**
  String get modToolsUnrestrict;

  /// The title of the user card's extra moderation actions sheet.
  ///
  /// In en, this message translates to:
  /// **'Mod actions'**
  String get modToolsUserActionsTitle;

  /// The label above the field naming a user to add as a moderator or VIP.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get modToolsUserLabel;

  /// A pill on the user card telling a moderator the user's state in this channel.
  ///
  /// In en, this message translates to:
  /// **'{pill, select, banned{Banned} timedOut{Timed out} warned{Warned} monitored{Monitored} restricted{Restricted} other{Flagged}}'**
  String modToolsUserPill({required String pill});

  /// Under the title of the VIPs list.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} VIP} other{{count} VIPs}}'**
  String modToolsVipCount({required int count});

  /// A mod tools row and the title of the channel's VIPs list.
  ///
  /// In en, this message translates to:
  /// **'VIPs'**
  String get modToolsVips;

  /// The votes an answer of the poll in progress has.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} vote} other{{count} votes}}'**
  String modToolsVotes({required int count});

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

  /// The one-line bar above the chat input (and its placeholder) after Twitch refused a message for a reason tied to the account or the channel. One line at 360 dp ×1.3. warned: a moderator warned the viewer; a tap on the bar opens the dialog that acknowledges it.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, verifiedEmail{Verified email required} verifiedPhone{Verified phone required} emailAliasBanned{Email banned here} phoneAliasBanned{Phone banned here} accountRestricted{Account restricted} channelRestricted{Chat suspended here} followRequired{Follow to chat} warned{Warning received} other{}}'**
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

  /// Badge details sheet (tap a badge in chat): what a Twitch badge means, under its kind. kind is the badge set; an unknown set shows nothing.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, broadcaster{Streams on this channel.} moderator{Moderates this channel’s chat.} leadModerator{Leads the moderators of this channel.} vip{Named a VIP by this channel.} subscriber{Subscribes to this channel; the badge changes with the length of the subscription.} founder{Among the first subscribers to this channel.} bits{Has sent Bits in this channel; the badge shows the total.} bitsLeader{Among the top Bits senders in this channel.} subGifter{Has gifted subs in this channel; the badge shows how many.} subGiftLeader{Among the top sub gifters in this channel.} partner{A Twitch Partner.} staff{Works at Twitch.} premium{Has Prime Gaming.} turbo{Has Twitch Turbo.} artist{Makes art for this channel.} noAudio{Watches without sound.} noVideo{Listens without the video.} predictions{Took part in the current prediction; the badge shows the outcome picked.} hypeTrain{Took part in a Hype Train on this channel.} other{}}'**
  String chatBadgeExplainer({required String kind});

  /// Badge details sheet, for a message sent from another channel of a shared chat: what a Twitch badge tied to that channel means. kind is the badge set (only channel badges; others use chatBadgeExplainer); channel is that channel's display name.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, broadcaster{Streams on {channel}.} moderator{Moderates {channel}’s chat.} leadModerator{Leads the moderators of {channel}.} vip{Named a VIP by {channel}.} subscriber{Subscribes to {channel}; the badge changes with the length of the subscription.} founder{Among the first subscribers to {channel}.} bits{Has sent Bits on {channel}; the badge shows the total.} bitsLeader{Among the top Bits senders on {channel}.} subGifter{Has gifted subs on {channel}; the badge shows how many.} subGiftLeader{Among the top sub gifters on {channel}.} artist{Makes art for {channel}.} predictions{Took part in {channel}’s current prediction; the badge shows the outcome picked.} hypeTrain{Took part in a Hype Train on {channel}.} other{}}'**
  String chatBadgeExplainerElsewhere({
    required String kind,
    required String channel,
  });

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

  /// Chat menu (the “⋯” sheet): the label above the quick switches for how chat looks (animated emotes, GIFs, offensive language, name colors).
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get chatDetailsPreferences;

  /// Chat menu, under Preferences: a switch that turns Twitch’s chat filters on or off (Settings › Chat › Edit chat filters picks what is filtered). One line in a 360 dp sheet.
  ///
  /// In en, this message translates to:
  /// **'Hide offensive language'**
  String get chatDetailsHideOffensive;

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

  /// Chat menu: the tooltip shown when the viewer taps an active chat mode pill. followers has a follow age shown on the pill; followersNow has none.
  ///
  /// In en, this message translates to:
  /// **'{mode, select, emoteOnly{Messages can only contain emotes.} followersNow{Only followers can chat.} followers{Only followers can chat, once they’ve followed for the time shown.} slow{Everyone must wait the time shown between messages.} subscribers{Only subscribers can chat.} uniqueChat{Each message must be unique: repeated messages are refused.} other{}}'**
  String chatModeExplainer({required String mode});

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

  /// A line ONSET adds to chat once, only for the viewer, the first time an animated emote shows; followed by the “Show me” link.
  ///
  /// In en, this message translates to:
  /// **'Animated emotes can be turned off in Settings › Chat.'**
  String get chatAnimatedEmotesCallout;

  /// The link after the one-time chat line about animated emotes: opens Settings › Chat.
  ///
  /// In en, this message translates to:
  /// **'Show me'**
  String get chatAnimatedEmotesCalloutShow;

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

  /// What a screen reader says for an animated emote in the emote menu (a small play mark sits on its corner). name is the emote's code.
  ///
  /// In en, this message translates to:
  /// **'{name}, animated emote'**
  String emoteMenuAnimated({required String name});

  /// Emote details sheet opened from the Recent tab of the emote menu: removes this one emote from the recent emotes.
  ///
  /// In en, this message translates to:
  /// **'Remove from recent emotes'**
  String get emoteMenuRemoveRecent;

  /// Emote menu, the channel's Twitch emotes: a note above the grid when it holds follower emotes. channel is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'Follower emotes can only be used in {channel}’s chat.'**
  String emoteMenuFollowerInfo({required String channel});

  /// Emote details sheet: a line under the emote's kind for an emote Twitch gives only for a limited time.
  ///
  /// In en, this message translates to:
  /// **'Limited-time emote'**
  String get emoteLimitedTime;

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

  /// A toggle under the watch streak card that shows or hides a short explanation of how Twitch counts streaks.
  ///
  /// In en, this message translates to:
  /// **'Where’s my streak?'**
  String get streakHelpTitle;

  /// The explanation shown when the viewer opens “Where’s my streak?”.
  ///
  /// In en, this message translates to:
  /// **'Twitch counts the live streams you watch in a row on this channel. A streak shows up here once Twitch has counted it, which can take a few minutes after a stream starts. If you miss a stream, the streak is suspended until the next one, and watching that one live saves it.'**
  String get streakHelpBody;

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

  /// A video's settings sheet: the entry, and the title of the dialog, that jumps to a typed time.
  ///
  /// In en, this message translates to:
  /// **'Go to time'**
  String get vodGoToTime;

  /// The « Go to time » dialog: under the field when the typed time is unreadable or past the end. {end} is the video's length, as on the seek bar.
  ///
  /// In en, this message translates to:
  /// **'Enter a time between 0:00 and {end}.'**
  String vodGoToTimeInvalid({required String end});

  /// The « Go to time » dialog: the button that jumps to the typed time.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get vodGoToTimeGo;

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

  /// Whispers: the header button (and its sheet title) that starts a whisper with anyone.
  ///
  /// In en, this message translates to:
  /// **'New whisper'**
  String get whispersNew;

  /// Whispers › New whisper: the hint of the search field (Twitch channel search).
  ///
  /// In en, this message translates to:
  /// **'Search for someone'**
  String get whispersNewSearch;

  /// Whispers › New whisper: no channel matches what the viewer typed. query is the text typed.
  ///
  /// In en, this message translates to:
  /// **'No one matches “{query}”.'**
  String whispersNewNoMatch({required String query});

  /// Error message. Whispers › New whisper: the channel search failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t search. Check your connection and try again.'**
  String get whispersNewFailed;

  /// Whispers: tooltip of the conversation header's « more » button (mute, archive, hide).
  ///
  /// In en, this message translates to:
  /// **'Conversation options'**
  String get whisperMore;

  /// Whispers › conversation options: stop in-app notices for this conversation (kept on this device).
  ///
  /// In en, this message translates to:
  /// **'Mute notifications'**
  String get whisperMute;

  /// Whispers › conversation options: notices come back for this conversation.
  ///
  /// In en, this message translates to:
  /// **'Unmute notifications'**
  String get whisperUnmute;

  /// Whispers: what a screen reader says for the muted icon on a conversation row.
  ///
  /// In en, this message translates to:
  /// **'Notifications muted'**
  String get whisperMuted;

  /// Whispers › conversation options: moves the conversation to the archived section until a new whisper arrives.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get whisperArchive;

  /// Whispers › conversation options: brings an archived conversation back to the list.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get whisperUnarchive;

  /// Whispers: the row that shows or hides archived conversations. count is how many.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Archived conversation ({count})} other{Archived conversations ({count})}}'**
  String whispersArchived({required int count});

  /// Whispers › conversation options: removes the conversation from the app (asks first).
  ///
  /// In en, this message translates to:
  /// **'Hide conversation'**
  String get whisperHide;

  /// Whispers: title of the dialog that confirms hiding a conversation.
  ///
  /// In en, this message translates to:
  /// **'Hide this conversation?'**
  String get whisperHideConfirmTitle;

  /// Whispers: text of the dialog that confirms hiding a conversation. name is the person's display name.
  ///
  /// In en, this message translates to:
  /// **'Your whispers with {name} will be removed from this app. A new whisper will start a new conversation.'**
  String whisperHideConfirmMessage({required String name});

  /// Whispers: the dialog's button that hides the conversation.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get whisperHideConfirm;

  /// Block dialog: the label above the reason choices sent to Twitch with the block.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get blockReasonTitle;

  /// Block dialog: reason choice.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get blockReasonHarassment;

  /// Block dialog: reason choice.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get blockReasonSpam;

  /// Block dialog: reason choice.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get blockReasonOther;

  /// A channel's menu (user card « More », profile « More »): the title above the bell level choices. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'Live notifications for {name}'**
  String goLiveBellLevelTitle({required String name});

  /// Bell level: notify each time the channel goes live.
  ///
  /// In en, this message translates to:
  /// **'All streams'**
  String get goLiveBellAll;

  /// Bell level: never notify for this channel (feminine in French: « aucune notification »).
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get goLiveBellNone;

  /// Settings › General › Browse: the row (and page title) listing the channels hidden from Live with « Not interested ».
  ///
  /// In en, this message translates to:
  /// **'Not interested'**
  String get settingsPageNotInterested;

  /// Not interested page: the section label above the list. count is how many channels.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} hidden channel} other{{count} hidden channels}}'**
  String notInterestedCount({required int count});

  /// Not interested page: nothing hidden yet.
  ///
  /// In en, this message translates to:
  /// **'No hidden channels'**
  String get notInterestedEmpty;

  /// Not interested page: the note under the list (and under the empty state). « Ça ne m’intéresse pas » must match liveFeedNotInterested in French.
  ///
  /// In en, this message translates to:
  /// **'Channels you mark “Not interested” in Live stay out of it until you show them again here.'**
  String get notInterestedNote;

  /// Not interested page: the button that brings a channel back to Live.
  ///
  /// In en, this message translates to:
  /// **'Show again'**
  String get notInterestedRestore;

  /// Not interested page: what a screen reader says for the button of one channel. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'Show {name} again'**
  String notInterestedRestoreName({required String name});

  /// Search: what a screen reader says for the row of suggestions shown while typing.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get searchSuggestions;

  /// Channel profile › Home: the label of the channel trailer card (shown while the channel is offline).
  ///
  /// In en, this message translates to:
  /// **'Trailer'**
  String get profileTrailer;

  /// Channel profile › Home: what a screen reader says for the trailer card. title is the trailer's title.
  ///
  /// In en, this message translates to:
  /// **'Play trailer: {title}'**
  String profileTrailerOpen({required String title});

  /// Channel profile › About: the title above the channel's Twitch teams (and the team page title while it loads).
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get profileTeams;

  /// Team page: how many channels are in the team.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} member} other{{count} members}}'**
  String teamMembersCount({required int count});

  /// Team page: the section of members who are live.
  ///
  /// In en, this message translates to:
  /// **'Live now'**
  String get teamLiveNow;

  /// Team page: the section of members who are offline.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get teamMembers;

  /// Error message. Team page: the team could not be loaded; « Try again » follows.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load this team.'**
  String get teamFailed;

  /// Channel profile › Schedule: the banner while the streamer has set a vacation. start and end are short dates (Nov 8).
  ///
  /// In en, this message translates to:
  /// **'On a break from {start} to {end}. The schedule resumes after that.'**
  String scheduleVacation({required String start, required String end});

  /// Channel profile › Schedule: a short tag on a stream that repeats every week.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get scheduleWeekly;

  /// Schedule slot detail: the line saying the stream repeats weekly.
  ///
  /// In en, this message translates to:
  /// **'Repeats every week'**
  String get scheduleRepeatsWeekly;

  /// Schedule slot detail: shares the link to this scheduled stream.
  ///
  /// In en, this message translates to:
  /// **'Share this stream'**
  String get scheduleShareSlot;

  /// Settings › General › Browse: which clips a channel's Clips lists show (all, or only the ones the streamer featured).
  ///
  /// In en, this message translates to:
  /// **'Channel clips'**
  String get settingsClipDiscovery;

  /// Channel clips setting: every clip.
  ///
  /// In en, this message translates to:
  /// **'All clips'**
  String get clipDiscoveryAll;

  /// Channel clips setting: only the clips the streamer featured.
  ///
  /// In en, this message translates to:
  /// **'Featured only'**
  String get clipDiscoveryFeatured;

  /// Settings › General › Browse: hides viewer counts on stream cards, the Live feed and the player.
  ///
  /// In en, this message translates to:
  /// **'Hide viewer counts'**
  String get settingsHideViewerCount;

  /// Settings › Video: plays a muted preview of the channel on screen in Live.
  ///
  /// In en, this message translates to:
  /// **'Stream previews'**
  String get settingsStreamPreviews;

  /// Settings › Video: the line under Stream previews.
  ///
  /// In en, this message translates to:
  /// **'Plays the channel on screen in Live before you open it.'**
  String get settingsStreamPreviewsDetail;

  /// Settings › Video: previews start without sound (a tap on the sound button still unmutes).
  ///
  /// In en, this message translates to:
  /// **'Start previews muted'**
  String get settingsMutePreviews;

  /// Settings › Video: on mobile data, live streams start at 480p at most and previews do not play.
  ///
  /// In en, this message translates to:
  /// **'Data saver'**
  String get settingsDataSaver;

  /// Settings › Video: the line under Data saver.
  ///
  /// In en, this message translates to:
  /// **'On mobile data, live streams start at 480p at most and previews don’t play. You can still pick another quality.'**
  String get settingsDataSaverDetail;

  /// Settings › Chat › celebrations: whether celebrations play over the video in landscape (off: a line in chat instead).
  ///
  /// In en, this message translates to:
  /// **'Alerts over the video in landscape'**
  String get settingsAlertsOverLandscapeVideo;

  /// Settings › Chat: the line under Alerts over the video in landscape.
  ///
  /// In en, this message translates to:
  /// **'When off, landscape shows a line in chat instead, so nothing covers the stream.'**
  String get settingsAlertsOverLandscapeVideoDetail;

  /// Following › sort: channels with a running watch streak first, then by viewers (« chaînes » is feminine in French).
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get followedSortRecommended;

  /// Following › Videos from followed channels: what a screen reader says for the count badge of videos posted since the list was last opened.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} new video} other{{count} new videos}}'**
  String followedVideosNew({required int count});

  /// Following, when no followed channel is live: the button that opens Browse.
  ///
  /// In en, this message translates to:
  /// **'Browse channels'**
  String get followedBrowseChannels;

  /// Share sheet (stream, clip or video link): its title.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareTitle;

  /// Share sheet: sends the link as a chat message in the channel's chat (no channel name known).
  ///
  /// In en, this message translates to:
  /// **'Send in chat'**
  String get shareSendToChat;

  /// Share sheet: sends the link as a chat message in that channel's chat. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'Send in {name}’s chat'**
  String shareSendToChannelChat({required String name});

  /// Share sheet: picks someone and whispers them the link.
  ///
  /// In en, this message translates to:
  /// **'Send as a whisper'**
  String get shareSendAsWhisper;

  /// Share sheet: opens the system share sheet.
  ///
  /// In en, this message translates to:
  /// **'More options…'**
  String get shareOther;

  /// Snackbar after the link was sent in a chat. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'Link sent in {name}’s chat.'**
  String shareSentToChat({required String name});

  /// Error message. Snackbar when the login predates the permission to send chat messages through Twitch's API.
  ///
  /// In en, this message translates to:
  /// **'Log in again to send links in chat from here.'**
  String get shareChatLogInAgain;

  /// Error message. Snackbar when the chat message could not be sent.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t send the link in chat.'**
  String get shareChatFailed;

  /// Snackbar after the link was whispered. name is the person's display name.
  ///
  /// In en, this message translates to:
  /// **'Link whispered to {name}.'**
  String shareWhisperSent({required String name});

  /// The small pill beside a recently added setting, shown until the viewer uses it (drawn in capitals).
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newFeaturePill;

  /// Channel points sheet: the title of the one-time intro card.
  ///
  /// In en, this message translates to:
  /// **'Channel points'**
  String get pointsIntroTitle;

  /// Channel points sheet: the text of the one-time intro card.
  ///
  /// In en, this message translates to:
  /// **'Each channel has its own points. You earn them by watching, and spend them on that channel’s rewards and predictions.'**
  String get pointsIntroBody;

  /// Channel points sheet: dismisses the intro card.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get pointsIntroGotIt;

  /// Channel points sheet: the row (and the intro's button) that opens the explainer of how points are earned; also the explainer's title.
  ///
  /// In en, this message translates to:
  /// **'How to earn points'**
  String get pointsHowToEarn;

  /// How to earn points: watching.
  ///
  /// In en, this message translates to:
  /// **'Watch the stream: points add up every few minutes while it’s live.'**
  String get pointsEarnWatch;

  /// How to earn points: the bonus chest.
  ///
  /// In en, this message translates to:
  /// **'Collect the bonus when it shows up in chat.'**
  String get pointsEarnBonus;

  /// How to earn points: watch streaks.
  ///
  /// In en, this message translates to:
  /// **'Keep a watch streak by coming back stream after stream.'**
  String get pointsEarnStreak;

  /// How to earn points: following (a one-time bonus).
  ///
  /// In en, this message translates to:
  /// **'Follow the channel.'**
  String get pointsEarnFollow;

  /// How to earn points: raids.
  ///
  /// In en, this message translates to:
  /// **'Join a raid the channel starts.'**
  String get pointsEarnRaid;

  /// How to earn points: the subscriber multiplier.
  ///
  /// In en, this message translates to:
  /// **'Subscribers earn more for everything above.'**
  String get pointsEarnSubscriber;

  /// How to earn points: the note at the end.
  ///
  /// In en, this message translates to:
  /// **'Each channel sets its own amounts. Watching in this app may not count everywhere it would on Twitch.'**
  String get pointsEarnNote;

  /// Settings › Chat › Channel points: brings back the intro card in the points sheet.
  ///
  /// In en, this message translates to:
  /// **'Show the channel points intro again'**
  String get settingsReplayPointsIntro;

  /// Settings › Chat: the line under Show the channel points intro again (« Elle » is la présentation).
  ///
  /// In en, this message translates to:
  /// **'It shows the next time you open a channel’s points.'**
  String get settingsReplayPointsIntroDetail;

  /// Snackbar after Show the channel points intro again.
  ///
  /// In en, this message translates to:
  /// **'The intro will show again.'**
  String get settingsPointsIntroReset;

  /// The one-time feedback prompt's title (after a dozen app opens).
  ///
  /// In en, this message translates to:
  /// **'Enjoying ONSET?'**
  String get feedbackPromptTitle;

  /// The feedback prompt's text.
  ///
  /// In en, this message translates to:
  /// **'Tell us what works and what doesn’t. Feedback goes to the project’s GitHub page, where you can report a bug or suggest an idea.'**
  String get feedbackPromptMessage;

  /// Feedback prompt: opens the project's GitHub issue page.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get feedbackPromptSend;

  /// Feedback prompt: asks again much later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get feedbackPromptLater;

  /// Feedback prompt: never asks again.
  ///
  /// In en, this message translates to:
  /// **'Don’t ask again'**
  String get feedbackPromptNever;

  /// Settings › Other › About: opens the project's GitHub issue page.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get settingsSendFeedback;

  /// Settings › Other › About: opens Twitch's Help Center.
  ///
  /// In en, this message translates to:
  /// **'Twitch help and support'**
  String get settingsTwitchHelp;

  /// Settings › Account › On twitch.tv: the profile settings page.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsTwitchProfile;

  /// Settings › Account: the line under Edit profile.
  ///
  /// In en, this message translates to:
  /// **'Display name, bio, picture — on twitch.tv'**
  String get settingsTwitchProfileDetail;

  /// Settings › Account › On twitch.tv: the notification and email settings page.
  ///
  /// In en, this message translates to:
  /// **'Email and notifications'**
  String get settingsTwitchNotifications;

  /// Settings › Account: the line under Email and notifications.
  ///
  /// In en, this message translates to:
  /// **'What Twitch emails and notifies you about — on twitch.tv'**
  String get settingsTwitchNotificationsDetail;

  /// Settings › Account › On twitch.tv: Twitch's parental supervision page.
  ///
  /// In en, this message translates to:
  /// **'Family Center'**
  String get settingsTwitchFamilyCenter;

  /// Settings › Account: the line under Family Center.
  ///
  /// In en, this message translates to:
  /// **'Parental supervision tools — on twitch.tv'**
  String get settingsTwitchFamilyCenterDetail;

  /// Settings › Account › On twitch.tv: the subscriptions page.
  ///
  /// In en, this message translates to:
  /// **'My subscriptions'**
  String get settingsTwitchSubscriptions;

  /// Settings › Account: the line under My subscriptions.
  ///
  /// In en, this message translates to:
  /// **'Manage your subscriptions — on twitch.tv'**
  String get settingsTwitchSubscriptionsDetail;

  /// Settings › Account › On twitch.tv: the Drops inventory page.
  ///
  /// In en, this message translates to:
  /// **'Drops inventory'**
  String get settingsTwitchDrops;

  /// Settings › Account: the line under Drops inventory.
  ///
  /// In en, this message translates to:
  /// **'Rewards earned by watching — on twitch.tv'**
  String get settingsTwitchDropsDetail;

  /// Settings › Account › On twitch.tv: the Turbo page (a brand name).
  ///
  /// In en, this message translates to:
  /// **'Twitch Turbo'**
  String get settingsTwitchTurbo;

  /// Settings › Account: the line under Twitch Turbo.
  ///
  /// In en, this message translates to:
  /// **'Ad-free viewing — on twitch.tv'**
  String get settingsTwitchTurboDetail;

  /// Settings › Account › On twitch.tv: the Prime Gaming page (a brand name).
  ///
  /// In en, this message translates to:
  /// **'Prime Gaming'**
  String get settingsTwitchPrime;

  /// Settings › Account: the line under Prime Gaming.
  ///
  /// In en, this message translates to:
  /// **'Your free monthly subscription — on twitch.tv'**
  String get settingsTwitchPrimeDetail;

  /// Settings › Account › On twitch.tv: Twitch's annual recap page.
  ///
  /// In en, this message translates to:
  /// **'Year recap'**
  String get settingsTwitchRecap;

  /// Settings › Account: the line under Year recap.
  ///
  /// In en, this message translates to:
  /// **'Your year on Twitch — on twitch.tv'**
  String get settingsTwitchRecapDetail;

  /// Settings › Account › On twitch.tv: the sign-up page.
  ///
  /// In en, this message translates to:
  /// **'Create another account'**
  String get settingsTwitchSignup;

  /// Settings › Account: the line under Create another account.
  ///
  /// In en, this message translates to:
  /// **'A new Twitch account — on twitch.tv'**
  String get settingsTwitchSignupDetail;

  /// Settings › Account › On twitch.tv: Twitch's account deletion page.
  ///
  /// In en, this message translates to:
  /// **'Disable or delete account'**
  String get settingsTwitchDeleteAccount;

  /// Settings › Account: the line under Disable or delete account.
  ///
  /// In en, this message translates to:
  /// **'Close your Twitch account — on twitch.tv'**
  String get settingsTwitchDeleteAccountDetail;

  /// A poll or prediction card: reports it on twitch.tv (the channel's report page).
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportOnTwitch;

  /// Chat message long-press menu: reports the message's author on twitch.tv, and that page's title.
  ///
  /// In en, this message translates to:
  /// **'Report message'**
  String get chatReportMessage;

  /// Emote details: reports a Twitch emote's owner on twitch.tv, and that page's title.
  ///
  /// In en, this message translates to:
  /// **'Report emote'**
  String get chatReportEmote;

  /// Clip details: opens the clip on twitch.tv to report it, and that page's title is « Report ».
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get clipReport;

  /// Mod tools: opens Twitch's Mod View for this channel on twitch.tv.
  ///
  /// In en, this message translates to:
  /// **'Mod View'**
  String get modToolsModView;

  /// Clip details: a pill saying the clip comes from a broadcast that still has its video.
  ///
  /// In en, this message translates to:
  /// **'From a past broadcast'**
  String get clipFromPastBroadcast;

  /// The player of an offline channel: the line above the past broadcasts button. name is the channel's display name.
  ///
  /// In en, this message translates to:
  /// **'{name} is offline. Check back soon!'**
  String streamCheckBackSoon({required String name});

  /// The player of an offline channel whose name is not known yet.
  ///
  /// In en, this message translates to:
  /// **'This channel is offline. Check back soon!'**
  String get streamCheckBackSoonGeneric;

  /// Error message. The player when neither the stream nor the channel could be read; « Try again » follows.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load this channel.'**
  String get streamOfflineLoadFailed;

  /// The title of a creator goal counting subscriptions, on the goal banner at the top of chat and in its dialog.
  ///
  /// In en, this message translates to:
  /// **'Sub goal'**
  String get goalKindSubs;

  /// The title of a creator goal counting sub points (a Tier 2 sub counts 2, a Tier 3 sub counts 6), on the goal banner and in its dialog.
  ///
  /// In en, this message translates to:
  /// **'Sub points goal'**
  String get goalKindSubPoints;

  /// The title of a creator goal counting only new subscriptions made since it started, on the goal banner and in its dialog.
  ///
  /// In en, this message translates to:
  /// **'New sub goal'**
  String get goalKindNewSubs;

  /// The title of a creator goal counting the sub points of new subscriptions only, on the goal banner and in its dialog.
  ///
  /// In en, this message translates to:
  /// **'New sub points goal'**
  String get goalKindNewSubPoints;

  /// The title of a creator goal counting followers, on the goal banner and in its dialog.
  ///
  /// In en, this message translates to:
  /// **'Follower goal'**
  String get goalKindFollowers;

  /// The title of a creator goal of a kind ONSET does not know, on the goal banner and in its dialog.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goalKindOther;

  /// Numbers a goal when the channel runs several at once, before its title on the goal banner (« 1/2 · Sub goal »).
  ///
  /// In en, this message translates to:
  /// **'{index}/{count}'**
  String goalOrdinal({required int index, required int count});

  /// How far a creator goal is, on its banner and in its dialog.
  ///
  /// In en, this message translates to:
  /// **'{current} of {target}'**
  String goalProgress({required int current, required int target});

  /// The title of the dialog that opens when the channel reaches a creator goal, and of the goal banner once the goal is reached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached'**
  String get goalReachedTitle;

  /// The text of the goal reached dialog.
  ///
  /// In en, this message translates to:
  /// **'The channel reached this goal. Thanks to everyone who chipped in!'**
  String get goalReachedBody;

  /// What a screen reader says the seek bar is at when the video has game chapters. value is the time read by vodSeekValue (« 12:05 of 1:02:15 »); chapter is the game played at that time.
  ///
  /// In en, this message translates to:
  /// **'{value}, {chapter}'**
  String vodSeekValueChapter({required String value, required String chapter});

  /// A link at the top of search results when the search is a single word: opens the live channels with that tag.
  ///
  /// In en, this message translates to:
  /// **'Live channels tagged {tag}'**
  String searchLiveWithTag({required String tag});

  /// Header above a message sent with the gigantify an emote power-up; its last emote is drawn large.
  ///
  /// In en, this message translates to:
  /// **'Gigantified emote'**
  String get chatGigantifiedEmote;

  /// A channel's profile: the Collections tab (the channel's playlists of videos).
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get profileTabCollections;

  /// A collection card on a channel's profile: how many videos the collection holds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} video} other{{count} videos}}'**
  String profileCollectionVideos({required int count});

  /// A clips list's sort chip: the newest clips first.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get clipSortNewest;

  /// A clips list's sort chip: the oldest clips first.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get clipSortOldest;

  /// A clips list's chip that opens a calendar to list the clips made between two dates.
  ///
  /// In en, this message translates to:
  /// **'Pick dates'**
  String get clipPickDates;

  /// A clips list's chip once two dates are picked: the first and last day.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String clipDateRange({required String start, required String end});

  /// A clips list's chip that puts the period, dates and sort back to their defaults.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get clipFiltersReset;

  /// A clips list with nothing in the last 24 hours.
  ///
  /// In en, this message translates to:
  /// **'No clips in the last 24 hours'**
  String get clipsNoneLastDay;

  /// A clips list with nothing in the last 7 days.
  ///
  /// In en, this message translates to:
  /// **'No clips in the last 7 days'**
  String get clipsNoneLastWeek;

  /// A clips list with nothing in the last 30 days.
  ///
  /// In en, this message translates to:
  /// **'No clips in the last 30 days'**
  String get clipsNoneLastMonth;

  /// A clips list with no clips at all.
  ///
  /// In en, this message translates to:
  /// **'No clips yet'**
  String get clipsNoneAllTime;

  /// A clips list with nothing between the two picked dates.
  ///
  /// In en, this message translates to:
  /// **'No clips between {start} and {end}'**
  String clipsNoneInRange({required String start, required String end});

  /// A clip's action: saves the clip's video through the system share sheet (Save video, Files…).
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get clipDownload;

  /// A snack bar while the clip's video downloads, before the share sheet opens.
  ///
  /// In en, this message translates to:
  /// **'Preparing the clip…'**
  String get clipDownloadPreparing;

  /// A snack bar when the clip's video could not be downloaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t download this clip.'**
  String get clipDownloadFailed;

  /// The screen listing the viewer's own clips: those of their channel and those they made.
  ///
  /// In en, this message translates to:
  /// **'My clips'**
  String get myClipsTitle;

  /// My clips: the tab with the clips made on the viewer's own channel.
  ///
  /// In en, this message translates to:
  /// **'My channel'**
  String get myClipsOfMyChannel;

  /// My clips: the tab with the clips the viewer made on any channel.
  ///
  /// In en, this message translates to:
  /// **'Clipped by me'**
  String get myClipsMadeByMe;

  /// My clips: opens Twitch's clip manager, where clips can be deleted (Twitch's API can't delete a clip).
  ///
  /// In en, this message translates to:
  /// **'Manage on Twitch'**
  String get myClipsManage;

  /// The settings row that opens My clips: what it lists.
  ///
  /// In en, this message translates to:
  /// **'Your channel’s clips and the ones you made'**
  String get myClipsSubtitle;

  /// A live list's filter chip that opens the languages to show, for this list only.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get streamFilterLanguage;

  /// A live list's language sheet: the first choice, which follows the stream language picked in settings.
  ///
  /// In en, this message translates to:
  /// **'As in Settings ({language})'**
  String streamFilterFollowSetting({required String language});

  /// A live list's chip that removes its language and tag filters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get streamFilterClear;

  /// Screen readers: the row of language and tag filters above a live list.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get streamFilterLabel;

  /// A live list emptied by its language or tag filter.
  ///
  /// In en, this message translates to:
  /// **'No live channels match these filters'**
  String get streamFilterNoMatch;

  /// Search: the shelf of live channels in the category the search matched.
  ///
  /// In en, this message translates to:
  /// **'Related live channels'**
  String get searchRelatedLives;

  /// Chat settings: the row that draws chosen chat events (subs, gifts, raids…) as rounded bubbles.
  ///
  /// In en, this message translates to:
  /// **'Event bubbles'**
  String get chatBubblesTitle;

  /// Chat settings: what Event bubbles does.
  ///
  /// In en, this message translates to:
  /// **'Draws the chat events you choose as rounded bubbles.'**
  String get chatBubblesDetail;

  /// Chat settings: Event bubbles when no event type is drawn as a bubble (feminine plural in French: les bulles).
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get chatBubblesOff;

  /// Chat settings: how many event types are drawn as bubbles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} type} other{{count} types}}'**
  String chatBubblesCount({required int count});

  /// Event bubbles: subs, resubs and sub upgrades.
  ///
  /// In en, this message translates to:
  /// **'Subs'**
  String get chatBubblesSubs;

  /// Event bubbles: gifted subs.
  ///
  /// In en, this message translates to:
  /// **'Gifted subs'**
  String get chatBubblesGifts;

  /// Event bubbles: raids.
  ///
  /// In en, this message translates to:
  /// **'Raids'**
  String get chatBubblesRaids;

  /// Event bubbles: announcements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get chatBubblesAnnouncements;

  /// Event bubbles: milestones, charity, Bits badges and the rest.
  ///
  /// In en, this message translates to:
  /// **'Other events'**
  String get chatBubblesOther;

  /// The page of one channel's own preferences: its bell, its chat and its place in lists.
  ///
  /// In en, this message translates to:
  /// **'Channel preferences'**
  String get channelPrefsTitle;

  /// Channel preferences: the note at the top.
  ///
  /// In en, this message translates to:
  /// **'These choices apply to {name} only.'**
  String channelPrefsIntro({required String name});

  /// Channel preferences: the notifications group.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get channelPrefsNotifications;

  /// Channel preferences: the switch that turns this channel's go-live notification on or off.
  ///
  /// In en, this message translates to:
  /// **'Live notifications'**
  String get channelPrefsBell;

  /// Channel preferences: what the bell does.
  ///
  /// In en, this message translates to:
  /// **'Get a notification when {name} goes live.'**
  String channelPrefsBellDetail({required String name});

  /// Channel preferences: the bell when live notifications are off in settings.
  ///
  /// In en, this message translates to:
  /// **'Turn on live notifications in Settings to use the bell.'**
  String get channelPrefsBellOff;

  /// Channel preferences: the bell when logged out.
  ///
  /// In en, this message translates to:
  /// **'Log in to get live notifications.'**
  String get channelPrefsBellLoggedOut;

  /// Channel preferences: the chat group.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get channelPrefsChat;

  /// Channel preferences: shows subs, gifts, raids and announcements in this channel's chat.
  ///
  /// In en, this message translates to:
  /// **'Show notices'**
  String get channelPrefsNotices;

  /// Channel preferences: what Show notices covers.
  ///
  /// In en, this message translates to:
  /// **'Subs, gifts, raids, and announcements in this chat.'**
  String get channelPrefsNoticesDetail;

  /// Channel preferences: Show notices when they are off for every chat.
  ///
  /// In en, this message translates to:
  /// **'Notices are turned off for every chat in Settings › Chat.'**
  String get channelPrefsNoticesOff;

  /// Channel preferences: the group about where the channel appears in lists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get channelPrefsLists;

  /// Channel preferences: pins the channel at the top of Following.
  ///
  /// In en, this message translates to:
  /// **'Pin to the top'**
  String get channelPrefsPin;

  /// Channel preferences: what Pin to the top does.
  ///
  /// In en, this message translates to:
  /// **'Shows this channel first in Following when it’s live.'**
  String get channelPrefsPinDetail;

  /// Channel preferences: leaves the channel out of Browse, category and tag lists.
  ///
  /// In en, this message translates to:
  /// **'Hide from Browse'**
  String get channelPrefsHide;

  /// Channel preferences: what Hide from Browse does.
  ///
  /// In en, this message translates to:
  /// **'Leaves this channel out of Browse, category, and tag lists. Following still shows it.'**
  String get channelPrefsHideDetail;

  /// A channel's More sheet: opens the channel's own preferences.
  ///
  /// In en, this message translates to:
  /// **'Channel preferences'**
  String get userActionsChannelPrefs;

  /// The channel points panel: the viewer's Bits balance, live from Twitch.
  ///
  /// In en, this message translates to:
  /// **'Bits balance: {bits}'**
  String pointsBitsBalance({required String bits});

  /// The channel points panel: how many subs viewers gifted in this channel since the viewer opened it.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} sub gifted here since you joined} other{{count} subs gifted here since you joined}}'**
  String pointsGiftedHere({required int count});

  /// The snack bar that says a goal was reached while the video fills the screen or the viewer types: opens the goal.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get goalReachedDetails;

  /// A live poll's button in ONSET: sends the viewer's vote for the answer they picked.
  ///
  /// In en, this message translates to:
  /// **'Vote'**
  String get pollVoteSend;

  /// Under a live poll once the viewer voted from ONSET.
  ///
  /// In en, this message translates to:
  /// **'You voted for {choice}'**
  String pollVotedFor({required String choice});

  /// Snack bar after a viewer action sent to Twitch from ONSET (a poll vote, leaving or joining a raid, sharing a watch streak, acknowledging a warning).
  ///
  /// In en, this message translates to:
  /// **'{status, select, done{Done.} refused{Twitch declined this.} integrityRefused{Twitch’s anti-bot check refused this. ONSET can’t pass it, so try on twitch.tv.} signedOut{Log in again to do this from ONSET.} other{Couldn’t reach Twitch. Try again.}}'**
  String viewerActionResult({required String status});

  /// The watch streak card's button, shown when Twitch lets the viewer share a milestone they just reached: posts it in the channel's chat.
  ///
  /// In en, this message translates to:
  /// **'Share in chat'**
  String get streakShareInChat;

  /// Snack bar once the viewer's watch streak milestone was shared in chat.
  ///
  /// In en, this message translates to:
  /// **'Your watch streak was shared in chat.'**
  String get streakSharedInChat;

  /// Title of the dialog opened from the bar above the chat input after a moderator warned the viewer.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge the warning?'**
  String get chatWarningTitle;

  /// Text of the dialog that acknowledges a moderator's warning; the warning itself is the notice line in chat.
  ///
  /// In en, this message translates to:
  /// **'A moderator sent you a warning in this chat. Read it in chat, then acknowledge it to send messages again.'**
  String get chatWarningBody;

  /// The dialog's button that tells Twitch the viewer read the moderator's warning, which lets them chat again.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge'**
  String get chatWarningAcknowledge;

  /// Title of the card atop the channel points panel when Twitch lets the viewer announce their sub anniversary (resub) in this chat.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, one{Share your {months}-month sub} other{Share your {months}-month sub}}'**
  String resubShareTitle({required int months});

  /// Text of the resub card in the channel points panel.
  ///
  /// In en, this message translates to:
  /// **'Twitch lets you announce it in this chat, with a message if you like.'**
  String get resubShareBody;

  /// Title of the dialog that announces the viewer's resub in chat; nothing is sent before the viewer taps Share.
  ///
  /// In en, this message translates to:
  /// **'Share your sub in chat?'**
  String get resubShareDialogTitle;

  /// Hint of the optional message field of the resub share dialog.
  ///
  /// In en, this message translates to:
  /// **'Message (optional)'**
  String get resubShareMessageHint;

  /// The resub share dialog's button that posts the resub in chat.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get resubShareSend;

  /// Snack bar once the viewer's resub was announced in chat.
  ///
  /// In en, this message translates to:
  /// **'Your sub was shared in chat.'**
  String get resubSharedInChat;

  /// Snack bar when a watch streak that was suspended (a stream was missed) is counted again by Twitch.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Your watch streak is saved: {count} stream in a row.} other{Your watch streak is saved: {count} streams in a row.}}'**
  String streakRecovered({required int count});

  /// Snack bar when a suspended watch streak was not saved in time and Twitch reset it.
  ///
  /// In en, this message translates to:
  /// **'Your watch streak in this channel has ended.'**
  String get streakExpired;

  /// The channel points panel's row, and the title of the sheet it opens, listing the channel's top Bits cheerers and gift sub givers.
  ///
  /// In en, this message translates to:
  /// **'Leaderboards'**
  String get leaderboardsTitle;

  /// Choice between the channel's two leaderboards: Bits cheered and subs gifted.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, cheers{Bits} gifts{Gift subs} other{Other}}'**
  String leaderboardsTab({required String kind});

  /// The period the channel's leaderboards cover, as the channel set it on Twitch.
  ///
  /// In en, this message translates to:
  /// **'{period, select, day{Today} week{This week} month{This month} allTime{All time} other{Recent}}'**
  String leaderboardsPeriod({required String period});

  /// A viewer's score on the Bits leaderboard; amount is count with the locale's digit grouping.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{amount} Bit cheered} other{{amount} Bits cheered}}'**
  String leaderboardsBits({required int count, required String amount});

  /// A viewer's score on the gift sub leaderboard; amount is count with the locale's digit grouping.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{amount} sub gifted} other{{amount} subs gifted}}'**
  String leaderboardsGifts({required int count, required String amount});

  /// Under a leaderboard, the logged-in viewer's own position when Twitch gives it.
  ///
  /// In en, this message translates to:
  /// **'Your rank: {rank}'**
  String leaderboardsYourRank({required int rank});

  /// A leaderboard with no entries.
  ///
  /// In en, this message translates to:
  /// **'No one is on this leaderboard yet.'**
  String get leaderboardsEmpty;

  /// The leaderboards sheet when Twitch did not answer or answered in a shape ONSET no longer reads.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load the leaderboards.'**
  String get leaderboardsFailed;

  /// Small heading of the card opened from a shoutout line in chat, which presents the channel the streamer recommends (shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'Shoutout'**
  String get shoutoutCardEyebrow;

  /// Above the categories the shouted-out channel streamed recently, on the shoutout card.
  ///
  /// In en, this message translates to:
  /// **'Recent categories'**
  String get shoutoutCardRecent;

  /// The shouted-out channel's next scheduled stream, on the shoutout card; time is a localized date and time.
  ///
  /// In en, this message translates to:
  /// **'Next stream: {time}'**
  String shoutoutCardNext({required String time});

  /// The shoutout card when Twitch did not answer; Follow and Profile still work.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load this channel’s details.'**
  String get shoutoutCardFailed;

  /// Title of the card in the channel points panel listing the Twitch Drops this channel offers.
  ///
  /// In en, this message translates to:
  /// **'Drops available'**
  String get dropsCardTitle;

  /// When a Drops campaign ends, under its name in the Drops card.
  ///
  /// In en, this message translates to:
  /// **'Ends {date}'**
  String dropsEndsOn({required String date});

  /// Watch time still needed before a Drop can be claimed.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{{minutes} minute left} other{{minutes} minutes left}}'**
  String dropsMinutesLeft({required int minutes});

  /// Subs bought or gifted so far toward a Drop that needs subs.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, one{{current} of {total} sub} other{{current} of {total} subs}}'**
  String dropsSubsProgress({required int current, required int total});

  /// Button that claims a Drop reward the viewer has earned.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get dropsClaim;

  /// State of a Drop reward the viewer already claimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get dropsClaimed;

  /// State of a Drop that needs an earlier Drop of the campaign first.
  ///
  /// In en, this message translates to:
  /// **'Unlocks after the previous Drop'**
  String get dropsLocked;

  /// Line in the Drops card for a logged-out viewer.
  ///
  /// In en, this message translates to:
  /// **'Log in to see your progress and claim rewards.'**
  String get dropsSignInForProgress;

  /// Note in the Drops card explaining how Twitch counts Drop progress.
  ///
  /// In en, this message translates to:
  /// **'Twitch counts Drop progress from its own player, so watching in ONSET may not add to it. You can only earn progress in one channel at a time.'**
  String get dropsProgressNote;

  /// Button in the Drops card that opens the publisher’s page to link a game account, needed before claiming.
  ///
  /// In en, this message translates to:
  /// **'Link your game account'**
  String get dropsLinkAccount;

  /// Snack bar after claiming a Drop reward from the Drops card.
  ///
  /// In en, this message translates to:
  /// **'{status, select, claimed{Reward claimed.} alreadyClaimed{You already claimed this reward.} needsAccountLink{Link your game account first, then claim again.} expired{This Drop has expired.} limitReached{You’ve reached this reward’s limit.} integrityRefused{Twitch’s anti-bot check refused this. ONSET can’t pass it, so claim it on twitch.tv.} signedOut{Log in again to claim from ONSET.} refused{Twitch declined this claim.} other{Couldn’t reach Twitch. Try again.}}'**
  String dropClaimResult({required String status});

  /// ONSET’s own chat line when the channel offers a Drop earned by watch time.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{{channel} turned on Drops for the community! Watch for {minutes} minute to claim the reward.} other{{channel} turned on Drops for the community! Watch for {minutes} minutes to claim the reward.}}'**
  String communityDropsWatch({required String channel, required int minutes});

  /// ONSET’s own chat line when the channel offers a Drop earned by buying or gifting subs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{channel} turned on Drops for the community! Buy or gift {count} sub while the channel is live to get the reward.} other{{channel} turned on Drops for the community! Buy or gift {count} subs while the channel is live to get the reward.}}'**
  String communityDropsSubs({required String channel, required int count});

  /// ONSET’s own chat line when the channel offers a Drop earned with Turbo.
  ///
  /// In en, this message translates to:
  /// **'{channel} turned on Drops for the community! Get Turbo to earn the rewards.'**
  String communityDropsTurbo({required String channel});

  /// ONSET’s own chat line when the channel offers several Drops.
  ///
  /// In en, this message translates to:
  /// **'{channel} turned on Drops for the community! Watch the stream and buy subs to claim the rewards.'**
  String communityDropsSeveral({required String channel});

  /// Title of the sheet and the points panel row listing the channel’s community goals, which viewers fund with channel points.
  ///
  /// In en, this message translates to:
  /// **'Community goals'**
  String get communityGoalsTitle;

  /// Community goals sheet when the channel has none.
  ///
  /// In en, this message translates to:
  /// **'No community goal is running.'**
  String get communityGoalsEmpty;

  /// Community goals sheet when Twitch did not answer.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load the community goals.'**
  String get communityGoalsFailed;

  /// How far a community goal is, under its progress bar.
  ///
  /// In en, this message translates to:
  /// **'{percent}% raised'**
  String communityGoalRaised({required int percent});

  /// Points given so far to a community goal, out of its target.
  ///
  /// In en, this message translates to:
  /// **'{raised} of {needed} points'**
  String communityGoalAmount({required String raised, required String needed});

  /// State of a community goal that is over.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get communityGoalEnded;

  /// State of a community goal the viewer already gave the most allowed to this stream.
  ///
  /// In en, this message translates to:
  /// **'Max contribution per stream reached'**
  String get communityGoalMaxReached;

  /// Button that gives channel points to a community goal; it asks for the amount first.
  ///
  /// In en, this message translates to:
  /// **'Contribute'**
  String get communityGoalContribute;

  /// Title of the dialog asking how many points to give to a community goal.
  ///
  /// In en, this message translates to:
  /// **'Contribute to this goal'**
  String get communityGoalContributeTitle;

  /// Hint of the amount field in the contribute dialog.
  ///
  /// In en, this message translates to:
  /// **'Points (up to {max})'**
  String communityGoalAmountHint({required String max});

  /// Chip in the contribute dialog that fills in the most points the viewer can give.
  ///
  /// In en, this message translates to:
  /// **'Max {amount}'**
  String communityGoalMax({required String amount});

  /// Line in the community goals sheet for a logged-out viewer.
  ///
  /// In en, this message translates to:
  /// **'Log in to contribute.'**
  String get communityGoalLogIn;

  /// Snack bar after giving channel points to a community goal.
  ///
  /// In en, this message translates to:
  /// **'{status, select, contributed{Thank you! Your points went to the goal.} notEnoughPoints{You don’t have enough points for this.} maxPerStream{You’ve given the most allowed for this stream. Try again next stream.} notOpen{This goal isn’t taking points right now.} refused{Twitch declined this contribution.} integrityRefused{Twitch’s anti-bot check refused this. ONSET can’t pass it, so contribute on twitch.tv.} signedOut{Log in again to contribute from ONSET.} other{Couldn’t reach Twitch. Try again.}}'**
  String goalContributionResult({required String status});

  /// Title of the channel’s Community sheet (challenges, goals, and top supporters), opened from the points panel.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get communityTabTitle;

  /// Section of the Community sheet listing the community goals viewers fund with channel points.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get communityChallenges;

  /// Section of the Community sheet listing the streamer’s sub and follower goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get communityCreatorGoals;

  /// Section of the Community sheet listing the top cheerers and gifters.
  ///
  /// In en, this message translates to:
  /// **'Top supporters'**
  String get communityTopSupporters;

  /// Button under the top supporters that opens the full leaderboards.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get communitySeeAll;

  /// A Community sheet section with nothing to show.
  ///
  /// In en, this message translates to:
  /// **'Nothing here right now.'**
  String get communityNothing;

  /// A Community sheet section Twitch did not answer for.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load this section.'**
  String get communitySectionFailed;

  /// Title of the confirmation before a first prediction. outcome is the outcome's title as the streamer wrote it; points is the stake, already formatted; pointsName is the channel's name for its points.
  ///
  /// In en, this message translates to:
  /// **'Predict “{outcome}” with {points} {pointsName}?'**
  String predictionTermsTitle({
    required String outcome,
    required String points,
    required String pointsName,
  });

  /// Body of the confirmation before a first prediction.
  ///
  /// In en, this message translates to:
  /// **'You’ll get a temporary chat badge, and you won’t be able to change your pick. By continuing, you accept Twitch’s prediction terms.'**
  String get predictionTermsBody;

  /// Title of the confirmation before a 0-point prediction (viewers whose region can't spend points). outcome is the outcome's title; pointsName is the channel's name for its points.
  ///
  /// In en, this message translates to:
  /// **'Predict “{outcome}” with 0 {pointsName}?'**
  String predictionSpectatorTitle({
    required String outcome,
    required String pointsName,
  });

  /// Body of the confirmation before a 0-point prediction. pointsName is the channel's name for its points.
  ///
  /// In en, this message translates to:
  /// **'You’ll get a temporary chat badge, and you won’t be able to change your pick or win {pointsName} from this prediction.'**
  String predictionSpectatorBody({required String pointsName});

  /// Why only a 0-point prediction is offered. kind is category (the stream's content is restricted in the viewer's region) or region; pointsName is the channel's name for its points.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, category{Viewers in your region can only predict on this content without spending {pointsName}.} other{Viewers in your region can only predict without spending {pointsName}.}}'**
  String predictionRegionNotice({
    required String kind,
    required String pointsName,
  });

  /// Link to Twitch's prediction terms and conditions.
  ///
  /// In en, this message translates to:
  /// **'Prediction terms'**
  String get predictionTermsLink;

  /// Confirms a prediction in the terms dialog.
  ///
  /// In en, this message translates to:
  /// **'Predict'**
  String get predictionTermsAccept;

  /// Closes the prediction terms dialog without predicting.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get predictionTermsDecline;

  /// Title of the step shown before a moderator predicts.
  ///
  /// In en, this message translates to:
  /// **'You’re taking part as a moderator'**
  String get predictionModeratorTitle;

  /// Explains what a moderator gives up by predicting. creator is streamer, self, other (name is who created it) or unknown.
  ///
  /// In en, this message translates to:
  /// **'{creator, select, streamer{The streamer created this prediction. If you take part, you won’t be able to help choose the outcome.} self{You created this prediction. If you take part, you won’t be able to help choose the outcome.} unknown{This prediction was created by the channel’s team. If you take part, you won’t be able to help choose the outcome.} other{{name} created this prediction. If you take part, you won’t be able to help choose the outcome.}}'**
  String predictionModeratorBody({
    required String creator,
    required String name,
  });

  /// Confirms the moderator wants to predict.
  ///
  /// In en, this message translates to:
  /// **'Take part anyway'**
  String get predictionModeratorAccept;

  /// Snackbar after a 0-point prediction. outcome is the outcome's title; pointsName is the channel's name for its points.
  ///
  /// In en, this message translates to:
  /// **'You predicted “{outcome}” with 0 {pointsName}.'**
  String predictionSpectatorDone({
    required String outcome,
    required String pointsName,
  });

  /// Snackbar when Twitch refuses a prediction. kind names Twitch's refusal; reason is Twitch's own code for any other refusal (never translated).
  ///
  /// In en, this message translates to:
  /// **'{kind, select, mustAcceptTerms{Accept the prediction terms first.} regionLocked{Viewers in your region can’t spend points on predictions.} categoryLocked{Viewers in your region can’t spend points on predictions for this content.} manager{Streamers can’t predict on their own channel.} spectatorDuplicate{You’ve already made a prediction.} spectatorIneligible{You can’t predict with 0 points here.} notEnoughPoints{You don’t have enough points.} notActive{This prediction is closed.} maxPoints{That’s more than this prediction allows.} multipleOutcomes{You’ve already picked another outcome.} other{Twitch refused: {reason}}}'**
  String predictionRefused({required String kind, required String reason});

  /// The points' name inside a prediction sentence when the channel didn't name them.
  ///
  /// In en, this message translates to:
  /// **'channel points'**
  String get predictionPointsFallback;

  /// Title of the weekly rewards card in the channel points panel.
  ///
  /// In en, this message translates to:
  /// **'Weekly rewards'**
  String get weeklyRewardsTitle;

  /// The viewer's weekly rewards level, on a chip.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String weeklyRewardsLevel({required int level});

  /// Weekly rewards progress: days the viewer watched this week out of the days needed.
  ///
  /// In en, this message translates to:
  /// **'{visited, plural, one{{visited} of {required} days this week} other{{visited} of {required} days this week}}'**
  String weeklyRewardsDays({required int required, required int visited});

  /// Where the viewer stands in the weekly rewards. status is earned (this week's reward is in), complete (every level reached) or progress; count is the days still needed this week.
  ///
  /// In en, this message translates to:
  /// **'{status, select, earned{You’ve earned this week’s reward. Come back next week for more.} complete{Your badge is fully upgraded, and you’ve collected every reward.} other{{count, plural, one{Watch on 1 more day this week to earn the next reward.} other{Watch on {count} more days this week to earn the next reward.}}}}'**
  String weeklyRewardsStatus({required String status, required int count});

  /// One weekly reward level: its number and the channel points it gives. points is the amount, already formatted; count is the same number, for the plural.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Level {level} · {points} point} other{Level {level} · {points} points}}'**
  String weeklyRewardsTier({
    required int count,
    required int level,
    required String points,
  });

  /// Footer of the weekly rewards card. date is the event's end date, already formatted.
  ///
  /// In en, this message translates to:
  /// **'Rewards level up every week. The event ends on {date}.'**
  String weeklyRewardsEnds({required String date});

  /// Title of the card offering to claim a community moment.
  ///
  /// In en, this message translates to:
  /// **'A community moment just happened'**
  String get momentCardTitle;

  /// Body of the card offering to claim a community moment.
  ///
  /// In en, this message translates to:
  /// **'Claim it to add it to your moments badge.'**
  String get momentCardBody;

  /// Button that claims a community moment.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get momentClaim;

  /// Snackbar after claiming a community moment. status is MomentClaimResult.name.
  ///
  /// In en, this message translates to:
  /// **'{status, select, claimed{Moment claimed. It can take a few minutes to show on your moments badge.} alreadyClaimed{You already claimed this moment.} expired{This moment can’t be claimed anymore.} invalid{Twitch doesn’t know this moment.} integrityRefused{Twitch’s anti-bot check refused this. ONSET can’t pass it, so claim it on twitch.tv.} signedOut{Log in again to claim from ONSET.} other{Couldn’t claim this moment. Try again.}}'**
  String momentClaimResult({required String status});

  /// Local chat line when a community moment can be claimed. channel is the channel's name.
  ///
  /// In en, this message translates to:
  /// **'A community moment just happened in {channel}’s chat. Claim it from the channel points panel.'**
  String momentChatLine({required String channel});

  /// Title of the emote picker for a channel points reward. kind is modified (pick an emote, then an effect) or chosen.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, modified{Modify an emote} other{Choose an emote to unlock}}'**
  String emoteUnlockTitle({required String kind});

  /// Section label above the modified versions of the chosen emote.
  ///
  /// In en, this message translates to:
  /// **'Pick an effect'**
  String get emoteUnlockModifier;

  /// Button that spends the points on the chosen emote. points is the cost, already formatted; count is the same number, for the plural.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Unlock for {points} point} other{Unlock for {points} points}}'**
  String emoteUnlockConfirm({required int count, required String points});

  /// The emote picker when the channel has no tier 1 emotes.
  ///
  /// In en, this message translates to:
  /// **'This channel has no emotes to unlock.'**
  String get emoteUnlockEmpty;

  /// The emote picker when Twitch did not answer.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load this channel’s emotes.'**
  String get emoteUnlockFailed;

  /// Snackbar after unlocking a chosen emote with channel points.
  ///
  /// In en, this message translates to:
  /// **'Emote unlocked. It’s in your emote menu.'**
  String get emoteUnlockDone;

  /// Title of the card showing the channel's emote chest collection (Twitch's Hype Chests).
  ///
  /// In en, this message translates to:
  /// **'Emote chests'**
  String get hypeChestsTitle;

  /// How many emotes of the chest collection the viewer owns.
  ///
  /// In en, this message translates to:
  /// **'{owned, plural, one{{owned} of {total} emotes collected} other{{owned} of {total} emotes collected}}'**
  String hypeChestsCollected({required int owned, required int total});

  /// How many chests the viewer has not opened yet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{You have 1 unopened chest.} other{You have {count} unopened chests.}}'**
  String hypeChestsUnopened({required int count});

  /// Why the card has no Open button.
  ///
  /// In en, this message translates to:
  /// **'ONSET can’t open chests yet. Open them on Twitch to reveal your emotes.'**
  String get hypeChestsOpenElsewhere;

  /// Button that opens the full emote collection.
  ///
  /// In en, this message translates to:
  /// **'See the collection'**
  String get hypeChestsSeeCollection;

  /// A rarity tier of the chest emote collection, as a section label. tier is Twitch's tier code.
  ///
  /// In en, this message translates to:
  /// **'{tier, select, LEGENDARY{Legendary} EPIC{Epic} RARE{Rare} UNCOMMON{Uncommon} COMMON{Common} other{Other}}'**
  String hypeChestsTier({required String tier});

  /// Screen-reader label of an owned collection emote. name is the emote's code.
  ///
  /// In en, this message translates to:
  /// **'{name}, collected'**
  String hypeChestsOwned({required String name});

  /// Screen-reader label of a collection emote the viewer doesn't own. name is the emote's code.
  ///
  /// In en, this message translates to:
  /// **'{name}, not collected yet'**
  String hypeChestsMissing({required String name});

  /// Title of the piñata section in the hype train details.
  ///
  /// In en, this message translates to:
  /// **'Piñata train'**
  String get pinataTitle;

  /// What a piñata hype train is.
  ///
  /// In en, this message translates to:
  /// **'Every contribution cracks the piñata a little more. When it breaks, it showers rewards on the people who took part.'**
  String get pinataBody;

  /// How cracked the piñata is.
  ///
  /// In en, this message translates to:
  /// **'Damage stage {stage}'**
  String pinataStage({required int stage});

  /// Whether the viewer will get piñata rewards. eligible is yes or no.
  ///
  /// In en, this message translates to:
  /// **'{eligible, select, yes{You’ll share the rewards when it breaks.} other{Contribute to share the rewards when it breaks.}}'**
  String pinataEligible({required String eligible});

  /// Section label in the chat menu: the streamer has guests (Guest Star) or streams together with other channels.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, guestStar{Guests on stream} other{Streaming together}}'**
  String liveTogetherTitle({required String kind});

  /// The line naming who the streamer is live with.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, guestStar{Live with {names}} other{Streaming together with {names}}}'**
  String liveTogetherLine({required String kind, required String names});

  /// Names shown, then how many more channels are part of it.
  ///
  /// In en, this message translates to:
  /// **'{names} and {count, plural, one{{count} other} other{{count} others}}'**
  String liveTogetherNamesMore({required String names, required int count});

  /// Viewers across every channel streaming together.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} viewer in total} other{{count} viewers in total}}'**
  String liveTogetherTotal({required int count});

  /// The channel that leads a shared stream or hosts the guests.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get liveTogetherHost;

  /// A guest who appears on the stream without streaming on their own channel.
  ///
  /// In en, this message translates to:
  /// **'Not live on their own channel'**
  String get liveTogetherNotLive;

  /// The Mythic Hype Train emote Twitch picked from the pool.
  ///
  /// In en, this message translates to:
  /// **'Chosen emote: {name}'**
  String htMythicChosen({required String name});

  /// In an emote's details: the effect (modifier) applied to a subscriber emote.
  ///
  /// In en, this message translates to:
  /// **'{code, select, BW{Effect: black and white} HF{Effect: flipped} SG{Effect: sunglasses} SQ{Effect: squished} TK{Effect: thinking} other{Effect: modified}}'**
  String emoteModifierLine({required String code});

  /// In a Bits emote's details: the Bits badge tier that unlocks it.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Unlocked by cheering {count} Bit in this channel} other{Unlocked by cheering {count} Bits in this channel}}'**
  String emoteBitsThreshold({required int count});

  /// Chat menu row and sheet title: choose the badge shown next to your name.
  ///
  /// In en, this message translates to:
  /// **'Your chat badge'**
  String get chatBadgeTitle;

  /// Section: the badge shown in this channel only.
  ///
  /// In en, this message translates to:
  /// **'In this channel'**
  String get chatBadgeChannel;

  /// Section: the global badge.
  ///
  /// In en, this message translates to:
  /// **'On every channel'**
  String get chatBadgeGlobal;

  /// Choice: show no badge.
  ///
  /// In en, this message translates to:
  /// **'No badge'**
  String get chatBadgeNone;

  /// Confirmation title before changing the displayed badge.
  ///
  /// In en, this message translates to:
  /// **'{none, select, yes{Show no badge next to your name?} other{Show “{badge}” next to your name?}}'**
  String chatBadgeConfirm({required String none, required String badge});

  /// Confirmation body before changing the displayed badge.
  ///
  /// In en, this message translates to:
  /// **'{scope, select, channel{Everyone in this channel will see it. You can change it back anytime.} other{Everyone will see it on channels where you haven’t picked a badge. You can change it back anytime.}}'**
  String chatBadgeConfirmBody({required String scope});

  /// Confirm button of a badge change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get chatBadgeChange;

  /// Snackbar after a badge or flair change, with an Undo button.
  ///
  /// In en, this message translates to:
  /// **'Badge changed.'**
  String get chatBadgeChanged;

  /// A badge or flair change failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t change your badge. Try again.'**
  String get chatBadgeFailed;

  /// The badge list could not be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your badges.'**
  String get chatBadgeLoadFailed;

  /// The web session needed for badges is missing.
  ///
  /// In en, this message translates to:
  /// **'Log in again to choose your badge from ONSET.'**
  String get chatBadgeLogIn;

  /// Switch: show the sub badge without its Tier 2 or Tier 3 look.
  ///
  /// In en, this message translates to:
  /// **'Hide sub badge flair'**
  String get chatBadgeHideFlair;

  /// Detail under the hide flair switch.
  ///
  /// In en, this message translates to:
  /// **'Your badge drops the Tier 2 or Tier 3 look.'**
  String get chatBadgeHideFlairDetail;

  /// Confirmation before changing the sub badge flair setting.
  ///
  /// In en, this message translates to:
  /// **'{hide, select, yes{Hide your sub badge flair?} other{Show your sub badge flair?}}'**
  String chatBadgeFlairConfirm({required String hide});

  /// Confirmation body for the flair setting.
  ///
  /// In en, this message translates to:
  /// **'It applies on every channel. You can change it back anytime.'**
  String get chatBadgeFlairBody;

  /// Sheet title, and what a screen reader says on the banned bar.
  ///
  /// In en, this message translates to:
  /// **'Request an unban'**
  String get unbanRequestTitle;

  /// Placeholder of the unban request text field.
  ///
  /// In en, this message translates to:
  /// **'Why should you come back to chat?'**
  String get unbanRequestHint;

  /// Under the unban request field.
  ///
  /// In en, this message translates to:
  /// **'You can only appeal a ban once, so make it count.'**
  String get unbanRequestOnce;

  /// Button sending the unban request.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get unbanRequestSend;

  /// Snackbar once the unban request is sent.
  ///
  /// In en, this message translates to:
  /// **'Your unban request will be reviewed.'**
  String get unbanRequestSent;

  /// The viewer's last unban request and its outcome.
  ///
  /// In en, this message translates to:
  /// **'{status, select, PENDING{You asked to be unbanned on {date}. The moderators haven’t answered yet.} DENIED{Your unban request from {date} was denied.} APPROVED{Your unban request from {date} was approved.} other{You asked to be unbanned on {date}.}}'**
  String unbanRequestStatus({required String status, required String date});

  /// Heading above the moderators' note on an unban request.
  ///
  /// In en, this message translates to:
  /// **'Note from the channel moderators:'**
  String get unbanRequestNote;

  /// Why no unban request can be sent.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, disabled{This channel doesn’t take unban requests.} wait{You can’t send an unban request right now.} other{Couldn’t load your unban request.}}'**
  String unbanRequestUnavailable({required String reason});

  /// Why an unban request was refused.
  ///
  /// In en, this message translates to:
  /// **'{code, select, ALREADY_CREATED{You’ve already sent an unban request.} TOO_SOON_SINCE_BAN{It’s too soon after your ban. Try again later.} UNBAN_REQUESTS_DISABLED{This channel doesn’t take unban requests.} NOT_BANNED{You’re not banned from this channel.} FAILED_MODERATION{Twitch refused this message. Reword it and try again.} signedOut{Log in again to send it from ONSET.} other{Couldn’t send your unban request. Try again.}}'**
  String unbanRequestFailed({required String code});

  /// A chat line Twitch sends to this viewer alone; the body is Twitch's own text.
  ///
  /// In en, this message translates to:
  /// **'{body} · Only visible to you'**
  String privateCalloutLine({required String body});

  /// Button on a private chat line when Twitch gives no label for its link.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get privateCalloutOpen;

  /// Banner when the viewer's prediction wins.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{You predicted it! You won {count} point.} other{You predicted it! You won {count} points.}}'**
  String predictionWon({required int count});

  /// Confirmation before sending the one-time unban request.
  ///
  /// In en, this message translates to:
  /// **'Send your unban request?'**
  String get unbanConfirmTitle;

  /// Body of the unban request confirmation.
  ///
  /// In en, this message translates to:
  /// **'You can only appeal once. The channel moderators will read your message.'**
  String get unbanConfirmBody;
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
