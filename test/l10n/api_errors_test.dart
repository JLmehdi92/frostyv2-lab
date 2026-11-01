import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/l10n/api_errors.dart';
import 'package:onset/l10n/l10n.dart';

import '../helpers/l10n.dart';

/// apiErrorText: what a failed request says, in each language.
void main() {
  final english = L10n.english;
  final french = lookupAppLocalizations(fr);

  test('English words every kind as a full sentence, in the app\'s style', () {
    // Each kind's English (docs/L10N.md, English style guide): "Couldn't",
    // no "Please", a full stop. ApiException.message keeps the API
    // client's words for the logs.
    const said = {
      ApiErrorKind.network: 'No internet connection. Check your network.',
      ApiErrorKind.connectionTimeout: 'The connection timed out. Try again.',
      ApiErrorKind.sendTimeout: 'Sending took too long. Try again.',
      ApiErrorKind.receiveTimeout:
          'Twitch took too long to respond. Try again.',
      ApiErrorKind.cancelled: 'The request was canceled.',
      ApiErrorKind.certificate:
          'Couldn’t verify Twitch’s security certificate.',
      ApiErrorKind.unknown: 'An unexpected error occurred.',
      ApiErrorKind.badRequest: 'The request wasn’t valid.',
      ApiErrorKind.unauthorized: 'Log in to continue.',
      ApiErrorKind.forbidden: 'Access denied: missing permissions.',
      ApiErrorKind.notFound: 'This content couldn’t be found.',
      ApiErrorKind.conflict:
          'This changed in the meantime. Refresh and try again.',
      ApiErrorKind.invalid: 'The data sent wasn’t valid.',
      ApiErrorKind.rateLimited:
          'Too many requests. Wait a moment, then try again.',
      ApiErrorKind.server: 'Twitch had a server error. Try again later.',
      ApiErrorKind.unavailable: 'Twitch is temporarily unavailable.',
      ApiErrorKind.maintenance: 'Twitch is under maintenance. Try again later.',
      ApiErrorKind.serverTimeout: 'Twitch’s server didn’t respond. Try again.',
      ApiErrorKind.http: 'HTTP error 418.',
      // The app's own errors.
      ApiErrorKind.userNotFound: 'This user doesn’t exist.',
      ApiErrorKind.channelNotFound: 'This channel doesn’t exist.',
      ApiErrorKind.categoryNotFound: 'Category not found.',
      ApiErrorKind.tokenProxyTimeout:
          'The ONSET token service didn’t respond in time.',
    };
    expect(said.keys.toSet(), ApiErrorKind.values.toSet());
    for (final MapEntry(key: kind, value: text) in said.entries) {
      expect(
        apiErrorKindText(english, kind, statusCode: 418),
        text,
        reason: kind.name,
      );
    }
  });

  test('French words every kind, each its own way', () {
    final texts = {
      for (final kind in ApiErrorKind.values)
        kind: apiErrorKindText(french, kind, statusCode: 418),
    };
    for (final MapEntry(key: kind, value: text) in texts.entries) {
      expect(text, isNot(apiErrorKindText(english, kind, statusCode: 418)));
      expect(text.trim(), isNotEmpty, reason: kind.name);
    }
    expect(texts.values.toSet(), hasLength(texts.length));
    expect(texts[ApiErrorKind.http], 'Erreur HTTP 418');
  });

  test('an error: Twitch\'s words, its kind, no connection, or the screen\'s '
      'own', () {
    const forbidden = ApiException(
      'Missing scope',
      403,
      null,
      ApiErrorKind.forbidden,
      'Missing scope',
    );
    expect(apiErrorText(french, forbidden), french.apiErrorForbidden);
    expect(apiErrorText(english, forbidden), 'Missing scope');
    expect(
      apiErrorText(french, const NotFoundException('Resource not found')),
      french.apiErrorNotFound,
    );
    expect(
      apiErrorText(french, const SocketException('down')),
      french.apiErrorUnableToConnect,
    );
    expect(
      apiErrorText(french, StateError('x'), fallback: 'Autre chose'),
      'Autre chose',
    );
    expect(apiErrorText(french, StateError('x')), french.apiErrorUnexpected);
    expect(
      apiErrorText(english, const SocketException('down')),
      'Couldn’t connect to Twitch.',
    );
  });

  test('Twitch\'s English stays off French screens, and in English a blank '
      'explanation falls back to the kind', () {
    for (final kind in ApiErrorKind.values) {
      final withWords = ApiException(
        'Invalid login names, emotes or ids',
        400,
        null,
        kind,
        'Invalid login names, emotes or ids',
      );
      // French: the kind, worded; Twitch's sentence is for the logs.
      expect(
        apiErrorText(french, withWords),
        apiErrorKindText(french, kind, statusCode: 400),
        reason: kind.name,
      );
      // English: Twitch's words, as before.
      expect(
        apiErrorText(english, withWords),
        'Invalid login names, emotes or ids',
        reason: kind.name,
      );
      for (final blank in ['', '   ', null]) {
        final bare = ApiException('x', 404, null, kind, blank);
        for (final l in [english, french]) {
          final text = apiErrorText(l, bare);
          expect(
            text,
            apiErrorKindText(l, kind, statusCode: 404),
            reason: '${kind.name} "$blank" ${l.localeName}',
          );
          expect(text.trim(), isNotEmpty);
        }
      }
    }
  });

  test('the app\'s own not-found errors say what was not found', () {
    // The API code's own message (for the logs), then what English shows.
    const cases = [
      (
        ApiErrorKind.userNotFound,
        'User does not exist',
        'This user doesn’t exist.',
      ),
      (
        ApiErrorKind.channelNotFound,
        'Channel does not exist',
        'This channel doesn’t exist.',
      ),
      (
        ApiErrorKind.categoryNotFound,
        'Category not found',
        'Category not found.',
      ),
    ];
    for (final (kind, logged, englishText) in cases) {
      final error = NotFoundException(logged, null, kind);
      expect(apiErrorText(english, error), englishText);
      expect(apiErrorText(french, error), apiErrorKindText(french, kind));
      expect(apiErrorText(french, error), isNot(french.apiErrorNotFound));
    }
    expect(french.apiErrorUserNotFound, 'Cet utilisateur n’existe pas');
    expect(french.apiErrorCategoryNotFound, 'Catégorie introuvable');
    const proxy = TimeoutException(
      'Token proxy timeout',
      ApiErrorKind.tokenProxyTimeout,
    );
    expect(
      apiErrorText(english, proxy),
      'The ONSET token service didn’t respond in time.',
    );
    expect(apiErrorText(french, proxy), french.apiErrorTokenProxyTimeout);
  });

  test('in chat, a French failure is a sentence; English reads as it '
      'always did', () {
    expect(asSentence('Requête non valide'), 'Requête non valide.');
    for (final ended in ['Réessayez.', 'Vraiment\u202f!', 'Ah\u202f?', 'Et…']) {
      expect(asSentence(ended), ended);
    }
    expect(asSentence('Fin.  '), 'Fin.');
    expect(asSentence(''), '');
    // Every kind, alone and with a short reason of Twitch's: a full stop
    // before the reason, and after its closing quote when its words have
    // none.
    for (final kind in ApiErrorKind.values) {
      for (final twitch in [null, 'Already done.', 'Not allowed']) {
        final error = ApiException('Logged words.', 400, null, kind, twitch);
        final line = chatErrorText(french, error);
        final worded = asSentence(apiErrorText(french, error));
        expect(endsSentence(worded), isTrue, reason: kind.name);
        expect(line, switch (twitch) {
          null => worded,
          'Not allowed' =>
            '$worded ${french.chatTwitchReason(reason: twitch)}.',
          _ => '$worded ${french.chatTwitchReason(reason: twitch)}',
        }, reason: '${kind.name} $twitch');
        // English: the logged words, exactly.
        expect(chatErrorText(english, error), 'Logged words.');
      }
    }
  });
}
