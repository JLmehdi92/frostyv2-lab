import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/l10n/api_errors.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/moderation_notice.dart';
import 'package:onset/services/telemetry.dart';

/// What a moderation action ended with: whether it worked, and the line to
/// show either way, worded in the language on screen when it ended.
typedef ModerationOutcome = ({bool ok, String message});

/// What an action says when it threw instead of answering (the bars that
/// run it must not stay busy for good).
ModerationOutcome get moderationFailed =>
    (ok: false, message: L10n.current.chatModNotThrough);

/// What [error] says, after « Couldn't … : » in chat: on an English screen
/// Twitch's own English words ([ApiException.message]), as the chat always
/// read; in another language its kind, worded ([apiErrorText]).
String chatErrorText(AppLocalizations l, ApiException error) =>
    l.localeName == 'en' ? error.message : apiErrorText(l, error);

/// The login a moderation command named belongs to nobody.
class _NoSuchUser extends NotFoundException {
  const _NoSuchUser(this.login) : super('no_such_user');

  final String login;
}

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
        Telemetry.recordError(
          error,
          stack,
          reason: 'moderation ${command.runtimeType}',
        );
      }
      return (
        ok: false,
        message: moderationFailure(error, moderationCommand(command)),
      );
    }
  }

  Future<String> _run(ModerationCommand command, String? knownId) async {
    Future<({String id, String name})> target(String login) async {
      if (knownId != null) return (id: knownId, name: login);
      try {
        final user = await api.getUser(userLogin: login);
        return (id: user.id, name: user.displayName);
      } on NotFoundException catch (_, stack) {
        Error.throwWithStackTrace(_NoSuchUser(login), stack);
      }
    }

    final l = L10n.current;
    switch (command) {
      case BanCommand(:final login, :final reason):
        final user = await target(login);
        await api.banUser(
          broadcasterId: broadcasterId,
          moderatorId: moderatorId,
          userId: user.id,
          reason: reason,
        );
        return l.chatModBanned(name: user.name);
      case TimeoutCommand(:final login, :final duration, :final reason):
        final user = await target(login);
        await api.banUser(
          broadcasterId: broadcasterId,
          moderatorId: moderatorId,
          userId: user.id,
          duration: duration,
          reason: reason,
        );
        return l.chatModTimedOut(
          name: user.name,
          duration: timeoutLength(duration.inSeconds, l),
        );
      case UnbanCommand(:final login, :final timeout):
        final user = await target(login);
        await api.unbanUser(
          broadcasterId: broadcasterId,
          moderatorId: moderatorId,
          userId: user.id,
        );
        return timeout
            ? l.chatModUntimedOut(name: user.name)
            : l.chatModUnbanned(name: user.name);
      case WarnCommand(:final login, :final reason):
        final user = await target(login);
        await api.warnUser(
          broadcasterId: broadcasterId,
          moderatorId: moderatorId,
          userId: user.id,
          reason: reason,
        );
        return l.chatModWarned(name: user.name);
      case DeleteMessageCommand(:final messageId):
        await api.deleteChatMessages(
          broadcasterId: broadcasterId,
          moderatorId: moderatorId,
          messageId: messageId,
        );
        return l.chatModMessageDeleted;
      case ClearChatCommand():
        await api.deleteChatMessages(
          broadcasterId: broadcasterId,
          moderatorId: moderatorId,
        );
        return l.chatModCleared;
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
        return _modeOutcome(l, mode, on, duration);
    }
  }

  static String _modeOutcome(
    AppLocalizations l,
    ChatMode mode,
    bool on,
    Duration? duration,
  ) {
    if (on && duration != null) {
      switch (mode) {
        case ChatMode.slow:
          return l.chatModeSlowOn(
            duration: timeoutLength(duration.inSeconds, l),
          );
        case ChatMode.followers when duration > Duration.zero:
          return l.chatModeFollowersOn(
            duration: timeoutLength(duration.inSeconds, l),
          );
        default:
          break;
      }
    }
    return l.chatModeChanged(mode: mode.name, state: OnOff.of(on).name);
  }
}

/// What [command] does, as the moderation failures name it
/// (`chatModFailed`'s command): ban, timeout, untimeout, unban, warn,
/// delete, clear, or a mode turned on or off ("slowOn").
String moderationCommand(ModerationCommand command) => switch (command) {
  BanCommand() => 'ban',
  TimeoutCommand() => 'timeout',
  UnbanCommand(:final timeout) => timeout ? 'untimeout' : 'unban',
  WarnCommand() => 'warn',
  DeleteMessageCommand() => 'delete',
  ClearChatCommand() => 'clear',
  ChatModeCommand(:final mode, :final on) => '${mode.name}${on ? 'On' : 'Off'}',
};

/// The line telling why [error] stopped a moderation [command]
/// ([moderationCommand]), worded in the language on screen.
String moderationFailure(Object error, String command) {
  final l = L10n.current;
  return switch (error) {
    // The login dialog shows too (the moderator scopes came with this app
    // version).
    UnauthorizedException() => l.chatModLogInAgain,
    _NoSuchUser(:final login) => l.chatModFailed(
      command: command,
      reason: l.chatModNoUser(login: login),
    ),
    ApiException(statusCode: 403) => l.chatModFailed(
      command: command,
      reason: l.chatModCannotModerate,
    ),
    final ApiException error => l.chatModFailed(
      command: command,
      reason: chatErrorText(l, error),
    ),
    _ => l.chatModFailedUnexpected(command: command),
  };
}
