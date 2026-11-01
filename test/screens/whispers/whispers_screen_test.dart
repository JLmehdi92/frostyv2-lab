import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show Observable, runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/whispers/whisper_conversation.dart';
import 'package:onset/screens/whispers/whisper_kit.dart';
import 'package:onset/screens/whispers/whispers_screen.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';
import 'package:onset/stores/whisper_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/state_glyph.dart';

import '../../helpers/l10n.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

const _phone = Size(390, 844);
const _tablet = Size(1280, 854);
const _tabletPortrait = Size(854, 1280);

void main() {
  late MockTwitchApi api;
  late StreamController<EventSubTopicEvent> events;
  late Observable<String?> me;
  late WhisperStore store;

  setUp(() => api = MockTwitchApi());

  /// Made in the test's zone, so events arrive on pump.
  void init() {
    events = StreamController<EventSubTopicEvent>.broadcast();
    me = Observable<String?>('7');
    store = WhisperStore(
      twitchApi: api,
      currentUserId: () => me.value,
      listen: (topic) => EventSubHandle.forTesting(topic, events.stream, () {}),
    );
  }

  tearDown(() => store.dispose());

  void receive(
    String text, {
    String id = 'w1',
    String from = '8',
    String login = 'friend',
    String name = 'Friend',
  }) => events.add(
    EventSubData({
      'from_user_id': from,
      'from_user_login': login,
      'from_user_name': name,
      'to_user_id': '7',
      'whisper_id': id,
      'whisper': {'text': text},
    }),
  );

  /// An event is handled in a microtask; the screen redraws a frame later,
  /// and what changes size (the status card, a new bubble) opens in 300 ms.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Profile pictures need the network: tests look at the text only.
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = _phone,
    ThemeMode theme = ThemeMode.dark,
    bool reduceMotion = false,
    Locale? locale,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await localizedApp(
      tester,
      locale: locale,
      textScale: textScale,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
    );
    final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      MaterialApp(
        locale: app.locale,
        supportedLocales: app.supportedLocales,
        localizationsDelegates: app.delegates,
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: theme,
        builder: app.builder,
        home: screen,
      ),
    );
    await tester.pump();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    // The send button lights up with the text.
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await settle(tester);
  }

  testWidgets('no whispers yet, and why some may not arrive', (tester) async {
    init();
    await pumpScreen(tester, WhispersScreen(store: store));
    expect(find.textContaining('No whispers yet'), findsOneWidget);
    expect(find.text('Whispers'), findsOneWidget);

    events.add(
      const EventSubUnavailable(
        'Forbidden',
        permanent: true,
        unauthorized: true,
      ),
    );
    await settle(tester);
    expect(find.textContaining('Log out and log in again'), findsOneWidget);

    // Reconnecting: the turning ring, then the card folds away.
    events.add(const EventSubUnavailable('Lost'));
    await settle(tester);
    expect(find.textContaining('Reconnecting'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    events.add(const EventSubListening(afterGap: true));
    await settle(tester);
    expect(find.textContaining('Reconnecting'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a conversation shows its last whisper and unread count', (
    tester,
  ) async {
    init();
    await pumpScreen(tester, WhispersScreen(store: store));
    receive('first');
    receive('second', id: 'w2');
    await settle(tester);

    expect(find.text('Friend'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(WhisperCountPill), findsOneWidget);
  });

  testWidgets('a whisper of the viewer is marked "You" in the list', (
    tester,
  ) async {
    init();
    when(
      () => api.sendWhisper(fromUserId: '7', toUserId: '8', message: 'yo'),
    ).thenAnswer((_) async {});
    receive('hey');
    await tester.pump();
    await store.sendTo(
      userId: '8',
      login: 'friend',
      displayName: 'Friend',
      text: 'yo',
    );
    await pumpScreen(tester, WhispersScreen(store: store));
    expect(find.text('yo'), findsOneWidget);
    // An arrow, not a "You:" a whisper could fake.
    expect(
      find.byWidgetPredicate(
        (w) => w is StateGlyph && w.kind == StateGlyphKind.reply,
      ),
      findsOneWidget,
    );
  });

  testWidgets('a name cannot turn text around or fake a line', (tester) async {
    init();
    receive('hey', name: 'Fr\u202Eiend\nStaff');
    await tester.pump();
    await pumpScreen(tester, WhispersScreen(store: store));
    expect(find.text('Fr iend Staff'), findsOneWidget);
    await tester.tap(find.text('Fr iend Staff'));
    await tester.pumpAndSettle();
    expect(find.text('Fr iend Staff'), findsOneWidget);
    expect(find.text('Whisper Fr iend Staff'), findsOneWidget);
  });

  testWidgets('phone: a conversation slides over the list, back returns', (
    tester,
  ) async {
    init();
    receive('hey');
    await tester.pump();
    await pumpScreen(tester, WhispersScreen(store: store));
    expect(store.unreadCount, 1);

    await tester.tap(find.text('Friend'));
    await tester.pumpAndSettle();
    expect(find.byType(WhisperConversation), findsOneWidget);
    expect(store.openUserId, '8');
    expect(store.unreadCount, 0);
    expect(find.text('Whisper Friend'), findsOneWidget);

    // Android's back closes the conversation, not the page.
    final popped = await tester.binding.handlePopRoute();
    expect(popped, isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(WhisperConversation), findsNothing);
    expect(store.openUserId, isNull);
    expect(find.byType(WhispersScreen), findsOneWidget);

    // Then the header's back button opens it again and closes it.
    await tester.tap(find.text('Friend'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(WhisperConversation), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a swipe from the left edge closes the conversation',
    (tester) async {
      init();
      receive('hey');
      await tester.pump();
      await pumpScreen(tester, WhispersScreen(store: store));
      await tester.tap(find.text('Friend'));
      await tester.pumpAndSettle();
      expect(store.openUserId, '8');

      // A short, slow drag follows the finger, then springs back.
      final gesture = await tester.startGesture(const Offset(4, 420));
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      final layer = find.ancestor(
        of: find.byType(WhisperConversation),
        matching: find.byType(FractionalTranslation),
      );
      final dragged = tester
          .widget<FractionalTranslation>(layer.first)
          .translation
          .dx;
      expect(dragged, closeTo(80 / 390, 0.02));
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(WhisperConversation), findsOneWidget);
      expect(
        tester.widget<FractionalTranslation>(layer.first).translation.dx,
        0,
      );
      expect(store.openUserId, '8');

      // Past the middle: it closes.
      await tester.timedDragFrom(
        const Offset(4, 420),
        const Offset(260, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WhisperConversation), findsNothing);
      expect(store.openUserId, isNull);

      // A quick flick closes it too.
      await tester.tap(find.text('Friend'));
      await tester.pumpAndSettle();
      await tester.flingFrom(const Offset(4, 420), const Offset(90, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.byType(WhisperConversation), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets('closed on a phone, not reopened when the window becomes a '
      'tablet', (tester) async {
    init();
    receive('hey');
    await tester.pump();
    await pumpScreen(tester, WhispersScreen(store: store));
    await tester.tap(find.text('Friend'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    receive('later', id: 'w2');
    await settle(tester);
    expect(store.unreadCount, 1);

    tester.view.physicalSize = _tablet;
    await tester.pumpAndSettle();
    expect(find.byType(WhisperConversation), findsNothing);
    expect(store.openUserId, isNull);
    expect(store.unreadCount, 1);
    expect(find.text('Choose a conversation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unread count grows with the text size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Center(child: WhisperCountPill(count: 12)),
        ),
      ),
    );
    final pill = tester.getSize(find.byType(WhisperCountPill));
    final digits = tester.getSize(find.text('12'));
    expect(pill.height, greaterThanOrEqualTo(digits.height));
    expect(pill.width, greaterThanOrEqualTo(digits.width));
    expect(pill.height, 40);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a conversation reads it; sending adds a bubble', (
    tester,
  ) async {
    init();
    when(
      () => api.sendWhisper(fromUserId: '7', toUserId: '8', message: 'hello'),
    ).thenAnswer((_) async {});
    receive('hey');
    await tester.pump();
    expect(store.unreadCount, 1);

    await pumpScreen(
      tester,
      WhisperConversation(
        store: store,
        userId: '8',
        login: 'friend',
        displayName: 'Friend',
      ),
    );
    expect(store.unreadCount, 0);
    expect(find.text('hey'), findsOneWidget);
    expect(find.textContaining('only this session'), findsOneWidget);

    // Nothing to send: the button is off.
    expect(
      tester.widget<IconButton>(find.byType(IconButton).last).onPressed,
      isNull,
    );
    await send(tester, 'hello');
    expect(find.text('hello'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('a refused whisper says why and keeps the text', (tester) async {
    init();
    when(
      () => api.sendWhisper(fromUserId: '7', toUserId: '8', message: 'hello'),
    ).thenThrow(const ApiException('Verify your phone number first.', 403));

    await pumpScreen(
      tester,
      WhisperConversation(
        store: store,
        userId: '8',
        login: 'friend',
        displayName: 'Friend',
      ),
    );
    await send(tester, 'hello');

    expect(
      find.text("Couldn't whisper: Verify your phone number first."),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'hello',
    );
  });

  testWidgets('while a whisper goes: the ring, and no second send', (
    tester,
  ) async {
    init();
    final sent = Completer<void>();
    var calls = 0;
    when(
      () => api.sendWhisper(fromUserId: '7', toUserId: '8', message: 'hello'),
    ).thenAnswer((_) {
      calls++;
      return sent.future;
    });
    await pumpScreen(
      tester,
      WhisperConversation(
        store: store,
        userId: '8',
        login: 'friend',
        displayName: 'Friend',
      ),
    );
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byTooltip('Send'), warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);
    sent.complete();
    await settle(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('leaving a conversation counts new whispers as unread', (
    tester,
  ) async {
    init();
    await pumpScreen(
      tester,
      WhisperConversation(
        store: store,
        userId: '8',
        login: 'friend',
        displayName: 'Friend',
      ),
    );
    await tester.pumpWidget(const SizedBox());
    receive('later');
    await tester.pump();
    expect(store.unreadCount, 1);
  });

  testWidgets('a whisper arriving in the open conversation is read', (
    tester,
  ) async {
    init();
    await pumpScreen(
      tester,
      WhisperConversation(
        store: store,
        userId: '8',
        login: 'friend',
        displayName: 'Friend',
      ),
    );
    receive('now');
    await settle(tester);
    expect(find.text('now'), findsOneWidget);
    expect(store.unreadCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final size in [_phone, _tablet]) {
    testWidgets('a bubble keeps its state when whispers arrive below it '
        '(${size.width}x${size.height})', (tester) async {
      init();
      receive('hey');
      await tester.pump();
      await pumpScreen(
        tester,
        WhisperConversation(
          store: store,
          userId: '8',
          login: 'friend',
          displayName: 'Friend',
          pane: size == _tablet,
        ),
        size: size,
      );
      final hey = find.byWidgetPredicate(
        (w) => w is EditableText && w.controller.text == 'hey',
      );
      final before = tester.state(hey);
      receive('again', id: 'w2');
      await settle(tester);
      expect(find.text('again'), findsOneWidget);
      expect(identical(tester.state(hey), before), isTrue);
    });
  }

  testWidgets('one conversation alone (from a chat): back leaves the page', (
    tester,
  ) async {
    init();
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => WhisperConversation.open(
              context,
              store: store,
              userId: '8',
              login: 'friend',
              displayName: 'Friend',
            ),
            child: const Text('chat'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('chat'));
    await tester.pumpAndSettle();
    expect(find.byType(WhisperConversation), findsOneWidget);
    // No list under it on a phone.
    expect(find.byType(WhispersList), findsNothing);
    expect(store.openUserId, '8');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('chat'), findsOneWidget);
    expect(store.openUserId, isNull);
  });

  testWidgets('logged out: why, and Connect with Twitch', (tester) async {
    init();
    runInAction(() => me.value = null);
    await pumpScreen(tester, WhispersScreen(store: store));
    expect(find.text('Log in to get whispers.'), findsOneWidget);
    expect(find.text('Connect with Twitch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('another account: the conversation on screen closes', (
    tester,
  ) async {
    init();
    receive('secret');
    await tester.pump();
    await pumpScreen(tester, WhispersScreen(store: store));
    await tester.tap(find.text('Friend'));
    await tester.pumpAndSettle();
    expect(find.text('secret'), findsOneWidget);

    runInAction(() => me.value = '9');
    await tester.pumpAndSettle();
    expect(find.text('secret'), findsNothing);
    expect(find.byType(WhisperConversation), findsNothing);
    expect(find.textContaining('No whispers yet'), findsOneWidget);
  });

  group('tablet', () {
    testWidgets('the conversations beside the first one, opened', (
      tester,
    ) async {
      init();
      receive('older', from: '9', login: 'other', name: 'Other');
      await tester.pump(const Duration(seconds: 1));
      receive('newest');
      await tester.pump();
      await pumpScreen(tester, WhispersScreen(store: store), size: _tablet);

      // The most recent is on screen, read; the other still unread.
      expect(store.openUserId, '8');
      expect(find.text('1 unread'), findsOneWidget);
      expect(find.byType(WhisperConversation), findsOneWidget);
      expect(find.text('friend'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('whisper-selected-bar')),
        findsOneWidget,
      );

      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();
      expect(store.openUserId, '9');
      expect(find.text('All read'), findsOneWidget);
      expect(find.text('older'), findsNWidgets(2));

      // A whisper elsewhere does not switch the pane.
      receive('again', id: 'w3');
      await settle(tester);
      expect(store.openUserId, '9');
      expect(tester.takeException(), isNull);
    });

    testWidgets('no conversation: the empty state in the pane', (tester) async {
      init();
      for (final size in [_tablet, _tabletPortrait]) {
        await pumpScreen(tester, WhispersScreen(store: store), size: size);
        expect(find.textContaining('No whispers yet'), findsOneWidget);
        expect(find.text('All read'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('opened on a conversation, from Activity or a chat', (
      tester,
    ) async {
      init();
      receive('hey');
      receive('yo', from: '9', login: 'other', name: 'Other', id: 'w2');
      await tester.pump();
      await pumpScreen(
        tester,
        WhispersScreen(
          store: store,
          initial: const WhisperTarget(
            userId: '8',
            login: 'friend',
            displayName: 'Friend',
          ),
        ),
        size: _tabletPortrait,
      );
      expect(store.openUserId, '8');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the window becoming a phone keeps the draft', (tester) async {
      init();
      receive('hey');
      await tester.pump();
      await pumpScreen(tester, WhispersScreen(store: store), size: _tablet);
      await tester.tap(find.text('Friend').first);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'draft');
      await tester.pump();

      tester.view.physicalSize = _phone;
      await tester.pumpAndSettle();
      expect(find.byType(WhisperConversation), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'draft',
      );
      expect(store.openUserId, '8');
      expect(tester.takeException(), isNull);

      // Back on the phone: the list.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(WhisperConversation), findsNothing);
      expect(store.openUserId, isNull);
    });
  });

  for (final theme in [ThemeMode.dark, ThemeMode.light]) {
    for (final size in [_phone, _tablet, _tabletPortrait]) {
      testWidgets('lays out at ${size.width}x${size.height} (${theme.name})', (
        tester,
      ) async {
        init();
        receive('a whisper long enough to wrap on two lines of a bubble ' * 3);
        receive('second', id: 'w2');
        await tester.pump();
        await pumpScreen(
          tester,
          WhispersScreen(store: store),
          size: size,
          theme: theme,
        );
        await tester.tap(find.text('Friend').first);
        await tester.pumpAndSettle();
        expect(find.byType(WhisperConversation), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('reduce motion: the conversation fades in, nothing slides', (
    tester,
  ) async {
    init();
    receive('hey');
    await tester.pump();
    await pumpScreen(tester, WhispersScreen(store: store), reduceMotion: true);
    await tester.tap(find.text('Friend'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    // No travel: the conversation is in place, fading.
    final layer = find.ancestor(
      of: find.byType(WhisperConversation),
      matching: find.byType(FractionalTranslation),
    );
    expect(
      tester.widget<FractionalTranslation>(layer.first).translation,
      Offset.zero,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(WhisperConversation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('the status hints', () {
    final en = L10n.english;
    expect(whisperStatusHint(WhisperStatus.listening, en), isNull);
    expect(whisperStatusHint(WhisperStatus.connecting, en), isNull);
    expect(whisperStatusHint(WhisperStatus.off, en), 'Log in to get whispers.');
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(
      whisperStatusHint(WhisperStatus.off, fr),
      'Connectez-vous pour recevoir des chuchotements.',
    );
  });

  group('in French', () {
    final french = lookupAppLocalizations(fr);

    for (final (sizeName, size) in frenchScreenSizes) {
      for (final scale in frenchTextScales) {
        testWidgets('the list, a conversation, $sizeName, text ×$scale', (
          tester,
        ) async {
          init();
          await pumpScreen(
            tester,
            WhispersScreen(store: store),
            size: size,
            locale: fr,
            textScale: scale,
          );
          expect(find.text(french.whispersEmpty), findsWidgets);
          await expectFrenchThroughout(tester, 'none');

          receive('salut');
          receive('ça va ?', id: 'w2', from: '9', login: 'amie', name: 'Amie');
          await settle(tester);
          expect(find.text('salut'), findsWidgets);
          await expectFrenchThroughout(tester, 'list');

          await pumpScreen(
            tester,
            WhisperConversation(
              store: store,
              userId: '8',
              login: 'friend',
              displayName: 'Friend',
            ),
            size: size,
            locale: fr,
            textScale: scale,
          );
          expect(find.text(french.whisperSessionNote), findsOneWidget);
          await expectFrenchThroughout(tester, 'conversation');
        });
      }
    }

    for (final (sizeName, size) in frenchChannelScreenSizes) {
      for (final scale in frenchTextScales) {
        testWidgets('why a whisper was not sent, $sizeName, text ×$scale', (
          tester,
        ) async {
          init();
          for (final (error, words) in <(Object, String)>[
            (
              const NetworkException('No internet connection.'),
              'Impossible de chuchoter. ${french.apiErrorNetwork}',
            ),
            (
              const ApiException(
                'Verify your phone number first.',
                403,
                null,
                ApiErrorKind.forbidden,
                'Verify your phone number first.',
              ),
              'Impossible de chuchoter. ${french.apiErrorForbidden} Raison '
                  'de Twitch\u00a0: «\u00a0Verify your phone number first.'
                  '\u00a0»',
            ),
            (
              const UnauthorizedException('Please log in'),
              french.whisperLogInAgain,
            ),
            (StateError('boom'), french.whisperFailedUnexpected),
          ]) {
            when(
              () => api.sendWhisper(
                fromUserId: '7',
                toUserId: '8',
                message: 'salut',
              ),
            ).thenThrow(error);
            await pumpScreen(
              tester,
              WhisperConversation(
                store: store,
                userId: '8',
                login: 'friend',
                displayName: 'Friend',
              ),
              size: size,
              locale: fr,
              textScale: scale,
            );
            await tester.enterText(find.byType(TextField), 'salut');
            await tester.pump();
            await tester.tap(find.byTooltip(french.whisperSend));
            await settle(tester);
            expect(find.text(words), findsOneWidget, reason: '$error');
            await expectFrenchThroughout(
              tester,
              'refused: $error',
              content: const ['Verify your phone number first.'],
            );
          }
        });
      }
    }
  });
}
