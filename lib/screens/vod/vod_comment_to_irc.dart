import 'package:frosty/models/irc.dart';
import 'package:frosty/models/vod_comment.dart';
import 'package:frosty/utils/irc_privmsg_builder.dart';

/// Turns a replayed chat comment into the [IRCMessage] live chat would have
/// produced, so it renders through the same pipeline (see
/// [buildPrivmsgIrcMessage]).
IRCMessage vodCommentToIrcMessage(
  VodComment comment, {
  required String channelId,
  required String channelLogin,
  required DateTime vodCreatedAt,
  String? viewerLogin,
}) => buildPrivmsgIrcMessage(
  fragments: [
    for (final fragment in comment.fragments)
      (text: fragment.text, emoteId: fragment.emoteId),
  ],
  login: comment.commenterLogin,
  displayName: comment.commenterDisplayName,
  userId: comment.commenterId,
  color: comment.color,
  badges: comment.badges,
  id:
      comment.id ??
      'vod-${comment.key.hashCode.toUnsigned(32).toRadixString(16)}',
  channelId: channelId,
  channelLogin: channelLogin,
  sentAt: vodCreatedAt.add(Duration(seconds: comment.offsetSeconds)),
  viewerLogin: viewerLogin,
);
