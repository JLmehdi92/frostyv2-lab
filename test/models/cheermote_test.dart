import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/cheermote.dart';

Map<String, Object?> _tier(int min, String color) => {
  'min_bits': min,
  'id': '$min',
  'color': color,
  'can_cheer': true,
  'show_in_bits_card': true,
  'images': {
    for (final theme in ['dark', 'light'])
      theme: {
        for (final kind in ['animated', 'static'])
          kind: {
            for (final scale in ['1', '1.5', '2', '3', '4'])
              scale:
                  'https://d3aqoihi2n8ty8.cloudfront.net/actions/cheer/$theme/$kind/$min/$scale.${kind == 'animated' ? 'gif' : 'png'}',
          },
      },
  },
};

final _response = {
  'data': [
    {
      'prefix': 'Cheer',
      'type': 'global_first_party',
      'order': 1,
      'tiers': [
        _tier(1, '#979797'),
        _tier(100, '#9c3ee8'),
        _tier(1000, '#1db2a5'),
      ],
    },
    {
      'prefix': '4Head',
      'tiers': [_tier(1, '#00ff00')],
    },
    {
      'prefix': 'ChannelPog',
      'type': 'channel_custom',
      'order': 1,
      'tiers': [_tier(1, '#ff0000')],
    },
  ],
};

void main() {
  final cheermotes = Cheermotes.fromHelix(_response);

  test('a cheer word picks the highest tier it reaches', () {
    final cheer = cheermotes.match('Cheer250')!;
    expect(cheer.amount, 250);
    expect(cheer.tier.minBits, 100);
    expect(cheer.tier.color, 0xFF9C3EE8);
    expect(
      cheer.tier.url(dark: true, animated: true),
      endsWith('dark/animated/100/2.gif'),
    );
    expect(
      cheer.tier.url(dark: false, animated: false),
      endsWith('light/static/100/2.png'),
    );
    expect(cheermotes.match('cheer1000')!.tier.minBits, 1000);
    expect(cheermotes.match('channelpog5')!.tier.minBits, 1);
    final head = cheermotes.match('4Head100')!;
    expect(head.prefix, '4Head');
    expect(head.amount, 100);
  });

  test('not a cheer', () {
    expect(cheermotes.match('Cheer'), isNull);
    expect(cheermotes.match('Cheer0'), isNull);
    expect(cheermotes.match('Kappa100'), isNull);
    expect(cheermotes.match('Cheer100x'), isNull);
    expect(cheermotes.match('100'), isNull);
    expect(cheermotes.match('Cheer99999999999'), isNull);
  });

  test('odd answers are skipped, not fatal', () {
    final odd = Cheermotes.fromHelix({
      'data': [
        {'prefix': 'NoTiers'},
        {'prefix': 7, 'tiers': []},
        {
          'prefix': 'BadImages',
          'tiers': [
            {'min_bits': 1, 'color': 'nope', 'images': 'x'},
          ],
        },
        {
          'prefix': 'Elsewhere',
          'tiers': [
            {
              'min_bits': 1,
              'color': '#00ff00',
              'images': {
                'dark': {
                  'animated': {'2': 'https://evil.example/x.gif'},
                  'static': {'2': 'https://evil.example/x.png'},
                },
              },
            },
          ],
        },
      ],
    });
    expect(odd.isEmpty, isTrue);
    expect(Cheermotes.fromHelix({'data': 'x'}).isEmpty, isTrue);
  });
}
