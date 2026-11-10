import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_account_gql_service.dart';
import 'package:onset/models/profile_edit.dart';

const _gql = 'https://gql.twitch.tv/gql';
const _upload = 'https://uploads.example-s3.amazonaws.com/avatar?sig=1';

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

  group('uploadProfileImage', () {
    final png = ProfileImageFile(
      bytes: Uint8List.fromList([1, 2, 3]),
      format: ProfileImageFormat.png,
    );

    test('asks for an upload URL, then puts the bytes there', () async {
      reply({
        'data': {
          'createProfileImageUploadURL': {
            'uploadURL': _upload,
            'uploadID': 'u1',
            'error': null,
          },
        },
      });
      adapter.onPut(
        _upload,
        (server) => server.reply(200, null),
        data: Matchers.any,
      );
      final outcome = await service.uploadProfileImage(
        userId: '42',
        kind: ProfileImageKind.avatar,
        file: png,
        authToken: 't',
      );
      expect(outcome, AccountEditOutcome.done);
      expect(input(), {'userID': '42', 'format': 'PNG'});
      expect(sent.last.method, 'PUT');
      expect(sent.last.headers['Authorization'], isNull);
      expect(sent.last.headers[Headers.contentTypeHeader], 'image/png');
    });

    test('a banner uses the banner mutation', () async {
      reply({
        'data': {
          'createProfileBannerImageUploadURL': {
            'uploadURL': _upload,
            'uploadID': 'u2',
            'error': null,
          },
        },
      });
      adapter.onPut(
        _upload,
        (server) => server.reply(200, null),
        data: Matchers.any,
      );
      final outcome = await service.uploadProfileImage(
        userId: '42',
        kind: ProfileImageKind.banner,
        file: png,
        authToken: 't',
      );
      expect(outcome, AccountEditOutcome.done);
      expect(
        (sent.first.data as Map)['operationName'],
        'CreateProfileBannerImageUploadURL',
      );
    });

    test('a refusal or an unsafe URL uploads nothing', () async {
      reply({
        'data': {
          'createProfileImageUploadURL': {
            'uploadURL': 'http://insecure.example.com/x',
            'uploadID': 'u1',
            'error': null,
          },
        },
      });
      expect(
        await service.uploadProfileImage(
          userId: '42',
          kind: ProfileImageKind.avatar,
          file: png,
          authToken: 't',
        ),
        AccountEditOutcome.failed,
      );
      expect(sent.where((r) => r.method == 'PUT'), isEmpty);
    });

    test('Twitch’s error code is a refusal', () async {
      reply({
        'data': {
          'createProfileImageUploadURL': {
            'uploadURL': null,
            'uploadID': null,
            'error': {'code': 'INVALID_FORMAT'},
          },
        },
      });
      expect(
        await service.uploadProfileImage(
          userId: '42',
          kind: ProfileImageKind.avatar,
          file: png,
          authToken: 't',
        ),
        AccountEditOutcome.refused,
      );
    });
  });

  group('ProfileImageFile', () {
    test('accepts PNG, JPG and GIF up to 10 MB only', () {
      final small = Uint8List(4);
      expect(
        ProfileImageFile.fromNamed('a.PNG', small)?.format,
        ProfileImageFormat.png,
      );
      expect(
        ProfileImageFile.fromNamed('a.jpeg', small)?.format,
        ProfileImageFormat.jpg,
      );
      expect(
        ProfileImageFile.fromNamed('a.gif', small)?.format,
        ProfileImageFormat.gif,
      );
      expect(ProfileImageFile.fromNamed('a.webp', small), isNull);
      expect(ProfileImageFile.fromNamed('a.png', Uint8List(0)), isNull);
      expect(
        ProfileImageFile.fromNamed(
          'a.png',
          Uint8List(ProfileImageFile.maxBytes + 1),
        ),
        isNull,
      );
    });
  });
}
