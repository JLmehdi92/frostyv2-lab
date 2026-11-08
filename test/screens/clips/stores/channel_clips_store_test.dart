import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/clips/stores/channel_clips_store.dart';

import '../../../fixtures/clip_responses.dart';

class MockClipService extends Mock implements TwitchClipService {}

void main() {
  late MockClipService service;
  late ChannelClipsStore store;
  final clip = Clip.fromGql(clipNode);
  final other = Clip.fromGql(clipNodeOrphan);

  setUpAll(() {
    registerFallbackValue(ClipPeriod.lastWeek);
    registerFallbackValue(ClipSort.top);
  });

  setUp(() {
    service = MockClipService();
    store = ChannelClipsStore(login: 'xqc', clipService: service);
  });

  tearDown(() => store.dispose());

  void answer(ClipPeriod period, ClipSort sort, List<Clip> clips) => when(
    () => service.getChannelClips(login: 'xqc', period: period, sort: sort),
  ).thenAnswer((_) async => ClipPage(items: clips, hasMore: true));

  test('starts on the top clips of the week', () async {
    answer(ClipPeriod.lastWeek, ClipSort.top, [clip]);

    await store.load();

    expect(store.period, ClipPeriod.lastWeek);
    expect(store.sort, ClipSort.top);
    expect(store.clips, [clip]);
    expect(store.hasMore, isTrue);
    expect(store.loaded, isTrue);
  });

  test('a chip already loaded comes back without a request', () async {
    answer(ClipPeriod.lastWeek, ClipSort.top, [clip]);
    answer(ClipPeriod.allTime, ClipSort.top, [other]);
    await store.load();

    await store.select(period: ClipPeriod.allTime);
    expect(store.clips, [other]);
    await store.select(period: ClipPeriod.lastWeek);

    expect(store.clips, [clip]);
    verify(
      () => service.getChannelClips(
        login: 'xqc',
        period: ClipPeriod.lastWeek,
        sort: ClipSort.top,
      ),
    ).called(1);
  });

  test('loads while loading join the same request', () async {
    answer(ClipPeriod.lastWeek, ClipSort.top, [clip]);

    await Future.wait([store.load(), store.load()]);

    verify(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).called(1);
  });

  test(
    'a slow answer for an old chip never replaces the current one',
    () async {
      final slow = Completer<ClipPage>();
      when(
        () => service.getChannelClips(
          login: 'xqc',
          period: ClipPeriod.lastWeek,
          sort: ClipSort.top,
        ),
      ).thenAnswer((_) => slow.future);
      answer(ClipPeriod.lastWeek, ClipSort.trending, [other]);

      final first = store.load();
      await store.select(sort: ClipSort.trending);
      slow.complete(ClipPage(items: [clip], hasMore: false));
      await first;

      expect(store.sort, ClipSort.trending);
      expect(store.clips, [other]);
      expect(store.isLoading, isFalse);
    },
  );

  test('errors read like the rest of the app', () async {
    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenThrow(const NotFoundException('nope'));
    await store.load();
    expect(store.error, ChannelClipsProblem.channelNotFound);

    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenThrow(const ClipApiException('server error'));
    await store.refresh();
    expect(store.error, ChannelClipsProblem.failed);
    expect(store.clips, isEmpty);
  });

  test('refresh asks again for the current chip', () async {
    answer(ClipPeriod.lastWeek, ClipSort.top, [clip]);
    await store.load();
    answer(ClipPeriod.lastWeek, ClipSort.top, [other]);

    await store.refresh();

    expect(store.clips, [other]);
  });

  test('another starting period can be asked for (links)', () async {
    store.dispose();
    store = ChannelClipsStore(
      login: 'xqc',
      clipService: service,
      period: ClipPeriod.lastDay,
    );
    answer(ClipPeriod.lastDay, ClipSort.top, [clip]);
    await store.load();
    expect(store.clips, [clip]);
  });

  test(
    'back on a chip still loading: the spinner, not the other list',
    () async {
      final slow = Completer<ClipPage>();
      when(
        () => service.getChannelClips(
          login: 'xqc',
          period: ClipPeriod.allTime,
          sort: ClipSort.top,
        ),
      ).thenAnswer((_) => slow.future);
      answer(ClipPeriod.lastWeek, ClipSort.top, [clip]);
      await store.load();

      final all = store.select(period: ClipPeriod.allTime);
      await store.select(period: ClipPeriod.lastWeek);
      final again = store.select(period: ClipPeriod.allTime);

      expect(store.isLoading, isTrue);
      slow.complete(ClipPage(items: [other], hasMore: false));
      await Future.wait([all, again]);
      expect(store.clips, [other]);
      expect(store.isLoading, isFalse);
    },
  );

  test('a failed pull-to-refresh keeps the list it had', () async {
    answer(ClipPeriod.lastWeek, ClipSort.top, [clip]);
    await store.load();
    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenThrow(const ClipApiException('down'));

    await store.refresh();

    expect(store.clips, [clip]);
    expect(store.error, isNull);
  });

  test('a category store asks for the category\'s clips', () async {
    when(
      () => service.getCategoryClips(
        gameId: '32982',
        period: ClipPeriod.lastWeek,
        sort: ClipSort.top,
      ),
    ).thenAnswer((_) async => ClipPage(items: [clip], hasMore: false));
    final category = ChannelClipsStore(
      login: '',
      gameId: '32982',
      clipService: service,
    );
    addTearDown(category.dispose);

    await category.load();

    expect(category.clips, [clip]);
    verifyNever(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    );
  });

  test('an unknown category says so', () async {
    when(
      () => service.getCategoryClips(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenThrow(const NotFoundException('nope'));
    final category = ChannelClipsStore(
      login: '',
      gameId: '1',
      clipService: service,
    );
    addTearDown(category.dispose);

    await category.load();

    expect(category.error, ChannelClipsProblem.categoryNotFound);
  });

  group('dates, sorts and reset', () {
    final older = Clip.fromGql({
      ...clipNode,
      'id': 'older',
      'slug': 'OlderClip',
      'createdAt': '2020-01-01T00:00:00Z',
    });
    final newer = Clip.fromGql({
      ...clipNode,
      'id': 'newer',
      'slug': 'NewerClip',
      'createdAt': '2030-01-01T00:00:00Z',
    });

    test(
      'newest and oldest reorder the top clips without a new request',
      () async {
        answer(ClipPeriod.lastWeek, ClipSort.top, [older, newer]);
        await store.load();

        await store.select(sort: ClipSort.newest);
        expect(store.clips, [newer, older]);
        await store.select(sort: ClipSort.oldest);
        expect(store.clips, [older, newer]);
        verify(
          () => service.getChannelClips(
            login: 'xqc',
            period: ClipPeriod.lastWeek,
            sort: ClipSort.top,
          ),
        ).called(1);
      },
    );

    test(
      'a date range lists its clips, hides trending, and reset comes back',
      () async {
        final asked = <(DateTime, DateTime)>[];
        final ranged = ChannelClipsStore(
          login: 'xqc',
          clipService: service,
          clipsBetween: (start, end) async {
            asked.add((start, end));
            return [older];
          },
        );
        addTearDown(ranged.dispose);
        answer(ClipPeriod.lastWeek, ClipSort.top, [clip]);
        answer(ClipPeriod.lastWeek, ClipSort.trending, [clip]);
        await ranged.select(sort: ClipSort.trending);
        expect(ranged.canPickRange, isTrue);
        expect(ranged.isFiltered, isTrue);

        final start = DateTime(2026, 3);
        final end = DateTime(2026, 3, 8);
        await ranged.selectRange(start, end);

        expect(asked, [(start, end)]);
        expect(ranged.range, (start: start, end: end));
        expect(ranged.clips, [older]);
        expect(ranged.sort, ClipSort.top);
        expect(ranged.sorts, isNot(contains(ClipSort.trending)));

        await ranged.select(period: ClipPeriod.lastWeek);
        expect(ranged.range, isNull);
        expect(ranged.clips, [clip]);

        await ranged.selectRange(start, end);
        expect(asked, hasLength(1));
        await ranged.reset();
        expect(ranged.range, isNull);
        expect(ranged.period, ClipPeriod.lastWeek);
        expect(ranged.sort, ClipSort.top);
        expect(ranged.isFiltered, isFalse);
      },
    );

    test('a failed range says so, and no range without a source', () async {
      final ranged = ChannelClipsStore(
        login: 'xqc',
        clipService: service,
        clipsBetween: (_, _) async => throw const NetworkException('down'),
      );
      addTearDown(ranged.dispose);
      await ranged.selectRange(DateTime(2026), DateTime(2026, 2));
      expect(ranged.error, ChannelClipsProblem.failed);
      expect(ranged.clips, isEmpty);

      expect(store.canPickRange, isFalse);
      await store.selectRange(DateTime(2026), DateTime(2026, 2));
      expect(store.range, isNull);
    });
  });
}
