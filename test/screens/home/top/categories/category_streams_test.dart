import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_clip_service.dart';
import 'package:frosty/apis/twitch_directory_service.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/category.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/clips/widgets/clip_card.dart';
import 'package:frosty/screens/home/top/categories/category_streams.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/onset_chip.dart';
import 'package:mobx/mobx.dart' show Observable, ObservableList, runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

/// A viewer whose login can change while the page is open.
class FakeAuthStore extends Mock implements AuthStore {
  FakeAuthStore(bool loggedIn) : _loggedIn = Observable(loggedIn);

  final Observable<bool> _loggedIn;

  @override
  bool get isLoggedIn => _loggedIn.value;

  void setLoggedIn(bool value) => runInAction(() => _loggedIn.value = value);
}

class MockVodService extends Mock implements TwitchVodService {}

class MockClipService extends Mock implements TwitchClipService {}

class MockHypeTrainService extends Mock implements TwitchHypeTrainService {}

class MockDirectoryService extends Mock implements TwitchDirectoryService {}

class MockUserStore extends Mock implements UserStore {}

const _gta = CategoryTwitch(
  'https://art/{width}x{height}.jpg',
  '32982',
  'Grand Theft Auto V',
);

StreamTwitch _stream(String id) => StreamTwitch(
  id,
  'streamer$id',
  'Streamer$id',
  '32982',
  'Grand Theft Auto V',
  'Heist $id',
  2104,
  DateTime.now().toUtc().toIso8601String(),
  'https://thumb-{width}x{height}.jpg',
  tags: const ['RP'],
);

