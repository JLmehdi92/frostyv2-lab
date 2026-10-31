import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/general_settings.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/language_setting.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

import 'settings_harness.dart';

/// Settings › General › Language: System, English, Français.
void main() {
  final english = L10n.english;
  final french = lookupAppLocalizations(const Locale('fr'));
  late SettingsStore settings;

  setUp(() {
    mockSettingsPlatform();
    settings = SettingsStore.fromJson({'languagePromptVersion': 1});
  });

  /// General, in an app that follows the language setting (main.dart's).
  Future<void> pump(
    WidgetTester tester, {
    List<Locale> device = const [Locale('en', 'US')],
  }) async {
    useWindow(tester, const Size(390, 844));
    tester.platformDispatcher.localesTestValue = device;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: FakeAuthStore()),
          Provider<SettingsStore>.value(value: settings),
        ],
        child: Observer(
          builder: (_) => MaterialApp(
            locale: settings.appLanguage.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            localeListResolutionCallback: (device, _) =>
                resolveAppLocale(AppLanguage.system, device ?? const []),
            theme: themes.light,
            darkTheme: themes.dark,
            themeMode: ThemeMode.dark,
            home: Scaffold(body: GeneralSettings(settingsStore: settings)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the first group: System (selected), English, Français', (
    tester,
  ) async {
    await pump(tester);
    final title = tester.getTopLeft(
      find.text(english.settingsLanguageTitle.toUpperCase()),
    );
    final theme = tester.getTopLeft(find.text('THEME'));
    expect(title.dy, lessThan(theme.dy));
    expect(find.text(english.appLanguageSystem), findsWidgets);
    expect(find.text('English'), findsWidgets);
    expect(find.text('Français'), findsOneWidget);
    expect(
      tester.getSemantics(
        find.bySemanticsLabel(english.appLanguageSystem).first,
      ),
      matchesSemantics(
        label: english.appLanguageSystem,
        isButton: true,
        isChecked: true,
        hasCheckedState: true,
        isSelected: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('System says the language it gives on this device', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.text(
        english.settingsLanguageSystemSubtitle(
          language: english.languageInTextEnglish,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('on a French device, System gives French: the page is in '
      'French and says so', (tester) async {
    await pump(tester, device: const [Locale('fr', 'FR')]);
    expect(
      find.text(french.settingsLanguageTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.text(
        french.settingsLanguageSystemSubtitle(
          language: french.languageInTextFrench,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Français applies at once, and System goes back', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(settings.appLanguage, AppLanguage.fr);
    expect(settings.languagePromptVersion, kLanguagePromptVersion);
    // The page now reads in French, live.
    expect(
      find.text(french.settingsLanguageTitle.toUpperCase()),
      findsOneWidget,
    );
    // (The theme's pill, now in French too, has its own « Système ».)
    Finder inLanguage(String text) => find.descendant(
      of: find.byType(LanguageSetting),
      matching: find.text(text),
    );
    expect(inLanguage(french.appLanguageSystem), findsOneWidget);
    // System still says the device's language (English here).
    expect(
      find.text(
        french.settingsLanguageSystemSubtitle(
          language: french.languageInTextEnglish,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(inLanguage(french.appLanguageSystem));
    await tester.pumpAndSettle();
    expect(settings.appLanguage, AppLanguage.system);
    expect(
      find.text(english.settingsLanguageTitle.toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('English, picked on a French device, sticks', (tester) async {
    await pump(tester, device: const [Locale('fr', 'FR')]);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(settings.appLanguage, AppLanguage.en);
    expect(
      find.text(english.settingsLanguageTitle.toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('a device language change updates what System says, even '
      'with an explicit language', (tester) async {
    settings.chooseLanguage(AppLanguage.en);
    await pump(tester);
    expect(
      find.text(
        english.settingsLanguageSystemSubtitle(
          language: english.languageInTextEnglish,
        ),
      ),
      findsOneWidget,
    );
    tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
    await tester.pumpAndSettle();
    expect(settings.appLanguage, AppLanguage.en);
    expect(
      find.text(
        english.settingsLanguageSystemSubtitle(
          language: english.languageInTextFrench,
        ),
      ),
      findsOneWidget,
    );
  });
}
