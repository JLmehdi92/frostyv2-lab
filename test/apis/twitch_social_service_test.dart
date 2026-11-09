import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_social_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/onsite_notification.dart';
import 'package:onset/models/recommended_channel.dart';

import '../fixtures/social_payloads.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late List<RequestOptions> requests;
  late TwitchSocialService service;

  setUp(() {
    dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    requests = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.next(options);
        },
      ),
    );
    service = TwitchSocialService(dio);
  });

  void reply(Object? body, {int status = 200}) => adapter.onPost(
    _gql,
    (server) => server.reply(status, body),
    data: Matchers.any,
  );

  Map<String, dynamic> sent() {
    final data = requests.single.data;
    return Map<String, dynamic>.from(
      data is String ? jsonDecode(data) as Map : data as Map,
    );
  }

  group('whispers', () {
    test('reads the threads with the viewer token', () async {
      reply(whisperThreadsResponse());

      final threads = await service.whisperThreads(me: '100', authToken: 'tok');

      expect(threads, hasLength(1));
      final thread = threads!.single;
      expect(thread.id, '100_200');
      expect(thread.peer.login, 'friend');
      expect(thread.peer.displayName, 'Friend');
      expect(thread.last?.text, 'See you tonight');
      expect(thread.unread, 2);
      expect(sent()['operationName'], 'UserWhisperThreadsQuery');
      expect(requests.single.headers['Authorization'], 'OAuth tok');
    });

    test('reads a thread oldest first', () async {
      reply(whisperMessagesResponse());

      final messages = await service.whisperMessages(
        threadId: '100_200',
        authToken: 'tok',
      );

      expect(messages!.map((m) => m.id), ['m1', 'm2']);
      expect(sent()['variables'], {'thread': '100_200', 'numMessages': 50});
    });

    test('sends nothing for a malformed thread id', () async {
      expect(
        await service.whisperMessages(threadId: '1_2"', authToken: 'tok'),
        isNull,
      );
      expect(requests, isEmpty);
    });

    test('hides history without a web token', () async {
      expect(await service.whisperThreads(me: '100', authToken: ''), isNull);
      expect(requests, isEmpty);
    });

    test('a changed response hides history', () async {
      reply({
        'data': {'currentUser': null},
      });
      expect(await service.whisperThreads(me: '100', authToken: 'tok'), isNull);
    });

    test('reads the privacy settings', () async {
      reply(whisperPrivacyResponse(block: true));

      final privacy = await service.whisperPrivacy(authToken: 'tok');

      expect(privacy?.blockStrangers, isTrue);
    });

    test('blocking strangers is done only when Twitch echoes it', () async {
      reply({
        'data': {
          'updateWhisperSettings': {
            'user': {
              'login': 'me',
              'whisperSettings': {
                'isWhisperBanned': false,
                'isBlockingWhispersFromStrangers': true,
              },
            },
          },
        },
      });

      expect(
        await service.setBlockStrangers(block: true, authToken: 'tok'),
        ViewerActionOutcome.done,
      );
      expect(sent()['variables'], {
        'input': {'isBlockingWhispersFromStrangers': true},
      });
    });

    test('a stale echo is a failure', () async {
      reply({
        'data': {
          'updateWhisperSettings': {
            'user': {
              'whisperSettings': {'isBlockingWhispersFromStrangers': false},
            },
          },
        },
      });

      expect(
        await service.setBlockStrangers(block: true, authToken: 'tok'),
        ViewerActionOutcome.failed,
      );
    });

    test('removes one conversation’s reply allowance', () async {
      reply({
        'data': {
          'updateWhisperThread': {
            'thread': {'id': '100_200'},
          },
        },
      });

      expect(
        await service.removeWhisperAllowance(
          threadId: '100_200',
          authToken: 'tok',
        ),
        ViewerActionOutcome.done,
      );
      expect(sent()['variables'], {'threadID': '100_200'});
    });

    test('an integrity refusal is reported as such', () async {
      reply({
        'errors': [
          {'message': 'failed integrity check'},
        ],
      });

      expect(
        await service.removeWhisperAllowance(
          threadId: '100_200',
          authToken: 'tok',
        ),
        ViewerActionOutcome.integrityRefused,
      );
    });
  });

  group('notifications', () {
    test('reads a page and strips markup', () async {
      reply(onsiteNotificationsResponse([onsiteNotificationNode()]));

      final page = await service.notifications(
        userId: '100',
        authToken: 'tok',
        language: 'fr-FR',
      );

      final n = page!.notifications.single;
      expect(n.body, 'Friend is live: Morning run');
      expect(n.channelLogin, 'friend');
      expect(n.link?.host, 'www.twitch.tv');
      expect(n.isRead, isFalse);
      expect(page.cursor, isNull);
      expect(sent()['variables'], {
        'user': '100',
        'limit': 30,
        'language': 'fr',
      });
    });

    test('ignores links outside twitch.tv', () async {
      final node = onsiteNotificationNode()
        ..['actions'] = [
          {'url': 'https://evil.example/x'},
        ]
        ..['extra'] = {'__typename': 'Clip', 'slug': 'x'};
      reply(onsiteNotificationsResponse([node]));

      final page = await service.notifications(
        userId: '100',
        authToken: 'tok',
        language: 'en',
      );

      expect(page!.notifications.single.link, isNull);
      expect(page.notifications.single.channelLogin, isNull);
    });

    test('reads the unseen count', () async {
      reply({
        'data': {
          'user': {
            'notifications': {
              'summary': {'lastSeenAt': null, 'unseenCount': 4},
            },
          },
        },
      });

      expect(
        await service.unseenNotifications(userId: '100', authToken: 'tok'),
        4,
      );
    });

    test('marks notifications read by id', () async {
      reply({
        'data': {
          'readNotifications': {'count': 2},
        },
      });

      expect(
        await service.markNotificationsRead(
          ids: ['n1', 'n2'],
          authToken: 'tok',
        ),
        ViewerActionOutcome.done,
      );
      expect(sent()['variables'], {
        'input': {
          'ids': ['n1', 'n2'],
        },
      });
    });

    test('reads push and email per category', () async {
      reply(notificationSettingsResponse());

      final settings = await service.notificationSettings(
        userId: '100',
        authToken: 'tok',
      );

      expect(settings, hasLength(2));
      expect(settings!.first.category, 'live');
      expect(settings.first.platforms, {
        NotificationPlatform.push: true,
        NotificationPlatform.email: false,
      });
    });

    test('only exact platform names count', () async {
      reply({
        'data': {
          'user': {
            'notificationSettings': [
              {
                'category': 'live',
                'platforms': [
                  {'platformName': 'push', 'isEnabled': true},
                  {'platformName': 'email_digest_push', 'isEnabled': false},
                  {'platformName': 'mobile_onsite', 'isEnabled': false},
                ],
              },
            ],
          },
        },
      });

      final settings = await service.notificationSettings(
        userId: '100',
        authToken: 'tok',
      );

      expect(settings!.single.platforms, {NotificationPlatform.push: true});
    });

    test('an error hides the settings', () async {
      reply({
        'errors': [
          {'message': 'service error'},
        ],
      });
      expect(
        await service.notificationSettings(userId: '100', authToken: 'tok'),
        isNull,
      );
    });
  });

  group('recommendations', () {
    test('reads channels anonymously, without the context channel', () async {
      reply(personalSectionsResponse());

      final channels = await service.recommendations(
        section: RecommendationSection.similar,
        channelLogin: 'Alpha_Live',
      );

      expect(channels!.map((c) => c.login), ['beta']);
      expect(channels.single.viewers, 1200);
      expect(channels.single.category, 'Chess');
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
      expect(sent()['variables'], {
        'input': {
          'sectionInputs': ['SIMILAR_SECTION'],
          'contextChannelName': 'alpha_live',
        },
      });
    });

    test('a server error hides the shelf', () async {
      reply({
        'errors': [
          {'message': 'server error'},
        ],
        'data': {'personalSections': null},
      });

      expect(
        await service.recommendations(
          section: RecommendationSection.recommended,
        ),
        isNull,
      );
    });

    test('sends not interested with its reason', () async {
      reply({
        'data': {
          'addRecommendationFeedback': {
            'recommendationFeedback': {'id': 'f1'},
          },
        },
      });

      expect(
        await service.notInterested(
          channelId: '1002',
          reason: NotInterestedReason.offensive,
          authToken: 'tok',
        ),
        ViewerActionOutcome.done,
      );
      expect(sent()['variables'], {
        'input': {
          'category': 'OFFENSIVE',
          'itemID': '1002',
          'itemType': 'CHANNEL',
          'sourceItemPage': '',
          'sourceItemRequestID': '',
          'sourceItemTrackingID': '',
        },
      });
    });

    test('not interested without a token asks to log in', () async {
      expect(
        await service.notInterested(
          channelId: '1002',
          reason: NotInterestedReason.other,
          authToken: '',
        ),
        ViewerActionOutcome.signedOut,
      );
      expect(requests, isEmpty);
    });
  });
}
