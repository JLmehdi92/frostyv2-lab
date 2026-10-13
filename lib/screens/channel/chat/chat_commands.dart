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

final class HelpCommand extends ChatCommand {
  const HelpCommand();
}

/// A command the app cannot run, with what to tell the viewer.
final class UnsupportedCommand extends ChatCommand {
  const UnsupportedCommand(this.message);

  final String message;
}

typedef ChatCommandInfo = ({String name, String usage, String description});

/// The commands the input suggests, with their usage.
const kChatCommands = <ChatCommandInfo>[
  (
    name: 'me',
    usage: '/me <message>',
    description: 'Speak in the third person',
  ),
  (
    name: 'color',
    usage: '/color <color>',
    description: 'Change your name color',
  ),
  (name: 'block', usage: '/block <user>', description: 'Block a user'),
  (name: 'unblock', usage: '/unblock <user>', description: 'Unblock a user'),
  (name: 'help', usage: '/help', description: 'List the commands'),
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

const _moderatorCommands = {
  'ban',
  'unban',
  'timeout',
  'untimeout',
  'slow',
  'slowoff',
  'followers',
  'followersoff',
  'subscribers',
  'subscribersoff',
  'emoteonly',
  'emoteonlyoff',
  'clear',
  'uniquechat',
  'uniquechatoff',
  'delete',
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
  'warn',
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

/// The commands to suggest for [text] being typed: a `/` and the start of
/// a name, before any space.
List<ChatCommandInfo> matchCommands(String text) {
  if (!text.startsWith('/') || text.contains(' ')) return const [];
  final term = text.substring(1).toLowerCase();
  return [
    for (final command in kChatCommands)
      if (command.name.startsWith(term)) command,
  ];
}

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
        return const UnsupportedCommand('Usage: /color <color>');
      }
      final named =
          kChatNamedColors[args.single.toLowerCase().replaceAll('_', '')];
      if (named != null) return ColorCommand(named);
      final hex = _hex.firstMatch(args.single);
      if (hex != null) return ColorCommand('#${hex[1]!.toUpperCase()}');
      return const UnsupportedCommand(
        'Unknown color. Try Blue, Coral, HotPink… or #RRGGBB (Turbo/Prime).',
      );
    case 'block' || 'unblock':
      final login = args.length == 1 ? _login.firstMatch(args.single) : null;
      if (login == null) return UnsupportedCommand('Usage: /$name <user>');
      final user = login[1]!.toLowerCase();
      return name == 'block' ? BlockCommand(user) : UnblockCommand(user);
    case 'w' || 'whisper':
      return const UnsupportedCommand(
        "Whispers aren't available in this app yet.",
      );
    case final command when _moderatorCommands.contains(command):
      return UnsupportedCommand(
        '/$command is a moderator command, which this app does not support.',
      );
    default:
      return UnsupportedCommand(
        'Unknown command /$name. Type /help for the commands you can use.',
      );
  }
}
