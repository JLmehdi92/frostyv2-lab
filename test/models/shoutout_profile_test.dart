import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/shoutout_profile.dart';

import '../fixtures/community_gql_payloads.dart';

void main() {
  test('reads the shouted-out channel with its recent categories', () {
    final profile = ShoutoutProfile.tryParse(shoutoutResponse)!;

    expect(profile.login, 'target');
    expect(profile.displayName, 'Target');
    expect(profile.profileImageUrl, startsWith('https://'));
    expect(profile.categories.map((c) => c.name), ['First Game', 'VALORANT']);
    expect(profile.nextStream, isNull);
    expect(profile.following, isNull);
  });

  test('reads the next scheduled stream unless it was cancelled', () {
    Map<String, Object?> withSegment(Map<String, Object?> segment) {
      final body = {
        'data': {
          'user': {
            'id': '2',
            'displayName': 'Target',
            'channel': {
              'name': 'target',
              'schedule': {'nextSegment': segment},
            },
          },
        },
      };
      return body;
    }

    final next = ShoutoutProfile.tryParse(
      withSegment({
        'startAt': '2026-11-10T18:00:00Z',
        'title': ' Ranked night ',
        'isCancelled': false,
        'categories': [
          {'displayName': 'VALORANT'},
        ],
      }),
    )!.nextStream!;
    expect(next.title, 'Ranked night');
    expect(next.startAt, DateTime.utc(2026, 11, 10, 18));
    expect(next.categories, ['VALORANT']);

    expect(
      ShoutoutProfile.tryParse(
        withSegment({'startAt': '2026-11-10T18:00:00Z', 'isCancelled': true}),
      )!.nextStream,
      isNull,
    );
  });

  test('a non-https image is dropped and a bad login refused', () {
    final body = {
      'data': {
        'user': {
          'id': '2',
          'displayName': 'T',
          'profileImageURL': 'http://example.com/a.png',
          'channel': {'name': 'target'},
        },
      },
    };
    expect(ShoutoutProfile.tryParse(body)!.profileImageUrl, isNull);

    final badLogin = {
      'data': {
        'user': {
          'id': '2',
          'displayName': 'T',
          'channel': {'name': '../x'},
        },
      },
    };
    expect(ShoutoutProfile.tryParse(badLogin), isNull);
    expect(ShoutoutProfile.tryParse({'errors': []}), isNull);
  });

  test('reads whether the viewer follows from the status answer', () {
    expect(
      ShoutoutProfile.followingIn(followingShoutoutStatusResponse),
      isTrue,
    );
    expect(
      ShoutoutProfile.followingIn(anonymousShoutoutStatusResponse),
      isNull,
    );
    expect(
      ShoutoutProfile.followingIn({
        'data': {
          'user': {
            'self': {'follower': null},
          },
        },
      }),
      isFalse,
    );
  });
}
