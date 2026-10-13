import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_channel_profile_service.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/channel_profile/stores/channel_profile_store.dart';
import 'package:mocktail/mocktail.dart';

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

  test('an unknown channel says so, without asking Helix', () async {
    when(() => service.getProfile(any())).thenAnswer((_) async => null);
    final store = create();
    await store.load();
    expect(store.notFound, isTrue);
    expect(helixCalls, isEmpty);
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
}
