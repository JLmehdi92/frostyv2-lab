import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/onset_update_service.dart';
import 'package:frosty/models/onset_release.dart';

const _token = 'github_pat_secret';
const _repo = 'owner/app';
const _latestUrl = 'https://api.github.com/repos/owner/app/releases/latest';
const _apkUrl = 'https://api.github.com/repos/owner/app/releases/assets/11';
const _shaUrl = 'https://api.github.com/repos/owner/app/releases/assets/12';
const _signedUrl = 'https://objects.githubusercontent.com/apk?sig=abc';

/// Answers each request with [handler] and keeps every request it saw.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

ResponseBody _redirect(String location) => ResponseBody.fromString(
  '',
  302,
  headers: {
    'location': [location],
  },
);

ResponseBody _bytes(List<int> bytes) => ResponseBody.fromBytes(
  bytes,
  200,
  headers: {
    Headers.contentLengthHeader: ['${bytes.length}'],
  },
);

Map<String, dynamic> _releaseJson({String tag = 'build-1023'}) => {
  'tag_name': tag,
  'body': 'notes',
  'assets': [
    {'id': 11, 'name': 'onset-arm64.apk', 'size': 6},
    {'id': 12, 'name': 'onset-arm64.apk.sha256', 'size': 64},
  ],
};

final _release = OnsetRelease.tryParse(_releaseJson())!;
final _apk = utf8.encode('apk!!!');
final _apkHash = sha256.convert(_apk).toString();

String? _header(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return '${entry.value}';
  }
  return null;
}

