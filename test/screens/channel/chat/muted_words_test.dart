import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/chat/muted_words.dart';

void main() {
  test('substring mode matches inside words, ignoring case', () {
    expect(isMuted('What a SPOILER here', ['spoil'], wholeWord: false), isTrue);
    expect(isMuted('nothing to see', ['spoil'], wholeWord: false), isFalse);
    // Not character by character: a muted word of several letters works.
    expect(isMuted('ending', ['end'], wholeWord: false), isTrue);
    expect(isMuted('e n d', ['end'], wholeWord: false), isFalse);
  });

  test('whole word mode ignores parts of words and punctuation', () {
    expect(isMuted('the ending was great', ['end'], wholeWord: true), isFalse);
    expect(isMuted('the end.', ['end'], wholeWord: true), isTrue);
    expect(isMuted('(END) of it', ['end'], wholeWord: true), isTrue);
    expect(isMuted('bad word here', ['bad word'], wholeWord: true), isTrue);
    expect(isMuted('badword here', ['bad word'], wholeWord: true), isFalse);
  });

  test('blank muted words never match', () {
    expect(isMuted('anything', ['', '  '], wholeWord: false), isFalse);
    expect(isMuted('anything', ['', '  '], wholeWord: true), isFalse);
  });

  test('whole words with punctuation still match (bot commands, links)', () {
    expect(isMuted('!sr never gonna', ['!sr'], wholeWord: true), isTrue);
    expect(
      isMuted('go to twitch.tv now', ['twitch.tv'], wholeWord: true),
      isTrue,
    );
    expect(isMuted('nice :D', [':D'], wholeWord: true), isTrue);
    expect(isMuted('i <3 you', ['<3'], wholeWord: true), isTrue);
    // Still whole: not inside a longer token.
    expect(isMuted('!srs please', ['!sr'], wholeWord: true), isFalse);
    expect(isMuted('xtwitch.tv', ['twitch.tv'], wholeWord: true), isFalse);
  });
}
