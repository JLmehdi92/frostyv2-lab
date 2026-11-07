import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/emote_entitlements.dart';

IRCMessage _notice(String tags) => IRCMessage.fromString(
  '@$tags;room-id=1;system-msg=x :tmi.twitch.tv USERNOTICE #c',
);

void main() {
  test('own subs and gifts received change the viewer’s emotes', () {
    bool changes(String tags) =>
        changesOwnEmotes(_notice(tags), ownUserId: '1');
    expect(changes('msg-id=sub;user-id=1'), isTrue);
    expect(changes('msg-id=resub;user-id=1'), isTrue);
    expect(changes('msg-id=primepaidupgrade;user-id=1'), isTrue);
    expect(
      changes('msg-id=subgift;user-id=8;msg-param-recipient-id=1'),
      isTrue,
    );
    expect(changes('msg-id=sub;user-id=2'), isFalse);
    expect(
      changes('msg-id=subgift;user-id=1;msg-param-recipient-id=2'),
      isFalse,
    );
    expect(changes('msg-id=raid;user-id=1'), isFalse);
    expect(changes('msg-id=sub;user-id=1;historical=1'), isFalse);
    expect(
      changesOwnEmotes(_notice('msg-id=sub;user-id=1'), ownUserId: null),
      isFalse,
    );
  });

  test('emote sets change only when the set itself changes', () {
    expect(emoteSetsChanged(null, '0,1'), isFalse);
    expect(emoteSetsChanged('0,1', null), isFalse);
    expect(emoteSetsChanged('0,1', '1,0'), isFalse);
    expect(emoteSetsChanged('0,1', '0,1,2'), isTrue);
    expect(emoteSetsChanged('0,1,2', '0,1'), isTrue);
  });

  test('a message has an animated emote when one of its words is one', () {
    const emotes = {
      'catJAM': Emote(
        name: 'catJAM',
        zeroWidth: false,
        url: 'u',
        type: EmoteType.bttvChannel,
        animated: true,
      ),
      'still': Emote(
        name: 'still',
        zeroWidth: false,
        url: 'u',
        type: EmoteType.bttvChannel,
      ),
    };
    IRCMessage line(String text, {String tags = ''}) => IRCMessage.fromString(
      '@id=a;$tags :f!f@f.tmi.twitch.tv PRIVMSG #c :$text',
    );
    expect(hasAnimatedEmote(line('look catJAM'), emotes), isTrue);
    expect(hasAnimatedEmote(line('still here'), emotes), isFalse);
    expect(hasAnimatedEmote(line('catJAMs'), emotes), isFalse);
    expect(
      hasAnimatedEmote(line('catJAM', tags: 'historical=1;'), emotes),
      isFalse,
    );
  });
}
