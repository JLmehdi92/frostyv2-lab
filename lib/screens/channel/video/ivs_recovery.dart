import 'dart:async' as async;

import 'package:onset/apis/base_api_client.dart';

/// How the IVS player should react to a native player error.
enum IvsErrorKind {
  /// Transient (network, timeout, unknown): reload with a new usher URL.
  recoverable,

  /// The playback token was rejected: reload with a freshly fetched token.
  refreshToken,

  /// The stream is gone (offline / ended): show the offline state.
  offline,

  /// The device cannot play this stream at all: use the WebView engine.
  fatal,
}

/// Classifies an IVS `PlayerException` forwarded by `IvsPlayerCore`.
///
/// [errorType] is the `ErrorType` enum name, [code] the HTTP-ish error code
/// and [source] the IVS error source (e.g. `MasterPlaylist`, `Segment`,
/// `Decode`). Anything unknown is treated as recoverable; the retry budget of
/// [IvsRecoveryPolicy] still bounds it.
IvsErrorKind classifyIvsError({String? errorType, int? code, String? source}) {
  final src = (source ?? '').toLowerCase();

  if (errorType == 'ERROR_AUTHORIZATION' || code == 401 || code == 403) {
    return IvsErrorKind.refreshToken;
  }
  if (errorType == 'ERROR_NOT_AVAILABLE' ||
      (code == 404 && src.contains('playlist'))) {
    return IvsErrorKind.offline;
  }
  switch (errorType) {
    case 'ERROR_NOT_SUPPORTED':
    case 'ERROR_NO_SOURCE':
    case 'ERROR_INVALID_PARAMETER':
    case 'ERROR_INVALID_STATE':
      return IvsErrorKind.fatal;
    case 'ERROR_INVALID_DATA':
      return src.contains('decode') || src.contains('render')
          ? IvsErrorKind.fatal
          : IvsErrorKind.recoverable;
    default:
      return IvsErrorKind.recoverable;
  }
}

/// What to do after an error, as decided by [IvsRecoveryPolicy].
sealed class IvsRecoveryAction {
  const IvsRecoveryAction();

  /// Reload after [delay]; fetch a new playback token when [freshToken].
  const factory IvsRecoveryAction.retry(Duration delay, {bool freshToken}) =
      IvsRetry;

  /// Show the offline state instead of retrying.
  const factory IvsRecoveryAction.offline() = IvsOffline;

  /// Give up on IVS and fall back to the WebView engine.
  const factory IvsRecoveryAction.fallback() = IvsFallback;
}

final class IvsRetry extends IvsRecoveryAction {
  const IvsRetry(this.delay, {this.freshToken = false});

  final Duration delay;

  /// The token was rejected: the reload must bypass any cached token.
  final bool freshToken;

  @override
  bool operator ==(Object other) =>
      other is IvsRetry &&
      other.delay == delay &&
      other.freshToken == freshToken;

  @override
  int get hashCode => Object.hash(delay, freshToken);

  @override
  String toString() => 'IvsRetry($delay, freshToken: $freshToken)';
}

final class IvsOffline extends IvsRecoveryAction {
  const IvsOffline();

  @override
  bool operator ==(Object other) => other is IvsOffline;

  @override
  int get hashCode => (IvsOffline).hashCode;
}

final class IvsFallback extends IvsRecoveryAction {
  const IvsFallback();

  @override
  bool operator ==(Object other) => other is IvsFallback;

  @override
  int get hashCode => (IvsFallback).hashCode;
}

/// Bounded retry policy: each retry waits for the next [backoff] delay, and
/// once every delay was used inside the rolling [window] the player falls
/// back to the WebView engine. A stream that keeps flapping therefore always
/// ends in a fallback instead of looping forever.
class IvsRecoveryPolicy {
  IvsRecoveryPolicy({
    this.backoff = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
    this.window = const Duration(seconds: 60),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final List<Duration> backoff;
  final Duration window;
  final DateTime Function() _now;
  final _attempts = <DateTime>[];

  int get maxAttempts => backoff.length;

  int get attemptsInWindow {
    _prune();
    return _attempts.length;
  }

  IvsRecoveryAction onError(IvsErrorKind kind) {
    switch (kind) {
      case IvsErrorKind.offline:
        return const IvsRecoveryAction.offline();
      case IvsErrorKind.fatal:
        return const IvsRecoveryAction.fallback();
      case IvsErrorKind.recoverable:
      case IvsErrorKind.refreshToken:
        _prune();
        if (_attempts.length >= backoff.length) {
          return const IvsRecoveryAction.fallback();
        }
        final delay = backoff[_attempts.length];
        _attempts.add(_now());
        return IvsRecoveryAction.retry(
          delay,
          freshToken: kind == IvsErrorKind.refreshToken,
        );
    }
  }

  /// Delay before the [attempt]-th (0-based) token fetch retry, or null when
  /// the budget is exhausted.
  Duration? tokenRetryDelay(int attempt) =>
      attempt < backoff.length ? backoff[attempt] : null;

  void reset() => _attempts.clear();

  void _prune() {
    final cutoff = _now().subtract(window);
    _attempts.removeWhere((t) => t.isBefore(cutoff));
  }
}

/// Whether a failed playback-token / usher request is worth retrying.
///
/// A missing token (channel offline) or a client error is not.
bool isRetryableTokenError(Object error) => switch (error) {
  NetworkException() || TimeoutException() => true,
  ServerException(:final statusCode?) => statusCode >= 500,
  async.TimeoutException() => true,
  _ => false,
};
