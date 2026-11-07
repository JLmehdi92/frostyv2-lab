import 'package:collection/collection.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';

bool changesOwnEmotes(IRCMessage message, {required String? ownUserId}) {
  if (ownUserId == null ||
      message.command != Command.userNotice ||
      message.tags['historical'] == '1') {
    return false;
  }
  final tags = message.tags;
  return switch (tags['msg-id']) {
    'sub' ||
    'resub' ||
    'extendsub' ||
    'giftpaidupgrade' ||
    'anongiftpaidupgrade' ||
    'primepaidupgrade' => tags['user-id'] == ownUserId,
    'subgift' || 'anonsubgift' => tags['msg-param-recipient-id'] == ownUserId,
    _ => false,
  };
}

bool emoteSetsChanged(String? before, String? after) =>
    before != null &&
    after != null &&
    !const SetEquality<String>().equals(
      before.split(',').toSet(),
      after.split(',').toSet(),
    );

bool hasAnimatedEmote(IRCMessage message, Map<String, Emote> emotes) {
  final text = message.message;
  if (message.command != Command.privateMessage ||
      text == null ||
      message.tags['historical'] == '1') {
    return false;
  }
  return text.split(' ').any((word) => emotes[word]?.animated ?? false);
}
