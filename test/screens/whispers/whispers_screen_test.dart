import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/whispers/whisper_conversation.dart';
import 'package:frosty/screens/whispers/whispers_screen.dart';
import 'package:frosty/services/realtime/twitch_eventsub_client.dart';
import 'package:frosty/stores/whisper_store.dart';
import 'package:mocktail/mocktail.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

void main() {
  late MockTwitchApi api;
  late StreamController<EventSubTopicEvent> events;
  late WhisperStore store;

  setUp(() => api = MockTwitchApi());

  /// Made in the test's zone, so events arrive on pump.
  void init() {
    events = StreamController<EventSubTopicEvent>.broadcast();
    store = WhisperStore(
      twitchApi: api,
      currentUserId: () => '7',
      listen: (topic) => EventSubHandle.forTesting(topic, events.stream, () {}),
    );
  }

  tearDown(() => store.dispose());

  void receive(String text, {String id = 'w1'}) => events.add(
    EventSubData({
      'from_user_id': '8',
      'from_user_login': 'friend',
      'from_user_name': 'Friend',
      'to_user_id': '7',
      'whisper_id': id,
      'whisper': {'text': text},
    }),
  );

  /// An event is handled in a microtask; the screen redraws a frame later.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  // Profile pictures need the network: tests look at the text only.
  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();
  }

  testWidgets('no whispers yet, and why some may not arrive', (tester) async {
    init();
    await pumpScreen(tester, WhispersScreen(store: store));
    expect(find.textContaining('No whispers yet'), findsOneWidget);

    events.add(const EventSubUnavailable('Forbidden', permanent: true));
    await settle(tester);
    expect(find.textContaining('Log out and log in again'), findsOneWidget);
  });

  testWidgets('a conversation shows its last whisper and unread count', (
    tester,
  ) async {
    init();
    await pumpScreen(tester, WhispersScreen(store: store));
    receive('first');
    receive('second', id: 'w2');
    await settle(tester);

    expect(find.text('Friend'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('opening a conversation reads it; sending adds a bubble', (
    tester,
  ) async {
    init();
    when(
      () => api.sendWhisper(fromUserId: '7', toUserId: '8', message: 'hello'),
    ).thenAnswer((_) async {});
    receive('hey');
    await tester.pump();
    expect(store.unreadCount, 1);

    await pumpScreen(
      tester,
      WhisperConversation(
        store: store,
        userId: '8',
        login: 'friend',
        displayName: 'Friend',
      ),
    );
    expect(store.unreadCount, 0);
    expect(find.text('hey'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pump();
    expect(find.text('hello'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('a refused whisper says why and keeps the text', (tester) async {
    init();
    when(
      () => api.sendWhisper(fromUserId: '7', toUserId: '8', message: 'hello'),
    ).thenThrow(const ApiException('Verify your phone number first.', 403));

    await pumpScreen(
      tester,
      WhisperConversation(
        store: store,
        userId: '8',
        login: 'friend',
        displayName: 'Friend',
      ),
    );
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text("Couldn't whisper: Verify your phone number first."),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'hello',
    );
  });

  testWidgets('leaving a conversation counts new whispers as unread', (
    tester,
  ) async {
    init();
    await pumpScreen(
      tester,
      WhisperConversation(
        store: store,
        userId: '8',
        login: 'friend',
        displayName: 'Friend',
      ),
    );
    await tester.pumpWidget(const SizedBox());
    receive('later');
    await tester.pump();
    expect(store.unreadCount, 1);
  });
}
