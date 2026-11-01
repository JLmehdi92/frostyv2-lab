import 'dart:math';

import 'package:onset/l10n/l10n.dart';

/// A chat line typed in the input: a message to send as is, or a slash
/// command the app runs itself (Twitch no longer runs commands sent over
/// IRC, except `/me`).
sealed class ChatCommand {
  const ChatCommand();
}

/// A normal message, or `/me` (sent over IRC).
final class SendAsIs extends ChatCommand {
  const SendAsIs();
}

/// `/color <name or #hex>`: the name colour (hex needs Turbo or Prime).
final class ColorCommand extends ChatCommand {
  const ColorCommand(this.color);

  /// A Helix colour: a named colour (`blue_violet`) or `#RRGGBB`.
  final String color;
}

final class BlockCommand extends ChatCommand {
  const BlockCommand(this.login);

  final String login;
}

final class UnblockCommand extends ChatCommand {
  const UnblockCommand(this.login);

  final String login;
}

/// `/w <user> <message>`: a whisper.
final class WhisperCommand extends ChatCommand {
  const WhisperCommand(this.login, this.message);

  final String login;
  final String message;
}

final class HelpCommand extends ChatCommand {
  const HelpCommand();
}

/// A command only moderators (and the broadcaster) can run, through Helix.
sealed class ModerationCommand extends ChatCommand {
  const ModerationCommand();
}

/// `/ban <user> [reason]`.
final class BanCommand extends ModerationCommand {
  const BanCommand(this.login, this.reason);

  final String login;
  final String reason;
}

/// `/timeout <user> [length] [reason]`.
final class TimeoutCommand extends ModerationCommand {
  const TimeoutCommand(this.login, this.duration, this.reason);

  final String login;
  final Duration duration;
  final String reason;
}

/// `/unban <user>`, or `/untimeout <user>` when [timeout] is set (both lift
/// either).
final class UnbanCommand extends ModerationCommand {
  const UnbanCommand(this.login, {this.timeout = false});

  final String login;
  final bool timeout;
}

/// `/warn <user> <reason>`.
final class WarnCommand extends ModerationCommand {
  const WarnCommand(this.login, this.reason);

  final String login;
  final String reason;
}

/// `/delete <message id>`.
final class DeleteMessageCommand extends ModerationCommand {
  const DeleteMessageCommand(this.messageId);

  final String messageId;
}

/// `/clear`: deletes every message of the chat.
final class ClearChatCommand extends ModerationCommand {
  const ClearChatCommand();
}

/// A room mode, named by `ChatModeLabel` (lib/l10n/enum_labels.dart).
enum ChatMode { slow, followers, subscribers, emoteOnly, uniqueChat }

/// A room mode turned on (with its wait or follow age when it has one) or
/// off.
final class ChatModeCommand extends ModerationCommand {
  const ChatModeCommand(this.mode, {required this.on, this.duration});

  final ChatMode mode;
  final bool on;

  /// The slow-mode wait or the follow age; null for the other modes and
  /// when turning off.
  final Duration? duration;
}

/// A command the app cannot run, with why ([problem]), worded by [text].
final class UnsupportedCommand extends ChatCommand {
  const UnsupportedCommand(this.problem);

  final CommandProblem problem;

  /// What the viewer is told, in [l]'s language.
  String text(AppLocalizations l) => problem.text(l);
}

/// Why the app cannot run a typed command.
sealed class CommandProblem {
  const CommandProblem();

  /// What the viewer is told, in [l]'s language: the commands, their
  /// lengths and their colour names stay as Twitch reads them.
  String text(AppLocalizations l);
}

/// Typed wrong: how to type [name], a command [kChatCommands] or
/// [kModeratorChatCommands] lists (or a mode command, which takes nothing).
final class UsageProblem extends CommandProblem {
  const UsageProblem(this.name);

  final String name;

  @override
  String text(AppLocalizations l) {
    final command = [
      ...kChatCommands,
      ...kModeratorChatCommands,
    ].where((c) => c.name == name).firstOrNull;
    return l.chatCommandUsage(
      usage: command?.usage(l, inChatLine: true) ?? commandInChatLine(name),
    );
  }
}

/// `/timeout` got a length it cannot read ([length], as typed).
final class BadLengthProblem extends CommandProblem {
  const BadLengthProblem(this.length);

  final String length;

  @override
  String text(AppLocalizations l) => l.chatCommandBadLength(length: length);
}

/// A length outside what Twitch accepts for a timeout, a slow-mode wait or
/// a follow age.
final class RangeProblem extends CommandProblem {
  const RangeProblem(this.mode);

