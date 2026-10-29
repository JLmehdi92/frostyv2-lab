import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/services/notifications/activity_log.dart';
import 'package:frosty/services/notifications/notice_ids.dart';
import 'package:frosty/stores/whisper_store.dart';

/// A chat message that mentions the viewer.
typedef ChatMention = ({
  String messageId,
  String channelId,
  String channelLogin,
  String channelName,
  String fromName,
  String text,
});

/// The notice posted for a [ChatMention].
typedef MentionNotice = ({
  String messageId,
  String channelId,
  String channelLogin,
  String title,
  String body,
});

/// At most one mention notice per channel in this window.
const kMentionThrottle = Duration(seconds: 30);

/// The message is cut beyond this many characters.
const kMentionMaxLength = 200;

/// The mention to notify in [message], or null: a live chat message (not
/// one of the recent messages loaded on joining) from someone else that
/// names the logged-in viewer ([ownLogin]), as the chat highlights it.
ChatMention? chatMentionOf(
  IRCMessage message, {
  required String? ownLogin,
  required String channelId,
  required String channelLogin,
  required String channelName,
}) {
  final text = message.message;
  if (ownLogin == null ||
      message.command != Command.privateMessage ||
      message.mention != true ||
      text == null ||
      message.tags['historical'] == '1' ||
      message.user?.toLowerCase() == ownLogin.toLowerCase()) {
    return null;
  }
  final from = message.tags['display-name'];
  return (
    messageId: message.tags['id'] ?? '${message.tags['tmi-sent-ts']}',
    channelId: channelId,
    channelLogin: channelLogin,
    channelName: channelName,
    fromName: from == null || from.isEmpty ? message.user ?? '' : from,
    text: text,
  );
}

/// The chat's hook: hands [message] to [alerts] when it mentions the
/// viewer and mention notices are [enabled]. Null when nothing was handed
/// over, else whether a notice was posted.
Future<bool?> alertChatMention(
  IRCMessage message, {
  required bool enabled,
  required String? ownLogin,
  required String channelId,
  required String channelLogin,
  required String channelName,
  required MentionAlerts alerts,
}) async {
  if (!enabled) return null;
  final mention = chatMentionOf(
    message,
    ownLogin: ownLogin,
    channelId: channelId,
    channelLogin: channelLogin,
    channelName: channelName,
  );
  if (mention == null) return null;
  return alerts.onMention(mention);
}

String _oneLine(String text, {int max = kMentionMaxLength}) {
  final line = whisperPreview(text);
  return line.length <= max ? line : '${line.substring(0, max)}…';
}

/// What a tapped mention notice does.
enum MentionTap {
  /// The channel is the page on screen (the app was in the background):
  /// the app comes back to the front, nothing more.
  bringToFront,

  /// The channel is open under other pages: back to it.
  backToChannel,

  /// The channel is in the mini player: it is restored.
  restoreMini,

  /// The channel is not open (closed meanwhile, the app killed): it opens.
  openChannel,
}

/// What a tapped mention notice for [login]'s chat does: whether its
/// channel is [open], and [shown] (its page on top), and the channel in the
/// mini player ([miniLogin]).
MentionTap mentionTapFor(
  String login, {
  required bool open,
  required bool shown,
  String? miniLogin,
}) {
  if (open) return shown ? MentionTap.bringToFront : MentionTap.backToChannel;
  if (miniLogin?.toLowerCase() == login.toLowerCase()) {
    return MentionTap.restoreMini;
  }
  return MentionTap.openChannel;
}

/// The Activity entry of a mention notice posted [at].
ActivityEntry mentionEntry(MentionNotice notice, DateTime at) => ActivityEntry(
  id: 'mention:${notice.channelId}:${notice.messageId}',
  kind: ActivityKind.mention,
  title: notice.title,
  body: notice.body,
  login: notice.channelLogin,
  at: at,
);

/// The notification id of a channel's mention notice: one per channel, a
/// new mention replaces the last. Kept apart from the go-live ids (a
/// channel's id) and the go-live summary and problem notices (0 and 1).
int mentionNoticeId(String channelId) {
  final id = stableNoticeId('mention:$channelId');
  return id == int.tryParse(channelId) ? id ^ 1 : id;
}

/// Tells the viewer about mentions in a chat they are connected to while
/// the app is not in front (in the background, or in picture-in-picture),
/// at most once per channel per [throttle].
class MentionAlerts {
  MentionAlerts({
    required this.post,
    required this.inFront,
    this.throttle = kMentionThrottle,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Off until the app sets it up (and in tests).
  static MentionAlerts shared = MentionAlerts(
    post: (_) async {},
    inFront: () => true,
  );

  /// Shows the notice (and lists it); throws when it could not be shown.
  final Future<void> Function(MentionNotice notice) post;

  /// Whether the viewer has the app in front (no notice then).
  final bool Function() inFront;

  final Duration throttle;
  final DateTime Function() _now;

  final _lastByChannel = <String, DateTime>{};

  /// True when a notice was posted for [mention].
  Future<bool> onMention(ChatMention mention) async {
    if (inFront()) return false;
    final now = _now();
    final last = _lastByChannel[mention.channelId];
    if (last != null && now.difference(last) < throttle) return false;
    _lastByChannel[mention.channelId] = now;
    final from = _oneLine(mention.fromName, max: 25);
    try {
      await post((
        messageId: mention.messageId,
        channelId: mention.channelId,
        channelLogin: mention.channelLogin,
        title:
            '$from mentioned you in ${_oneLine(mention.channelName, max: 25)}',
        body: _oneLine(mention.text),
      ));
      return true;
    } catch (e) {
      debugPrint('Mention notice failed: $e');
      // Not shown: the next mention may try again.
      if (_lastByChannel[mention.channelId] == now) {
        _lastByChannel.remove(mention.channelId);
      }
      return false;
    }
  }
}

/// The app is in front: resumed. Picture-in-picture is inactive, the
/// background paused or hidden.
bool appInFront() =>
    WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

/// The mention notifications (Twitch's "Chat Mentions" category). The
/// plugin is set up by the go-live notices at launch.
abstract final class MentionNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'chat_mentions',
      'Chat Mentions',
      channelDescription:
          'When someone mentions you in a chat you are watching while ONSET '
          'is in the background',
      groupKey: 'frosty.mentions',
      category: AndroidNotificationCategory.message,
    ),
    iOS: DarwinNotificationDetails(threadIdentifier: 'chat_mentions'),
  );

  /// Whether notices can show (Android 13+ asks; the user may block them).
  static Future<bool> allowed() async {
    if (!Platform.isAndroid) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        true;
  }

  static Future<void> show(MentionNotice notice) => _plugin.show(
    id: mentionNoticeId(notice.channelId),
    title: notice.title,
    body: notice.body,
    notificationDetails: _details,
    // Not a bare login (not a go-live notice): tapping brings the chat
    // back, opening its channel only when it is not open (mentionTapFor).
    payload: 'mention:${notice.channelLogin}',
  );
}
