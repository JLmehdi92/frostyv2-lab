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

  test('English says what the API client always said, for every kind', () {
    // The messages ApiException carried before it had a kind: the screens
    // read the same in English.
    const said = {
      ApiErrorKind.network:
          'No internet connection. Please check your network.',
      ApiErrorKind.connectionTimeout: 'Connection timeout. Please try again.',
      ApiErrorKind.sendTimeout: 'Upload timeout. Please try again.',
      ApiErrorKind.receiveTimeout: 'Server response timeout. Please try again.',
      ApiErrorKind.cancelled: 'Request was cancelled',
      ApiErrorKind.certificate: 'Security certificate error',
      ApiErrorKind.unknown: 'An unexpected error occurred',
      ApiErrorKind.badRequest: 'Invalid request data',
      ApiErrorKind.unauthorized: 'Please log in to continue',
      ApiErrorKind.forbidden: 'Access denied. Insufficient permissions',
      ApiErrorKind.notFound: 'Resource not found',
      ApiErrorKind.conflict: 'Conflict with current state. Please refresh',
      ApiErrorKind.invalid: 'Invalid data provided',
      ApiErrorKind.rateLimited:
          'Rate limit exceeded. Please wait before trying again',
      ApiErrorKind.server: 'Server error. Please try again later',
      ApiErrorKind.unavailable: 'Service temporarily unavailable',
      ApiErrorKind.maintenance: 'Service maintenance. Please try again later',
      ApiErrorKind.serverTimeout: 'Server timeout. Please try again',
      ApiErrorKind.http: 'HTTP Error 418 occurred',
      // The app's own errors, as their messages always read.
      ApiErrorKind.userNotFound: 'User does not exist',
      ApiErrorKind.channelNotFound: 'Channel does not exist',
      ApiErrorKind.categoryNotFound: 'Category not found',
      ApiErrorKind.tokenProxyTimeout: 'Token proxy timeout',
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
      'Unable to connect to Twitch',
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
    const cases = [
      (ApiErrorKind.userNotFound, 'User does not exist'),
      (ApiErrorKind.channelNotFound, 'Channel does not exist'),
      (ApiErrorKind.categoryNotFound, 'Category not found'),
    ];
    for (final (kind, englishText) in cases) {
      final error = NotFoundException(englishText, null, kind);
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
    expect(apiErrorText(english, proxy), 'Token proxy timeout');
    expect(apiErrorText(french, proxy), french.apiErrorTokenProxyTimeout);
  });
}