  /// [ChatMode.slow], [ChatMode.followers], or null for a timeout.
  final ChatMode? mode;

  @override
  String text(AppLocalizations l) => switch (mode) {
    ChatMode.slow => l.chatCommandSlowRange,
    ChatMode.followers => l.chatCommandFollowAgeRange,
    _ => l.chatCommandTimeoutRange,
  };
}

/// `/color` got a colour it does not know.
final class UnknownColorProblem extends CommandProblem {
  const UnknownColorProblem();

  @override
  String text(AppLocalizations l) => l.chatCommandUnknownColor;
}

/// A Twitch command this app does not run ([command]).
final class NotInAppProblem extends CommandProblem {
  const NotInAppProblem(this.command);

  final String command;

  @override
  String text(AppLocalizations l) => l.chatCommandNotInApp(command: command);
}

/// A command nobody knows ([command], as typed).
final class UnknownCommandProblem extends CommandProblem {
  const UnknownCommandProblem(this.command);

  final String command;

  @override
  String text(AppLocalizations l) => l.chatCommandUnknown(command: command);
}

/// What a command takes, in its usage: a word between `<>` (required) or
/// `[]` (optional), translated; the command's name never is.
enum ChatCommandArg {
  user,
  message,
  color,
  reason,
  length,
  seconds,
  messageId;

  String word(AppLocalizations l) => switch (this) {
    user => l.chatCommandArgUser,
    message => l.chatCommandArgMessage,
    color => l.chatCommandArgColor,
    reason => l.chatCommandArgReason,
    length => l.chatCommandArgLength,
    seconds => l.chatCommandArgSeconds,
    messageId => l.chatCommandArgMessageId,
  };
}

/// `/name` for a line chat shows: a word joiner (U+2060) after the slash, so
/// a wrapped line never leaves the slash alone at the end of a row (a line
/// may break after a slash).
String commandInChatLine(String name) => '/\u2060$name';

/// A command the input suggests: its [name] (what is typed, never
/// translated), what it takes ([required], then [optional]), worded by
/// [usage] and [description].
final class ChatCommandInfo {
  const ChatCommandInfo(
    this.name, {
    this.required = const [],
    this.optional = const [],
  });

  final String name;
  final List<ChatCommandArg> required;
  final List<ChatCommandArg> optional;

  /// `/ban <user> [reason]`, in [l]'s language. [inChatLine] keeps the
  /// slash with the name when a chat line wraps (a word joiner, U+2060,
  /// after it): only for the lines chat shows, never for what is typed.
  String usage(AppLocalizations l, {bool inChatLine = false}) => [
    inChatLine ? commandInChatLine(name) : '/$name',
    for (final arg in required) '<${arg.word(l)}>',
    for (final arg in optional) '[${arg.word(l)}]',
  ].join(' ');

  /// What it does, in [l]'s language.
  String description(AppLocalizations l) =>
      l.chatCommandDescription(command: name);
}

/// The commands the input suggests, with their usage.
const kChatCommands = <ChatCommandInfo>[
  ChatCommandInfo('me', required: [ChatCommandArg.message]),
  ChatCommandInfo('color', required: [ChatCommandArg.color]),
  ChatCommandInfo('block', required: [ChatCommandArg.user]),
  ChatCommandInfo('unblock', required: [ChatCommandArg.user]),
  ChatCommandInfo('w', required: [ChatCommandArg.user, ChatCommandArg.message]),
  ChatCommandInfo('help'),
];

/// The commands suggested to moderators and the broadcaster as well.
const kModeratorChatCommands = <ChatCommandInfo>[
  ChatCommandInfo(
    'ban',
    required: [ChatCommandArg.user],
    optional: [ChatCommandArg.reason],
  ),
  ChatCommandInfo('unban', required: [ChatCommandArg.user]),
  ChatCommandInfo(
    'timeout',
    required: [ChatCommandArg.user],
    optional: [ChatCommandArg.length, ChatCommandArg.reason],
  ),
  ChatCommandInfo('untimeout', required: [ChatCommandArg.user]),
  ChatCommandInfo(
    'warn',
    required: [ChatCommandArg.user, ChatCommandArg.reason],
  ),
  ChatCommandInfo('delete', required: [ChatCommandArg.messageId]),
  ChatCommandInfo('clear'),
  ChatCommandInfo('slow', optional: [ChatCommandArg.seconds]),
  ChatCommandInfo('slowoff'),
  ChatCommandInfo('followers', optional: [ChatCommandArg.length]),
  ChatCommandInfo('followersoff'),
  ChatCommandInfo('subscribers'),
  ChatCommandInfo('subscribersoff'),
  ChatCommandInfo('emoteonly'),
  ChatCommandInfo('emoteonlyoff'),
  ChatCommandInfo('uniquechat'),
  ChatCommandInfo('uniquechatoff'),
];