/// Lets loads and transitions finish (a skeleton's sheen never settles).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late MockTwitchApi helix;
  late MockVodService vods;
  late MockClipService clips;
  late MockDirectoryService directory;

  setUpAll(() {
    registerFallbackValue(ClipPeriod.lastWeek);
    registerFallbackValue(ClipSort.top);
    registerFallbackValue(StreamSort.recent);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    helix = MockTwitchApi();
    vods = MockVodService();
    clips = MockClipService();
    directory = MockDirectoryService();
    when(
      () => directory.getCategoryStreams(
        gameId: any(named: 'gameId'),
        sort: any(named: 'sort'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) => Completer<StreamsTwitch>().future);
    // The live list stays loading: these tests are about the sections.
    when(
      () => helix.getCategory(gameId: any(named: 'gameId')),
    ).thenAnswer((_) => Completer<CategoriesTwitch>().future);
    when(
      () => helix.getStreamsUnderCategory(
        gameId: any(named: 'gameId'),
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) => Completer<StreamsTwitch>().future);
    when(() => vods.getCategoryVideos(any())).thenAnswer(
      (_) async => VodPage(
        items: [
          Vod(
            id: '9',
            title: 'Heist',
            lengthSeconds: 3600,
            createdAt: DateTime.utc(2026),
            viewCount: 5,
            ownerId: '42',
            ownerLogin: 'streamer',
            ownerDisplayName: 'Streamer',
            gameName: 'Grand Theft Auto V',
          ),
        ],
        hasMore: false,
      ),
    );
    when(
      () => clips.getCategoryClips(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer(
      (_) async => ClipPage(
        items: [
          Clip(
            id: '1',
            slug: 'Slug',
            title: 'Wow',
            viewCount: 1,
            createdAt: DateTime.utc(2026),
            durationSeconds: 30,
            broadcasterId: '43',
            broadcasterLogin: 'other',
            broadcasterDisplayName: 'Other',
            gameName: 'Grand Theft Auto V',
          ),
        ],
        hasMore: false,
      ),
    );
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Size? size,
    ThemeMode mode = ThemeMode.light,
    bool loggedIn = false,
    bool reduceMotion = false,
    bool pushed = false,
    AuthStore? authStore,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final user = MockUserStore();
    final auth = authStore ?? MockAuthStore();
    if (authStore == null) when(() => auth.isLoggedIn).thenReturn(loggedIn);
    when(() => auth.user).thenReturn(user);
    when(() => auth.twitchWebToken).thenReturn(null);
    when(() => user.details).thenReturn(null);
    when(() => user.blockedUsers).thenReturn(ObservableList());
    final themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsStore>.value(value: SettingsStore.fromJson({})),
          Provider<AuthStore>.value(value: auth),
          Provider<TwitchApi>.value(value: helix),
          Provider<TwitchVodService>.value(value: vods),
          Provider<TwitchClipService>.value(value: clips),
          Provider<TwitchDirectoryService>.value(value: directory),
          Provider<TwitchHypeTrainService>.value(value: MockHypeTrainService()),
        ],
        child: MaterialApp(
          theme: themes.light,
          darkTheme: themes.dark,
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: pushed
              ? Builder(
                  builder: (context) => TextButton(
                    onPressed: () => CategoryStreams.open(context, '32982'),
                    child: const Text('open'),
                  ),
                )
              : const CategoryStreams(categoryId: '32982'),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('live first, then the category\'s videos and clips', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.widgetWithText(OnsetChip, 'Live'), findsOneWidget);
    verifyNever(() => vods.getCategoryVideos(any()));

    await tester.tap(find.widgetWithText(OnsetChip, 'Videos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(VodCard), findsOneWidget);
    expect(find.text('Streamer'), findsOneWidget);
    verify(() => vods.getCategoryVideos('32982')).called(1);

    await tester.tap(find.widgetWithText(OnsetChip, 'Clips'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ClipCard), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live streams can be sorted; videos and clips cannot', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(
      find.text('Sorted by Viewers (high to low)', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Sort streams'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Recently started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    verify(
      () => directory.getCategoryStreams(
        gameId: '32982',
        sort: StreamSort.recent,
      ),
    ).called(1);
    expect(
      find.text('Sorted by Recently started', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OnsetChip, 'Videos'));
    await tester.pump();
    expect(find.byTooltip('Sort streams'), findsNothing);
  });

  testWidgets('leaving without videos or clips asks for neither', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.pumpWidget(const SizedBox());

    expect(tester.takeException(), isNull);
    verifyNever(() => vods.getCategoryVideos(any()));
    verifyNever(
      () => clips.getCategoryClips(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    );
  });

  testWidgets('the live list is kept while another section shows', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Sort streams'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Recently started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.widgetWithText(OnsetChip, 'Videos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(OnsetChip, 'Live'));
    await tester.pump();

    expect(
      find.text('Sorted by Recently started', findRichText: true),
      findsOneWidget,
    );
    // Asked once: coming back did not build a new list.
    verify(
      () => directory.getCategoryStreams(
        gameId: '32982',
        sort: StreamSort.recent,
      ),
    ).called(1);
    verify(() => helix.getStreamsUnderCategory(gameId: '32982')).called(1);
  });

  group('the redesigned page (board Categorie)', () {
    setUp(() {
      when(
        () => helix.getCategory(gameId: any(named: 'gameId')),
      ).thenAnswer((_) async => const CategoriesTwitch([_gta], {}));
      when(
        () => helix.getStreamsUnderCategory(
          gameId: any(named: 'gameId'),
          cursor: any(named: 'cursor'),
          language: any(named: 'language'),
        ),
      ).thenAnswer(
        (_) async => StreamsTwitch([
          for (var i = 0; i < 12; i++) _stream('$i'),
        ], const {}),
      );
      when(
        () => helix.getUser(userLogin: any(named: 'userLogin')),
      ).thenAnswer((_) => Completer<UserTwitch>().future);
    });

    const sizes = [Size(390, 844), Size(1280, 854), Size(854, 1280)];
    for (final size in sizes) {
      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        testWidgets('the header scrolls with the streams '
            '(${size.width.toInt()}x${size.height.toInt()}, ${mode.name})', (
          tester,
        ) async {
          await pumpPage(tester, size: size, mode: mode);
          await settle(tester);
          expect(tester.takeException(), isNull);
          expect(find.text('CATEGORY'), findsOneWidget);
          expect(find.text('Grand Theft Auto V'), findsOneWidget);
          expect(find.byTooltip('Back'), findsOneWidget);
          // Logged out: following is twitch.tv's, behind a login.
          expect(find.text('Follow on Twitch'), findsNothing);
          // The sections and the order.
          for (final label in ['Live', 'Videos', 'Clips']) {
            expect(find.widgetWithText(OnsetChip, label), findsOneWidget);
          }
          expect(find.byTooltip('Sort streams'), findsOneWidget);
          // A category's rows name their viewers, not the category.
          expect(find.text('2,104 viewers'), findsWidgets);

          final title = tester.getTopLeft(find.text('CATEGORY')).dy;
          await tester.drag(
            find.byType(CustomScrollView).first,
            const Offset(0, -120),
          );
          await tester.pump();
          expect(tester.getTopLeft(find.text('CATEGORY')).dy, lessThan(title));
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('on a tablet the order sits on the sections\' row', (
      tester,
    ) async {
      await pumpPage(tester, size: const Size(1280, 854));
      await settle(tester);
      final chip = tester.getCenter(find.widgetWithText(OnsetChip, 'Live'));
      final sort = tester.getCenter(find.byTooltip('Sort streams'));
      expect((sort.dy - chip.dy).abs(), lessThan(2));
      expect(sort.dx, greaterThan(chip.dx));
      // At the row's end (board: margin-left auto).
      expect(
        tester.getRect(find.byTooltip('Sort streams')).right,
        greaterThan(1280 - 28 - 8 - 1),
      );
    });

    testWidgets('logged in, "Follow on Twitch" is offered', (tester) async {
      await pumpPage(tester, size: const Size(390, 844), loggedIn: true);
      await settle(tester);
      expect(find.text('Follow on Twitch'), findsOneWidget);
    });

    testWidgets('a screen reader hears the title, then the follow button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester, size: const Size(390, 844), loggedIn: true);
      await settle(tester);
      // The heading is the category alone: no action, no button in it.
      final heading = tester.getSemantics(find.text('Grand Theft Auto V'));
      expect(heading.flagsCollection.isHeader, isTrue);
      expect(heading.label, isNot(contains('Follow on Twitch')));
      expect(
        heading.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      expect(
        tester.getSemantics(find.text('Follow on Twitch')),
        matchesSemantics(
          label: 'Follow on Twitch',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('"Follow on Twitch" follows the login', (tester) async {
      final auth = FakeAuthStore(false);
      await pumpPage(tester, size: const Size(390, 844), authStore: auth);
      await settle(tester);
      expect(find.text('Follow on Twitch'), findsNothing);
      auth.setLoggedIn(true);
      await settle(tester);
      expect(find.text('Follow on Twitch'), findsOneWidget);
      auth.setLoggedIn(false);
      await settle(tester);
      expect(find.text('Follow on Twitch'), findsNothing);
    });

    testWidgets('the order menu ticks the current order', (tester) async {
      await pumpPage(tester, size: const Size(390, 844), mode: ThemeMode.dark);
      await settle(tester);
      await tester.tap(find.byTooltip('Sort streams'));
      await settle(tester);
      for (final sort in StreamSort.values) {
        expect(find.text(sort.label), findsOneWidget);
      }
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        tester.getCenter(find.byIcon(Icons.check_rounded)).dy,
        moreOrLessEquals(
          tester.getCenter(find.text('Viewers (high to low)')).dy,
          epsilon: 2,
        ),
      );
    });

    testWidgets('back pops the page', (tester) async {
      await pumpPage(tester, size: const Size(390, 844), pushed: true);
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(find.byType(CategoryStreams), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.byType(CategoryStreams), findsNothing);
    });

    testWidgets('reduce motion: the sections still switch', (tester) async {
      await pumpPage(tester, size: const Size(390, 844), reduceMotion: true);
      await settle(tester);
      await tester.tap(find.widgetWithText(OnsetChip, 'Clips'));
      await settle(tester);
      expect(find.byType(ClipCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the clips\' period and order chips scroll with the list', (
      tester,
    ) async {
      await pumpPage(tester, size: const Size(390, 844));
      await settle(tester);
      await tester.tap(find.widgetWithText(OnsetChip, 'Clips'));
      await settle(tester);
      await tester.tap(find.widgetWithText(OnsetChip, '24 hours'));
      await settle(tester);
      verify(
        () => clips.getCategoryClips(
          gameId: '32982',
          period: ClipPeriod.lastDay,
          sort: ClipSort.top,
        ),
      ).called(1);
      // The test font is wider than Inter: the row scrolls to it.
      await tester.ensureVisible(find.widgetWithText(OnsetChip, 'Trending'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OnsetChip, 'Trending'));
      await settle(tester);
      verify(
        () => clips.getCategoryClips(
          gameId: '32982',
          period: ClipPeriod.lastDay,
          sort: ClipSort.trending,
        ),
      ).called(1);
      // Under the category's header, not above it.
      expect(
        tester.getTopLeft(find.text('24 hours')).dy,
        greaterThan(tester.getTopLeft(find.text('CATEGORY')).dy),
      );
    });
  });
}
