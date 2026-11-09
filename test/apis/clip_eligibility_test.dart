import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/channel_profile.dart';

import '../fixtures/clip_eligibility_payloads.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  group('ClipEligibilityRefusal.fromGql', () {
    test('reads each Twitch code', () {
      final codes = {
        'CAN_CREATE_CLIP_NOT_SUBSCRIBED': ClipIneligibility.notSubscribed,
        'USER_NOT_FOLLOWING': ClipIneligibility.notFollowing,
        'FOLLOWING_LENGTH_REQUIREMENT_NOT_MET':
            ClipIneligibility.followingTooShort,
        'CATEGORY_NOT_CLIPPABLE': ClipIneligibility.categoryNotClippable,
        'DJ_CATEGORY_NOT_CLIPPABLE': ClipIneligibility.djCategory,
        'PARTICIPATING_DJ': ClipIneligibility.participatingDj,
      };
      for (final MapEntry(key: code, value: reason) in codes.entries) {
        expect(
          ClipEligibilityRefusal.fromGql(canCreateClipRefused(code))?.reason,
          reason,
        );
      }
      expect(
        ClipEligibilityRefusal.fromGql(
          canCreateClipRefused('FOLLOWING_LENGTH_REQUIREMENT_NOT_MET'),
        )?.requiredFollowMinutes,
        60,
      );
    });

    test('allowed, unknown codes and the anonymous null mean no refusal', () {
      expect(ClipEligibilityRefusal.fromGql(canCreateClipAllowed), isNull);
      expect(
        ClipEligibilityRefusal.fromGql(
          canCreateClipRefused('PERMISSION_DENIED'),
        ),
        isNull,
      );
      expect(
        ClipEligibilityRefusal.fromGql(canCreateClipAnonymous['data']),
        isNull,
      );
      expect(ClipEligibilityRefusal.fromGql('junk'), isNull);
    });
  });

  group('clipRefusal', () {
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

    test('asks with the exact document and the web token', () async {
      adapter.onPost(
        _gql,
        (server) => server.reply(200, {
          'data': canCreateClipRefused('PARTICIPATING_DJ'),
        }),
        data: Matchers.any,
      );
      final refusal = await service.clipRefusal(
        broadcasterId: '42',
        authToken: 'tok',
      );
      expect(refusal?.reason, ClipIneligibility.participatingDj);
      final data = requests.single.data;
      final body = Map<String, dynamic>.from(
        data is String ? jsonDecode(data) as Map : data as Map,
      );
      expect(body['operationName'], 'CanCreateClipForChannelQuery');
      expect(body['variables'], {'broadcasterId': '42'});
      expect(requests.single.headers['Authorization'], 'OAuth tok');
    });

    test('errors and a missing token give null', () async {
      adapter.onPost(
        _gql,
        (server) => server.reply(200, canCreateClipAnonymous),
        data: Matchers.any,
      );
      expect(
        await service.clipRefusal(broadcasterId: '42', authToken: 'tok'),
        isNull,
      );
      expect(
        await service.clipRefusal(broadcasterId: '42', authToken: ''),
        isNull,
      );
      expect(
        await service.clipRefusal(broadcasterId: 'x', authToken: 'tok'),
        isNull,
      );
    });
  });

  test('the profile reads the DJ role seen live', () {
    final profile = ChannelProfile.fromGql(djProfileUser)!;
    expect(profile.isParticipatingDj, isTrue);
    expect(
      ChannelProfile.fromGql({
        ...djProfileUser,
        'roles': nonDjRoles,
      })!.isParticipatingDj,
      isFalse,
    );
  });
}
