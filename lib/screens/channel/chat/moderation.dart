import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/channel/chat/chat_commands.dart';
import 'package:frosty/screens/channel/chat/moderation_notice.dart';

/// What a moderation action ended with: whether it worked, and the line to
/// show either way.
typedef ModerationOutcome = ({bool ok, String message});

/// Runs moderation commands in one chat, as one moderator (the broadcaster
/// is their own moderator), through Helix.
class ChatModeration {
  const ChatModeration({
    required this.api,
    required this.broadcasterId,
    required this.moderatorId,
  });

  final TwitchApi api;
  final String broadcasterId;
  final String moderatorId;

  /// Runs [command] and says how it went. Never throws.
  ///
  /// [userId] is the target's id when the caller already knows it (the user
  /// card), which saves looking the login up.
  Future<ModerationOutcome> run(
    ModerationCommand command, {
    String? userId,
  }) async {
    try {
      return (ok: true, message: await _run(command, userId));
    } catch (error, stack) {
      debugPrint('Moderation ${command.runtimeType} failed: $error');
      // A refusal or a network error is expected now and then; anything
      // else is a bug (or Twitch changed something).
      if (error is! ApiException) {
        try {
          FirebaseCrashlytics.instance.recordError(
            error,
            stack,
            reason: 'moderation ${command.runtimeType}',
          );
        } catch (_) {
          // Firebase may not be initialized (e.g., in tests).
        }
      }
      return (ok: false, message: moderationFailure(error, _verb(command)));
    }
  }

  Future<String> _run(ModerationCommand command, String? knownId) async {
    Future<({String id, String name})> target(String login) async {
      if (knownId != null) return (id: knownId, name: login);
      try {
        final user = await api.getUser(userLogin: login);
        return (id: user.id, name: user.displayName);
      } on NotFoundException catch (_, stack) {
        Error.throwWithStackTrace(
          NotFoundException('no user named $login'),
          stack,
        );
      }
    }

    switch (command) {
      case BanCommand(:final login, :final reason):
        final user = await target(login);
        await api.banUser(
          broadcasterId: broadcasterId,
          moderatorId: moderatorId,
          userId: user.id,
          reason: reason,
        );
        return 'You banned ${user.name}.';
      case TimeoutCommand(:final login, :final duration, :final reason):
        final user = await target(login);
        await api.banUser(
          broadcasterId: broadcasterId,
          moderatorId: moderatorId,
          userId: user.id,
          duration: duration,
          reason: reason,
        );
        return 'You timed out ${user.name} for '
            '${timeoutLength(duration.inSeconds)}.';
      case UnbanCommand(:final login, :final timeout):
        final user = await target(login);
        await api.unbanUser(
          broadcasterId: broadcasterId,
          moderatorId: moderatorId,
          userId: user.id,
        );
        return timeout
            ? 'You removed the timeout of ${user.name}.'
            : 'You unbanned ${user.name}.';
      case WarnCommand(:final login, :final reason):
        final user = await target(login);
        await api.warnUser(
          broadcasterId: broadcasterId,
          moderatorId: moderatorId,
          userId: user.id,
          reason: reason,
        );
        return 'You warned ${user.name}.';
      case DeleteMessageCommand(:final messageId):
        await api.deleteChatMessages(
          broadcasterId: broadcasterId,
          moderatorId: moderatorId,
          messageId: messageId,
        );
        return 'Message deleted.';
      case ClearChatCommand():
        await api.deleteChatMessages(
          broadcasterId: broadcasterId,
          moderatorId: moderatorId,
        );
        return 'You cleared the chat.';
      case ChatModeCommand(:final mode, :final on, :final duration):
        await api.updateChatSettings(
          broadcasterId: broadcasterId,
          moderatorId: moderatorId,
          slowMode: mode == ChatMode.slow ? on : null,
          slowModeWaitTime: mode == ChatMode.slow && on ? duration : null,
          followerMode: mode == ChatMode.followers ? on : null,
          followerModeDuration: mode == ChatMode.followers && on
              ? duration
              : null,
          subscriberMode: mode == ChatMode.subscribers ? on : null,
          emoteMode: mode == ChatMode.emoteOnly ? on : null,
          uniqueChatMode: mode == ChatMode.uniqueChat ? on : null,
        );
        return '${mode.label} ${on ? 'on' : 'off'}${_modeDetail(mode, on, duration)}.';
    }
  }

  static String _modeDetail(ChatMode mode, bool on, Duration? duration) {
    if (!on || duration == null) return '';
    return switch (mode) {
      ChatMode.slow => ' (${timeoutLength(duration.inSeconds)})',
      ChatMode.followers when duration > Duration.zero =>
        ' (followers of ${timeoutLength(duration.inSeconds)})',
      _ => '',
    };
  }

  static String _verb(ModerationCommand command) => switch (command) {
    BanCommand() => 'ban',
    TimeoutCommand() => 'time out',
    UnbanCommand(:final timeout) => timeout ? 'remove the timeout of' : 'unban',
    WarnCommand() => 'warn',
    DeleteMessageCommand() => 'delete the message',
    ClearChatCommand() => 'clear the chat',
    ChatModeCommand(:final mode, :final on) =>
      'turn ${mode.label.toLowerCase()} ${on ? 'on' : 'off'}',
  };
}

/// The line telling why [error] stopped a moderation action ([verb], as in
/// "Couldn't ban").
String moderationFailure(Object error, String verb) => switch (error) {
  // The login dialog shows too (the moderator scopes came with this app
  // version).
  UnauthorizedException() => 'Log in again to moderate from this app.',
  ApiException(statusCode: 403) =>
    "Couldn't $verb: Twitch says you can't moderate this chat.",
  ApiException(:final message) => "Couldn't $verb: $message",
  _ => "Couldn't $verb (unexpected error).",
};
