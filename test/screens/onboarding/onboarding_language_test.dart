import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/onboarding/onboarding_flow.dart';
import 'package:onset/screens/onboarding/onboarding_intro.dart';
import 'package:onset/screens/onboarding/onboarding_language_choice.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/widgets/launch/launch_intro.dart';
import 'package:onset/widgets/launch/onset_mark.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/l10n.dart';

class _MockUserStore extends Mock implements UserStore {}

class _FakeAuthStore extends Mock implements AuthStore {
  _FakeAuthStore() {
    when(
      () => _user.details,
    ).thenReturn(const UserTwitch('1', 'viewer', 'Viewer', ''));
    when(() => _user.blockedUsers).thenReturn(ObservableList());
  }

  final _user = _MockUserStore();

  @override
  bool get isLoggedIn => false;

  @override
  UserStore get user => _user;
}

/// The language pill of the onboarding's Intro, and the onboarding in
/// French. In the real Inter font, so French running longer than English
/// shows (this file only: the font stays loaded for the whole file).
void main() {
  final english = L10n.english;
  final french = lookupAppLocalizations(fr);
  late SettingsStore settings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'ONSET',
      packageName: 'onset',
      version: '5.0.5',
      buildNumber: '68',
      buildSignature: '',
    );
    settings = SettingsStore.fromJson({});
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    List<Locale> device = const [Locale('en', 'US')],
    double textScale = 1,
  }) async {
    await tester.runAsync(loadInter);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.reset);
    tester.platformDispatcher
      ..localesTestValue = device
      ..textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: _FakeAuthStore()),
          Provider<SettingsStore>.value(value: settings),
        ],
        child: Observer(
          builder: (_) => MaterialApp(
            locale: settings.appLanguage.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            localeListResolutionCallback: (device, _) =>
                resolveAppLocale(AppLanguage.system, device ?? const []),
            navigatorObservers: [LaunchIntro.navigatorObserver],
            builder: (context, child) => LaunchIntro(child: child!),
            home: OnboardingFlow(
              loadLiveStreams: () async => const [],
              loginPanelBuilder: (_, _, _) => const SizedBox(),
              homeBuilder: (_) => const Scaffold(body: Text('home')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 18; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).hitTestable());
    await settle(tester);
  }

  /// What overlaps on the phone's Intro, in reading order: the tile, the
  /// description, the language pill, the version, then "Next". A part that
  /// scrolled out of its area is not drawn there, so only the visible part
  /// of each counts.
  List<String> introOverlaps(WidgetTester tester, AppLocalizations l) {
    final scroll = find.descendant(
      of: find.byType(OnboardingIntroPhone),
      matching: find.byType(Scrollable),
    );
    final area = scroll.evaluate().isEmpty
        ? Offset.zero & tester.view.physicalSize
        : tester.getRect(scroll);
    Rect shown(Finder finder) => tester.getRect(finder).intersect(area);
    final parts = [
      ('tile', tester.getRect(find.byType(OnsetMarkTile))),
      ('description', shown(find.text(l.onboardingIntroDescription))),
      ('pill', shown(find.byType(OnboardingLanguageChoice))),
      ('version', shown(find.text('v5.0.5 (68)'))),
      ('Next', tester.getRect(find.text(l.commonNext))),
    ];
    final problems = <String>[];
    for (var i = 1; i < parts.length; i++) {
      final (aboveName, above) = parts[i - 1];
      final (name, rect) = parts[i];
      if (rect.height <= 0 || above.height <= 0) continue;
      if (above.bottom > rect.top + 0.01) {
        problems.add(
          '$aboveName (to ${above.bottom}) over $name (${rect.top})',
        );
      }
    }
    // Nothing scrolled under "Next".
    final next = tester.getRect(find.text(l.commonNext));
    if (area.bottom > next.top + 0.01 && scroll.evaluate().isNotEmpty) {
      problems.add('the scrolling area runs under Next');
    }
    return problems;
  }

  OnboardingLanguageChoice pill(WidgetTester tester) =>
      tester.widget(find.byType(OnboardingLanguageChoice));

  group('preselection', () {
    testWidgets('an English device: English, and the Intro in English', (
      tester,
    ) async {
      await pump(tester);
      await settle(tester);
      expect(pill(tester).value, AppLanguage.en);
      expect(find.text(english.onboardingIntroDescription), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Français'), findsOneWidget);
    });

    testWidgets('a French device (fr-CA too): French, the Intro in French', (
      tester,
    ) async {
      await pump(tester, device: const [Locale('fr', 'CA')]);
      await settle(tester);
      expect(pill(tester).value, AppLanguage.fr);
      expect(find.text(french.onboardingIntroDescription), findsOneWidget);
      expect(find.text(french.commonNext), findsOneWidget);
      // The languages keep their own names.
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Français'), findsOneWidget);
    });

    testWidgets('a language not supported: English', (tester) async {
      await pump(tester, device: const [Locale('de', 'DE')]);
      await settle(tester);
      expect(pill(tester).value, AppLanguage.en);
    });

    testWidgets('a choice already made wins over the device', (tester) async {
      settings.appLanguage = AppLanguage.fr;
      await pump(tester);
      await settle(tester);
      expect(pill(tester).value, AppLanguage.fr);
      expect(find.text(french.onboardingIntroDescription), findsOneWidget);
    });
  });

  testWidgets('a tap on Français switches the onboarding at once, and back', (
    tester,
  ) async {
    await pump(tester);
    await settle(tester);
    await tapText(tester, 'Français');
    expect(settings.appLanguage, AppLanguage.fr);
    expect(settings.languagePromptVersion, kLanguagePromptVersion);
    expect(find.text(french.onboardingIntroDescription), findsOneWidget);
    expect(find.text(english.onboardingIntroDescription), findsNothing);
    expect(pill(tester).value, AppLanguage.fr);

    await tapText(tester, french.commonNext);
    expect(find.text(french.onboardingLoginTitle), findsOneWidget);
    expect(settings.appLanguage, AppLanguage.fr);

    // Back to the Intro, English again.
    await tester.tap(find.byTooltip(french.commonBack));
    await settle(tester);
    await tapText(tester, 'English');
    expect(settings.appLanguage, AppLanguage.en);
    expect(find.text(english.onboardingIntroDescription), findsOneWidget);
  });

  testWidgets('Next without a tap stores the language shown, explicitly', (
    tester,
  ) async {
    await pump(tester, device: const [Locale('fr', 'FR')]);
    await settle(tester);
    expect(settings.appLanguage, AppLanguage.system);
    expect(settings.languagePromptVersion, 0);
    await tapText(tester, french.commonNext);
    expect(settings.appLanguage, AppLanguage.fr);
    expect(settings.languagePromptVersion, kLanguagePromptVersion);
  });

  testWidgets('the pill: "Language · Langue", two exclusive buttons, the '
      'selected one said', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    await settle(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Language · Langue')),
      matchesSemantics(
        label: 'Language · Langue',
        children: [
          matchesSemantics(
            label: 'English',
            isButton: true,
            isSelected: true,
            hasSelectedState: true,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
          ),
          matchesSemantics(
            label: 'Français',
            isButton: true,
            hasSelectedState: true,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
          ),
        ],
      ),
    );
    // Each name is spoken in its own language.
    for (final (name, locale) in const [
      ('English', Locale('en')),
      ('Français', Locale('fr')),
    ]) {
      final label = tester
          .getSemantics(find.bySemanticsLabel(name))
          .attributedLabel;
      expect(
        label.attributes.whereType<LocaleStringAttribute>().map(
          (a) => a.locale,
        ),
        [locale],
        reason: name,
      );
    }
    semantics.dispose();
  });

  group('every step fits, in both languages', () {
    for (final (name, size) in const [
      ('a 390x844 phone', Size(390, 844)),
      ('a small phone', Size(360, 640)),
      ('a 320x568 phone', Size(320, 568)),
      ('a 360x560 phone', Size(360, 560)),
      ('a short window', Size(400, 480)),
      ('a landscape tablet', Size(1280, 854)),
      ('a portrait tablet', Size(854, 1280)),
    ]) {
      for (final (lang, l, device) in [
        ('English', english, const Locale('en', 'US')),
        ('French', french, const Locale('fr', 'FR')),
      ]) {
        for (final scale in const [1.0, 1.3, 2.0]) {
          testWidgets('$name, $lang, text ×$scale', (tester) async {
            await pump(tester, size: size, device: [device], textScale: scale);
            await settle(tester);
            expect(tester.takeException(), isNull);
            expect(find.text(l.onboardingIntroDescription), findsOneWidget);
            if (size.shortestSide < 600) {
              expect(introOverlaps(tester, l), isEmpty);
            }

            void noEnglish() {
              if (l == french) expect(englishLeaks(tester), isEmpty);
            }

            noEnglish();
            await tapText(tester, l.commonNext);
            expect(tester.takeException(), isNull);
            expect(find.text(l.onboardingLoginTitle), findsOneWidget);
            noEnglish();
            await tapText(tester, l.onboardingLoginSkip);
            expect(tester.takeException(), isNull);
            expect(find.text(l.onboardingSetupTitle), findsOneWidget);
            // The preview's stand-in line is never cut.
            final detail = tester.renderObject<RenderParagraph>(
              find.text(l.onboardingSetupPreviewDetail),
            );
            expect(detail.didExceedMaxLines, isFalse);
            noEnglish();
            await tapText(tester, l.commonNext);
            expect(tester.takeException(), isNull);
            expect(find.text(l.onboardingWelcomeTitle), findsOneWidget);
            expect(find.text(l.onboardingWelcomeGo), findsOneWidget);
            noEnglish();
          });
        }
      }
    }
  });

  testWidgets('the leak check sees English on a French screen', (tester) async {
    await pump(tester, device: const [Locale('fr', 'FR')]);
    await settle(tester);
    expect(englishLeaks(tester), isEmpty);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Text(english.onboardingLoginSkip),
            Text(english.homeOpenChannelFailed(login: 'jltomy')),
            Text(french.onboardingLoginSkip),
          ],
        ),
      ),
    );
    expect(englishLeaks(tester), [
      english.onboardingLoginSkip,
      english.homeOpenChannelFailed(login: 'jltomy'),
    ]);
  });
}
