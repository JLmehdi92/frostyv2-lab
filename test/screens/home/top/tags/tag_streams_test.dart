import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/home/top/tags/tag_streams.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockDirectoryService extends Mock implements TwitchDirectoryService {}

class MockUserStore extends Mock implements UserStore {}

void main() {
  late MockDirectoryService directory;

  setUpAll(() => registerFallbackValue(StreamSort.recent));

  setUp(() {
    directory = MockDirectoryService();
    when(
      () => directory.getTagStreams(
        tag: any(named: 'tag'),
        sort: any(named: 'sort'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) async => const StreamsTwitch([], {}));
  });

  Future<void> pumpApp(WidgetTester tester, Widget home) => tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SettingsStore>.value(value: SettingsStore.fromJson({})),
        Provider<AuthStore>.value(value: MockAuthStore()),
        Provider<TwitchApi>.value(value: MockTwitchApi()),
        Provider<TwitchDirectoryService>.value(value: directory),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [OnsetColors.light]),
        home: home,
      ),
    ),
  );

  testWidgets('the tag\'s live streams, in the picked order', (tester) async {
    await pumpApp(tester, const TagStreams(tag: 'Chill'));
    await tester.pump();

    expect(find.text('Chill'), findsOneWidget);
    expect(find.text('No live streams'), findsOneWidget);
    verify(
      () => directory.getTagStreams(tag: 'Chill', sort: StreamSort.viewersHigh),
    ).called(1);

    await tester.tap(find.byTooltip('Sort streams'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Viewers (low to high)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    verify(
      () => directory.getTagStreams(tag: 'Chill', sort: StreamSort.viewersLow),
    ).called(1);
  });

  testWidgets('the header is not blurred until the page is in place', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => TagStreams.open(context, 'Chill'),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Mid-transition the page below (the Live feed's preview) shows
    // through: never blurred.
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isTrue,
    );
  });

  testWidgets('only Twitch tags open a page', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Column(
          children: [
            TextButton(
              onPressed: () => TagStreams.open(context, 'two words'),
              child: const Text('bad'),
            ),
            TextButton(
              onPressed: () => TagStreams.open(context, 'Speedrun'),
              child: const Text('good'),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('bad'));
    await tester.pump();
    expect(find.byType(TagStreams), findsNothing);

    await tester.tap(find.text('good'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TagStreams), findsOneWidget);
  });

  group('the redesigned page (tag state)', () {
    late MockTwitchApi api;

    setUp(() {
      api = MockTwitchApi();
      when(
        () => api.getUser(userLogin: any(named: 'userLogin')),
      ).thenAnswer((_) => Completer<UserTwitch>().future);
      when(
        () => directory.getTagStreams(
          tag: any(named: 'tag'),
          sort: any(named: 'sort'),
          language: any(named: 'language'),
        ),
      ).thenAnswer(
        (_) async => StreamsTwitch([
          for (var i = 0; i < 3; i++)
            StreamTwitch(
              '$i',
              'streamer$i',
              'Streamer$i',
              '1',
              'Just Chatting',
              'Title $i',
              900,
              DateTime.now().toUtc().toIso8601String(),
              'https://thumb-{width}x{height}.jpg',
              tags: const ['Chill', 'English'],
            ),
        ], const {}),
      );
    });

    Future<void> pumpPage(
      WidgetTester tester,
      Size size,
      ThemeMode mode,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = MockAuthStore();
      final user = MockUserStore();
      when(() => auth.isLoggedIn).thenReturn(false);
      when(() => auth.user).thenReturn(user);
      when(() => user.blockedUsers).thenReturn(ObservableList());
      final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<SettingsStore>.value(value: SettingsStore.fromJson({})),
            Provider<AuthStore>.value(value: auth),
            Provider<TwitchApi>.value(value: api),
            Provider<TwitchDirectoryService>.value(value: directory),
          ],
          child: MaterialApp(
            theme: themes.light,
            darkTheme: themes.dark,
            themeMode: mode,
            home: const TagStreams(tag: 'Chill'),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    const sizes = [Size(390, 844), Size(1280, 854), Size(854, 1280)];
    for (final size in sizes) {
      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        testWidgets('the tag is the title and is lit on every card '
            '(${size.width.toInt()}x${size.height.toInt()}, ${mode.name})', (
          tester,
        ) async {
          await pumpPage(tester, size, mode);
          expect(tester.takeException(), isNull);
          expect(find.byTooltip('Back'), findsOneWidget);
          expect(find.byTooltip('Sort streams'), findsOneWidget);
          // The title, and the three cards' pills.
          expect(find.text('Chill'), findsNWidgets(4));
          // Only the other tags open a page from here.
          expect(find.bySemanticsLabel('Tag Chill'), findsNothing);
          expect(find.bySemanticsLabel('Tag English'), findsNWidgets(3));
          // The first card starts under the header.
          expect(
            tester.getTopLeft(find.text('Streamer0')).dy,
            greaterThan(TagStreams.headerHeight),
          );
        });
      }
    }
  });
}
