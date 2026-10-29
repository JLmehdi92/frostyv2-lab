import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/channel_profile.dart';

import '../fixtures/channel_profile_payloads.dart';

Object? _user(String body) => (jsonDecode(body) as Map)['data']['user'];

void main() {
  group('profile', () {
    test('the captured profile', () {
      final profile = ChannelProfile.fromGql(_user(gqlChannelProfileXqc))!;

      expect(profile.id, '71092938');
      expect(profile.login, 'xqc');
      expect(profile.displayName, 'xQc');
      expect(profile.description, startsWith('THE BEST'));
      expect(profile.createdAt?.year, 2014);
      expect(profile.role, BroadcasterRole.partner);
      expect(profile.followers, greaterThan(1000000));
      expect(profile.accentColor, 0xFFFFBF00);
      expect(profile.bannerUrl, startsWith('https://static-cdn.jtvnw.net/'));
      expect(profile.offlineImageUrl, isNotNull);
      expect(profile.socials.map((s) => s.name), contains('discord'));
      // Extension panels carry nothing and are skipped.
      expect(profile.panels, isNotEmpty);
      expect(profile.panels.every((p) => p.id.isNotEmpty), isTrue);
      expect(
        profile.panels.any((p) => p.description?.contains('Félix') ?? false),
        isTrue,
      );
      expect(profile.lastBroadcast?.gameName, 'Grand Theft Auto V');
      expect(profile.live?.isRerun, isFalse);
      expect(profile.live?.viewers, greaterThan(0));
    });

    test('an unknown channel is null', () {
      expect(ChannelProfile.fromGql(_user(gqlChannelProfileNoUser)), isNull);
      expect(ChannelProfile.fromGql({'id': 'x', 'login': 'a'}), isNull);
      expect(ChannelProfile.fromGql({'id': '1', 'login': 'a b'}), isNull);
    });

    test('a bare channel still reads, offline and without extras', () {
      final profile = ChannelProfile.fromGql({'id': '1', 'login': 'someone'})!;
      expect(profile.displayName, 'someone');
      expect(profile.live, isNull);
      expect(profile.socials, isEmpty);
      expect(profile.panels, isEmpty);
      expect(profile.role, BroadcasterRole.none);
    });

    test('images only from Twitch hosts over https; links only http(s)', () {
      final profile = ChannelProfile.fromGql({
        'id': '1',
        'login': 'someone',
        'profileImageURL': 'https://evil.example/a.png',
        'bannerImageURL': 'http://static-cdn.jtvnw.net/b.png',
        'primaryColorHex': 'red',
        'channel': {
          'socialMedias': [
            {'name': 'X', 'title': 'X', 'url': 'javascript:alert(1)'},
            {'name': 'Site', 'title': 'Site', 'url': 'https://site.example/'},
          ],
        },
        'panels': [
          {
            'id': '1',
            'type': 'DEFAULT',
            'title': 'Rules',
            'imageURL': 'https://evil.example/p.png',
            'linkURL': 'intent://x',
          },
          {'id': '2', 'type': 'EXTENSION'},
          {'id': '3', 'type': 'DEFAULT'},
        ],
      })!;
      expect(profile.profileImageUrl, isNull);
      expect(profile.bannerUrl, isNull);
      for (final url in [
        'https://user:pw@static-cdn.jtvnw.net/a.png',
        'https://static-cdn.jtvnw.net:444/a.png',
        'https://static-cdn.jtvnw.net.evil.com/a.png',
      ]) {
        expect(
          ChannelProfile.fromGql({
            'id': '1',
            'login': 'someone',
            'profileImageURL': url,
          })!.profileImageUrl,
          isNull,
          reason: url,
        );
      }
      expect(profile.accentColor, isNull);
      expect(profile.socials.single.name, 'site');
      expect(profile.panels.single.title, 'Rules');
      expect(profile.panels.single.imageUrl, isNull);
      expect(profile.panels.single.linkUrl, isNull);
    });

    test('a rerun', () {
      final profile = ChannelProfile.fromGql({
        'id': '1',
        'login': 'someone',
        'stream': {'id': '9', 'type': 'rerun', 'viewersCount': '12'},
      })!;
      expect(profile.live?.isRerun, isTrue);
      expect(profile.live?.viewers, 12);
    });

    test('a live stream: when it started and what it plays', () {
      final profile = ChannelProfile.fromGql({
        'id': '1',
        'login': 'someone',
        'stream': {
          'id': '9',
          'type': 'live',
          'viewersCount': 963,
          'createdAt': '2026-10-28T21:47:06Z',
          'game': {'id': '32982', 'displayName': 'Grand Theft Auto V'},
        },
      })!;
      expect(profile.live?.startedAt, DateTime.utc(2026, 10, 28, 21, 47, 6));
      expect(profile.live?.gameName, 'Grand Theft Auto V');

      // Odd values are dropped, the stream still reads.
      final odd = ChannelProfile.fromGql({
        'id': '1',
        'login': 'someone',
        'stream': {
          'id': '9',
          'createdAt': 'soon',
          'game': {'displayName': 3},
        },
      })!;
      expect(odd.live, isNotNull);
      expect(odd.live?.startedAt, isNull);
      expect(odd.live?.gameName, isNull);
    });

    test('garbage never throws', () {
      for (final value in <Object?>[
        null,
        1,
        'x',
        <Object>[],
        {'id': 1},
        {
          'id': '1',
          'login': 'a',
          'panels': 'x',
          'channel': 3,
          'followers': {'totalCount': 'many'},
          'lastBroadcast': [],
          'stream': {'id': 5},
        },
      ]) {
        ChannelProfile.fromGql(value);
        ChannelSchedule.fromGql(value);
      }
    });
  });

  group('hostile values', () {
    test('over-long ids, logins and colours are refused, not cut', () {
      expect(
        ChannelProfile.fromGql({'id': '1' * 25, 'login': 'someone'}),
        isNull,
      );
      expect(ChannelProfile.fromGql({'id': '1', 'login': 'a' * 30}), isNull);
      final profile = ChannelProfile.fromGql({
        'id': '1',
        'login': 'someone',
        'primaryColorHex': '#ABCDEFZZZ',
        'lastBroadcast': {
          'title': 'x',
          'game': {'id': '1' * 30, 'displayName': 'Game'},
        },
      })!;
      expect(profile.accentColor, isNull);
      expect(profile.lastBroadcast?.gameId, isNull);
    });

    test('deep Markdown nesting is flattened to a few levels', () {
      String? describe(String text) => ChannelPanel.fromGql({
        'id': '1',
        'type': 'DEFAULT',
        'description': text,
      })?.description;

      final quotes = describe('${'>' * 4990} x')!;
      expect(quotes, startsWith('>>>>'));
      expect(quotes.substring(4), isNot(startsWith('>')));
      expect(describe('${'- ' * 2490}x'), startsWith('- - - - '));
      expect(describe('${'- ' * 2490}x')!.substring(8), startsWith(r'\-'));
      // Normal Markdown is untouched.
      expect(describe('> quote\n- item\n  - sub'), '> quote\n- item\n  - sub');
    });
  });

  group('schedule', () {
    Object? schedule() =>
        (_user(gqlChannelScheduleLirik)! as Map)['channel']['schedule'];

    test('the captured schedule, sorted, with the next start', () {
      final parsed = ChannelSchedule.fromGql(schedule());

      expect(parsed.segments, hasLength(6));
      expect(
        parsed.segments.map((s) => s.startAt),
        orderedEquals([...parsed.segments.map((s) => s.startAt)]..sort()),
      );
      expect(parsed.nextStartAt, DateTime.utc(2026, 10, 14, 16));
    });

    test('upcoming drops what is over', () {
      final parsed = ChannelSchedule.fromGql(schedule());
      final upcoming = parsed.upcoming(DateTime.utc(2026, 10, 14, 12));
      expect(upcoming.first.startAt, DateTime.utc(2026, 10, 14, 16));
      expect(upcoming, hasLength(3));
    });

    test('no schedule reads as empty', () {
      expect(ChannelSchedule.fromGql(null).segments, isEmpty);
      expect(
        ChannelSchedule.fromGql({'id': 's', 'segments': null}).segments,
        isEmpty,
      );
    });

    test('a cancelled segment and its category', () {
      final parsed = ChannelSchedule.fromGql({
        'segments': [
          {
            'id': 'a',
            'startAt': '2026-10-15T18:00:00Z',
            'endAt': '2026-10-15T22:00:00Z',
            'title': 'Ranked',
            'isCancelled': true,
            'categories': [
              {'id': '1', 'name': 'Chess'},
            ],
          },
          {'id': 'b'},
        ],
      });
      final segment = parsed.segments.single;
      expect(segment.isCancelled, isTrue);
      expect(segment.categoryName, 'Chess');
      expect(segment.title, 'Ranked');
    });
  });
}
