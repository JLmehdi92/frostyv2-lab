import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/screens/whispers/whispers_screen.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';
import 'package:onset/stores/whisper_store.dart';
import 'package:onset/widgets/share_sheet.dart';

import '../helpers/l10n.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

void main() {
  group('sendChatMessage', () {
    const helix = 'https://api.twitch.tv/helix';
    late DioAdapter adapter;
    late TwitchApi api;

    setUp(() {
      final dio = Dio(BaseOptions());
      adapter = DioAdapter(dio: dio);
      api = TwitchApi(dio);
    });

    test('posts the link to the channel chat as the viewer', () async {
      adapter.onPost(
        '$helix/chat/messages',
        (s) => s.reply(200, {
          'data': [
            {'message_id': 'm', 'is_sent': true},
          ],
        }),
        data: {
          'broadcaster_id': '42',
          'sender_id': '7',
          'message': 'https://clips.twitch.tv/Slug',
        },
      );
      await api.sendChatMessage(
        broadcasterId: '42',
        senderId: '7',
        message: 'https://clips.twitch.tv/Slug',
      );
    });

    test('a dropped message throws with Twitch’s reason', () async {
      adapter.onPost(
        '$helix/chat/messages',
        (s) => s.reply(200, {
          'data': [
            {
              'message_id': '',
              'is_sent': false,
              'drop_reason': {
                'code': 'followers_only',
                'message': 'Followers only',
              },
            },
          ],
        }),
        data: Matchers.any,
      );
      await expectLater(
        api.sendChatMessage(broadcasterId: '42', senderId: '7', message: 'x'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.twitchMessage,
            'twitchMessage',
            'Followers only',
          ),
        ),
      );
    });
  });

  Future<void> open(WidgetTester tester, Widget sheet) async {
    await pumpLocalized(
      tester,
      locale: en,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => sheet,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('send in chat posts the link and says so', (tester) async {
    final sent = <(String, String, String)>[];
    await open(
      tester,
      ShareSheet(
        url: 'https://www.twitch.tv/videos/1',
        viewerId: '7',
        channelId: '42',
        channelName: 'Streamer',
        sendToChat:
            ({
              required broadcasterId,
              required senderId,
              required message,
            }) async => sent.add((broadcasterId, senderId, message)),
        onShare: () async {},
        pickWhisperTarget: (_) async => null,
      ),
    );
    await tester.tap(find.text('Send in Streamer’s chat'));
    await tester.pumpAndSettle();
    expect(sent, [('42', '7', 'https://www.twitch.tv/videos/1')]);
    expect(find.text('Link sent in Streamer’s chat.'), findsOneWidget);
  });

  testWidgets('a login without the chat permission asks to log in again', (
    tester,
  ) async {
    await open(
      tester,
      ShareSheet(
        url: 'u',
        viewerId: '7',
        channelId: '42',
        channelName: 'Streamer',
        sendToChat:
            ({
              required broadcasterId,
              required senderId,
              required message,
            }) async => throw const UnauthorizedException('Missing scope'),
        onShare: () async {},
        pickWhisperTarget: (_) async => null,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('share-chat')));
    await tester.pumpAndSettle();
    expect(
      find.text('Log in again to send links in chat from here.'),
      findsOneWidget,
    );
  });

  testWidgets('send as a whisper picks someone and whispers the link', (
    tester,
  ) async {
    final api = MockTwitchApi();
    when(
      () => api.sendWhisper(
        fromUserId: '7',
        toUserId: '9',
        message: 'https://www.twitch.tv/streamer',
      ),
    ).thenAnswer((_) async {});
    final events = StreamController<EventSubTopicEvent>.broadcast();
    final store = WhisperStore(
      twitchApi: api,
      currentUserId: () => '7',
      listen: (topic) => EventSubHandle.forTesting(topic, events.stream, () {}),
    );
    addTearDown(store.dispose);
    var shared = false;
    await open(
      tester,
      ShareSheet(
        url: 'https://www.twitch.tv/streamer',
        viewerId: '7',
        sendToChat:
            ({
              required broadcasterId,
              required senderId,
              required message,
            }) async {},
        whisperStore: store,
        onShare: () async => shared = true,
        pickWhisperTarget: (_) async => const WhisperTarget(
          userId: '9',
          login: 'buddy',
          displayName: 'Buddy',
        ),
      ),
    );
    expect(find.byKey(const ValueKey('share-chat')), findsNothing);
    await tester.tap(find.text('Send as a whisper'));
    await tester.pumpAndSettle();
    expect(find.text('Link whispered to Buddy.'), findsOneWidget);
    expect(
      store.threads.single.whispers.single.text,
      'https://www.twitch.tv/streamer',
    );
    expect(shared, isFalse);
  });
}
