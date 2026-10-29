import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/onboarding/onboarding_flow.dart';
import 'package:frosty/screens/onboarding/onboarding_login.dart';
import 'package:frosty/screens/onboarding/onboarding_parts.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:frosty/widgets/launch/launch_intro.dart';
import 'package:frosty/widgets/launch/onset_mark.dart';
import 'package:mobx/mobx.dart' show Observable, ObservableList, runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockUserStore extends Mock implements UserStore {}

class MockTwitchApi extends Mock implements TwitchApi {}

class FakeAuthStore extends Mock implements AuthStore {
  FakeAuthStore({bool loggedIn = false}) : _loggedIn = Observable(loggedIn) {
    when(
      () => _user.details,
    ).thenReturn(const UserTwitch('1', 'viewer', 'Viewer', ''));
    when(() => _user.blockedUsers).thenReturn(ObservableList());
  }

  final Observable<bool> _loggedIn;
  final _user = MockUserStore();

  @override
  bool get isLoggedIn => _loggedIn.value;

  @override
  UserStore get user => _user;

  void setLoggedIn(bool value) => runInAction(() => _loggedIn.value = value);
}

const _phone = Size(390, 844);
const _tablet = Size(1280, 854);
const _tabletPortrait = Size(854, 1280);

void main() {
  late SettingsStore settings;
  late FakeAuthStore auth;
  late List<bool> crashChoices;
  late List<List<String>> orientations;
  VoidCallback? signIn;
  ValueChanged<Future<void>>? tokenBack;

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
    auth = FakeAuthStore();
    crashChoices = [];
    orientations = [];
    signIn = null;
    tokenBack = null;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  OnboardingFlow flow({
    List<StreamTwitch> streams = const [],
    WidgetBuilder? home,
  }) => OnboardingFlow(
    loadLiveStreams: () async => streams,
    loginPanelBuilder: (context, onSignedIn, onTokenCaptured) {
      signIn = onSignedIn;
      tokenBack = onTokenCaptured;
      return const ColoredBox(
        key: Key('twitch-page'),
        color: Color(0xFF111111),
      );
    },
    onShareCrashLogsChanged: crashChoices.add,
    homeBuilder: home ?? (_) => const Scaffold(body: Text('home')),
  );

  Future<void> pump(
    WidgetTester tester, {
    Size size = _phone,
    Widget? child,
    bool intro = false,
    bool holdOnName = false,
    bool reduceMotion = false,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.reset);
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
    }
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientations.add(List<String>.from(call.arguments as List));
        }
        return null;
      },
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
          Provider<AuthStore>.value(value: auth),
          Provider<SettingsStore>.value(value: settings),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [LaunchIntro.navigatorObserver],
          builder: (context, child) =>
              LaunchIntro(play: intro, holdOnName: holdOnName, child: child!),
          home: child ?? flow(),
        ),
      ),
    );
    await tester.pump();
  }

  /// Lets every step, sheet and dialog animation end (the mosaic drifts
  /// for ever, so nothing ever "settles").
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 18; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).hitTestable());
    await settle(tester);
  }

  Future<void> toSetup(WidgetTester tester) async {
    await settle(tester);
    await tapText(tester, 'Next');
    await tapText(tester, 'Skip');
  }

  group('every step, phone and tablet', () {
    for (final (name, size) in const [
      ('a 390x844 phone', _phone),
      ('a small phone', Size(360, 640)),
      ('a short window', Size(400, 480)),
      ('a landscape tablet', _tablet),
      ('a portrait tablet', _tabletPortrait),
    ]) {
      testWidgets('$name: Intro, Log in, Setup, Welcome fit', (tester) async {
        await pump(tester, size: size);
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            'A mobile Twitch client with 7TV, BetterTTV (BTTV), and '
            'FrankerFaceZ (FFZ) support.',
          ),
          findsOneWidget,
        );
        expect(find.text('v5.0.5 (68)'), findsOneWidget);

        await tapText(tester, 'Next');
        expect(tester.takeException(), isNull);
        expect(find.text('Log in'), findsOneWidget);
        expect(find.text('What you will authorize'.toUpperCase()), findsOne);
        expect(find.text('Connect with Twitch'), findsOneWidget);

        await tapText(tester, 'Skip');
        expect(tester.takeException(), isNull);
        expect(find.text('Setup'), findsOneWidget);
        expect(find.text('Show historical recent messages'), findsOneWidget);
        expect(find.text('Share crash logs and analytics'), findsOneWidget);

        await tapText(tester, 'Next');
        expect(tester.takeException(), isNull);
        expect(find.text('Welcome!'), findsOneWidget);
        expect(find.text('Let’s go!'), findsOneWidget);
      });
    }
  });

  group('the steps', () {
    testWidgets('a 4-segment progress tells the step', (tester) async {
      await pump(tester);
      await settle(tester);
      expect(find.bySemanticsLabel('Onboarding progress'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Onboarding progress')).value,
        'Step 1 of 4',
      );
      await tapText(tester, 'Next');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Onboarding progress')).value,
        'Step 2 of 4',
      );
    });

    testWidgets('back goes one step back; none on the intro', (tester) async {
      await pump(tester);
      await settle(tester);
      expect(find.byTooltip('Back').hitTestable(), findsNothing);

      await tapText(tester, 'Next');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Next');
      expect(find.text('Welcome!'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.text('Setup'), findsOneWidget);
      // Setup goes back to Log in (the Twitch page is not a step of its own).
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.text('Log in'), findsOneWidget);
      // Android's back too.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(
        find.text(
          'A mobile Twitch client with 7TV, BetterTTV (BTTV), and '
          'FrankerFaceZ (FFZ) support.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the permissions listed are the ones the login asks for', (
      tester,
    ) async {
      final asked = AuthBase.loginScopes.split(' ').toSet();
      final listed = {
        for (final permission in onboardingPermissions) ...permission.scopes,
      };
      expect(listed, asked);
      await pump(tester);
      await settle(tester);
      await tapText(tester, 'Next');
      for (final permission in onboardingPermissions) {
        expect(find.text(permission.title), findsOneWidget);
        expect(find.text(permission.detail), findsOneWidget);
      }
    });
  });

  group('connecting with Twitch', () {
    testWidgets('opens the Twitch page with its bar and the cookie help', (
      tester,
    ) async {
      await pump(tester);
      await settle(tester);
      await tapText(tester, 'Next');
      await tapText(tester, 'Connect with Twitch');
      expect(find.byKey(const Key('twitch-page')), findsOneWidget);
      // The bar names the page instead of the progress.
      expect(find.text('Connect with Twitch'), findsOneWidget);
      expect(find.bySemanticsLabel('Onboarding progress'), findsNothing);

      await tester.tap(find.byTooltip('Login help'));
      await settle(tester);
      expect(
        find.text('Workaround for the Twitch cookie banner'),
        findsOneWidget,
      );
      await tapText(tester, 'Close');
      expect(
        find.text('Workaround for the Twitch cookie banner'),
        findsNothing,
      );

      // Back leaves the page for the Log in step.
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.byKey(const Key('twitch-page')), findsNothing);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('signed in: on to Setup, which says who is logged in', (
      tester,
    ) async {
      await pump(tester);
      await settle(tester);
      await tapText(tester, 'Next');
      await tapText(tester, 'Connect with Twitch');
      final login = Completer<void>();
      tokenBack!(login.future);
      await tester.pump();
      signIn!();
      await settle(tester);
      expect(find.text('Setup'), findsOneWidget);
      expect(find.text('Signing you in…'), findsOneWidget);

      auth.setLoggedIn(true);
      login.complete();
      await tester.pump();
      expect(find.text('Signing you in…'), findsNothing);
      expect(find.textContaining('Logged in as'), findsOneWidget);
      expect(find.textContaining('Viewer'), findsOneWidget);
    });

    testWidgets('a login that fails says so on Setup', (tester) async {
      await pump(tester);
      await settle(tester);
      await tapText(tester, 'Next');
      await tapText(tester, 'Connect with Twitch');
      final login = Completer<void>();
      tokenBack!(login.future);
      signIn!();
      await settle(tester);
      login.complete();
      await tester.pump();
      expect(
        find.text(
          'Login failed · go back to try again, or log in later from Profile',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the Twitch page shrinks above the keyboard', (tester) async {
      await pump(tester);
      await settle(tester);
      await tapText(tester, 'Next');
      await tapText(tester, 'Connect with Twitch');
      expect(
        tester.getRect(find.byKey(const Key('twitch-page'))).bottom,
        844 - 16,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const Key('twitch-page'))).bottom,
        844 - 300,
      );
    });

    testWidgets('Twitch done without a token (the user said no): on to '
        'Setup, not logged in', (tester) async {
      await pump(tester);
      await settle(tester);
      await tapText(tester, 'Next');
      await tapText(tester, 'Connect with Twitch');
      signIn!();
      await settle(tester);
      expect(find.text('Setup'), findsOneWidget);
      expect(
        find.text('Not logged in · you can log in later from Profile'),
        findsOneWidget,
      );
    });

    testWidgets('skipped: Setup says how to log in later', (tester) async {
      await pump(tester);
      await toSetup(tester);
      expect(
        find.text('Not logged in · you can log in later from Profile'),
        findsOneWidget,
      );
    });
  });

  group('setup', () {
    testWidgets('keeps every default', (tester) async {
      await pump(tester);
      await toSetup(tester);
      expect(settings.themeType, ThemeType.system);
      expect(settings.accentColor, 0xffc8ff3d);
      expect(settings.showRecentMessages, isFalse);
      expect(settings.shareCrashLogsAndAnalytics, isTrue);
      expect(find.text('Follows your device'), findsOneWidget);
      expect(find.text('#C8FF3D'), findsOneWidget);
    });

    testWidgets('the theme, and the preview follows it', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pump(tester);
      await toSetup(tester);
      Color preview() => tester
          .widget<AnimatedContainer>(find.byKey(const Key('setup-preview')))
          .decoration!
          .let((d) => (d as BoxDecoration).color!);
      expect(preview(), const Color(0xFF0A0A0A));

      await tapText(tester, 'Light');
      expect(settings.themeType, ThemeType.light);
      expect(find.text('Light surfaces everywhere'), findsOneWidget);
      expect(preview(), const Color(0xFFFFFFFF));

      await tapText(tester, 'Dark');
      expect(settings.themeType, ThemeType.dark);
      expect(find.text('Noir, the ONSET default'), findsOneWidget);
      expect(preview(), const Color(0xFF0A0A0A));
    });

    for (final (name, size) in const [('phone', _phone), ('tablet', _tablet)]) {
      testWidgets('$name: the accent picker, Random, Cancel and Done', (
        tester,
      ) async {
        await pump(tester, size: size);
        await toSetup(tester);
        await tester.tap(find.bySemanticsLabel(RegExp('^Accent color')));
        await settle(tester);
        expect(find.text('Random'), findsOneWidget);
        // Phone: a sheet; tablet: a dialog.
        expect(
          find.byType(Dialog),
          size == _tablet ? findsOneWidget : findsNothing,
        );

        await tapText(tester, 'Random');
        expect(settings.accentColor, isNot(0xffc8ff3d));
        await tapText(tester, 'Cancel');
        expect(settings.accentColor, 0xffc8ff3d);

        await tester.tap(find.bySemanticsLabel(RegExp('^Accent color')));
        await settle(tester);
        await tester.tap(find.bySemanticsLabel('Hue 202 degrees'));
        await tester.pump();
        final picked = settings.accentColor;
        expect(picked, isNot(0xffc8ff3d));
        await tapText(tester, 'Done');
        expect(settings.accentColor, picked);
        expect(find.text('Random'), findsNothing);
      });
    }

    test('a debug build never collects, whatever the switch says', () {
      // Tests run in debug mode.
      expect(firebaseCollectionFor(true), isFalse);
      expect(firebaseCollectionFor(false), isFalse);
    });

    testWidgets('the live pictures are asked quietly (no "Session expired" '
        'over the onboarding)', (tester) async {
      final api = MockTwitchApi();
      when(
        () => api.getTopStreams(quiet: any(named: 'quiet')),
      ).thenAnswer((_) async => const StreamsTwitch([], {}));
      tester.view
        ..physicalSize = _phone
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStore>.value(value: auth),
            Provider<SettingsStore>.value(value: settings),
            Provider<TwitchApi>.value(value: api),
          ],
          child: MaterialApp(
            home: OnboardingFlow(
              loginPanelBuilder: (_, _, _) => const SizedBox(),
              onShareCrashLogsChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      verify(() => api.getTopStreams(quiet: true)).called(1);
    });

    testWidgets('history and crash reports switch', (tester) async {
      await pump(tester);
      await toSetup(tester);
      await tester.tap(find.byType(OnboardingSwitch).at(0));
      await tester.pump();
      expect(settings.showRecentMessages, isTrue);

      // Below the fold on a phone with its system bars: it scrolls.
      await tester.ensureVisible(find.byType(OnboardingSwitch).at(1));
      await tester.pump();
      await tester.tap(find.byType(OnboardingSwitch).at(1));
      await tester.pump();
      expect(settings.shareCrashLogsAndAnalytics, isFalse);
      expect(crashChoices, [false]);
    });
  });

  group('the end', () {
    testWidgets('Welcome marks the first run done; Let’s go! opens the app', (
      tester,
    ) async {
      await pump(tester);
      await toSetup(tester);
      await tapText(tester, 'Next');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('first_run'), isFalse);
      for (final tip in [
        'Check out the GitHub repo at the top-right of the settings page to '
            'explore ONSET’s source code, report bugs, make feature requests, '
            'and more.',
        'Links to the full changelog and FAQ are in the settings page under '
            '“Other”.',
        'Don’t forget to leave a rating and/or review on the app store!',
      ]) {
        expect(find.text(tip), findsOneWidget);
      }

      await tester.tap(find.text('Let’s go!'));
      await tester.pump();
      // The tile lands: the screen goes black, the app comes in under it.
      expect(find.byKey(LaunchIntro.overlayKey), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('home'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(LaunchIntro.overlayKey), findsNothing);
      expect(find.text('Welcome!'), findsNothing);
      expect(find.byType(OnboardingFlow), findsNothing);
    });

    testWidgets('a link opening during the landing stays on top of the app', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      await pump(tester, navigatorKey: navigator);
      await toSetup(tester);
      await tapText(tester, 'Next');
      await tester.tap(find.text('Let’s go!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('link')),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('link'), findsOneWidget);
      expect(find.byType(OnboardingFlow), findsNothing);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('reduce motion: no flight, a short fade to the app', (
      tester,
    ) async {
      await pump(tester, reduceMotion: true);
      await toSetup(tester);
      await tapText(tester, 'Next');
      await tester.tap(find.text('Let’s go!'));
      await tester.pump();
      expect(find.byKey(LaunchIntro.overlayKey), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(OnboardingFlow), findsNothing);
    });

    testWidgets('a phone is held in portrait, a tablet is not', (tester) async {
      await pump(tester);
      expect(orientations.last, [
        'DeviceOrientation.portraitUp',
        'DeviceOrientation.portraitDown',
      ]);
      await tester.pumpWidget(const SizedBox());
      expect(orientations.last, isEmpty);

      orientations.clear();
      await pump(tester, size: _tablet);
      expect(orientations.isEmpty || orientations.last.isEmpty, isTrue);
    });
  });

  testWidgets('a deep-linked page that frees the orientation as it closes: '
      'back on the onboarding, a phone is held in portrait again', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await pump(tester, navigatorKey: navigator);
    await settle(tester);
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const _FreesOrientation()),
    );
    await settle(tester);
    navigator.currentState!.pop();
    await settle(tester);
    expect(orientations.last, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.portraitDown',
    ]);
    // It was freed on the way (the page's own reset), then held again.
    expect(orientations.where((o) => o.isEmpty), isNotEmpty);
  });

  group('after the launch intro', () {
    testWidgets('the first frame is the intro\'s last: same tile, same name', (
      tester,
    ) async {
      await pump(tester, intro: true, holdOnName: true);
      await tester.pump(LaunchIntro.duration * 0.52);
      expect(find.byKey(LaunchIntro.overlayKey), findsOneWidget);
      final introTile = tester.getRect(find.byKey(LaunchIntro.tileKey));
      final introLetters = [
        for (final letter in 'ONSET'.split(''))
          tester.getRect(
            find.descendant(
              of: find.byKey(LaunchIntro.overlayKey),
              matching: find.text(letter),
            ),
          ),
      ];
      await tester.pump(LaunchIntro.duration * 0.1);
      await tester.pump();
      expect(find.byKey(LaunchIntro.overlayKey), findsNothing);

      final tile = tester.getRect(find.byType(OnsetMarkTile));
      expect(tile.center.dx, closeTo(introTile.center.dx, 0.01));
      expect(tile.center.dy, closeTo(introTile.center.dy, 0.01));
      expect(tile.width, closeTo(introTile.width, 0.01));
      for (final (i, letter) in 'ONSET'.split('').indexed) {
        final rect = tester.getRect(find.text(letter));
        expect(rect.topLeft.dx, closeTo(introLetters[i].topLeft.dx, 0.01));
        expect(rect.topLeft.dy, closeTo(introLetters[i].topLeft.dy, 0.01));
      }
      // Then the live mosaic and the text come in around it.
      await settle(tester);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('tablet: the tile slides from the launch spot to its pane', (
      tester,
    ) async {
      await pump(tester, size: _tablet, intro: true, holdOnName: true);
      await tester.pump(LaunchIntro.duration * 0.7);
      await tester.pump();
      expect(find.byKey(LaunchIntro.overlayKey), findsNothing);
      expect(
        tester.getCenter(find.byType(OnsetMarkTile)),
        const Offset(640, 427),
      );
      await settle(tester);
      expect(
        tester.getCenter(find.byType(OnsetMarkTile)),
        const Offset(280, 427),
      );
    });
  });

  testWidgets('never blurs', (tester) async {
    await pump(tester);
    await settle(tester);
    expect(find.byType(BackdropFilter), findsNothing);
    await tapText(tester, 'Next');
    expect(find.byType(BackdropFilter), findsNothing);
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

/// Lets the orientation go when it is disposed, as the channel screen does.
class _FreesOrientation extends StatefulWidget {
  const _FreesOrientation();

  @override
  State<_FreesOrientation> createState() => _FreesOrientationState();
}

class _FreesOrientationState extends State<_FreesOrientation> {
  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('player'));
}
