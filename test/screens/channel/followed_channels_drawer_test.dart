import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' hide when;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/followed_channel.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/channel/followed_channels_drawer.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:provider/provider.dart';

import '../../helpers/l10n.dart';

class MockListStore extends Mock implements ListStore {}

class MockTwitchApi extends Mock implements TwitchApi {}

MockListStore fakeFollowedStore({
  List<StreamTwitch> live = const [],
  List<FollowedChannel> offline = const [],
  bool loading = false,
  Object? error,
}) {
  final store = MockListStore();
  when(() => store.allPinnedChannels).thenReturn(const []);
  when(() => store.streams).thenReturn(ObservableList.of(live));
  when(() => store.offlineChannels).thenReturn(ObservableList.of(offline));
  when(() => store.isLoading).thenReturn(loading);
  when(() => store.error).thenReturn(error);
  when(() => store.hasMore).thenReturn(false);
  when(() => store.hasMoreOfflineChannels).thenReturn(false);
  return store;
}

Widget drawerHost(ListStore store, {String current = 'c1'}) {
  final api = MockTwitchApi();
  when(
    () => api.getUser(userLogin: any(named: 'userLogin')),
  ).thenThrow(Exception('offline'));
  return Provider<TwitchApi>.value(
    value: api,
    child: Scaffold(
      drawer: FollowedChannelsDrawer(currentLogin: current, store: store),
      body: Builder(
        builder: (context) => TextButton(
          key: const ValueKey('open-drawer'),
          onPressed: Scaffold.of(context).openDrawer,
          child: const SizedBox(width: 40, height: 40),
        ),
      ),
    ),
  );
}

StreamTwitch _stream(String id) =>
    StreamTwitch(id, 'c$id', 'C$id', '1', 'Game', 'Title', 10, '', '');

FollowedChannel _channel(String id, String name) => FollowedChannel(
  broadcasterId: id,
  broadcasterLogin: name.toLowerCase(),
  broadcasterName: name,
  followedAt: DateTime.utc(2025),
);

void main() {
  test('live: pinned first, each channel once, in the list order', () {
    final sections = followedDrawerSections(
      pinned: [_stream('2')],
      streams: [_stream('1'), _stream('2'), _stream('3')],
      offline: const [],
    );
    expect(sections.live.map((s) => s.userId), ['2', '1', '3']);
  });

  test('offline: sorted by name, never a channel that is live', () {
    final sections = followedDrawerSections(
      pinned: const [],
      streams: [_stream('1')],
      offline: [
        _channel('9', 'zeta'),
        _channel('1', 'Live'),
        _channel('8', 'Alpha'),
        _channel('7', 'beta'),
      ],
    );
    expect(sections.offline.map((c) => c.broadcasterName), [
      'Alpha',
      'beta',
      'zeta',
    ]);
  });

  testWidgets('live and offline sections', (tester) async {
    final store = fakeFollowedStore(
      live: [_stream('1'), _stream('2')],
      offline: [_channel('8', 'Alpha')],
    );
    await pumpLocalized(tester, drawerHost(store), locale: const Locale('en'));
    await tester.tap(find.byKey(const ValueKey('open-drawer')));
    await tester.pumpAndSettle();

    expect(find.text('Followed channels'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('C1'), findsOneWidget);
    expect(find.text('C2'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    verify(() => store.isOfflineChannelsExpanded = true).called(1);
  });

  testWidgets('says when the list cannot be had', (tester) async {
    final store = fakeFollowedStore(error: Exception('x'));
    await pumpLocalized(tester, drawerHost(store), locale: const Locale('en'));
    await tester.tap(find.byKey(const ValueKey('open-drawer')));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load your followed channels.'), findsOneWidget);
  });
}
