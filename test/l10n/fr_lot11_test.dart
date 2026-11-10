import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/app_localizations.dart';

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('the emote change lines read naturally in French', () {
    expect(
      fr.chatSevenTvEmoteRenamed(name: 'Ana', old: 'KEKW', emote: 'LUL'),
      'Ana a renommé l’emote 7TV « KEKW » en « LUL »',
    );
    expect(
      fr.chatSevenTvEmoteSetSwitched(name: 'Ana', set: 'Été'),
      'Ana a remplacé les emotes 7TV de la chaîne par l’ensemble '
      '« Été »',
    );
    expect(
      fr.chatBttvEmoteAdded(emote: 'catJAM'),
      'L’emote BTTV « catJAM » a été ajoutée au chat',
    );
    expect(
      fr.chatBttvEmoteRemoved(emote: 'catJAM'),
      'L’emote BTTV « catJAM » a été retirée du chat',
    );
    expect(
      fr.chatBttvEmoteRenamed(old: 'a', emote: 'b'),
      'L’emote BTTV « a » a été renommée « b »',
    );
    expect(fr.chatSevenTvSomeone, 'Quelqu’un');
  });

  test('the new emote kinds are named in both languages', () {
    expect(fr.emoteTypeName(type: 'sevenTVPersonal'), 'Emote personnelle 7TV');
    expect(
      fr.emoteTypeName(type: 'bttvPersonal'),
      'Emote personnelle BetterTTV',
    );
    expect(en.emoteTypeName(type: 'sevenTVPersonal'), '7TV personal emote');
    expect(en.emoteTypeName(type: 'bttvPersonal'), 'BetterTTV personal emote');
  });

  test('the new settings are worded in French', () {
    expect(fr.settingsShow7tvBadges, 'Afficher les badges 7TV');
    expect(fr.settingsShow7tvPaints, 'Afficher les peintures de pseudo 7TV');
    expect(
      fr.settingsShowFfzRoomBadges,
      'Afficher les badges de modérateur et de VIP FFZ de la chaîne',
    );
    expect(
      fr.settingsShowEmoteChangeNoticesSubtitle,
      'Quand la chaîne ajoute, retire ou renomme une emote 7TV ou BTTV.',
    );
  });
}
