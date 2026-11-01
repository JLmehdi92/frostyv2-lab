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
  ApiErrorKind.userNotFound => l.apiErrorUserNotFound,
  ApiErrorKind.channelNotFound => l.apiErrorChannelNotFound,
  ApiErrorKind.categoryNotFound => l.apiErrorCategoryNotFound,
  ApiErrorKind.tokenProxyTimeout => l.apiErrorTokenProxyTimeout,
};

/// What [error], caught while loading something, says to a viewer in
/// [l]'s language:
/// - an [ApiException]: on an English screen, Twitch's own explanation when
///   it gave one (its words, shown as they are); else, and in any other
///   language (Twitch explains in English, its words stay in the logs), its
///   [ApiErrorKind] worded;
/// - a [SocketException] (no network under the API client): "Unable to
///   connect to Twitch";
/// - anything else: [fallback] (the screen's "Something went wrong
///   loading …"), else "An unexpected error occurred".
String apiErrorText(AppLocalizations l, Object error, {String? fallback}) =>
    switch (error) {
      ApiException(:final twitchMessage?)
          when l.localeName == 'en' && twitchMessage.trim().isNotEmpty =>
        twitchMessage,
      ApiException(:final kind, :final statusCode) => apiErrorKindText(
        l,
        kind,
        statusCode: statusCode,
      ),
      SocketException() => l.apiErrorUnableToConnect,
      _ => fallback ?? l.apiErrorUnexpected,
    };

/// What [error] says, after « Couldn't … » in chat: on an English screen
/// Twitch's own English words ([ApiException.message]), as the chat always
/// read; in another language its kind, worded ([apiErrorText]) and ended
/// as a sentence, then Twitch's explanation quoted when it gave a short
/// one (`chatTwitchReason`), the line ending as a sentence too: the words
/// in the language on screen come first, and Twitch's English never stands
/// alone. « Impossible de bannir. Requête non valide. Raison de Twitch :
/// « The user is already banned. » »
String chatErrorText(AppLocalizations l, ApiException error) {
  if (l.localeName == 'en') return error.message;
  // The worded kinds are captions of the error screens too, most of them
  // with no full stop: in a chat line they become a sentence.
  final kind = asSentence(apiErrorText(l, error));
  final reason = error.twitchMessage?.trim();
  if (reason == null ||
      reason.isEmpty ||
      reason.length > maxQuotedTwitchReason ||
      reason.contains('\n')) {
    return kind;
  }
  final quoted = l.chatTwitchReason(reason: reason);
  // No full stop after the closing quote when the quote ends a sentence.
  return '$kind ${endsSentence(reason) ? quoted : '$quoted.'}';
}

/// Whether [text] ends with a sentence's closing punctuation (. ! ? …).
bool endsSentence(String text) => RegExp(r'[.!?…]$').hasMatch(text.trimRight());

/// [text] ended as a sentence: as it is when it already ends with closing
/// punctuation ([endsSentence]), else with a full stop.
String asSentence(String text) {
  final trimmed = text.trimRight();
  if (trimmed.isEmpty || endsSentence(trimmed)) return trimmed;
  return '$trimmed.';
}

/// The longest explanation of Twitch's [chatErrorText] quotes after the
/// worded kind: a longer one would bury the line, and stays in the logs.
const maxQuotedTwitchReason = 120;
