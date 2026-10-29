import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/screens/channel/chat/incoming_raid.dart';

import '../../../fixtures/irc_messages.dart';

IncomingRaid? _raid(String raw, {String channelId = '12345'}) =>
    IncomingRaid.fromNotice(
      IRCMessage.fromString(raw).notice!,
      channelId: channelId,
    );

void main() {
  test('a live raid on this channel: who, avatar, viewers', () {
    final raid = _raid(raidNotice)!;
    expect(raid.raiderName, 'Raider');
    expect(raid.raiderLogin, 'raider');
    expect(raid.viewers, 15);
    expect(
      raid.avatarUrl,
      'https://static-cdn.jtvnw.net/jtv_user_pictures/'
      'raider-profile_image-70x70.png',
    );
    expect(raid.raiderKey, 'raider');
  });

  test('history, another channel of a shared chat: no pin', () {
    expect(_raid(raidNotice.replaceFirst('@', '@historical=1;')), isNull);
    expect(_raid(raidNotice.replaceFirst('@', '@source-room-id=999;')), isNull);
    expect(
      _raid(raidNotice.replaceFirst('@', '@source-room-id=12345;')),
      isNotNull,
    );
  });

  test('not a raid: no pin; a picture that is not https: none', () {
    expect(_raid(raidNotice.replaceFirst('msg-id=raid', 'msg-id=sub')), isNull);
    final raid = _raid(
      raidNotice.replaceFirst('https://static-cdn', 'http://static-cdn'),
    )!;
    expect(raid.avatarUrl, isNull);
  });

  test("only Twitch's picture host; never a negative count", () {
    final elsewhere = _raid(
      raidNotice.replaceFirst(
        'https://static-cdn.jtvnw.net',
        'https://evil.example.com',
      ),
    )!;
    expect(elsewhere.avatarUrl, isNull);
    final negative = _raid(
      raidNotice.replaceFirst(
        'msg-param-viewerCount=15',
        'msg-param-viewerCount=-4',
      ),
    )!;
    expect(negative.viewers, 0);
  });
}
