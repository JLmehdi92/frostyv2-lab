import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/models/vod_comment.dart';
import 'package:frosty/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/stores/vod_chat_replay_store.dart';
import 'package:mocktail/mocktail.dart';

class MockTwitchVodService extends Mock implements TwitchVodService {}

class MockChatAssetsStore extends Mock implements ChatAssetsStore {}

Vod _vod({
  int length = 3600,
  VodType type = VodType.archive,
  bool recording = false,
}) => Vod(
  id: '1000000001',
  title: 'Stream',
  lengthSeconds: length,
  createdAt: DateTime.utc(2026, 10, 12, 17),
  viewCount: 1,
  ownerId: '42',
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
  type: type,
  isRecording: recording,
);

VodComment _c(String id, int second, {String user = 'viewer'}) => VodComment(
  id: id,
  offsetSeconds: second,
  fragments: [VodFragment(text: 'msg $id')],
  badges: const [],
  commenterId: '1',
  commenterLogin: user,
  commenterDisplayName: user,
);

/// One comment per second from [from] to [to] (inclusive), ids `s<second>`.
VodCommentPage _span(int from, int to, {bool hasNext = true}) => VodCommentPage(
  comments: [for (var s = from; s <= to; s++) _c('s$s', s)],
  hasNextPage: hasNext,
);

