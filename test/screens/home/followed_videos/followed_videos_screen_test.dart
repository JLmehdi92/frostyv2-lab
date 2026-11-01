import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/followed_channel.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/home/followed_videos/followed_videos_screen.dart';
import 'package:onset/screens/home/followed_videos/stores/followed_videos_store.dart';
import 'package:onset/screens/vod/widgets/vod_card.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

import '../../../helpers/l10n.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockVodService extends Mock implements TwitchVodService {}

/// Fixed clocks on either side of midnight: the day sections must not
/// depend on when the suite runs.
final _justAfterMidnight = DateTime(2026, 10, 30, 0, 30);
final _justBeforeMidnight = DateTime(2026, 10, 29, 23, 30);

void main() {
  late MockTwitchApi api;
  late MockVodService vods;

  /// The screen's clock in these tests.
  var clock = _justAfterMidnight;

  setUp(() {
    clock = _justAfterMidnight;
    api = MockTwitchApi();
    vods = MockVodService();
    when(() => api.getFollowedChannels(userId: '7')).thenAnswer(
      (_) async => FollowedChannels(
        data: [
          FollowedChannel(
            broadcasterId: '1',
            broadcasterLogin: 'c1',
            broadcasterName: 'C1',
            followedAt: DateTime.utc(2026),
          ),
        ],
        pagination: const {},
        total: 1,
      ),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    ThemeData? theme,
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
    );
    await tester.pumpWidget(
      Provider<TwitchApi>.value(
        value: api,
        child: MaterialApp(
          locale: app.locale,
          supportedLocales: app.supportedLocales,
          localizationsDelegates: app.delegates,
          builder: app.builder,
          theme: theme ?? ThemeData(extensions: const [OnsetColors.light]),
          home: FollowedVideosScreen(
            now: () => clock,
            store: FollowedVideosStore(
              twitchApi: api,
              vodService: vods,
              userId: '7',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Vod video(String id, Duration age, {String title = 'Video'}) => Vod(
    id: id,
    title: title,
    lengthSeconds: 3600,
    createdAt: clock.subtract(age),
    viewCount: 10,
    ownerId: '1',
    ownerLogin: 'c1',
    ownerDisplayName: 'Streamer',
    type: VodType.archive,
  );

  testWidgets('lists the videos with their channel', (tester) async {
    when(() => vods.getFollowedVideos(any())).thenAnswer(
      (_) async => [
        Vod(
          id: 'a',
          title: 'Morning stream',
          lengthSeconds: 3600,
          createdAt: clock.subtract(const Duration(days: 1)),
          viewCount: 10,
          ownerId: '1',
          ownerLogin: 'c1',
          ownerDisplayName: 'Streamer',
          type: VodType.archive,
        ),
      ],
    );
    await pump(tester);

    expect(find.text('Followed videos'), findsOneWidget);
    expect(find.text('Morning stream'), findsOneWidget);
    expect(find.textContaining('Streamer'), findsWidgets);
  });

  testWidgets('says when there is nothing', (tester) async {
    when(() => vods.getFollowedVideos(any())).thenAnswer((_) async => []);
    await pump(tester);
    expect(find.text('No recent videos'), findsOneWidget);
  });

  testWidgets('a failure offers to try again', (tester) async {
    when(
      () => vods.getFollowedVideos(any()),
    ).thenThrow(const VodApiException('Unreadable videos'));
    await pump(tester);
    // An error the app raised itself (its message is for logs) reads as
    // an unexpected one.
    expect(find.text('An unexpected error occurred'), findsOneWidget);

    when(() => vods.getFollowedVideos(any())).thenAnswer((_) async => []);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('No recent videos'), findsOneWidget);
  });

  for (final at in [_justAfterMidnight, _justBeforeMidnight]) {
    final label = '${at.hour}:${at.minute}';
    testWidgets('videos fall in Today / Yesterday / This week / Older '
        '(clock at $label)', (tester) async {
      clock = at;
      when(() => vods.getFollowedVideos(any())).thenAnswer(
        (_) async => [
          video('a', Duration.zero, title: 'Now'),
          video('b', const Duration(days: 1), title: 'Day before'),
          video('c', const Duration(days: 3), title: 'Mid week'),
          video('d', const Duration(days: 12), title: 'Long ago'),
        ],
      );
      await pump(tester, size: const Size(390, 1400));

      expect(tester.takeException(), isNull);
      for (final label in ['TODAY', 'YESTERDAY', 'THIS WEEK', 'OLDER']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('TODAY'), lessThan(top('Now')));
      expect(top('Now'), lessThan(top('YESTERDAY')));
      expect(top('YESTERDAY'), lessThan(top('Day before')));
      expect(top('THIS WEEK'), lessThan(top('Mid week')));
      expect(top('OLDER'), lessThan(top('Long ago')));
    });

    testWidgets('the sections follow the screen\'s clock ($label)', (
      tester,
    ) async {
      clock = at;
      when(() => vods.getFollowedVideos(any())).thenAnswer(
        (_) async => [
          video('a', const Duration(minutes: 10), title: 'Just now'),
          video('b', const Duration(hours: 1), title: 'An hour ago'),
        ],
      );
      await pump(tester, size: const Size(390, 1400));
      expect(find.text('TODAY'), findsOneWidget);
      // An hour before 00:30 is yesterday; before 23:30, still today.
      expect(
        find.text('YESTERDAY'),
        at.hour == 0 ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('a tablet shows tiles in a grid, light and dark', (tester) async {
    // Six videos of the same day, whichever side of midnight the clock is.
    when(() => vods.getFollowedVideos(any())).thenAnswer(
      (_) async => [
        for (var i = 0; i < 6; i++) video('$i', Duration(minutes: i * 4)),
      ],
    );
    for (final at in [_justAfterMidnight, _justBeforeMidnight]) {
      clock = at;
      for (final theme in [
        ThemeData(extensions: const [OnsetColors.light]),
        ThemeData(
          brightness: Brightness.dark,
          extensions: const [OnsetColors.dark],
        ),
      ]) {
        for (final size in const [Size(1280, 854), Size(854, 1280)]) {
          // A new screen each time (its own store, loaded once).
          await tester.pumpWidget(const SizedBox());
          await pump(tester, size: size, theme: theme);
          expect(tester.takeException(), isNull);
          expect(
            find.text('The newest videos of the channels you follow'),
            findsOneWidget,
          );
          final cards = find.byType(VodCard);
          expect(cards, findsWidgets);
          expect(tester.widget<VodCard>(cards.first).tile, isTrue);
          // Several tiles share the first row.
          final first = tester.getTopLeft(cards.at(0));
          final second = tester.getTopLeft(cards.at(1));
          expect(second.dy, first.dy);
          expect(second.dx, greaterThan(first.dx));
        }
      }
    }
  });

  test('sections count calendar days', () {
    final now = DateTime(2026, 10, 29, 0, 30);
    expect(
      FollowedVideosSection.of(DateTime(2026, 10, 29, 0, 5), now),
      FollowedVideosSection.today,
    );
    expect(
      FollowedVideosSection.of(DateTime(2026, 10, 28, 23, 50), now),
      FollowedVideosSection.yesterday,
    );
    expect(
      FollowedVideosSection.of(DateTime(2026, 10, 23, 12), now),
      FollowedVideosSection.thisWeek,
    );
    expect(
      FollowedVideosSection.of(DateTime(2026, 10, 22, 12), now),
      FollowedVideosSection.older,
    );
    expect(
      FollowedVideosSection.of(DateTime(2026, 10, 30), now),
      FollowedVideosSection.today,
      reason: 'a clock behind the server',
    );
  });

  group('in French', () {
    final french = lookupAppLocalizations(fr);

    for (final (sizeName, size) in frenchScreenSizes) {
      for (final scale in frenchTextScales) {
        testWidgets('the sections, $sizeName, text ×$scale', (tester) async {
          when(() => vods.getFollowedVideos(any())).thenAnswer(
            (_) async => [
              // Titles are Twitch's data: neither language's words.
              video('a', Duration.zero, title: 'Partie 1'),
              video('b', const Duration(days: 1), title: 'Partie 2'),
              video('c', const Duration(days: 3), title: ''),
              video('d', const Duration(days: 12), title: 'Partie 4'),
            ],
          );
          await pump(tester, size: size, locale: fr, textScale: scale);
          expect(
            find.text(french.followedVideosToday.toUpperCase()),
            findsOneWidget,
          );
          expect(find.text(french.followedVideosTitle), findsOneWidget);
          await expectFrenchThroughout(tester, 'followed videos');
        });
      }
    }

    testWidgets('empty', (tester) async {
      when(() => vods.getFollowedVideos(any())).thenAnswer((_) async => []);
      await pump(tester, locale: fr);
      expect(find.text(french.followedVideosEmpty), findsOneWidget);
      await expectFrenchThroughout(tester, 'empty');
    });

    testWidgets('a failure', (tester) async {
      when(
        () => vods.getFollowedVideos(any()),
      ).thenThrow(const VodApiException('Unreadable videos'));
      await pump(tester, locale: fr);
      expect(find.text(french.apiErrorUnexpected), findsOneWidget);
      await expectFrenchThroughout(tester, 'failed');
    });
  });
}
