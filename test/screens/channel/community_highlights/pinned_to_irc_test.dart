import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/community_highlight_event.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/screens/channel/community_highlights/pinned_to_irc.dart';

import '../../../fixtures/community_highlights_payloads.dart';

void main() {
  test('a Hermes pin becomes a chat message with its badges and colour', () {
    final pin =
        (ChEvent.parse(
                  HighlightTopic.pinned,
                  hermesPinnedChatUpdatesV1PinMessage,
                )
                as PinEvent)
            .message;

    final message = pinnedToIrcMessage(
      pin,
      channelId: '1',
      channelLogin: 'chan',
    );

    expect(message.user, 'streamelements');
    expect(message.tags['display-name'], 'StreamElements');
    expect(message.tags['color'], '#5B99FF');
    expect(message.tags['badges'], 'moderator/1,bot-badge/1');
    expect(message.message, startsWith('Meta Is NIET'));
  });

  test('a GQL pin keeps its emote fragments as emote ranges', () {
    final pin = PinnedChatMessage.fromGql({
      'id': 'p',
      'pinnedMessage': {
        'id': 'm',
        'content': {
          'text': 'gg Kappa',
          'fragments': [
            {'text': 'gg ', 'content': null},
            {
              'text': 'Kappa',
              'content': {'__typename': 'Emote', 'emoteID': '25'},
            },
          ],
        },
        'sender': {'id': '7', 'login': 'mod', 'displayName': 'Mod'},
      },
    })!;

    final message = pinnedToIrcMessage(
      pin,
      channelId: '1',
      channelLogin: 'chan',
    );

    expect(message.message, 'gg Kappa');
    expect(message.tags['emotes'], '25:3-7');
  });

  test('the GQL sample pin parses back', () {
    final edge =
        ((jsonDecode(gqlGetPinnedChat0)
                        as Map)['data']['channel']['pinnedChatMessages']['edges']
                    as List)
                .first
            as Map;
    final message = pinnedToIrcMessage(
      PinnedChatMessage.fromGql(edge['node'])!,
      channelId: '145972905',
      channelLogin: 'sondergaardlol',
    );
    expect(message.user, 'nightbot');
    expect(message.message, contains('boozt.com'));
  });
}