/// Twitch's named colours (non-Turbo), as Helix spells them.
const kChatNamedColors = {
  'blue': 'blue',
  'blueviolet': 'blue_violet',
  'cadetblue': 'cadet_blue',
  'chocolate': 'chocolate',
  'coral': 'coral',
  'dodgerblue': 'dodger_blue',
  'firebrick': 'firebrick',
  'goldenrod': 'golden_rod',
  'green': 'green',
  'hotpink': 'hot_pink',
  'orangered': 'orange_red',
  'red': 'red',
  'seagreen': 'sea_green',
  'springgreen': 'spring_green',
  'yellowgreen': 'yellow_green',
};

/// Moderator and broadcaster commands this app does not run (yet).
const _otherModeratorCommands = {
  'mod',
  'unmod',
  'vip',
  'unvip',
  'raid',
  'unraid',
  'commercial',
  'marker',
  'announce',
  'announceblue',
  'announcegreen',
  'announceorange',
  'announcepurple',
  'shoutout',
  'pin',
  'monitor',
  'restrict',
  'unmonitor',
  'unrestrict',
  'shield',
  'shieldoff',
  'mods',
  'vips',
};

final _login = RegExp(r'^@?([a-zA-Z0-9_]{1,25})$');
final _hex = RegExp(r'^#?([0-9a-fA-F]{6})$');
final _length = RegExp(r'^(\d+)(s|m|h|d|w|mo)?$', caseSensitive: false);
final _messageId = RegExp(r'^[0-9a-fA-F-]{1,64}$');
final _digit = RegExp(r'^\d');

const _timeoutDefault = Duration(minutes: 10);
const _timeoutMax = Duration(days: 14);
const _slowDefault = Duration(seconds: 30);
const _slowMin = Duration(seconds: 3);
const _slowMax = Duration(seconds: 120);
const _followAgeMax = Duration(days: 90);

/// A length as Twitch's commands write it ("30", "10m", "2h", "1d", "1w",
/// "3mo"); a bare number counts in [unit]. Null when it is not one; a huge
/// one is capped (far past any bound the commands accept).
Duration? parseCommandLength(String text, {required Duration unit}) {
  final match = _length.firstMatch(text);
  if (match == null) return null;
  // Nine digits keep the products below within an int and a Duration.
  final digits = match[1]!;
  final count = digits.length > 9 ? 999999999 : int.parse(digits);
  final unitSeconds = switch (match[2]?.toLowerCase()) {
    null => unit.inSeconds,
    's' => 1,
    'm' => 60,
    'h' => 3600,
    'd' => 86400,
    'w' => 604800,
    _ => 2592000,
  };
  return Duration(seconds: min(count * unitSeconds, _maxLengthSeconds));
}

/// About 31 years.
const _maxLengthSeconds = 1000000000;

/// The commands to suggest for [text] being typed: a `/` and the start of
/// a name, before any space.
/// [moderator] adds the moderator commands.
List<ChatCommandInfo> matchCommands(String text, {bool moderator = false}) {
  if (!text.startsWith('/') || text.contains(' ')) return const [];
  final term = text.substring(1).toLowerCase();
  return [
    for (final command in [
      ...kChatCommands,
      if (moderator) ...kModeratorChatCommands,
    ])
      if (command.name.startsWith(term)) command,
  ];
}

String? _loginOf(String arg) => _login.firstMatch(arg)?[1]!.toLowerCase();

ChatCommand _usage(String name) => UnsupportedCommand(UsageProblem(name));

