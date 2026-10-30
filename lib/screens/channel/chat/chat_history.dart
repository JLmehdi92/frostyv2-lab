import 'package:collection/collection.dart';
import 'package:onset/models/chat_history.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/utils/irc_privmsg_builder.dart';

final _twitchLogin = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

bool _never(String text) => false;

/// The chat lines of [history] (Twitch's `ChatHistory`), oldest first, as
/// live chat would have drawn them: the same IRC message model, so emotes
/// (Twitch, 7TV, BTTV, FFZ), badges, colours, mentions, replies, cheers and
/// GIFs render through the live code paths.
///
/// Every line is marked `historical=1`, which keeps it out of everything
/// that reacts to what happens now. A deleted message is shown deleted (as
/// a CLEARMSG leaves it), so the deleted-message reveal works on it.
///
/// Like the official app, a message without a sender is dropped, and so
/// are the messages of [hiddenUserIds] / [hiddenLogins] (blocked people)
/// and those [muted] hides.
List<IRCMessage> chatHistoryLines(
  Iterable<ChatHistoryMessage> history, {
  required String channelId,
  required String channelLogin,
  String? viewerLogin,
  Set<String> hiddenUserIds = const {},
  Set<String> hiddenLogins = const {},
  bool Function(String text)? muted,
}) {
  final isMuted = muted ?? _never;
  final hidden = {for (final login in hiddenLogins) login.toLowerCase()};
  final ordered = history.toList();
  // Oldest first whatever the order Twitch answers in; equal times keep
  // theirs (a stable sort).
  mergeSort(ordered, compare: (a, b) => a.sentAt.compareTo(b.sentAt));

  final lines = <IRCMessage>[];
  for (final message in ordered) {
    final sender = message.sender;
    final login = sender?.login;
    if (sender == null || login == null || !_twitchLogin.hasMatch(login)) {
      continue;
    }
    if (hidden.contains(login.toLowerCase()) ||
        (sender.id != null && hiddenUserIds.contains(sender.id))) {
      continue;
    }

    final fragments = [
      for (final fragment in message.fragments)
        (text: fragment.text, emoteId: fragment.emoteId),
    ];
    final gifs = <int, ({String id, String url})>{
      for (final (index, fragment) in message.fragments.indexed)
        index: ?fragment.gif,
    };
    final bits = message.fragments.fold(0, (sum, f) => sum + f.bits);

    final extraTags = <String, String>{
      'historical': '1',
      if (bits > 0) 'bits': '$bits',
      'source-room-id': ?message.sourceChannelId,
    };

    // A reply shows its parent above it, and hides its own first word, the
    // parent's @name, which live replies always start with.
    final parent = message.parent;
    final parentSender = parent?.sender;
    final parentLogin = parentSender?.login;
    final parentText = parent?.text;
    if (parent != null &&
        parentText != null &&
        parentLogin != null &&
        _twitchLogin.hasMatch(parentLogin)) {
      final parentName = (parentSender?.displayName ?? '').isEmpty
          ? parentLogin
          : parentSender!.displayName!;
      extraTags.addAll({
        'reply-parent-msg-id': parent.id,
        'reply-parent-msg-body': parentText,
        'reply-parent-user-login': parentLogin.toLowerCase(),
        'reply-parent-display-name': parentName,
        'reply-parent-user-id': ?parentSender?.id,
      });
      final text = fragments.map((f) => f.text).join();
      final firstWord = text.split(' ').first.toLowerCase();
      if (firstWord != '@${parentLogin.toLowerCase()}' &&
          firstWord != '@${parentName.toLowerCase()}') {
        fragments.insert(0, (
          text: '@${parentLogin.toLowerCase()} ',
          emoteId: null,
        ));
        // The GIFs move one fragment along.
        final moved = {
          for (final MapEntry(:key, :value) in gifs.entries) key + 1: value,
        };
        gifs
          ..clear()
          ..addAll(moved);
      }
      final thread = message.threadParent;
      final threadLogin = thread?.sender?.login;
      if (thread != null && threadLogin != null) {
        extraTags.addAll({
          'reply-thread-parent-msg-id': thread.id,
          'reply-thread-parent-user-login': threadLogin.toLowerCase(),
          'reply-thread-parent-display-name':
              thread.sender?.displayName ?? threadLogin,
        });
      }
    }

    final line = buildPrivmsgIrcMessage(
      fragments: fragments,
      login: login,
      displayName: sender.displayName,
      id: message.id,
      channelId: channelId,
      channelLogin: channelLogin,
      sentAt: message.sentAt,
      userId: sender.id,
      color: message.color,
      badges: message.badges,
      viewerLogin: viewerLogin,
      extraTags: extraTags,
      gifs: gifs,
    );
    final text = line.message;
    if (text != null && isMuted(text)) continue;
    if (message.deleted) line.command = Command.clearMessage;
    lines.add(line);
  }
  return lines;
}

/// The lines of [history] not already in [shown] (by message id), each
/// once: a line seen live while the history was on its way is not shown
/// twice. Lines without an id are always kept.
List<IRCMessage> newHistoryLines(
  List<IRCMessage> history, {
  required Iterable<IRCMessage> shown,
}) {
  final seen = {for (final message in shown) ?message.tags['id']};
  final fresh = <IRCMessage>[];
  for (final message in history) {
    final id = message.tags['id'];
    if (id == null || seen.add(id)) fresh.add(message);
  }
  return fresh;
}

/// Puts the new lines of [history] at the top of [messages] in one
/// insert, above everything shown, and returns them.
///
/// In the chat's reversed list, lines added above the newest ones do not
/// move what is on screen: a chat pinned to its newest line stays pinned,
/// a chat scrolled up stays where it is.
List<IRCMessage> insertHistory(
  List<IRCMessage> messages,
  List<IRCMessage> history, {
  Iterable<IRCMessage> alsoShown = const [],
}) {
  final fresh = newHistoryLines(history, shown: messages.followedBy(alsoShown));
  if (fresh.isNotEmpty) messages.insertAll(0, fresh);
  return fresh;
}
