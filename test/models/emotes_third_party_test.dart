import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/emotes.dart';

Map<String, dynamic> _ffz(String name, {bool? modifier, int? flags}) => {
  'name': name,
  'height': 28,
  'width': 28,
  'owner': {'display_name': 'Owner', 'name': 'owner'},
  'urls': {'1': 'https://cdn.frankerfacez.com/emote/1/1'},
  'modifier': ?modifier,
  'modifier_flags': ?flags,
};

void main() {
  test('an FFZ modifier is drawn over the emote before it', () {
    final emote = Emote.fromFFZ(
      EmoteFFZ.fromJson(_ffz('ffzX', modifier: true, flags: 3)),
      EmoteType.ffzGlobal,
    );
    expect(emote.zeroWidth, isTrue);
    expect(emote.modifierFlags, FfzModifier.hidden | FfzModifier.flipX);
    expect(emote.hidesItself, isTrue);
  });

  test('a plain FFZ emote is unchanged', () {
    final emote = Emote.fromFFZ(
      EmoteFFZ.fromJson(_ffz('WideHard', modifier: false, flags: 0)),
      EmoteType.ffzChannel,
    );
    expect(emote.zeroWidth, isFalse);
    expect(emote.modifierFlags, 0);
    final old = Emote.fromFFZ(
      EmoteFFZ.fromJson(_ffz('Old')),
      EmoteType.ffzChannel,
    );
    expect(old.zeroWidth, isFalse);
  });

  test('flags on an emote that is not a modifier are ignored', () {
    final emote = Emote.fromFFZ(
      EmoteFFZ.fromJson(_ffz('odd', modifier: false, flags: 3)),
      EmoteType.ffzChannel,
    );
    expect(emote.modifierFlags, 0);
  });

  test('BTTV and 7TV emotes keep their provider id', () {
    expect(
      Emote.fromBTTV(
        const EmoteBTTV('b1', 'catJAM'),
        EmoteType.bttvChannel,
      ).providerId,
      'b1',
    );
  });

  test('a renamed emote remembers its original code', () {
    const emote = Emote(
      name: 'catJAM',
      zeroWidth: false,
      url: 'https://cdn.betterttv.net/emote/b1/3x',
      type: EmoteType.bttvChannel,
      providerId: 'b1',
    );
    final renamed = emote.renamed('catDance');
    expect(renamed.name, 'catDance');
    expect(renamed.realName, 'catJAM');
    expect(renamed.providerId, 'b1');
    expect(renamed.url, emote.url);
    expect(renamed.renamed('catJAM').realName, isNull);
  });

  test('the new fields survive the recent emotes store', () {
    const emote = Emote(
      name: 'mine',
      zeroWidth: true,
      url: 'https://cdn.example/mine.webp',
      type: EmoteType.sevenTVPersonal,
      providerId: 'e1',
      modifierFlags: 2,
    );
    final back = Emote.fromJson(emote.toJson());
    expect(back.type, EmoteType.sevenTVPersonal);
    expect(back.providerId, 'e1');
    expect(back.modifierFlags, 2);
    expect(
      Emote.fromJson({
        'name': 'old',
        'zeroWidth': false,
        'url': 'u',
        'type': 'bttvChannel',
      }).modifierFlags,
      0,
    );
  });
}
