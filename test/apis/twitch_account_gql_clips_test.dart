import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/integrity_retry_interceptor.dart';
import 'package:onset/apis/twitch_account_gql_service.dart';
import 'package:onset/models/profile_edit.dart';

const _gql = 'https://gql.twitch.tv/gql';
const _slug = 'SmellySlipperyEggnogDBstyle-YKZwOj2rR3IVcuor';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchAccountGqlService service;
  late List<RequestOptions> sent;

  setUp(() {
    dio = Dio();
    adapter = DioAdapter(dio: dio);
    sent = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sent.add(options);
          handler.next(options);
        },
      ),
    );
    service = TwitchAccountGqlService(dio);
  });

  void reply(Object? body) => adapter.onPost(
    _gql,
    (server) => server.reply(200, body),
    data: Matchers.any,
  );

  Map<String, Object?> input() =>
      Map<String, Object?>.from(
            (sent.first.data as Map)['variables'] as Map,
          )['input']!
          as Map<String, Object?>;

  group('deleteClip', () {
    test('sends DeleteClipsMutation as a user action', () async {
      reply({
        'data': {
          'deleteClips': {
            'clips': [
              {'slug': _slug},
            ],
          },
        },
      });
      final outcome = await service.deleteClip(slug: _slug, authToken: 't');
      expect(outcome, AccountEditOutcome.done);
      expect((sent.single.data as Map)['operationName'], 'DeleteClipsMutation');
      expect(input(), {
        'slugs': [_slug],
      });
      expect(
        sent.single.extra[IntegrityRetryInterceptor.userActionKey],
        isTrue,
      );
    });

    test('a clip missing from the answer was not deleted', () async {
      reply({
        'data': {
          'deleteClips': {'clips': <Object>[]},
        },
      });
      expect(
        await service.deleteClip(slug: _slug, authToken: 't'),
        AccountEditOutcome.refused,
      );
    });

    test('a bad slug or no session sends nothing', () async {
      expect(
        await service.deleteClip(slug: 'bad slug!', authToken: 't'),
        AccountEditOutcome.failed,
      );
      expect(
        await service.deleteClip(slug: _slug, authToken: ''),
        AccountEditOutcome.signedOut,
      );
      expect(sent, isEmpty);
    });
  });

  group('renameClip', () {
    test('saves the trimmed title', () async {
      reply({
        'data': {
          'updateClip': {
            'clip': {'slug': _slug, 'title': 'Clutch'},
            'error': null,
          },
        },
      });
      final result = await service.renameClip(
        slug: _slug,
        title: '  Clutch ',
        authToken: 't',
      );
      expect(result.succeeded, isTrue);
      expect(result.value, 'Clutch');
      expect(input(), {'slug': _slug, 'title': 'Clutch'});
    });

    test('Twitch’s error is a refusal', () async {
      reply({
        'data': {
          'updateClip': {
            'clip': null,
            'error': {'message': 'forbidden'},
          },
        },
      });
      final result = await service.renameClip(
        slug: _slug,
        title: 'x',
        authToken: 't',
      );
      expect(result.outcome, AccountEditOutcome.refused);
    });

    test('an empty or too long title sends nothing', () async {
      for (final title in ['   ', 'a' * 101]) {
        final result = await service.renameClip(
          slug: _slug,
          title: title,
          authToken: 't',
        );
        expect(result.outcome, AccountEditOutcome.failed);
      }
      expect(sent, isEmpty);
    });
  });
}
