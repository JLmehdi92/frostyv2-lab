import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/state_glyph.dart';
import 'package:onset/widgets/state_views.dart';

const _sizes = [Size(390, 844), Size(1280, 854), Size(854, 1280)];

Finder _glyph(StateGlyphKind kind) =>
    find.byWidgetPredicate((w) => w is StateGlyph && w.kind == kind);

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    ThemeMode theme = ThemeMode.dark,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      MaterialApp(
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: theme,
        home: Scaffold(body: child),
      ),
    );
  }

  test("the app's words for a connection problem", () {
    expect(isConnectionProblem('Unable to connect to Twitch'), isTrue);
    expect(
      isConnectionProblem('No internet connection. Please check your network.'),
      isTrue,
    );
    expect(isConnectionProblem('Unable to load videos'), isFalse);
  });

  test('dark digits on the lime accent, light ones on a dark accent', () {
    expect(onFillColor(OnsetTokens.accent), OnsetTokens.backgroundDark);
    expect(onFillColor(const Color(0xFF3A1A8A)), Colors.white);
  });

  testWidgets('offline: the network mark, the message, Try again', (
    tester,
  ) async {
    var retried = 0;
    await pump(
      tester,
      FeedStatusView.error(
        message: 'No internet connection. Please check your network.',
        onRetry: () => retried++,
      ),
    );
    expect(_glyph(StateGlyphKind.offline), findsOneWidget);
    expect(
      find.text('No internet connection. Please check your network.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });

  testWidgets('another failure: the alert mark', (tester) async {
    await pump(
      tester,
      FeedStatusView.error(message: "Couldn't load clips", onRetry: () {}),
    );
    expect(_glyph(StateGlyphKind.alert), findsOneWidget);
    expect(_glyph(StateGlyphKind.offline), findsNothing);
    expect(_glyph(StateGlyphKind.retry), findsOneWidget);
  });

  testWidgets('empty: the signal turned off, or a glyph with a detail', (
    tester,
  ) async {
    await pump(tester, const FeedStatusView.empty(message: 'No clips'));
    expect(find.byType(SignalOffMark), findsOneWidget);
    expect(find.text('Try again'), findsNothing);

    await pump(
      tester,
      const FeedStatusView.empty(
        message: 'Nothing',
        detail: 'Come back later.',
        glyph: StateGlyphKind.bell,
      ),
    );
    expect(find.byType(SignalOffMark), findsNothing);
    expect(_glyph(StateGlyphKind.bell), findsOneWidget);
    expect(find.text('Come back later.'), findsOneWidget);
  });

  testWidgets('logged out: why, and Connect with Twitch', (tester) async {
    var connected = 0;
    await pump(
      tester,
      FeedStatusView.signIn(
        message: 'Log in to get whispers.',
        onConnect: () => connected++,
      ),
    );
    expect(_glyph(StateGlyphKind.account), findsOneWidget);
    await tester.tap(find.text('Connect with Twitch'));
    expect(connected, 1);
  });

  testWidgets('inline: a failure retries, nothing found does not', (
    tester,
  ) async {
    var retried = 0;
    await pump(
      tester,
      Column(
        children: [
          InlineStatus.error(
            message: 'Unable to connect to Twitch',
            onRetry: () => retried++,
          ),
          const InlineStatus(message: 'No search results found', glyph: null),
        ],
      ),
    );
    expect(_glyph(StateGlyphKind.offline), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });

  for (final theme in [ThemeMode.dark, ThemeMode.light]) {
    for (final size in _sizes) {
      testWidgets('every state lays out at ${size.width}x${size.height} '
          '(${theme.name})', (tester) async {
        for (final state in [
          FeedStatusView.error(
            message: 'Unable to connect to Twitch',
            onRetry: () {},
          ),
          const FeedStatusView.empty(message: 'No followed streams'),
          const FeedStatusView.empty(
            message: "Hooray! You're up to date",
            detail:
                'Check back soon for alerts about you and the broadcasters '
                'you follow.',
            glyph: StateGlyphKind.bell,
          ),
          FeedStatusView.signIn(
            message: 'Log in to get whispers.',
            onConnect: () {},
          ),
          InlineStatus.error(message: 'Unable to load videos', onRetry: () {}),
        ]) {
          await pump(tester, state, size: size, theme: theme);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
