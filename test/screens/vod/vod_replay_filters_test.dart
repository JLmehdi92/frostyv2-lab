import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/screens/vod/vod_replay_filters.dart';

IRCMessage _msg(String user, String text) => IRCMessage.fromString(
  '@display-name=$user;id=1 :$user!$user@$user.tmi.twitch.tv '
  'PRIVMSG #streamer :$text',
);

bool _hidden(
  IRCMessage m, {
  List<String> blocked = const [],
  List<String> muted = const [],
  bool wholeWord = true,
  String? viewerLogin,
}) => isReplayCommentHidden(
  m,
  blockedLogins: blocked,
  mutedWords: muted,
  matchWholeWord: wholeWord,
  viewerLogin: viewerLogin,
  channelLogin: 'streamer',
);

void main() {
  test('a message from a blocked user is hidden', () {
    expect(_hidden(_msg('troll', 'hi'), blocked: ['troll']), isTrue);
    expect(_hidden(_msg('friend', 'hi'), blocked: ['troll']), isFalse);
  });

  test('the channel owner sees blocked users, like live chat', () {
    expect(
      _hidden(_msg('troll', 'hi'), blocked: ['troll'], viewerLogin: 'streamer'),
      isFalse,
    );
  });

  test('a whole muted word hides the message, case-insensitively', () {
    expect(
      _hidden(_msg('a', 'that is SPOILER here'), muted: ['spoiler']),
      isTrue,
    );
    expect(_hidden(_msg('a', 'spoilers here'), muted: ['spoiler']), isFalse);
  });

  test(
    'without whole-word matching a muted word hides any message with it',
    () {
      expect(
        _hidden(
          _msg('a', 'spoilers here'),
          muted: ['Spoiler'],
          wholeWord: false,
        ),
        isTrue,
      );
      expect(
        _hidden(_msg('a', 'all good'), muted: ['spoiler'], wholeWord: false),
        isFalse,
      );
    },
  );

  test('an empty muted word hides nothing', () {
    expect(_hidden(_msg('a', 'hi'), muted: [''], wholeWord: false), isFalse);
  });
}
