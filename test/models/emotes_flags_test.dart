import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/emotes.dart';

void main() {
  test('a Twitch emote is animated when Helix lists the animated format', () {
    Emote twitch(Map<String, dynamic> json) => Emote.fromTwitch(
      EmoteTwitch.fromJson({'id': '1', 'name': 'catJAM', ...json}),
      EmoteType.twitchChannel,
    );
    expect(
      twitch({
        'format': ['static', 'animated'],
      }).animated,
      isTrue,
    );
    expect(
      twitch({
        'format': ['static'],
      }).animated,
      isFalse,
    );
    expect(twitch({}).animated, isFalse);
  });

  test('limited-time emotes are labelled from their emote type', () {
    Emote twitch(String type) => Emote.fromTwitch(
      EmoteTwitch.fromJson({'id': '1', 'name': 'x', 'emote_type': type}),
      EmoteType.twitchUnlocked,
    );
    expect(twitch('limitedtime').limitedTime, isTrue);
    expect(twitch('subscriptions').limitedTime, isFalse);
  });

  test('third-party emotes carry their own animated flag', () {
    expect(
      Emote.fromBTTV(
        const EmoteBTTV('a', 'catJAM', animated: true),
        EmoteType.bttvChannel,
      ).animated,
      isTrue,
    );
    expect(
      Emote.fromBTTV(
        const EmoteBTTV('a', 'still'),
        EmoteType.bttvChannel,
      ).animated,
      isFalse,
    );
    final seventv = Emote7TV.fromJson({
      'id': 'e',
      'name': 'pepeD',
      'data': {
        'id': 'e',
        'name': 'pepeD',
        'flags': 0,
        'animated': true,
        'host': {
          'url': '//cdn.7tv.app/emote/e',
          'files': [
            {'name': '1x.webp', 'width': 32, 'height': 32, 'format': 'WEBP'},
          ],
        },
      },
    });
    expect(Emote.from7TV(seventv, EmoteType.sevenTVChannel).animated, isTrue);
  });

  test('a saved recent emote keeps its flags, an old one reads as plain', () {
    const emote = Emote(
      name: 'catJAM',
      zeroWidth: false,
      url: 'https://cdn.example/catJAM.gif',
      type: EmoteType.sevenTVChannel,
      animated: true,
      limitedTime: true,
    );
    final restored = Emote.fromJson(emote.toJson());
    expect(restored.animated, isTrue);
    expect(restored.limitedTime, isTrue);
    final old = Emote.fromJson({
      'name': 'Kappa',
      'zeroWidth': false,
      'url': 'https://cdn.example/Kappa.png',
      'type': 'twitchGlobal',
    });
    expect(old.animated, isFalse);
    expect(old.limitedTime, isFalse);
  });
}