void main() {
  late MockTwitchVodService service;
  late MockChatAssetsStore assets;
  late SettingsStore settings;
  late VodChatReplayStore store;
  VodChatReplayStore? created;

  /// Offsets requested from the service, in order.
  late List<int> requests;

  /// Pages served per requested offset; a missing offset gets an empty
  /// last page.
  late Map<int, Object> pages;

  /// When set, every request waits for it.
  Completer<void>? gate;

  Future<void> settle([int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  VodChatReplayStore build({
    Vod? vod,
    List<String> blocked = const [],
    List<Duration> backoff = const [Duration.zero, Duration.zero],
  }) {
    final s = VodChatReplayStore(
      vod: vod ?? _vod(),
      vodService: service,
      assetsStore: assets,
      settings: settings,
      headers: const {},
      blockedLogins: () => blocked,
      backoff: backoff,
    );
    created = s;
    return s;
  }

  List<String?> ids() => store.messages.map((m) => m.tags['id']).toList();

  setUpAll(() {
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    service = MockTwitchVodService();
    assets = MockChatAssetsStore();
    settings = SettingsStore.fromJson({});
    requests = [];
    pages = {};
    gate = null;
    when(() => assets.init()).thenAnswer((_) async {});
    when(() => assets.dispose()).thenReturn(null);
    when(
      () => assets.assetsFuture(
        channelId: any(named: 'channelId'),
        headers: any(named: 'headers'),
        onEmoteError: any(named: 'onEmoteError'),
        onBadgeError: any(named: 'onBadgeError'),
        showTwitchEmotes: any(named: 'showTwitchEmotes'),
        showTwitchBadges: any(named: 'showTwitchBadges'),
        show7TVEmotes: any(named: 'show7TVEmotes'),
        showBTTVEmotes: any(named: 'showBTTVEmotes'),
        showBTTVBadges: any(named: 'showBTTVBadges'),
        showFFZEmotes: any(named: 'showFFZEmotes'),
        showFFZBadges: any(named: 'showFFZBadges'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => service.getComments(
        vodId: any(named: 'vodId'),
        offsetSeconds: any(named: 'offsetSeconds'),
      ),
    ).thenAnswer((inv) async {
      final offset = inv.namedArguments[#offsetSeconds] as int;
      requests.add(offset);
      await gate?.future;
      final page = pages[offset];
      if (page is VodCommentPage) return page;
      if (page != null) throw page;
      return const VodCommentPage(comments: [], hasNextPage: false);
    });
  });

  tearDown(() {
    created?.dispose();
    created = null;
  });

  test('loads the channel assets for the vod owner', () async {
    store = build();
    await settle();

    verify(() => assets.init()).called(1);
    verify(
      () => assets.assetsFuture(
        channelId: '42',
        headers: any(named: 'headers'),
        onEmoteError: any(named: 'onEmoteError'),
        onBadgeError: any(named: 'onBadgeError'),
        showTwitchEmotes: any(named: 'showTwitchEmotes'),
        showTwitchBadges: any(named: 'showTwitchBadges'),
        show7TVEmotes: any(named: 'show7TVEmotes'),
        showBTTVEmotes: any(named: 'showBTTVEmotes'),
        showBTTVBadges: any(named: 'showBTTVBadges'),
        showFFZEmotes: any(named: 'showFFZEmotes'),
        showFFZBadges: any(named: 'showFFZBadges'),
      ),
    ).called(1);
  });

  test(
    'the first tick fetches at its second and shows what came before',
    () async {
      pages[0] = _span(0, 20);
      store = build();

      store.onPositionSecond(0);
      expect(store.status, ReplayStatus.loading);
      await settle();

      expect(requests, [0]);
      expect(store.status, ReplayStatus.active);
      expect(ids(), ['s0']);
    },
  );

  test('forward ticks append only the new seconds, in order', () async {
    pages[0] = _span(0, 40);
    store = build();
    store.onPositionSecond(0);
    await settle();

    for (var s = 1; s <= 10; s++) {
      store.onPositionSecond(s);
    }

    expect(ids(), [for (var s = 0; s <= 10; s++) 's$s']);
  });

  test('no second request while one is in flight', () async {
    gate = Completer<void>();
    store = build();

    store.onPositionSecond(0);
    store.onPositionSecond(1);
    store.onPositionSecond(2);
    await settle();

    expect(requests, [0]);
    gate!.complete();
  });

  test('prefetches before the covered range ends', () async {
    pages[0] = _span(0, 30);
    pages[30] = _span(30, 60);
    store = build();
    store.onPositionSecond(0);
    await settle();
    expect(requests, [0], reason: 'covered up to 29, 29 s ahead');

    store.onPositionSecond(1);
    store.onPositionSecond(14);
    await settle();
    expect(requests, [0], reason: 'still more than 15 s ahead');

    store.onPositionSecond(15);
    await settle();
    expect(requests, [0, 30]);
  });

  test('the prefetch lead scales with the playback rate', () async {
    pages[0] = _span(0, 30);
    store = build();
    store.playbackRate = 2;
    store.onPositionSecond(0);
    await settle();

    expect(requests, [0, 30], reason: '30 s lead at 2x');
  });

  test(
    'a seek into an uncovered range clears, loads, then shows lastN',
    () async {
      pages[0] = _span(0, 30);
      pages[1000] = VodCommentPage(
        comments: [for (var s = 940; s <= 1010; s++) _c('s$s', s)],
        hasNextPage: true,
      );
      store = build();
      store.onPositionSecond(0);
      await settle();

      store.onPositionSecond(1000);
      expect(store.messages, isEmpty);
      expect(store.status, ReplayStatus.loading);
      await settle();

      expect(requests, contains(1000));
      expect(store.status, ReplayStatus.active);
      expect(ids(), hasLength(50));
      expect(ids().last, 's1000');
    },
  );

  test('a seek back into a covered range is served from the cache', () async {
    pages[0] = _span(0, 100);
    store = build();
    store.onPositionSecond(0);
    await settle();
    store.onPositionSecond(80);
    await settle();
    final before = requests.length;

    store.onPositionSecond(10);

    expect(requests, hasLength(before));
    expect(ids().last, 's10');
    expect(ids(), hasLength(11));
  });

  test('a late page backfills up to the current second', () async {
    gate = Completer<void>();
    pages[0] = _span(0, 30);
    store = build();

    store.onPositionSecond(0);
    store.onPositionSecond(1);
    store.onPositionSecond(2);
    gate!.complete();
    await settle();

    expect(ids(), ['s0', 's1', 's2']);
  });

  test('a stale page after a newer seek changes nothing on screen', () async {
    final slow = Completer<void>();
    pages[0] = _span(0, 30);
    pages[2000] = _span(2000, 2030);
    gate = slow;
    store = build();
    store.onPositionSecond(0);
    await settle();

    gate = null;
    store.onPositionSecond(2000);
    await settle();
    final shown = ids();
    slow.complete();
    await settle();

    expect(ids(), shown);
    expect(ids().last, 's2000');
  });

  test('an integrity error makes replay unavailable for good', () async {
    pages[0] = const VodApiException('integrity', isIntegrity: true);
    store = build();

    store.onPositionSecond(0);
    await settle();
    store.onPositionSecond(500);
    store.retry();
    await settle();

    expect(store.status, ReplayStatus.unavailable);
    expect(requests, [0]);
  });

  test(
    'three failures in a row make replay unavailable; retry resets',
    () async {
      pages[0] = const ApiException('boom');
      store = build();

      store.onPositionSecond(0);
      await settle(20);
      expect(requests, [0, 0, 0]);
      expect(store.status, ReplayStatus.unavailable);

      pages[0] = _span(0, 10, hasNext: false);
      store.retry();
      await settle();

      expect(store.status, ReplayStatus.active);
      expect(ids(), ['s0']);
    },
  );

  test('an upload has no chat replay and never calls the network', () async {
    store = build(vod: _vod(type: VodType.upload));

    store.onPositionSecond(0);
    await settle();

    expect(store.status, ReplayStatus.notApplicable);
    expect(requests, isEmpty);
    verifyNever(() => assets.init());
  });

  test('never asks for an offset at or past the end of the video', () async {
    pages[0] = _span(0, 50);
    pages[50] = _span(50, 59);
    store = build(vod: _vod(length: 60));

    for (final second in [0, 35, 45, 55, 58]) {
      store.onPositionSecond(second);
      await settle();
    }

    expect(requests, [0, 50, 59]);
  });

  test('keeps at most 300 messages', () async {
    pages[0] = VodCommentPage(
      comments: [for (var i = 0; i < 400; i++) _c('m$i', 1 + i ~/ 100)],
      hasNextPage: false,
    );
    store = build();
    store.onPositionSecond(0);
    await settle();

    for (var s = 1; s <= 4; s++) {
      store.onPositionSecond(s);
    }

    expect(store.messages.length, lessThanOrEqualTo(300));
    expect(ids().last, 'm399');
  });

  test('messages from blocked users are hidden', () async {
    pages[0] = VodCommentPage(
      comments: [
        _c('a', 0),
        _c('b', 0, user: 'troll'),
        _c('c', 0),
      ],
      hasNextPage: false,
    );
    store = build(blocked: ['troll']);

    store.onPositionSecond(0);
    await settle();

    expect(ids(), ['a', 'c']);
  });

  test('dispose stops retries and releases the assets store', () async {
    pages[0] = const ApiException('boom');
    store = build(
      backoff: const [Duration(milliseconds: 30), Duration(milliseconds: 30)],
    );
    store.onPositionSecond(0);
    await settle();

    store.dispose();
    created = null;
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(requests, [0]);
    verify(() => assets.dispose()).called(1);
  });
}
