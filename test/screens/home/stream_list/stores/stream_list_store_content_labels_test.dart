import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

StreamTwitch stream(String id) =>
    StreamTwitch(id, 'login$id', 'Name$id', '1', 'Game', 'Title', 10, '', '');

Channel channel(String id, List<String> labels) => Channel(
  broadcasterId: id,
  broadcasterLogin: 'login$id',
  broadcasterName: 'Name$id',
  broadcasterLanguage: 'en',
  title: 'Title',
  gameId: '1',
  gameName: 'Game',
  contentClassificationLabels: labels,
);

Future<void> settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockTwitchApi api;
  late MockAuthStore auth;
  late SettingsStore settings;

  setUp(() {
    api = MockTwitchApi();
    auth = MockAuthStore();
    settings = SettingsStore.fromJson({});
    final user = MockUserStore();
    when(() => auth.user).thenReturn(user);
    when(() => user.details).thenReturn(const UserTwitch('me', 'me', 'Me', ''));
    when(() => user.blockedUsers).thenReturn(ObservableList());
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer(
      (_) async => StreamsTwitch([stream('1'), stream('2'), stream('3')], {}),
    );
    when(
      () => api.getFollowedStreams(
        id: any(named: 'id'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => StreamsTwitch([stream('1')], {}));
    when(() => api.getChannelsByIds(any())).thenAnswer(
      (_) async => {
        '1': channel('1', ['SexualThemes']),
        '2': channel('2', []),
        '3': channel('3', ['Gambling', 'MatureGame']),
      },
    );
  });

  ListStore build(ListType type) => ListStore(
    authStore: auth,
    settingsStore: settings,
    twitchApi: api,
    listType: type,
  );

  test('nothing is looked up while no label is hidden', () async {
    final store = build(ListType.top);
    await settle();

    expect(store.streams.map((s) => s.userId), ['1', '2', '3']);
    expect(store.hiddenByLabels, 0);
    verifyNever(() => api.getChannelsByIds(any()));
    store.dispose();
  });

  test('streams with a hidden label are left out, and counted', () async {
    settings.hiddenContentLabels = ['SexualThemes', 'Gambling'];
    final store = build(ListType.top);
    await settle();

    expect(store.streams.map((s) => s.userId), ['2']);
    expect(store.hiddenByLabels, 2);

    store.showLabeledStreams();
    expect(store.streams.map((s) => s.userId), ['1', '2', '3']);
    store.dispose();
  });

  test('changing the hidden labels starts the list over', () async {
    final store = build(ListType.top);
    await settle();

    settings.hiddenContentLabels = ['MatureGame'];
    await settle();

    expect(store.streams.map((s) => s.userId), ['1', '2']);
    store.dispose();
  });

  test('followed channels are never hidden', () async {
    settings.hiddenContentLabels = ['SexualThemes'];
    final store = build(ListType.followed);
    await settle();

    expect(store.streams.map((s) => s.userId), ['1']);
    verifyNever(() => api.getChannelsByIds(any()));
    store.dispose();
  });

  test('labels that cannot be read hide nothing', () async {
    settings.hiddenContentLabels = ['SexualThemes'];
    when(() => api.getChannelsByIds(any())).thenThrow(Exception('down'));
    final store = build(ListType.top);
    await settle();

    expect(store.streams.map((s) => s.userId), ['1', '2', '3']);
    expect(store.error, isNull);
    store.dispose();
  });

  test('a page shown in full keeps showing as more pages load', () async {
    settings.hiddenContentLabels = ['SexualThemes'];
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((invocation) async {
      final cursor = invocation.namedArguments[#cursor] as String?;
      return cursor == null
          ? StreamsTwitch([stream('1'), stream('2')], {'cursor': 'p2'})
          : StreamsTwitch([stream('3')], {});
    });
    final store = build(ListType.top);
    await settle();
    expect(store.streams.map((s) => s.userId), ['2']);

    store.showLabeledStreams();
    await store.getStreams();
    expect(store.streams.map((s) => s.userId), ['1', '2', '3']);

    await store.refreshStreams();
    expect(store.streams.map((s) => s.userId), ['2']);
    expect(store.hiddenByLabels, 1);
    store.dispose();
  });

  test('pages hidden in full are skipped to the next ones', () async {
    settings.hiddenContentLabels = ['SexualThemes'];
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((invocation) async {
      final cursor = invocation.namedArguments[#cursor] as String?;
      return cursor == null
          ? StreamsTwitch([stream('1')], {'cursor': 'p2'})
          : StreamsTwitch([stream('2')], {'cursor': 'p3'});
    });
    final store = build(ListType.top);
    await settle();

    expect(store.streams.map((s) => s.userId), ['2']);
    store.dispose();
  });

  test('a list hidden in full stops looking after a few pages', () async {
    settings.hiddenContentLabels = ['SexualThemes'];
    var pages = 0;
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) async {
      pages++;
      return StreamsTwitch([stream('1')], {'cursor': 'more'});
    });
    final store = build(ListType.top);
    await settle();
    await settle();

    expect(store.streams, isEmpty);
    expect(store.hiddenByLabels, greaterThan(0));
    expect(pages, lessThanOrEqualTo(4));
    store.dispose();
  });

  test('labels read for an older list are dropped', () async {
    final pending = Completer<Map<String, Channel>>();
    settings.hiddenContentLabels = ['Gambling'];
    when(() => api.getChannelsByIds(any())).thenAnswer((_) => pending.future);
    final store = build(ListType.top);
    await settle();

    when(() => api.getChannelsByIds(any())).thenAnswer(
      (_) async => {
        '1': channel('1', ['SexualThemes']),
      },
    );
    settings.hiddenContentLabels = ['SexualThemes'];
    await settle();
    pending.complete({
      '3': channel('3', ['Gambling']),
    });
    await settle();

    expect(store.streams.map((s) => s.userId), ['2', '3']);
    store.dispose();
  });
}
