import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/screens/whispers/whisper_actions.dart';
import 'package:onset/screens/whispers/whispers_screen.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';
import 'package:onset/stores/whisper_store.dart';

import '../../helpers/l10n.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

ChannelQuery _channel(String id, String name) => ChannelQuery(
  broadcasterLogin: name.toLowerCase(),
  displayName: name,
  id: id,
  isLive: false,
  startedAt: '',
);

void main() {
  late StreamController<EventSubTopicEvent> events;
  late WhisperStore store;

  void init() {
    events = StreamController<EventSubTopicEvent>.broadcast();
    store = WhisperStore(
      twitchApi: MockTwitchApi(),
      currentUserId: () => '7',
      listen: (topic) => EventSubHandle.forTesting(topic, events.stream, () {}),
    );
    addTearDown(store.dispose);
  }

  void receive(String id, {String from = '8', String name = 'Friend'}) =>
      events.add(
        EventSubData({
          'from_user_id': from,
          'from_user_login': name.toLowerCase(),
          'from_user_name': name,
          'to_user_id': '7',
          'whisper_id': id,
          'whisper': {'text': 'hello $id'},
        }),
      );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'the new whisper sheet searches and picks someone, never the viewer',
    (tester) async {
      final queries = <String>[];
      WhisperTarget? picked;
      await pumpLocalized(
        tester,
        locale: en,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await Navigator.of(context).push<WhisperTarget>(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    body: NewWhisperSheet(
                      me: '7',
                      search: ({required query}) async {
                        queries.add(query);
                        return [_channel('7', 'Me'), _channel('9', 'Buddy')];
                      },
                    ),
                  ),
                ),
              );
            },
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'bud');
      await tester.pump(NewWhisperSheet.debounce);
      await settle(tester);

      expect(queries, ['bud']);
      expect(find.text('Me'), findsNothing);
      await tester.tap(find.text('Buddy'));
      await settle(tester);
      expect(picked?.userId, '9');
    },
  );

  testWidgets(
    'the new whisper sheet says when nothing matches or the search fails',
    (tester) async {
      var fail = false;
      await pumpLocalized(
        tester,
        locale: en,
        Scaffold(
          body: NewWhisperSheet(
            search: ({required query}) async {
              if (fail) throw Exception('offline');
              return [];
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(NewWhisperSheet.debounce);
      await settle(tester);
      expect(find.text('No one matches “zzz”.'), findsOneWidget);

      fail = true;
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump(NewWhisperSheet.debounce);
      await settle(tester);
      expect(
        find.text('Couldn’t search. Check your connection and try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a long press mutes, archives and hides a conversation after confirming',
    (tester) async {
      init();
      await pumpLocalized(tester, locale: en, WhispersScreen(store: store));
      receive('w1');
      receive('w2', from: '9', name: 'Other');
      await settle(tester);

      await tester.longPress(find.text('Friend'));
      await settle(tester);
      await tester.tap(find.text('Mute notifications'));
      await settle(tester);
      expect(store.isMuted('8'), isTrue);
      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);

      await tester.longPress(find.text('Other'));
      await settle(tester);
      await tester.tap(find.text('Archive'));
      await settle(tester);
      expect(find.text('Other'), findsNothing);
      await tester.tap(find.text('Archived conversation (1)'));
      await settle(tester);
      expect(find.text('Other'), findsOneWidget);

      await tester.longPress(find.text('Friend'));
      await settle(tester);
      await tester.tap(find.text('Hide conversation'));
      await settle(tester);
      expect(find.text('Hide this conversation?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(store.threads.single.userId, '8');

      await tester.longPress(find.text('Friend'));
      await settle(tester);
      await tester.tap(find.text('Hide conversation'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('whisper-hide-confirm')));
      await settle(tester);
      expect(store.threads, isEmpty);
      expect(find.text('Friend'), findsNothing);
    },
  );

  testWidgets('the conversation menu hides the conversation and goes back', (
    tester,
  ) async {
    init();
    receive('w1');
    await tester.pump();
    await pumpLocalized(
      tester,
      locale: en,
      WhispersScreen(
        store: store,
        initial: const WhisperTarget(
          userId: '8',
          login: 'friend',
          displayName: 'Friend',
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('whisper-more')));
    await settle(tester);
    await tester.tap(find.text('Hide conversation'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('whisper-hide-confirm')));
    await settle(tester);
    expect(store.threads, isEmpty);
    expect(find.byKey(const ValueKey('whisper-more')), findsNothing);
  });
}
