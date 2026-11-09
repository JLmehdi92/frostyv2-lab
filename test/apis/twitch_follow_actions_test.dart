import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_channel_profile_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/follow_result.dart';

import '../fixtures/follow_payloads.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late List<RequestOptions> requests;
  late TwitchViewerActionsService service;

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
    service = TwitchViewerActionsService(dio);
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

  group('followChannel', () {
    test(
      'sends the follow with the viewer token and notifications on',
      () async {
        reply(followUserResponse());

        expect(
          await service.followChannel(channelId: '1000', authToken: 'tok'),
          FollowResult.done,
        );
        final body = sent();
        expect(body['operationName'], 'FollowUserMutation');
        expect(body['variables'], {
          'targetId': '1000',
          'disableNotifications': false,
        });
        expect(requests.single.headers['Authorization'], 'OAuth tok');
        expect(
          requests.single.headers['Client-ID'],
          'kimne78kx3ncx6brgo4mv6wki5h1ko',
        );
      },
    );

    for (final (code, result) in [
      ('TOO_MANY_FOLLOWS', FollowResult.tooManyFollows),
      ('UNVERIFIED_EMAIL', FollowResult.unverifiedEmail),
      ('UNVERIFIED_PHONE', FollowResult.unverifiedPhone),
      ('UNVERIFIED_PHONE_AND_EMAIL', FollowResult.unverifiedPhoneAndEmail),
      ('FORBIDDEN', FollowResult.forbidden),
      ('SOMETHING_NEW', FollowResult.refused),
    ]) {
      test('reads the $code refusal', () async {
        reply(followUserResponse(errorCode: code));
        expect(
          await service.followChannel(channelId: '1000', authToken: 'tok'),
          result,
        );
      });
    }

    test('an integrity refusal sends the viewer to twitch.tv', () async {
      reply(integrityRefusedResponse);
      final result = await service.followChannel(
        channelId: '1000',
        authToken: 'tok',
      );
      expect(result, FollowResult.integrityRefused);
      expect(result.opensTwitch, isTrue);
    });

    test('a signed-out viewer sends nothing', () async {
      expect(
        await service.followChannel(channelId: '1000', authToken: ''),
        FollowResult.signedOut,
      );
      expect(requests, isEmpty);
    });

    test('a channel id that is not numeric sends nothing', () async {
      expect(
        await service.followChannel(channelId: '1 or 1', authToken: 'tok'),
        FollowResult.failed,
      );
      expect(requests, isEmpty);
    });

    test('a server error or an unreadable body fails', () async {
      reply({'data': null});
      expect(
        await service.followChannel(channelId: '1000', authToken: 'tok'),
        FollowResult.failed,
      );
    });
  });

  test('unfollowChannel sends the unfollow', () async {
    reply(unfollowUserResponse);
    expect(
      await service.unfollowChannel(channelId: '1000', authToken: 'tok'),
      FollowResult.done,
    );
    expect(sent()['operationName'], 'UnfollowUserMutation');
    expect(sent()['variables'], {'targetId': '1000'});
  });

  test('followCategory and unfollowCategory send the game id', () async {
    reply(followGameResponse('followGame'));
    expect(
      await service.followCategory(categoryId: '509658', authToken: 'tok'),
      FollowResult.done,
    );
    expect(sent()['operationName'], 'FollowGameMutation');
    expect(sent()['variables'], {'gameID': '509658'});

    requests.clear();
    adapter.reset();
    reply(followGameResponse('unfollowGame'));
    expect(
      await service.unfollowCategory(categoryId: '509658', authToken: 'tok'),
      FollowResult.done,
    );
    expect(sent()['operationName'], 'UnfollowGameMutation');
  });

  group('gift settings', () {
    test('reads both switches', () async {
      reply(giftSettingsResponse(followedOnly: true));
      expect(
        await service.giftSettings(authToken: 'tok'),
        const GiftSettings(followedChannelsOnly: true, countHidden: false),
      );
      expect(sent()['operationName'], 'UserGiftedSubSettingsQuery');
    });

    test('an unreadable answer hides the settings', () async {
      reply({
        'data': {'currentUser': null},
      });
      expect(await service.giftSettings(authToken: 'tok'), isNull);
    });

    test('signed out asks nothing', () async {
      expect(await service.giftSettings(authToken: ''), isNull);
      expect(requests, isEmpty);
    });

    test('a change is done only when Twitch answers the new values', () async {
      const wanted = GiftSettings(
        followedChannelsOnly: false,
        countHidden: true,
      );
      reply(updateGiftSettingsResponse(hidden: true));
      expect(
        await service.updateGiftSettings(settings: wanted, authToken: 'tok'),
        ViewerActionOutcome.done,
      );
      expect((sent()['variables'] as Map)['input'], {
        'giftsToFollowedChannelsOnly': false,
        'isGiftCountHidden': true,
      });

      requests.clear();
      adapter.reset();
      reply(updateGiftSettingsResponse());
      expect(
        await service.updateGiftSettings(settings: wanted, authToken: 'tok'),
        ViewerActionOutcome.failed,
      );
    });
  });

  group('channel restriction', () {
    late TwitchChannelProfileService profiles;

    setUp(() => profiles = TwitchChannelProfileService(dio));

    test(
      'the live shape of a channel in good standing is not restricted',
      () async {
        reply(channelRestrictionLiveResponse);
        expect(await profiles.isRestricted('1000'), isFalse);
        expect(sent()['operationName'], 'ChannelProfileRestriction');
        expect(sent()['variables'], {'channelID': '1000'});
        expect(requests.single.headers.containsKey('Authorization'), isFalse);
      },
    );

    test('a restricted status shows the banner', () async {
      reply(channelRestrictionResponse(['RESTRICTED']));
      expect(await profiles.isRestricted('1000'), isTrue);
    });

    test('an unknown status or a failure hides it', () async {
      reply(channelRestrictionResponse(['SOMETHING_ELSE']));
      expect(await profiles.isRestricted('1000'), isFalse);
      adapter.reset();
      reply(null, status: 500);
      expect(await profiles.isRestricted('1000'), isFalse);
    });

    test('a channel id that is not numeric asks nothing', () async {
      expect(await profiles.isRestricted('abc'), isFalse);
      expect(requests, isEmpty);
    });
  });
}
