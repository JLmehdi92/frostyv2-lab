import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/models/onset_release.dart';
import 'package:path_provider/path_provider.dart';

/// The download failed (network, server or an unexpected redirect).
class UpdateDownloadException implements Exception {
  const UpdateDownloadException();
}

/// The downloaded APK does not match its published SHA-256, or there was no
/// hash to check it against.
class UpdateIntegrityException implements Exception {
  const UpdateIntegrityException();
}

/// The viewer cancelled the download.
class UpdateCancelledException implements Exception {
  const UpdateCancelledException();
}

/// GitHub shows no release to this build: it has no token and the repository
/// answers 404, because it is private (or has no release yet). Not a failure:
/// a build made while the repository was public simply cannot see it.
class UpdateNotVisibleException implements Exception {
  const UpdateNotVisibleException();
}

/// GitHub refused an anonymous request for its rate limit (403 or 429).
class UpdateRateLimitedException implements Exception {
  const UpdateRateLimitedException();
}

/// Reads ONSET builds from the GitHub releases of the update repository.
///
/// It gets its own [Dio], never the app's: the Twitch interceptors must not
/// see these requests, and the GitHub token must not reach Twitch. The token
/// is only ever sent to api.github.com: asset downloads answer with a redirect
/// to a signed URL, which is followed by hand without it.
///
/// A build made while the repository was public has no token (the workflow
/// never bakes one into an APK that anyone can download): it reads the same
/// API anonymously, with no Authorization header at all, which works as long
/// as the repository is public.
class OnsetUpdateService extends BaseApiClient {
  static const _apiOrigin = 'https://api.github.com';
  static final _repoPattern = RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$');
  static final _hashPattern = RegExp(r'^[0-9a-f]{64}$');

  /// The only hosts an asset redirect may lead to, matched exactly.
  static const _downloadHosts = {
    'api.github.com',
    'github.com',
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
  };

  final String _token;
  final String _repo;
  final Dio _http;
  final Future<Directory> Function() _cacheDirectory;
  final Duration _idleTimeout;

  /// [idleTimeout] bounds the wait for the next bytes of an asset: Dio's
  /// receive timeout does not cover streamed bodies, so a stalled download
  /// would otherwise wait forever.
  OnsetUpdateService({
    required String token,
    required String repo,
    Dio? dio,
    Future<Directory> Function()? cacheDirectory,
    Duration idleTimeout = const Duration(seconds: 30),
  }) : this._(
         token,
         repo,
         dio ??
             Dio(
               BaseOptions(
                 connectTimeout: const Duration(seconds: 5),
                 receiveTimeout: const Duration(seconds: 15),
               ),
             ),
         cacheDirectory ?? getTemporaryDirectory,
         idleTimeout,
       );

  OnsetUpdateService._(
    this._token,
    this._repo,
    this._http,
    this._cacheDirectory,
    this._idleTimeout,
  ) : super(_http, _apiOrigin);

  bool get _validRepo =>
      _repo.isNotEmpty && !_repo.contains('..') && _repoPattern.hasMatch(_repo);

  bool get _anonymous => _token.isEmpty;