ChatCommand _parseModeration(String name, List<String> args) {
  switch (name) {
    case 'ban':
      final login = args.isEmpty ? null : _loginOf(args.first);
      if (login == null) return _usage('ban');
      return BanCommand(login, args.skip(1).join(' '));
    case 'timeout':
      final login = args.isEmpty ? null : _loginOf(args.first);
      if (login == null) return _usage('timeout');
      final length = args.length > 1
          ? parseCommandLength(args[1], unit: const Duration(seconds: 1))
          : null;
      // "5min" or "1h30m" is a mistyped length, not the reason.
      if (length == null && args.length > 1 && args[1].startsWith(_digit)) {
        return UnsupportedCommand(BadLengthProblem(args[1]));
      }
      final duration = length ?? _timeoutDefault;
      if (duration < const Duration(seconds: 1) || duration > _timeoutMax) {
        return const UnsupportedCommand(RangeProblem(null));
      }
      return TimeoutCommand(
        login,
        duration,
        args.skip(length == null ? 1 : 2).join(' '),
      );
    case 'unban' || 'untimeout':
      final login = args.length == 1 ? _loginOf(args.single) : null;
      if (login == null) return _usage(name);
      return UnbanCommand(login, timeout: name == 'untimeout');
    case 'warn':
      final login = args.isEmpty ? null : _loginOf(args.first);
      if (login == null || args.length < 2) return _usage('warn');
      return WarnCommand(login, args.skip(1).join(' '));
    case 'delete':
      if (args.length != 1 || !_messageId.hasMatch(args.single)) {
        return _usage('delete');
      }
      return DeleteMessageCommand(args.single);
    case 'clear':
      return args.isEmpty ? const ClearChatCommand() : _usage('clear');
    case 'slow':
      if (args.length > 1) return _usage('slow');
      final wait = args.isEmpty
          ? _slowDefault
          : parseCommandLength(args.single, unit: const Duration(seconds: 1));
      if (wait == null || wait < _slowMin || wait > _slowMax) {
        return const UnsupportedCommand(RangeProblem(ChatMode.slow));
      }
      return ChatModeCommand(ChatMode.slow, on: true, duration: wait);
    case 'followers':
      if (args.length > 1) return _usage('followers');
      final age = args.isEmpty
          ? Duration.zero
          : parseCommandLength(args.single, unit: const Duration(minutes: 1));
      // Twitch counts it in whole minutes.
      if (age == null || age > _followAgeMax || age.inSeconds % 60 != 0) {
        return const UnsupportedCommand(RangeProblem(ChatMode.followers));
      }
      return ChatModeCommand(ChatMode.followers, on: true, duration: age);
  }
  final (mode, on) = switch (name) {
    'slowoff' => (ChatMode.slow, false),
    'followersoff' => (ChatMode.followers, false),
    'subscribers' => (ChatMode.subscribers, true),
    'subscribersoff' => (ChatMode.subscribers, false),
    'emoteonly' => (ChatMode.emoteOnly, true),
    'emoteonlyoff' => (ChatMode.emoteOnly, false),
    'uniquechat' || 'r9kbeta' => (ChatMode.uniqueChat, true),
    'uniquechatoff' || 'r9kbetaoff' => (ChatMode.uniqueChat, false),
    _ => throw StateError('Unparsed moderation command /$name'),
  };
  if (args.isNotEmpty) return UnsupportedCommand(UsageProblem(name));
  return ChatModeCommand(mode, on: on);
}

final _moderationNames = {
  for (final command in kModeratorChatCommands) command.name,
  'r9kbeta',
  'r9kbetaoff',
};

ChatCommand parseChatCommand(String text) {
  final trimmed = text.trim();
  if (!trimmed.startsWith('/') && !trimmed.startsWith('.')) {
    return const SendAsIs();
  }
  final parts = trimmed.substring(1).split(RegExp(r'\s+'));
  final name = parts.first.toLowerCase();
  final args = parts.skip(1).where((a) => a.isNotEmpty).toList();
  // `.` only starts a command for `.me`, like Twitch; anything else is text.
  if (trimmed.startsWith('.') && name != 'me') return const SendAsIs();
  switch (name) {
    case 'me':
      return const SendAsIs();
    case 'help' || 'commands':
      return const HelpCommand();
    case 'color':
      if (args.length != 1) {
        return const UnsupportedCommand(UsageProblem('color'));
      }
      final named =
          kChatNamedColors[args.single.toLowerCase().replaceAll('_', '')];
      if (named != null) return ColorCommand(named);
      final hex = _hex.firstMatch(args.single);
      if (hex != null) return ColorCommand('#${hex[1]!.toUpperCase()}');
      return const UnsupportedCommand(UnknownColorProblem());
    case 'block' || 'unblock':
      final login = args.length == 1 ? _login.firstMatch(args.single) : null;
      if (login == null) return UnsupportedCommand(UsageProblem(name));
      final user = login[1]!.toLowerCase();
      return name == 'block' ? BlockCommand(user) : UnblockCommand(user);
    case 'w' || 'whisper':
      final login = args.isEmpty ? null : _loginOf(args.first);
      if (login == null || args.length < 2) {
        return const UnsupportedCommand(UsageProblem('w'));
      }
      return WhisperCommand(login, args.skip(1).join(' '));
    case final command when _moderationNames.contains(command):
      return _parseModeration(command, args);
    case final command when _otherModeratorCommands.contains(command):
      return UnsupportedCommand(NotInAppProblem(command));
    default:
      return UnsupportedCommand(UnknownCommandProblem(name));
  }
}
