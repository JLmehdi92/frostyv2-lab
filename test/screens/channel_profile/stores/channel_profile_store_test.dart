import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_channel_profile_service.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/models/team.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel_profile/stores/channel_profile_store.dart';

class MockProfileService extends Mock implements TwitchChannelProfileService {}

const _profile = ChannelProfile(
  id: '42',
  login: 'streamer',
  displayName: 'Streamer',
);

void main() {
  late MockProfileService service;
  late List<String> helixCalls;

  setUp(() {
    service = MockProfileService();
    helixCalls = [];
  });

  ChannelProfileStore create() => ChannelProfileStore(
    login: 'streamer',
    profileService: service,
    helixUser: (login) async {
      helixCalls.add(login);
      return const UserTwitch('42', 'streamer', 'Streamer', 'https://x/p.png');
    },
  );

  test('the profile, once for concurrent loads', () async {
    final answer = Completer<ChannelProfile?>();
    when(() => service.getProfile(any())).thenAnswer((_) => answer.future);
    final store = create();

    final first = store.load();
    final second = store.load();
    answer.complete(_profile);
    await Future.wait([first, second]);

    verify(() => service.getProfile('streamer')).called(1);
    expect(store.profile, same(_profile));
    expect(store.userId, '42');
    expect(store.loaded, isTrue);
    expect(store.error, isNull);
    expect(helixCalls, isEmpty);
  });

  test('an unknown channel says so once Helix agrees', () async {
    when(() => service.getProfile(any())).thenAnswer((_) async => null);
    final store = ChannelProfileStore(
      login: 'gone',
      profileService: service,
      helixUser: (login) async {
        helixCalls.add(login);
        throw Exception('User does not exist');
      },
    );
    await store.load();
    expect(store.notFound, isTrue);
    expect(helixCalls, ['gone']);
  });

  test('a channel GQL misses but Helix knows keeps the page', () async {
    when(() => service.getProfile(any())).thenAnswer((_) async => null);
    final store = create();
    await store.load();
    expect(store.notFound, isFalse);
    expect(store.fallback?.id, '42');
  });

  test('Helix is asked once, not on every failed retry', () async {
    when(
      () => service.getProfile(any()),
    ).thenThrow(const ChannelProfileApiException('down'));
    final store = create();
    await store.load();
    await store.load();
    await store.load();
    expect(helixCalls, hasLength(1));
  });

  test('a failed profile falls back to the Helix header', () async {
    when(
      () => service.getProfile(any()),
    ).thenThrow(const ChannelProfileApiException('schema'));
    final store = create();
    await store.load();

    expect(store.profile, isNull);
    expect(store.error, isNotNull);
    expect(store.fallback?.id, '42');
    expect(store.displayName, 'Streamer');

    // A later success replaces it.
    when(() => service.getProfile(any())).thenAnswer((_) async => _profile);
    await store.refresh();
    expect(store.profile, same(_profile));
    expect(store.fallback, isNull);
    expect(store.error, isNull);
  });

  test('the schedule loads on demand, and refreshes once shown', () async {
    when(() => service.getProfile(any())).thenAnswer((_) async => _profile);
    when(
      () => service.getSchedule(any()),
    ).thenAnswer((_) async => ChannelSchedule.empty);
    final store = create();
    await store.refresh();
    verifyNever(() => service.getSchedule(any()));

    await store.loadSchedule();
    expect(store.schedule, isNotNull);
    await store.refresh();
    verify(() => service.getSchedule('streamer')).called(2);
  });

  test('a failed schedule keeps the page', () async {
    when(() => service.getSchedule(any())).thenThrow(Exception('down'));
    final store = create();
    await store.loadSchedule();
    expect(store.scheduleError, isNotNull);
    expect(store.scheduleLoading, isFalse);
  });

  test('a late answer after dispose is ignored', () async {
    final answer = Completer<ChannelProfile?>();
    when(() => service.getProfile(any())).thenAnswer((_) => answer.future);
    final store = create();
    final load = store.load();
    store.dispose();
    answer.complete(_profile);
    await load;
    expect(store.profile, isNull);
  });

  test('the trailer and teams load with the profile', () async {
    when(() => service.getProfile(any())).thenAnswer((_) async => _profile);
    when(
      () => service.getTrailer(any()),
    ).thenAnswer((_) async => const ChannelTrailer(videoId: '9', title: 'Hi'));
    final asked = <String>[];
    final store = ChannelProfileStore(
      login: 'streamer',
      profileService: service,
      teamsOf: (id) async {
        asked.add(id);
        return const [Team(id: '1', name: 'staff', displayName: 'Staff')];
      },
    );
    await store.load();
    expect(store.trailer?.videoId, '9');
    expect(store.teams.single.name, 'staff');
    expect(asked, ['42']);
  });

  test('a failed trailer or team list keeps the page', () async {
    when(() => service.getProfile(any())).thenAnswer((_) async => _profile);
    when(() => service.getTrailer(any())).thenThrow(Exception('gql'));
    final store = ChannelProfileStore(
      login: 'streamer',
      profileService: service,
      teamsOf: (_) async => throw Exception('helix'),
    );
    await store.load();
    expect(store.profile, _profile);
    expect(store.error, isNull);
    expect(store.trailer, isNull);
    expect(store.teams, isEmpty);
  });

  test(
    'the profile loads when the DJ query fails, and the flag stays off',
    () async {
      when(() => service.getProfile(any())).thenAnswer((_) async => _profile);
      when(() => service.getTrailer(any())).thenAnswer((_) async => null);
      when(
        () => service.isParticipatingDj(any()),
      ).thenAnswer((_) async => throw StateError('schema changed'));
      final store = create();
      await store.load();
      expect(store.profile, same(_profile));
      expect(store.error, isNull);
      expect(store.isParticipatingDj, isFalse);
    },
  );

  test('the DJ flag comes from its own query', () async {
    when(() => service.getProfile(any())).thenAnswer((_) async => _profile);
    when(() => service.getTrailer(any())).thenAnswer((_) async => null);
    when(
      () => service.isParticipatingDj('streamer'),
    ).thenAnswer((_) async => true);
    final store = create();
    await store.load();
    expect(store.isParticipatingDj, isTrue);
  });
}
