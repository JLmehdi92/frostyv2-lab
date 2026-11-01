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
import 'package:onset/screens/onboarding/onboarding_language_choice.dart';
import 'package:onset/screens/onboarding/onboarding_parts.dart';
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

  /// The rectangle [element] draws in, in the window's coordinates.
  Rect drawnRect(Element element) {
    final box = element.renderObject! as RenderBox;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  /// What [finder] shows of itself: its rectangle inside the window and
  /// inside every scrolling area it sits in.
  Rect visibleRect(WidgetTester tester, Finder finder) {
    final window = Offset.zero & tester.view.physicalSize;
    var rect = tester.getRect(finder).intersect(window);
    for (final scrollable
        in find
            .ancestor(of: finder, matching: find.byType(Scrollable))
            .evaluate()) {
      rect = rect.intersect(drawnRect(scrollable));
    }
    return rect;
  }

  /// What is wrong on the phone's Intro:
  /// - any two parts overlapping: the tile, the name, the description, the
  ///   language pill, the version (when shown), "Next" (one column in
  ///   portrait, two side by side on a landscape window); only the visible
  ///   part of each counts (a part scrolled out of its area is not drawn
  ///   there);
  /// - the language pill not wholly in view: cut by the window or by a
  ///   scrolling edge, under "Next", or its labels cut short.
  List<String> introProblems(WidgetTester tester, AppLocalizations l) {
    final version = find.text('v5.0.5 (68)');
    final languagePill = find.byType(OnboardingLanguageChoice);
    final parts = [
      ('tile', tester.getRect(find.byType(OnsetMarkTile))),
      ('name', tester.getRect(find.byType(OnsetWordmark))),
      (
        'description',
        visibleRect(tester, find.text(l.onboardingIntroDescription)),
      ),
      ('pill', visibleRect(tester, languagePill)),
      if (version.evaluate().isNotEmpty)
        ('version', visibleRect(tester, version)),
      ('Next', tester.getRect(find.text(l.commonNext))),
    ];
    final problems = <String>[];
    for (var i = 0; i < parts.length; i++) {
      for (var j = i + 1; j < parts.length; j++) {
        final (aName, a) = parts[i];
        final (bName, b) = parts[j];
        if (a.height <= 0 || b.height <= 0) continue;
        final common = a.intersect(b);
        if (common.width > 0.01 && common.height > 0.01) {
          problems.add('$aName ($a) overlaps $bName ($b)');
        }
      }
    }
    final whole = tester.getRect(languagePill);
    final seen = visibleRect(tester, languagePill);
    if ((whole.height - seen.height).abs() > 0.01 ||
        (whole.width - seen.width).abs() > 0.01) {
      problems.add('the pill is cut: $whole shows only $seen');
    }
    final next = tester.getRect(
      find.ancestor(
        of: find.text(l.commonNext),
        matching: find.byType(OnboardingButton),
      ),
    );
    if (whole.bottom > next.top + 0.01) {
      problems.add('the pill (to ${whole.bottom}) runs under Next');
    }
    for (final label in [
      english.languageNameEnglish,
      english.languageNameFrench,
    ]) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: languagePill, matching: find.text(label)),
      );
      if (paragraph.didExceedMaxLines) problems.add('"$label" is cut short');
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

  group('a tap on the pill never moves the tile or the name', () {
    for (final (size, scale) in const [
      (Size(360, 560), 1.3),
      (Size(360, 640), 1.3),
      (Size(360, 640), 1.6),
      (Size(412, 915), 1.6),
      (Size(320, 568), 2.0),
      (Size(844, 390), 1.3),
    ]) {
      testWidgets('${size.width.round()}x${size.height.round()}, text '
          '×$scale', (tester) async {
        await pump(tester, size: size, textScale: scale);
        await settle(tester);
        Rect tile() => tester.getRect(find.byType(OnsetMarkTile));
        Rect name() => tester.getRect(find.byType(OnsetWordmark));
        final (tileBefore, nameBefore) = (tile(), name());

        await tapText(tester, 'Français');
        expect(find.text(french.onboardingIntroDescription), findsOneWidget);
        expect(tile(), tileBefore);
        expect(name(), nameBefore);

        await tapText(tester, 'English');
        expect(find.text(english.onboardingIntroDescription), findsOneWidget);
        expect(tile(), tileBefore);
        expect(name(), nameBefore);
      });
    }
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
      // A phone's window held sideways: split screen, freeform or desktop
      // mode (the flow asks a phone for portrait, but these still occur).
      ('a 844x390 landscape phone window', Size(844, 390)),
      ('a 740x360 landscape phone window', Size(740, 360)),
      ('a 568x320 landscape phone window', Size(568, 320)),
      ('a landscape tablet', Size(1280, 854)),
      ('a portrait tablet', Size(854, 1280)),
    ]) {
      for (final (lang, l, device) in [
        ('English', english, const Locale('en', 'US')),
        ('French', french, const Locale('fr', 'FR')),
      ]) {
        for (final scale in const [1.0, 1.3, 1.6, 2.0]) {
          testWidgets('$name, $lang, text ×$scale', (tester) async {
            await pump(tester, size: size, device: [device], textScale: scale);
            await settle(tester);
            expect(tester.takeException(), isNull);
            expect(find.text(l.onboardingIntroDescription), findsOneWidget);
            if (size.shortestSide < 600) {
              expect(introProblems(tester, l), isEmpty);
            } else {
              // A tablet's pill, under the description, is wholly in view.
              final languagePill = find.byType(OnboardingLanguageChoice);
              expect(
                visibleRect(tester, languagePill),
                tester.getRect(languagePill),
              );
            }

            void noEnglish() {
              if (l != french) return;
              expect(englishLeaks(tester), isEmpty);
              // Nothing cut and no label shortened in the windows and text
              // sizes every French screen is checked at (360 dp and up,
              // text up to ×1.3); smaller windows and larger text only
              // have to fit.
              if (scale <= 1.3 && size.shortestSide >= 360) {
                expect(clippedTexts(tester), isEmpty);
                expect(ellipsizedAppTexts(tester), isEmpty);
              }
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
