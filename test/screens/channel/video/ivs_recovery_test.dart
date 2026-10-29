import 'dart:async' as async;

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/screens/channel/video/ivs_recovery.dart';

void main() {
  group('classifyIvsError', () {
    final cases = <String?, IvsErrorKind>{
      'ERROR_NETWORK': IvsErrorKind.recoverable,
      'ERROR_NETWORK_IO': IvsErrorKind.recoverable,
      'ERROR_TIMEOUT': IvsErrorKind.recoverable,
      'ERROR_AUTHORIZATION': IvsErrorKind.refreshToken,
      'ERROR_NOT_AVAILABLE': IvsErrorKind.offline,
      'ERROR_NOT_SUPPORTED': IvsErrorKind.fatal,
      'ERROR_NO_SOURCE': IvsErrorKind.fatal,
      'ERROR_INVALID_PARAMETER': IvsErrorKind.fatal,
      'ERROR_INVALID_STATE': IvsErrorKind.fatal,
      'ERROR': IvsErrorKind.recoverable,
      'ERROR_TYPE_UNKNOWN': IvsErrorKind.recoverable,
      'SOMETHING_NEW': IvsErrorKind.recoverable,
      null: IvsErrorKind.recoverable,
    };

    cases.forEach((type, kind) {
      test('$type -> ${kind.name}', () {
        expect(classifyIvsError(errorType: type), kind);
      });
    });

    test('HTTP 401/403 means the playback token must be refreshed', () {
      expect(
        classifyIvsError(errorType: 'ERROR', code: 403),
        IvsErrorKind.refreshToken,
      );
      expect(classifyIvsError(code: 401), IvsErrorKind.refreshToken);
    });

    test('a 404 on a playlist means the stream went offline', () {
      expect(
        classifyIvsError(
          errorType: 'ERROR',
          code: 404,
          source: 'MasterPlaylist',
        ),
        IvsErrorKind.offline,
      );
      expect(
        classifyIvsError(code: 404, source: 'media_playlist'),
        IvsErrorKind.offline,
      );
    });

    test('a 404 on a segment is recoverable', () {
      expect(
        classifyIvsError(code: 404, source: 'Segment'),
        IvsErrorKind.recoverable,
      );
    });

    test('invalid data from the decoder or renderer is fatal', () {
      expect(
        classifyIvsError(errorType: 'ERROR_INVALID_DATA', source: 'Decode'),
        IvsErrorKind.fatal,
      );
      expect(
        classifyIvsError(errorType: 'ERROR_INVALID_DATA', source: 'render'),
        IvsErrorKind.fatal,
      );
    });

    test('invalid data from the network is recoverable', () {
      expect(
        classifyIvsError(errorType: 'ERROR_INVALID_DATA', source: 'Segment'),
        IvsErrorKind.recoverable,
      );
    });
  });

  group('IvsRecoveryPolicy', () {
    late DateTime now;
    late IvsRecoveryPolicy policy;

    setUp(() {
      now = DateTime(2026, 10, 13, 12);
      policy = IvsRecoveryPolicy(now: () => now);
    });

    test('retries recoverable errors with 1/2/4 s backoff then falls back', () {
      final actions = [
        for (var i = 0; i < 4; i++) policy.onError(IvsErrorKind.recoverable),
      ];

      expect(actions[0], const IvsRecoveryAction.retry(Duration(seconds: 1)));
      expect(actions[1], const IvsRecoveryAction.retry(Duration(seconds: 2)));
      expect(actions[2], const IvsRecoveryAction.retry(Duration(seconds: 4)));
      expect(actions[3], const IvsRecoveryAction.fallback());
    });

    test('a refresh-token error retries with a fresh token', () {
      expect(
        policy.onError(IvsErrorKind.refreshToken),
        const IvsRecoveryAction.retry(Duration(seconds: 1), freshToken: true),
      );
    });

    test('attempts outside the rolling window are forgotten', () {
      for (var i = 0; i < 3; i++) {
        policy.onError(IvsErrorKind.recoverable);
      }
      now = now.add(const Duration(seconds: 61));

      expect(
        policy.onError(IvsErrorKind.recoverable),
        const IvsRecoveryAction.retry(Duration(seconds: 1)),
      );
    });

    test('offline and fatal errors are never retried', () {
      expect(
        policy.onError(IvsErrorKind.offline),
        const IvsRecoveryAction.offline(),
      );
      expect(
        policy.onError(IvsErrorKind.fatal),
        const IvsRecoveryAction.fallback(),
      );
    });

    test('reset forgets previous attempts', () {
      for (var i = 0; i < 3; i++) {
        policy.onError(IvsErrorKind.recoverable);
      }
      policy.reset();

      expect(
        policy.onError(IvsErrorKind.recoverable),
        const IvsRecoveryAction.retry(Duration(seconds: 1)),
      );
    });

    test('attemptsInWindow and maxAttempts describe progress', () {
      expect(policy.maxAttempts, 3);
      policy.onError(IvsErrorKind.recoverable);
      policy.onError(IvsErrorKind.recoverable);

      expect(policy.attemptsInWindow, 2);
    });
  });

  group('isRetryableTokenError', () {
    test('network, timeout and 5xx errors are retryable', () {
      expect(isRetryableTokenError(const NetworkException('down')), isTrue);
      expect(isRetryableTokenError(const TimeoutException('slow')), isTrue);
      expect(
        isRetryableTokenError(async.TimeoutException('dart timeout')),
        isTrue,
      );
      expect(isRetryableTokenError(const ServerException('boom', 503)), isTrue);
    });

    test('a missing token (channel offline) is not retryable', () {
      expect(
        isRetryableTokenError(
          const ApiException('No playback access token (channel offline?)'),
        ),
        isFalse,
      );
      expect(isRetryableTokenError(const ServerException('bad', 400)), isFalse);
      expect(isRetryableTokenError(StateError('bug')), isFalse);
    });
  });
}
