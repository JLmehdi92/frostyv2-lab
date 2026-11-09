import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_account_gql_service.dart';
import 'package:onset/models/clip_comment.dart';
import 'package:onset/models/profile_edit.dart';

import '../fixtures/clip_extras_payloads.dart';

TwitchAccountGqlService _service(
  List<RequestOptions> sent,
  Object? Function(RequestOptions) reply,
) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        sent.add(options);
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: reply(options),
          ),
        );
      },
    ),
  );
  return TwitchAccountGqlService(dio);
}

Map<String, Object?> _body(RequestOptions o) =>
    Map<String, Object?>.from(o.data as Map);

const _slug = 'SmellySlipperyEggnogDBstyle-YKZwOj2rR3IVcuor';

Map<String, Object?> _eligibility(
  bool allowed, [
  List<String> codes = const [],
]) => {
  'data': {
    'clip': {
      'self': {
        'commentCreationEligibility': {
          'isAllowed': allowed,
          'errorCodes': codes,
          'requiredFollowingLengthMinutes': codes.isEmpty ? null : 10,
        },
      },
      'broadcaster': {'self': null},
    },
  },
};

void main() {
  group('commentEligibility', () {
    test('allowed', () async {
      final sent = <RequestOptions>[];
      final eligibility = await _service(
        sent,
        (_) => _eligibility(true),
      ).commentEligibility(slug: _slug, authToken: 'tok');
      expect(eligibility!.allowed, isTrue);
      expect(
        _body(sent.single)['operationName'],
        'ClipCommentEligibilityQuery',
      );
      expect(sent.single.headers['Authorization'], 'OAuth tok');
    });

    test('maps each refusal to its reason', () async {
      Future<ClipCommentBlock?> blockFor(String code) async => (await _service(
        <RequestOptions>[],
        (_) => _eligibility(false, [code]),
      ).commentEligibility(slug: _slug, authToken: 'tok'))!.block;
      expect(
        await blockFor('COMMENTS_DISABLED'),
        ClipCommentBlock.commentsDisabled,
      );
      expect(
        await blockFor('USER_NOT_FOLLOWING'),
        ClipCommentBlock.notFollowing,
      );
      expect(
        await blockFor('FOLLOWING_LENGTH_REQUIREMENT_NOT_MET'),
        ClipCommentBlock.followTooRecent,
      );
      expect(
        await blockFor('USER_NOT_SUBSCRIBED'),
        ClipCommentBlock.notSubscribed,
      );
      expect(await blockFor('PHONE_NOT_VERIFIED'), ClipCommentBlock.unverified);
      expect(await blockFor('NOT_ELIGIBLE'), ClipCommentBlock.other);
    });

    test(
      'no token or an error: unknown, and nothing sent without a token',
      () async {
        final sent = <RequestOptions>[];
        expect(
          await _service(
            sent,
            (_) => _eligibility(true),
          ).commentEligibility(slug: _slug, authToken: ''),
          isNull,
        );
        expect(sent, isEmpty);
        expect(
          await _service(
            sent,
            (_) => {
              'errors': [
                {'message': 'boom'},
              ],
            },
          ).commentEligibility(slug: _slug, authToken: 'tok'),
          isNull,
        );
      },
    );
  });

  group('postComment', () {
    final created = {
      'data': {
        'createClipComment': {
          'comment':
              (((clipCommentsLiveResponse['data']! as Map)['clip']
                          as Map)['comments']
                      as Map)['edges']
                  is List
              ? ((((clipCommentsLiveResponse['data']! as Map)['clip']
                                as Map)['comments']
                            as Map)['edges']
                        as List)
                    .first['node']
              : null,
          'error': null,
        },
      },
    };

    test('sends the exact mutation and returns the new comment', () async {
      final sent = <RequestOptions>[];
      final result = await _service(
        sent,
        (_) => created,
      ).postComment(slug: _slug, body: '  nice clip  ', authToken: 'tok');
      expect(result.succeeded, isTrue);
      expect(result.value!.id, 'comment-1');
      final body = _body(sent.single);
      expect(body['operationName'], 'CreateClipComment');
      expect(body['query'], startsWith('mutation CreateClipComment('));
      expect(body['variables'], {
        'input': {'clipSlug': _slug, 'body': 'nice clip'},
      });
    });

    test('a refusal keeps Twitch’s code', () async {
      final result = await _service(
        <RequestOptions>[],
        (_) => {
          'data': {
            'createClipComment': {'comment': null, 'error': 'CONTAINS_LINK'},
          },
        },
      ).postComment(slug: _slug, body: 'x.com', authToken: 'tok');
      expect(result.outcome, AccountEditOutcome.refused);
      expect(result.code, 'CONTAINS_LINK');
    });

    test('anti-bot refusal, signed out, empty or too long', () async {
      final sent = <RequestOptions>[];
      final service = _service(
        sent,
        (_) => {
          'errors': [
            {'message': 'failed integrity check'},
          ],
        },
      );
      expect(
        (await service.postComment(
          slug: _slug,
          body: 'hi',
          authToken: 'tok',
        )).outcome,
        AccountEditOutcome.integrityRefused,
      );
      expect(
        (await service.postComment(
          slug: _slug,
          body: 'hi',
          authToken: '',
        )).outcome,
        AccountEditOutcome.signedOut,
      );
      expect(
        (await service.postComment(
          slug: _slug,
          body: '   ',
          authToken: 'tok',
        )).outcome,
        AccountEditOutcome.failed,
      );
      expect(
        (await service.postComment(
          slug: _slug,
          body: 'a' * (TwitchAccountGqlService.maxCommentLength + 1),
          authToken: 'tok',
        )).outcome,
        AccountEditOutcome.failed,
      );
      expect(sent, hasLength(1));
    });
  });

  group('setCommentLiked', () {
    test('like and unlike use their own mutations', () async {
      final sent = <RequestOptions>[];
      final service = _service(sent, (o) {
        final op = _body(o)['operationName'];
        return {
          'data': {
            op == 'LikeClipComment' ? 'likeClipComment' : 'unlikeClipComment': {
              'error': null,
            },
          },
        };
      });
      expect(
        await service.setCommentLiked(
          slug: _slug,
          commentId: 'comment-1',
          liked: true,
          authToken: 'tok',
        ),
        AccountEditOutcome.done,
      );
      expect(
        await service.setCommentLiked(
          slug: _slug,
          commentId: 'comment-1',
          liked: false,
          authToken: 'tok',
        ),
        AccountEditOutcome.done,
      );
      expect(_body(sent.first)['operationName'], 'LikeClipComment');
      expect(_body(sent.last)['operationName'], 'UnlikeClipComment');
      expect(_body(sent.last)['variables'], {
        'input': {'clipSlug': _slug, 'commentID': 'comment-1'},
      });
    });

    test('an error code is a refusal', () async {
      expect(
        await _service(
          <RequestOptions>[],
          (_) => {
            'data': {
              'likeClipComment': {'error': 'COMMENT_NOT_FOUND'},
            },
          },
        ).setCommentLiked(
          slug: _slug,
          commentId: 'gone',
          liked: true,
          authToken: 'tok',
        ),
        AccountEditOutcome.refused,
      );
    });
  });

  group('ClipComment', () {
    test('like counts follow the viewer’s like', () {
      final comment = ClipComment.tryParse({
        'id': 'c',
        'body': 'b',
        'createdAt': '2026-11-06T03:35:43Z',
        'likeCount': 1,
      })!;
      final liked = comment.withLike(liked: true);
      expect(liked.likeCount, 2);
      expect(liked.likedByViewer, isTrue);
      expect(liked.withLike(liked: false).likeCount, 1);
      expect(comment.withLike(liked: false).likeCount, 1);
    });

    test('a node without id, body or date is dropped', () {
      expect(ClipComment.tryParse({'body': 'b', 'createdAt': '2026'}), isNull);
      expect(ClipComment.tryParse('x'), isNull);
    });
  });
}
