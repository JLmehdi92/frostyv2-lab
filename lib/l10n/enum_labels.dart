import 'package:onset/l10n/app_localizations.dart';
import 'package:onset/screens/home/stores/home_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

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
