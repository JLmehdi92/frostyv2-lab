import 'package:onset/models/community_highlights.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/utils/irc_privmsg_builder.dart';

/// A pinned chat message as the [IRCMessage] live chat would have shown,
/// so it renders with the same badges, colour and emotes (Twitch emotes
/// from its fragments, 7TV/BTTV/FFZ words from the chat assets).
IRCMessage pinnedToIrcMessage(
  PinnedChatMessage pin, {
  required String channelId,
  required String channelLogin,
  String? viewerLogin,
}) => buildPrivmsgIrcMessage(
  fragments: pin.fragments.isEmpty
      ? [(text: pin.text, emoteId: null)]
      : [for (final f in pin.fragments) (text: f.text, emoteId: f.emoteId)],
  login: pin.senderLogin,
  displayName: pin.senderDisplayName,
  userId: pin.senderId,
  color: pin.color,
  badges: [
    for (final badge in pin.badges)
      (setId: badge.setId, version: badge.version),
  ],
  id: 'pin-${pin.messageId ?? pin.id}',
  channelId: channelId,
  channelLogin: channelLogin,
  sentAt: pin.startsAt ?? DateTime.now().toUtc(),
  viewerLogin: viewerLogin,
);
