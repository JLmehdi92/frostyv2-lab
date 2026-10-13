import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/chat/chat_commands.dart';

void main() {
  test('messages and /me go out as they are', () {
    expect(parseChatCommand('hello'), isA<SendAsIs>());
    expect(parseChatCommand('/me waves'), isA<SendAsIs>());
    expect(parseChatCommand('.me waves'), isA<SendAsIs>());
    expect(parseChatCommand('...ok'), isA<SendAsIs>());
    expect(parseChatCommand('. hello'), isA<SendAsIs>());
  });

  test('/color takes a Twitch name or a hex', () {
    expect(
      (parseChatCommand('/color HotPink') as ColorCommand).color,
      'hot_pink',
    );
    expect(
      (parseChatCommand('/color blue_violet') as ColorCommand).color,
      'blue_violet',
    );
    expect(
      (parseChatCommand('/color #ff00aa') as ColorCommand).color,
      '#FF00AA',
    );
    expect(
      (parseChatCommand('/color ff00aa') as ColorCommand).color,
      '#FF00AA',
    );
    expect(parseChatCommand('/color purple'), isA<UnsupportedCommand>());
    expect(parseChatCommand('/color'), isA<UnsupportedCommand>());
  });

  test('/block and /unblock take one login', () {
    expect(
      (parseChatCommand('/block @SomeOne') as BlockCommand).login,
      'someone',
    );
    expect(
      (parseChatCommand('/unblock someone') as UnblockCommand).login,
      'someone',
    );
    expect(parseChatCommand('/block'), isA<UnsupportedCommand>());
    expect(parseChatCommand('/block a b'), isA<UnsupportedCommand>());
    expect(parseChatCommand('/block a-b'), isA<UnsupportedCommand>());
  });

  test('help, whispers, moderator and unknown commands', () {
    expect(parseChatCommand('/help'), isA<HelpCommand>());
    expect(
      (parseChatCommand('/w friend hi') as UnsupportedCommand).message,
      contains('Whispers'),
    );
    expect(
      (parseChatCommand('/ban someone') as UnsupportedCommand).message,
      contains('moderator'),
    );
    expect(
      (parseChatCommand('/dance') as UnsupportedCommand).message,
      contains('/help'),
    );
  });
}
