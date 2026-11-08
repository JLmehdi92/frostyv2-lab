import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/vod/vod_time.dart';

void main() {
  group('formatVodTime', () {
    test('uses M:SS under an hour and H:MM:SS above', () {
      expect(formatVodTime(Duration.zero), '0:00');
      expect(formatVodTime(const Duration(seconds: 59)), '0:59');
      expect(formatVodTime(const Duration(minutes: 1)), '1:00');
      expect(formatVodTime(const Duration(minutes: 59, seconds: 59)), '59:59');
      expect(formatVodTime(const Duration(hours: 1)), '1:00:00');
      expect(
        formatVodTime(const Duration(hours: 10, minutes: 2, seconds: 3)),
        '10:02:03',
      );
    });

    test('drops milliseconds and treats negatives as zero', () {
      expect(formatVodTime(const Duration(milliseconds: 1999)), '0:01');
      expect(formatVodTime(const Duration(seconds: -5)), '0:00');
    });
  });

  group('formatVodTimeForShare', () {
    test('writes the Twitch t= format', () {
      expect(
        formatVodTimeForShare(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1h2m3s',
      );
      expect(formatVodTimeForShare(const Duration(minutes: 5)), '5m0s');
      expect(formatVodTimeForShare(const Duration(seconds: 7)), '7s');
      expect(formatVodTimeForShare(const Duration(hours: 2)), '2h0m0s');
    });
  });

  group('parseGoToTime', () {
    test('reads h:mm:ss, m:ss and plain seconds', () {
      expect(
        parseGoToTime('1:02:03'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(
        parseGoToTime(' 12:34 '),
        const Duration(minutes: 12, seconds: 34),
      );
      expect(parseGoToTime('95'), const Duration(seconds: 95));
      expect(
        parseGoToTime('1h2m3s'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
    });

    test('refuses out-of-range parts and anything else', () {
      expect(parseGoToTime('1:60:00'), isNull);
      expect(parseGoToTime('1:00:60'), isNull);
      expect(parseGoToTime('12:345'), isNull);
      expect(parseGoToTime('::'), isNull);
      expect(parseGoToTime('abc'), isNull);
      expect(parseGoToTime(''), isNull);
    });
  });

  group('parseTwitchTimestamp', () {
    test('accepts the Twitch forms', () {
      expect(
        parseTwitchTimestamp('1h2m3s'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(
        parseTwitchTimestamp('01h02m03s'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(
        parseTwitchTimestamp('2m3s'),
        const Duration(minutes: 2, seconds: 3),
      );
      expect(parseTwitchTimestamp('3s'), const Duration(seconds: 3));
      expect(parseTwitchTimestamp('90'), const Duration(seconds: 90));
      expect(parseTwitchTimestamp('1h'), const Duration(hours: 1));
      expect(parseTwitchTimestamp('5m'), const Duration(minutes: 5));
      expect(parseTwitchTimestamp(' 1H5M '), const Duration(minutes: 65));
    });

    test('rejects anything else', () {
      for (final bad in [
        '',
        'abc',
        '1x',
        '-5',
        'h',
        '1h1h',
        '1s2m',
        '1.5s',
        '1h 2m',
        '99999999999999999999',
      ]) {
        expect(parseTwitchTimestamp(bad), isNull, reason: bad);
      }
    });

    test('rejects absurdly long timestamps', () {
      expect(parseTwitchTimestamp('1000h'), isNull);
      expect(parseTwitchTimestamp('999h'), const Duration(hours: 999));
      expect(parseTwitchTimestamp('9999999'), isNull);
      expect(parseTwitchTimestamp('3596400'), const Duration(hours: 999));
    });
  });

  group('formatTimeAgo', () {
    final now = DateTime.utc(2026, 10, 13, 12);
    String ago(Duration d) =>
        formatTimeAgo(now.subtract(d), L10n.english, now: now);

    test('reads like Twitch', () {
      expect(ago(const Duration(seconds: 20)), 'Just now');
      expect(ago(const Duration(minutes: 1)), '1 minute ago');
      expect(ago(const Duration(minutes: 5)), '5 minutes ago');
      expect(ago(const Duration(hours: 1)), '1 hour ago');
      expect(ago(const Duration(hours: 3)), '3 hours ago');
      expect(ago(const Duration(days: 1)), 'Yesterday');
      expect(ago(const Duration(days: 3)), '3 days ago');
      expect(ago(const Duration(days: 14)), '2 weeks ago');
      expect(ago(const Duration(days: 65)), '2 months ago');
      expect(ago(const Duration(days: 400)), '1 year ago');
      expect(ago(const Duration(days: 800)), '2 years ago');
    });

    test('a date in the future is just now', () {
      expect(
        formatTimeAgo(
          now.add(const Duration(minutes: 5)),
          L10n.english,
          now: now,
        ),
        'Just now',
      );
    });

    test('in French, "one" covering 0 and 1', () {
      final fr = lookupAppLocalizations(const Locale('fr'));
      String agoFr(Duration d) => formatTimeAgo(now.subtract(d), fr, now: now);
      expect(agoFr(const Duration(seconds: 20)), 'À l’instant');
      expect(agoFr(const Duration(minutes: 1)), 'Il y a 1\u00a0minute');
      expect(agoFr(const Duration(minutes: 5)), 'Il y a 5\u00a0minutes');
      expect(agoFr(const Duration(hours: 3)), 'Il y a 3\u00a0heures');
      expect(agoFr(const Duration(days: 1)), 'Hier');
      expect(agoFr(const Duration(days: 3)), 'Il y a 3\u00a0jours');
      expect(agoFr(const Duration(days: 14)), 'Il y a 2\u00a0semaines');
      expect(agoFr(const Duration(days: 65)), 'Il y a 2\u00a0mois');
      expect(agoFr(const Duration(days: 400)), 'Il y a 1\u00a0an');
      expect(agoFr(const Duration(days: 800)), 'Il y a 2\u00a0ans');
    });

    test('inside a sentence, its first letter in lower case', () {
      final fr = lookupAppLocalizations(const Locale('fr'));
      final day = now.subtract(const Duration(days: 3));
      expect(timeAgoInText(day, L10n.english, now: now), '3 days ago');
      expect(timeAgoInText(now, L10n.english, now: now), 'just now');
      expect(timeAgoInText(day, fr, now: now), 'il y a 3\u00a0jours');
      expect(timeAgoInText(now, fr, now: now), 'à l’instant');
    });
  });
}