void main() {
  late Directory cache;

  setUp(() => cache = Directory.systemTemp.createTempSync('onset_update'));
  tearDown(() => cache.deleteSync(recursive: true));

  OnsetUpdateService service(_Adapter adapter) => OnsetUpdateService(
    token: _token,
    repo: _repo,
    dio: Dio()..httpClientAdapter = adapter,
    cacheDirectory: () async => cache,
  );

  group('latest', () {
    test('reads the latest release with the token and API headers', () async {
      final adapter = _Adapter((_) => _json(_releaseJson()));

      final release = await service(adapter).latest();

      expect(release!.build, 1023);
      final request = adapter.requests.single;
      expect(request.uri.toString(), _latestUrl);
      expect(_header(request, 'Authorization'), 'Bearer $_token');
      expect(_header(request, 'Accept'), 'application/vnd.github+json');
      expect(_header(request, 'X-GitHub-Api-Version'), '2022-11-28');
    });

    for (final status in [401, 404, 500]) {
      test('a $status reads as no release', () async {
        final adapter = _Adapter((_) => _json({'message': 'x'}, status));

        expect(await service(adapter).latest(), isNull);
      });
    }

    test('a malformed answer reads as no release', () async {
      expect(await service(_Adapter((_) => _json(['x']))).latest(), isNull);
      expect(
        await service(
          _Adapter((_) => ResponseBody.fromString('<html>', 200)),
        ).latest(),
        isNull,
      );
    });

    test('a release that is not an ONSET build reads as none', () async {
      final adapter = _Adapter((_) => _json(_releaseJson(tag: 'v2.0.0')));

      expect(await service(adapter).latest(), isNull);
    });

    test('a network error reads as no release', () async {
      final adapter = _Adapter(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );

      expect(await service(adapter).latest(), isNull);
    });

    test('a malformed repository is never requested', () async {
      final adapter = _Adapter((_) => _json(_releaseJson()));
      final bad = OnsetUpdateService(
        token: _token,
        repo: '../evil',
        dio: Dio()..httpClientAdapter = adapter,
        cacheDirectory: () async => cache,
      );

      expect(await bad.latest(), isNull);
      expect(adapter.requests, isEmpty);
    });
  });

  group('expectedSha256', () {
    test('reads the hash asset through its signed redirect', () async {
      final adapter = _Adapter(
        (options) => options.uri.toString() == _shaUrl
            ? _redirect(_signedUrl)
            : ResponseBody.fromString('${_apkHash.toUpperCase()}\n', 200),
      );

      expect(await service(adapter).expectedSha256(_release), _apkHash);
      expect(
        _header(adapter.requests[0], 'Accept'),
        'application/octet-stream',
      );
      expect(_header(adapter.requests[1], 'Authorization'), isNull);
    });

    test('also takes "sha256sum" output with a file name', () async {
      final adapter = _Adapter(
        (_) => ResponseBody.fromString('$_apkHash  onset-arm64.apk\n', 200),
      );

      expect(await service(adapter).expectedSha256(_release), _apkHash);
    });

    test('a body that is not a hash reads as no hash', () async {
      for (final body in ['', 'abc', 'z' * 64, 'a' * 5000]) {
        final adapter = _Adapter((_) => ResponseBody.fromString(body, 200));
        expect(await service(adapter).expectedSha256(_release), isNull);
      }
    });

    test('a hash that cannot be fetched is a download error', () async {
      for (final failing in [
        _Adapter((_) => _json({}, 404)),
        _Adapter((_) => _json({}, 503)),
        _Adapter(
          (options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          ),
        ),
        _Adapter((_) => _redirect('http://objects.githubusercontent.com/x')),
      ]) {
        await expectLater(
          service(failing).expectedSha256(_release),
          throwsA(isA<UpdateDownloadException>()),
        );
      }
    });
  });

  group('removeDownloadsUpTo', () {
    File touch(String name) =>
        File('${cache.path}/updates/$name')..createSync(recursive: true);

    test('keeps only downloads newer than the installed build', () async {
      final installed = touch('onset-1023.apk');
      final older = touch('onset-1001.apk');
      final newer = touch('onset-1030.apk');
      final partial = touch('onset-1031.apk.part');
      final stray = touch('notes.txt');

      await service(_Adapter((_) => _json({}))).removeDownloadsUpTo(1023);

      expect(installed.existsSync(), isFalse);
      expect(older.existsSync(), isFalse);
      expect(partial.existsSync(), isFalse);
      expect(stray.existsSync(), isFalse);
      expect(newer.existsSync(), isTrue);
    });

    test('does nothing without a download folder', () async {
      await service(_Adapter((_) => _json({}))).removeDownloadsUpTo(1023);

      expect(Directory('${cache.path}/updates').existsSync(), isFalse);
    });
  });

  group('download', () {
    _Adapter serving({
      List<int>? apk,
      String? hash,
      bool redirect = true,
      String location = _signedUrl,
    }) => _Adapter((options) {
      final url = options.uri.toString();
      if (url == _shaUrl) return ResponseBody.fromString(hash ?? _apkHash, 200);
      if (url == _apkUrl && redirect) return _redirect(location);
      return _bytes(apk ?? _apk);
    });

    test(
      'follows the redirect by hand, without the token on the second hop',
      () async {
        final adapter = serving();

        final file = await service(adapter).download(_release);

        final apkRequests = adapter.requests
            .where((r) => r.uri.toString() != _shaUrl)
            .toList();
        expect(apkRequests.map((r) => r.uri.toString()), [_apkUrl, _signedUrl]);
        expect(apkRequests[0].followRedirects, isFalse);
        expect(_header(apkRequests[0], 'Authorization'), 'Bearer $_token');
        expect(_header(apkRequests[0], 'Accept'), 'application/octet-stream');
        expect(_header(apkRequests[1], 'Authorization'), isNull);
        expect(file.readAsBytesSync(), _apk);
        expect(file.path, '${cache.path}/updates/onset-1023.apk');
      },
    );

    test('takes the APK when the API answers it directly', () async {
      final file = await service(serving(redirect: false)).download(_release);

      expect(file.readAsBytesSync(), _apk);
    });

    test('reports progress', () async {
      final progress = <(int, int)>[];

      await service(serving()).download(
        _release,
        onProgress: (done, total) => progress.add((done, total)),
      );

      expect(progress.last, (6, 6));
    });

    test('deletes the file and throws when the hash does not match', () async {
      final adapter = serving(hash: sha256.convert([1, 2, 3]).toString());

      await expectLater(
        service(adapter).download(_release),
        throwsA(isA<UpdateIntegrityException>()),
      );
      expect(Directory('${cache.path}/updates').listSync(), isEmpty);
    });

    test('refuses to download without a hash to check', () async {
      final adapter = serving(hash: 'nope');

      await expectLater(
        service(adapter).download(_release),
        throwsA(isA<UpdateIntegrityException>()),
      );
      expect(
        adapter.requests.where((r) => r.uri.toString() == _apkUrl),
        isEmpty,
      );
    });

    test('an unreachable hash is a download error, not corruption', () async {
      final adapter = _Adapter(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );

      await expectLater(
        service(adapter).download(_release),
        throwsA(isA<UpdateDownloadException>()),
      );
    });

    test('refuses a redirect that is not https', () async {
      await expectLater(
        service(
          serving(location: 'http://objects.githubusercontent.com/apk'),
        ).download(_release),
        throwsA(isA<UpdateDownloadException>()),
      );
    });

    test('a failed download throws a download error', () async {
      final adapter = _Adapter((options) {
        if (options.uri.toString() == _shaUrl) {
          return ResponseBody.fromString(_apkHash, 200);
        }
        return _json({'message': 'gone'}, 404);
      });

      await expectLater(
        service(adapter).download(_release),
        throwsA(isA<UpdateDownloadException>()),
      );
    });

    test('removes older downloads', () async {
      final old = File('${cache.path}/updates/onset-1001.apk')
        ..createSync(recursive: true);

      await service(serving()).download(_release);

      expect(old.existsSync(), isFalse);
    });

    OnsetUpdateService patient(_Adapter adapter, Duration idle) =>
        OnsetUpdateService(
          token: _token,
          repo: _repo,
          dio: Dio()..httpClientAdapter = adapter,
          cacheDirectory: () async => cache,
          idleTimeout: idle,
        );

    test('a stalled download fails instead of hanging', () async {
      final stalled = StreamController<Uint8List>();
      final adapter = _Adapter((options) {
        final url = options.uri.toString();
        if (url == _shaUrl) return ResponseBody.fromString(_apkHash, 200);
        if (url == _apkUrl) return _redirect(_signedUrl);
        return ResponseBody(stalled.stream, 200);
      });

      await expectLater(
        patient(adapter, const Duration(milliseconds: 50)).download(_release),
        throwsA(isA<UpdateDownloadException>()),
      );
      expect(Directory('${cache.path}/updates').listSync(), isEmpty);
      await stalled.close();
    });

    test('a stalled hash fails instead of hanging', () async {
      final stalled = StreamController<Uint8List>();
      final adapter = _Adapter((_) => ResponseBody(stalled.stream, 200));

      await expectLater(
        patient(
          adapter,
          const Duration(milliseconds: 50),
        ).expectedSha256(_release),
        throwsA(isA<UpdateDownloadException>()),
      );
      await stalled.close();
    });

    test('cancelling while the hash loads stops the download', () async {
      final stalled = StreamController<Uint8List>();
      final adapter = _Adapter((_) => ResponseBody(stalled.stream, 200));
      final cancelToken = CancelToken();

      final download = patient(
        adapter,
        const Duration(minutes: 5),
      ).download(_release, cancelToken: cancelToken);
      // Cancel once the hash body is being read, not before the request.
      await pumpEventQueue();
      expect(stalled.hasListener, isTrue);
      cancelToken.cancel();

      await expectLater(
        download.timeout(const Duration(seconds: 5)),
        throwsA(isA<UpdateCancelledException>()),
      );
      expect(
        adapter.requests.where((r) => r.uri.toString() == _apkUrl),
        isEmpty,
      );
      await stalled.close();
    });

    test('a cancelled download stops and leaves nothing behind', () async {
      final cancelToken = CancelToken();
      final chunks = StreamController<Uint8List>();
      final adapter = _Adapter((options) {
        final url = options.uri.toString();
        if (url == _shaUrl) return ResponseBody.fromString(_apkHash, 200);
        if (url == _apkUrl) return _redirect(_signedUrl);
        return ResponseBody(
          chunks.stream,
          200,
          headers: {
            Headers.contentLengthHeader: ['6'],
          },
        );
      });

      final download = service(adapter).download(
        _release,
        cancelToken: cancelToken,
        onProgress: (_, _) => cancelToken.cancel(),
      );
      chunks.add(Uint8List.fromList([1, 2]));

      await expectLater(download, throwsA(isA<UpdateCancelledException>()));
      expect(Directory('${cache.path}/updates').listSync(), isEmpty);
      await chunks.close();
    });
  });
}
