import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show Observable, runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/whisper_history.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';
import 'package:onset/stores/whisper_store.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

const _friend = WhisperPeer(id: '200', login: 'friend', displayName: 'Friend');

WhisperHistoryMessage _message(String id, String from, String text, int min) =>
    WhisperHistoryMessage(
      id: id,
      fromId: from,
      text: text,
      sentAt: DateTime(2026, 11, 8, 20, min),
    );

void main() {
  late Observable<String?> user;
  late List<String> threadCalls;
  late List<WhisperHistoryThread>? remoteThreads;
  late List<WhisperHistoryMessage>? remoteMessages;
  late WhisperStore store;

  setUp(() {
    user = Observable<String?>('100');
    threadCalls = [];
    remoteThreads = [
      WhisperHistoryThread(
        id: '100_200',
        peer: _friend,
        unread: 1,
        archived: false,
        muted: false,
        last: _message('m2', '200', 'See you', 5),
      ),
    ];
    remoteMessages = [
      _message('m1', '100', 'Ready?', 1),
      _message('m2', '200', 'See you', 5),
    ];
    store = WhisperStore(
      twitchApi: MockTwitchApi(),
      currentUserId: () => user.value,
      listen: (topic) => EventSubHandle.forTesting(
        topic,
        const Stream<EventSubTopicEvent>.empty(),
        () {},
      ),
      historyThreads: (me) async {
        threadCalls.add(me);
        return remoteThreads;
      },
      historyMessages: (threadId) async => remoteMessages,
    );
  });

  tearDown(() => store.dispose());

  test('brings Twitch’s conversations into the list', () async {
    await store.refreshHistory();

    expect(store.historyAvailable, isTrue);
    final thread = store.threads.single;
    expect(thread.displayName, 'Friend');
    expect(thread.whispers.single.text, 'See you');
    expect(thread.whispers.single.mine, isFalse);
    expect(thread.unread, 0);
    expect(store.remoteThreadId('200'), '100_200');
    expect(threadCalls, ['100']);
  });

  test('opening a conversation loads its earlier whispers once each',
      () async {
    await store.refreshHistory();
    await store.loadConversation('200');
    await store.loadConversation('200');

    final whispers = store.threads.single.whispers;
    expect(whispers.map((w) => w.id), ['m1', 'm2']);
    expect(whispers.first.mine, isTrue);
  });

  test('a failure keeps the session’s whispers and says so', () async {
    remoteThreads = null;

    await store.refreshHistory();

    expect(store.historyAvailable, isFalse);
    expect(store.threads, isEmpty);
  });

  test('a hidden conversation stays hidden until a newer whisper', () async {
    Future<void> at(int minute, Future<void> Function() body) =>
        withClock(Clock.fixed(DateTime(2026, 11, 8, 21, minute)), body);

    await at(0, store.refreshHistory);
    await at(0, () async => store.hide('200'));
    await at(1, store.refreshHistory);
    expect(store.threads, isEmpty);

    remoteThreads = [
      WhisperHistoryThread(
        id: '100_200',
        peer: _friend,
        unread: 0,
        archived: false,
        muted: false,
        last: WhisperHistoryMessage(
          id: 'm3',
          fromId: '200',
          text: 'Still there?',
          sentAt: DateTime(2026, 11, 8, 21, 30),
        ),
      ),
    ];
    await at(2, store.refreshHistory);
    expect(store.threads.single.whispers.single.text, 'Still there?');
  });

  test('asks Twitch again only after a pause', () async {
    await store.refreshHistory();
    await store.refreshHistory();

    expect(threadCalls, hasLength(1));
  });

  test('another account drops the history it fetched meanwhile', () async {
    final pending = Completer<List<WhisperHistoryThread>?>();
    final slow = WhisperStore(
      twitchApi: MockTwitchApi(),
      currentUserId: () => user.value,
      listen: (topic) => EventSubHandle.forTesting(
        topic,
        const Stream<EventSubTopicEvent>.empty(),
        () {},
      ),
      historyThreads: (me) => pending.future,
    );
    addTearDown(slow.dispose);

    final refreshing = slow.refreshHistory();
    runInAction(() => user.value = '300');
    pending.complete(remoteThreads);
    await refreshing;

    expect(slow.threads, isEmpty);
  });
}

