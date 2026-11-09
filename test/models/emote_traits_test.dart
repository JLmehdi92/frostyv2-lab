import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/emote_traits.dart';

const _base = 'https://static-cdn.jtvnw.net/emoticons/v2';

void main() {
  test('reads the effect off a modified Twitch emote', () {
    const id = 'emotesv2_6a06e06a83a3442cb3784528d5d7c674';
    expect(emoteModifierOf('$_base/${id}_BW/default/dark/3.0'), 'BW');
    expect(emoteModifierOf('$_base/25_TK/default/dark/3.0'), 'TK');
    expect(emoteModifierOf('$_base/$id/default/dark/3.0'), isNull);
    expect(emoteModifierOf('$_base/25_ZZ/default/dark/3.0'), isNull);
    expect(emoteModifierOf('https://cdn.7tv.app/emote/x_BW/2x.webp'), isNull);
    expect(twitchEmoteIdOf('$_base/25/static/dark/3.0'), '25');
  });

  test('reads the Bits tier that unlocks an emote', () {
    expect(
      bitsThresholdFrom({
        'data': {
          'emote': {
            'bitsBadgeTierSummary': {'threshold': 1000, 'self': null},
          },
        },
      }),
      1000,
    );
    expect(
      bitsThresholdFrom({
        'data': {
          'emote': {'bitsBadgeTierSummary': null},
        },
      }),
      isNull,
    );
    expect(bitsThresholdFrom(null), isNull);
  });
}
