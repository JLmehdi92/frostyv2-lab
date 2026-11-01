import 'dart:io';

import 'package:onset/apis/base_api_client.dart';
import 'package:onset/l10n/l10n.dart';

/// What a request's [kind] of failure says to a viewer, in [l]'s language.
/// [statusCode] is the HTTP status, named by [ApiErrorKind.http].
String apiErrorKindText(
  AppLocalizations l,
  ApiErrorKind kind, {
  int? statusCode,
}) => switch (kind) {
  ApiErrorKind.network => l.apiErrorNetwork,
  ApiErrorKind.connectionTimeout => l.apiErrorConnectionTimeout,
  ApiErrorKind.sendTimeout => l.apiErrorSendTimeout,
  ApiErrorKind.receiveTimeout => l.apiErrorReceiveTimeout,
  ApiErrorKind.cancelled => l.apiErrorCancelled,
  ApiErrorKind.certificate => l.apiErrorCertificate,
  ApiErrorKind.unknown => l.apiErrorUnexpected,
  ApiErrorKind.badRequest => l.apiErrorBadRequest,
  ApiErrorKind.unauthorized => l.apiErrorUnauthorized,
  ApiErrorKind.forbidden => l.apiErrorForbidden,
  ApiErrorKind.notFound => l.apiErrorNotFound,
  ApiErrorKind.conflict => l.apiErrorConflict,
  ApiErrorKind.invalid => l.apiErrorInvalid,
  ApiErrorKind.rateLimited => l.apiErrorRateLimited,
  ApiErrorKind.server => l.apiErrorServer,
  ApiErrorKind.unavailable => l.apiErrorUnavailable,
  ApiErrorKind.maintenance => l.apiErrorMaintenance,
  ApiErrorKind.serverTimeout => l.apiErrorServerTimeout,
  ApiErrorKind.http => l.apiErrorHttp(status: statusCode ?? 500),
};

/// What [error], caught while loading something, says to a viewer in
/// [l]'s language:
/// - an [ApiException]: Twitch's own explanation when it gave one (its
///   words, shown as they are), else its [ApiErrorKind] worded;
/// - a [SocketException] (no network under the API client): "Unable to
///   connect to Twitch";
/// - anything else: [fallback] (the screen's "Something went wrong
///   loading …"), else "An unexpected error occurred".
String apiErrorText(AppLocalizations l, Object error, {String? fallback}) =>
    switch (error) {
      ApiException(:final twitchMessage?) => twitchMessage,
      ApiException(:final kind, :final statusCode) => apiErrorKindText(
        l,
        kind,
        statusCode: statusCode,
      ),
      SocketException() => l.apiErrorUnableToConnect,
      _ => fallback ?? l.apiErrorUnexpected,
    };