  ApiHeaders get _apiHeaders => {
    if (!_anonymous) 'Authorization': 'Bearer $_token',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  String _assetUrl(int id) => '$_apiOrigin/repos/$_repo/releases/assets/$id';

  /// The latest ONSET build, or null when there is none or it cannot be read.
  ///
  /// Without a token, throws [UpdateNotVisibleException] when GitHub answers
  /// 404 (the repository is private, or has no release yet) and
  /// [UpdateRateLimitedException] on 403 or 429 (the anonymous rate limit).
  Future<OnsetRelease?> latest() async {
    if (!_validRepo) return null;
    try {
      final json = await get<Object?>(
        '/repos/$_repo/releases/latest',
        headers: _apiHeaders,
      );
      return OnsetRelease.tryParse(json);
    } on ApiException catch (e) {
      if (_anonymous && e.statusCode == 404) {
        throw const UpdateNotVisibleException();
      }
      if (_anonymous && (e.statusCode == 403 || e.statusCode == 429)) {
        throw const UpdateRateLimitedException();
      }
      // The message and status only: never the request, which holds the token.
      debugPrint('Update check failed: ${e.statusCode ?? e.message}');
      return null;
    } catch (e) {
      debugPrint('Update check failed: ${e.runtimeType}');
      return null;
    }
  }

  /// The SHA-256 published for [release]'s APK, in lowercase hex, or null
  /// when the asset holds no valid hash.
  ///
  /// Throws [UpdateDownloadException] when the asset cannot be fetched: a
  /// network failure is not a corrupted update.
  Future<String?> expectedSha256(
    OnsetRelease release, {
    CancelToken? cancelToken,
  }) async {
    if (!_validRepo) return null;
    final Uint8List bytes;
    try {
      final body = await _openAsset(
        release.shaAssetId,
        cancelToken: cancelToken,
      );
      bytes = await _collect(body.stream, cancelToken, maxBytes: 4096);
    } on UpdateIntegrityException {
      return null;
    } catch (e) {
      debugPrint('Update hash unavailable: ${e.runtimeType}');
      throw _failure(e);
    }
    final text = String.fromCharCodes(bytes).trim();
    final hash = text.split(RegExp(r'\s+')).first.toLowerCase();
    return _hashPattern.hasMatch(hash) ? hash : null;
  }

  /// What a failed request means to the update flow.
  static Exception _failure(Object error) => switch (error) {
    UpdateDownloadException() ||
    UpdateIntegrityException() ||
    UpdateCancelledException() => error as Exception,
    DioException(type: DioExceptionType.cancel) =>
      const UpdateCancelledException(),
    _ => const UpdateDownloadException(),
  };

  /// Downloads [release]'s APK into the app cache, under `updates/`, and
  /// checks it against its published SHA-256. A file that does not match is
  /// deleted. Older downloads are removed first.
  ///
  /// Throws [UpdateDownloadException], [UpdateIntegrityException] or
  /// [UpdateCancelledException].
  Future<File> download(
    OnsetRelease release, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final expected = await expectedSha256(release, cancelToken: cancelToken);
    if (expected == null) throw const UpdateIntegrityException();
    if (cancelToken?.isCancelled ?? false) {
      throw const UpdateCancelledException();
    }

    final directory = Directory('${(await _cacheDirectory()).path}/updates');
    await _clear(directory);
    final file = File('${directory.path}/onset-${release.build}.apk');
    final part = File('${file.path}.part');

    try {
      final body = await _openAsset(
        release.apkAssetId,
        cancelToken: cancelToken,
      );
      final total = body.contentLength > 0
          ? body.contentLength
          : release.apkSize;
      await _save(body.stream, part, total, onProgress, cancelToken);

      final actual = (await sha256.bind(part.openRead()).first).toString();
      if (actual != expected) throw const UpdateIntegrityException();
      return await part.rename(file.path);
    } catch (e) {
      await _delete(part);
      debugPrint(
        'Update download failed: '
        '${e is DioException ? e.response?.statusCode : e.runtimeType}',
      );
      throw _failure(e);
    }
  }

  /// Deletes what an earlier update left in the cache `updates/` directory:
  /// every APK up to [installedBuild], half-finished downloads and anything
  /// else. Only a downloaded build newer than the installed one is kept.
  Future<void> removeDownloadsUpTo(int installedBuild) async {
    final directory = Directory('${(await _cacheDirectory()).path}/updates');
    if (!await directory.exists()) return;
    final download = RegExp(r'^onset-(\d{1,9})\.apk$');
    await for (final entity in directory.list()) {
      final name = entity.uri.pathSegments.lastWhere(
        (segment) => segment.isNotEmpty,
      );
      final build = int.tryParse(download.firstMatch(name)?.group(1) ?? '');
      if (entity is File && build != null && build > installedBuild) continue;
      await _delete(entity);
    }
  }

  /// Opens a release asset's bytes. GitHub answers with a redirect to a signed
  /// URL; it is followed by hand so that the token stays on api.github.com,
  /// and only to an https URL on one of [_downloadHosts].
  Future<ResponseBody> _openAsset(int id, {CancelToken? cancelToken}) async {
    final first = await _http.get<ResponseBody>(
      _assetUrl(id),
      cancelToken: cancelToken,
      options: Options(
        headers: {..._apiHeaders, 'Accept': 'application/octet-stream'},
        followRedirects: false,
        responseType: ResponseType.stream,
        validateStatus: (status) =>
            status == 200 || (status != null && status >= 300 && status < 400),
      ),
    );
    final body = first.data!;
    if (first.statusCode == 200) return body;

    unawaited(body.stream.listen(null).cancel());
    final location = first.headers.value('location');
    final target = location == null
        ? null
        : first.requestOptions.uri.resolve(location);
    if (target == null ||
        target.scheme != 'https' ||
        target.port != 443 ||
        target.userInfo.isNotEmpty ||
        !_downloadHosts.contains(target.host)) {
      throw const UpdateDownloadException();
    }

    final second = await _http.getUri<ResponseBody>(
      target,
      cancelToken: cancelToken,
      options: Options(
        headers: {'Accept': 'application/octet-stream'},
        responseType: ResponseType.stream,
      ),
    );
    return second.data!;
  }

  Future<Uint8List> _collect(
    Stream<Uint8List> stream,
    CancelToken? cancelToken, {
    required int maxBytes,
  }) async {
    final builder = BytesBuilder(copy: false);
    await _read(stream, cancelToken, (chunk) {
      builder.add(chunk);
      if (builder.length > maxBytes) throw const UpdateIntegrityException();
    });
    return builder.takeBytes();
  }

  Future<void> _save(
    Stream<Uint8List> stream,
    File file,
    int total,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  ) async {
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    var received = 0;
    try {
      await _read(stream, cancelToken, (chunk) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      });
    } finally {
      await sink.close();
    }
  }

  /// Hands each chunk of [stream] to [onChunk] until it ends. Fails with
  /// [UpdateDownloadException] when no bytes come for [_idleTimeout], and
  /// with [UpdateCancelledException] as soon as [cancelToken] is cancelled.
  /// An exception thrown by [onChunk] stops the read and is passed on.
  Future<void> _read(
    Stream<Uint8List> stream,
    CancelToken? cancelToken,
    void Function(Uint8List chunk) onChunk,
  ) {
    final done = Completer<void>();
    late final StreamSubscription<Uint8List> subscription;

    void fail(Object error) {
      if (done.isCompleted) return;
      unawaited(subscription.cancel());
      done.completeError(_failure(error));
    }

    subscription = stream
        .timeout(_idleTimeout)
        .listen(
          (chunk) {
            try {
              onChunk(chunk);
            } catch (e) {
              fail(e);
            }
          },
          onError: fail,
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );
    if (cancelToken != null) {
      if (cancelToken.isCancelled) {
        fail(const UpdateCancelledException());
      } else {
        unawaited(
          cancelToken.whenCancel.then(
            (_) => fail(const UpdateCancelledException()),
          ),
        );
      }
    }
    return done.future;
  }

  Future<void> _clear(Directory directory) async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      await _delete(entity);
    }
  }

  Future<void> _delete(FileSystemEntity entity) async {
    try {
      await entity.delete(recursive: true);
    } on FileSystemException {
      // Already gone.
    }
  }
}
