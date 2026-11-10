import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/seventv_api.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/third_party_cosmetics.dart';
import 'package:onset/services/seventv_cosmetics_cache.dart';

class _MockSevenTVApi extends Mock implements SevenTVApi {}

const _badge = ChatBadge(
  name: 'Sub',
  url: 'https://cdn.7tv.app/badge/b/3x.webp',
  type: BadgeType.sevenTV,
);

void main() {
  late _MockSevenTVApi api;
  late DateTime clock;

  setUp(() {
    api = _MockSevenTVApi();
    clock = DateTime(2026);
  });

  SevenTvCosmeticsCache cache({int batchSize = 20}) =>
      SevenTvCosmeticsCache(api, batchSize: batchSize, now: () => clock);

  test('chatters seen together are asked for in one request, once', () {
    when(() => api.getUsersCosmetics(any())).thenAnswer(
      (invocation) async => {
        for (final id in invocation.positionalArguments.first as List<String>)
          id: const SevenTvUserCosmetics(badge: _badge),
      },
    );
    fakeAsync((async) {
      final subject = cache();
      final results = <SevenTvUserCosmetics>[];
      for (final id in ['1', '2', '1', '3']) {
        subject.lookup(id).then(results.add);
      }
      async.elapse(const Duration(milliseconds: 500));

      expect(results, hasLength(4));
      verify(() => api.getUsersCosmetics(['1', '2', '3'])).called(1);

      subject.lookup('2').then(results.add);
      async.flushMicrotasks();
      expect(results.last.badge, _badge);
      verifyNoMoreInteractions(api);
    });
  });

  test('a long list is split into batches', () {
    when(() => api.getUsersCosmetics(any())).thenAnswer((_) async => {});
    fakeAsync((async) {
      final subject = cache(batchSize: 2);
      for (final id in ['1', '2', '3']) {
        subject.lookup(id);
      }
      async.elapse(const Duration(seconds: 1));
      verify(() => api.getUsersCosmetics(['1', '2'])).called(1);
      verify(() => api.getUsersCosmetics(['3'])).called(1);
    });
  });

  test('after a failure, nothing is asked for a while', () {
    when(() => api.getUsersCosmetics(any())).thenThrow(Exception('down'));
    fakeAsync((async) {
      final subject = cache();
      SevenTvUserCosmetics? result;
      subject.lookup('1').then((value) => result = value);
      async.elapse(const Duration(seconds: 1));
      expect(result!.badge, isNull);

      subject.lookup('2');
      async.elapse(const Duration(seconds: 1));
      verify(() => api.getUsersCosmetics(any())).called(1);

      clock = clock.add(const Duration(minutes: 6));
      subject.lookup('2');
      async.elapse(const Duration(seconds: 1));
      verify(() => api.getUsersCosmetics(['2'])).called(1);
    });
  });

  test('the cache forgets the oldest users past its capacity', () {
    final subject = SevenTvCosmeticsCache(api, capacity: 2);
    subject.remember('1', SevenTvUserCosmetics.none);
    subject.remember('2', SevenTvUserCosmetics.none);
    subject.remember('3', SevenTvUserCosmetics.none);
    expect(subject.cached('1'), isNull);
    expect(subject.cached('3'), isNotNull);
  });

  test('an emote set is fetched once and a failure is retried', () async {
    var calls = 0;
    when(
      () => api.getEmoteSet(id: 's', type: EmoteType.sevenTVPersonal),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('down');
      return const [];
    });
    final subject = cache();
    expect(await subject.emoteSet('s'), isEmpty);
    await subject.emoteSet('s');
    await subject.emoteSet('s');
    expect(calls, 2);
  });
}
