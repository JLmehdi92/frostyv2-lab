import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_account_gql_service.dart';
import 'package:onset/models/profile_edit.dart';

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

const _user = {
  '__typename': 'User',
  'id': '1000',
  'login': 'caster',
  'displayName': 'Caster',
  'description': 'Speedruns on weekends.',
  'profileImageURL': 'https://static-cdn.jtvnw.net/jtv_user_pictures/a.png',
  'bannerImageURL': null,
};

Map<String, Object?> _updated(String field, {String? code}) => {
  'data': {
    field: {
      'error': code == null ? null : {'code': code},
      'user': code == null ? _user : null,
    },
  },
};

Map<String, Object?> _links(String field, List<Map<String, Object?>> links) => {
  'data': {
    field: {
      'channel': {'__typename': 'Channel', 'socialMedias': links},
      'error': null,
    },
  },
};

void main() {
  group('reads', () {
    test('the profile, with the web token', () async {
      final sent = <RequestOptions>[];
      final profile = await _service(
        sent,
        (_) => {
          'data': {'currentUser': _user},
        },
      ).profile(authToken: 'tok');
      expect(profile!.login, 'caster');
      expect(profile.description, 'Speedruns on weekends.');
      expect(profile.bannerImageUrl, isNull);
      expect(sent.single.headers['Authorization'], 'OAuth tok');
      expect(_body(sent.single)['operationName'], 'EditableProfile');
    });

    test('nothing without a token, and null on any error', () async {
      final sent = <RequestOptions>[];
      final service = _service(
        sent,
        (_) => {
          'errors': [
            {'message': 'Cannot query field'},
          ],
        },
      );
      expect(await service.profile(authToken: ''), isNull);
      expect(sent, isEmpty);
      expect(await service.profile(authToken: 'tok'), isNull);
      expect(await service.socialLinks(authToken: 'tok'), isNull);
      expect(await service.renameStatus(authToken: 'tok'), isNull);
    });

    test('the rename status, with Twitch’s exact query', () async {
      final sent = <RequestOptions>[];
      final status = await _service(
        sent,
        (_) => {
          'data': {
            'currentUser': {
              'loginRenameStatus': {
                'isEligible': false,
                'eligibleAt': '2027-01-08T00:00:00Z',
              },
            },
          },
        },
      ).renameStatus(authToken: 'tok');
      expect(status!.eligible, isFalse);
      expect(status.eligibleAt, DateTime.utc(2027, 1, 8));
      expect(
        _body(sent.single)['query'],
        'query UserLoginRenameStatusQuery { currentUser { loginRenameStatus { '
        'isEligible eligibleAt } } }',
      );
    });

    test('social links keep only https or http addresses', () async {
      final links = await _service(
        <RequestOptions>[],
        (_) => {
          'data': {
            'currentUser': {
              'id': '1000',
              'channel': {
                'socialMedias': [
                  {
                    'id': 'a',
                    'name': 'youtube',
                    'title': 'YouTube',
                    'url': 'https://youtube.com/@caster',
                  },
                  {
                    'id': 'b',
                    'name': 'x',
                    'title': '',
                    'url': 'http://example.com/me',
                  },
                  {
                    'id': 'c',
                    'name': 'bad',
                    'title': 'Bad',
                    'url': 'javascript:alert(1)',
                  },
                ],
              },
            },
          },
        },
      ).socialLinks(authToken: 'tok');
      expect(links!.map((l) => l.id), ['a', 'b']);
      expect(links.last.title, 'example.com');
    });

    test(
      'username availability, and the anti-bot refusal as unknown',
      () async {
        final sent = <RequestOptions>[];
        final free = _service(
          sent,
          (_) => {
            'data': {'isUsernameAvailable': true},
          },
        );
        expect(
          await free.usernameAvailability(login: 'New_Name', authToken: 'tok'),
          UsernameAvailability.available,
        );
        expect(_body(sent.single)['variables'], {'login': 'new_name'});
        expect(
          await _service(
            <RequestOptions>[],
            (_) => {
              'data': {'isUsernameAvailable': false},
            },
          ).usernameAvailability(login: 'taken', authToken: 'tok'),
          UsernameAvailability.taken,
        );
        expect(
          await _service(
            <RequestOptions>[],
            (_) => {
              'errors': [
                {
                  'message': 'failed integrity check',
                  'extensions': {'code': 'IntegrityCheckFailed'},
                },
              ],
              'data': {'isUsernameAvailable': null},
            },
          ).usernameAvailability(login: 'maybe', authToken: 'tok'),
          UsernameAvailability.unknown,
        );
        expect(
          await free.usernameAvailability(login: '_bad', authToken: 'tok'),
          UsernameAvailability.taken,
        );
        expect(sent, hasLength(1));
      },
    );
  });

  group('changes', () {
    test('display name, bio and username send Twitch’s exact mutations', () async {
      final sent = <RequestOptions>[];
      final service = _service(sent, (o) {
        final op = _body(o)['operationName'];
        return _updated(
          op == 'ChangeUsernameMutation' ? 'changeUsername' : 'updateUser',
        );
      });
      final name = await service.updateDisplayName(
        userId: '1000',
        displayName: ' CASTER ',
        authToken: 'tok',
      );
      final bio = await service.updateDescription(
        userId: '1000',
        description: 'New bio',
        authToken: 'tok',
      );
      final login = await service.changeUsername(
        userId: '1000',
        login: 'New_Name',
        authToken: 'tok',
      );
      expect([name, bio, login].every((r) => r.succeeded), isTrue);
      expect(name.value!.login, 'caster');
      expect(sent.map((o) => _body(o)['operationName']), [
        'UpdateUserDisplayNameMutation',
        'UpdateUserDescriptionMutation',
        'ChangeUsernameMutation',
      ]);
      expect(_body(sent[0])['variables'], {
        'userID': '1000',
        'newDisplayName': 'CASTER',
      });
      expect(_body(sent[2])['variables'], {
        'userID': '1000',
        'newLogin': 'new_name',
      });
      expect(
        _body(sent[2])['query'],
        startsWith(
          'mutation ChangeUsernameMutation(\$userID: ID!, \$newLogin: String!) '
          '{ changeUsername(input: { userID: \$userID login: \$newLogin } ) {',
        ),
      );
    });

    test('Twitch’s error code is kept', () async {
      final result = await _service(
        <RequestOptions>[],
        (_) => _updated('changeUsername', code: 'LOGIN_UNAVAILABLE'),
      ).changeUsername(userId: '1000', login: 'taken', authToken: 'tok');
      expect(result.outcome, AccountEditOutcome.refused);
      expect(result.code, 'LOGIN_UNAVAILABLE');
    });

    test('nothing invalid is sent', () async {
      final sent = <RequestOptions>[];
      final service = _service(sent, (_) => _updated('updateUser'));
      expect(
        (await service.updateDisplayName(
          userId: 'x',
          displayName: 'a',
          authToken: 'tok',
        )).outcome,
        AccountEditOutcome.failed,
      );
      expect(
        (await service.updateDescription(
          userId: '1000',
          description: 'a' * 301,
          authToken: 'tok',
        )).outcome,
        AccountEditOutcome.failed,
      );
      expect(
        (await service.changeUsername(
          userId: '1000',
          login: 'ab',
          authToken: 'tok',
        )).outcome,
        AccountEditOutcome.failed,
      );
      expect(
        (await service.updateDescription(
          userId: '1000',
          description: 'ok',
          authToken: '',
        )).outcome,
        AccountEditOutcome.signedOut,
      );
      expect(sent, isEmpty);
    });

    test('social links: add, edit and delete return the new list', () async {
      final sent = <RequestOptions>[];
      final link = {
        'id': 'a',
        'name': 'youtube',
        'title': 'YouTube',
        'url': 'https://youtube.com/@caster',
      };
      final service = _service(sent, (o) {
        final op = _body(o)['operationName'];
        return switch (op) {
          'CreateSocialLink' => _links('createSocialMedia', [link]),
          'UpdateSocialLink' => _links('updateSocialMedia', [link]),
          _ => _links('deleteSocialMedia', []),
        };
      });
      final added = await service.addSocialLink(
        channelId: '1000',
        title: 'YouTube',
        url: 'https://youtube.com/@caster',
        authToken: 'tok',
      );
      final edited = await service.updateSocialLink(
        channelId: '1000',
        linkId: 'a',
        title: 'YouTube',
        url: 'https://youtube.com/@caster',
        authToken: 'tok',
      );
      final deleted = await service.deleteSocialLink(
        channelId: '1000',
        linkId: 'a',
        authToken: 'tok',
      );
      expect(added.value!.single.title, 'YouTube');
      expect(edited.succeeded, isTrue);
      expect(deleted.value, isEmpty);
      expect(_body(sent[0])['variables'], {
        'input': {
          'channelID': '1000',
          'title': 'YouTube',
          'url': 'https://youtube.com/@caster',
        },
      });
      expect(_body(sent[2])['variables'], {
        'input': {'channelID': '1000', 'id': 'a'},
      });
    });

    test(
      'a social link error is a refusal; a bad address is never sent',
      () async {
        final sent = <RequestOptions>[];
        final result =
            await _service(
              sent,
              (_) => {
                'data': {
                  'createSocialMedia': {'channel': null, 'error': 'TOO_MANY'},
                },
              },
            ).addSocialLink(
              channelId: '1000',
              title: 'Site',
              url: 'https://example.com',
              authToken: 'tok',
            );
        expect(result.outcome, AccountEditOutcome.refused);
        expect(result.code, 'TOO_MANY');
        final bad = await _service(sent, (_) => null).addSocialLink(
          channelId: '1000',
          title: 'Site',
          url: 'ftp://example.com',
          authToken: 'tok',
        );
        expect(bad.outcome, AccountEditOutcome.failed);
        expect(sent, hasLength(1));
      },
    );
  });
}
