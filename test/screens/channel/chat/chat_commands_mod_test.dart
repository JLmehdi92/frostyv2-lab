import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';

String _problem(String text) =>
    (parseChatCommand(text) as UnsupportedCommand).text(L10n.english);

void main() {
  test('/announce and its colors keep the message on one line', () {
    final plain =
        parseChatCommand('/announce  hello   chat') as AnnounceCommand;
    expect(plain.message, 'hello chat');
    expect(plain.color, AnnouncementColor.primary);
    final purple =
        parseChatCommand('/announcepurple big news') as AnnounceCommand;
    expect(purple.color, AnnouncementColor.purple);
    expect(
      (parseChatCommand('/announceblue x') as AnnounceCommand).color,
      AnnouncementColor.blue,
    );
    expect(_problem('/announce'), 'Usage: /⁠announce <message>');
  });

  test('/shoutout, /raid and roles take one login', () {
    expect(
      (parseChatCommand('/shoutout @Kai') as ShoutoutCommand).login,
      'kai',
    );
    expect((parseChatCommand('/raid Kai') as RaidCommand).login, 'kai');
    expect(parseChatCommand('/unraid'), isA<UnraidCommand>());
    expect(parseChatCommand('/raid'), isA<UnsupportedCommand>());
    expect(parseChatCommand('/raid a b'), isA<UnsupportedCommand>());
    expect(parseChatCommand('/shoutout bad-login'), isA<UnsupportedCommand>());

    final mod = parseChatCommand('/mod Ana') as RoleCommand;
    expect(
      (mod.login, mod.role, mod.granted),
      ('ana', ChannelRole.moderator, true),
    );
    final unvip = parseChatCommand('/unvip ana') as RoleCommand;
    expect((unvip.role, unvip.granted), (ChannelRole.vip, false));
    expect(
      (parseChatCommand('/mods') as RoleListCommand).role,
      ChannelRole.moderator,
    );
    expect(
      (parseChatCommand('/vips') as RoleListCommand).role,
      ChannelRole.vip,
    );
    expect(parseChatCommand('/mods extra'), isA<UnsupportedCommand>());
  });

  test('/shield, /marker and /commercial', () {
    expect((parseChatCommand('/shield') as ShieldCommand).on, isTrue);
    expect((parseChatCommand('/shieldoff') as ShieldCommand).on, isFalse);
    expect(
      (parseChatCommand('/marker nice\tplay') as MarkerCommand).description,
      'nice play',
    );
    expect((parseChatCommand('/marker') as MarkerCommand).description, '');
    expect((parseChatCommand('/commercial') as CommercialCommand).seconds, 30);
    expect(
      (parseChatCommand('/commercial 90') as CommercialCommand).seconds,
      90,
    );
    expect(
      (parseChatCommand('/commercial 120s') as CommercialCommand).seconds,
      120,
    );
    expect(parseChatCommand('/commercial 45'), isA<UnsupportedCommand>());
    expect(parseChatCommand('/commercial 999'), isA<UnsupportedCommand>());
  });

  test('/monitor, /restrict and their opposites', () {
    final monitor = parseChatCommand('/monitor Ana') as SuspicionCommand;
    expect(
      (monitor.login, monitor.status, monitor.on),
      ('ana', SuspiciousStatus.monitored, true),
    );
    final unrestrict = parseChatCommand('/unrestrict ana') as SuspicionCommand;
    expect(
      (unrestrict.status, unrestrict.on),
      (SuspiciousStatus.restricted, false),
    );
  });

  test('only the owner\'s commands are named as such', () {
    expect(broadcasterOnlyName(const RaidCommand('kai')), 'raid');
    expect(
      broadcasterOnlyName(
        const RoleCommand('ana', ChannelRole.vip, granted: false),
      ),
      'unvip',
    );
    expect(broadcasterOnlyName(const ShieldCommand(on: true)), isNull);
    expect(broadcasterOnlyName(const ShoutoutCommand('kai')), isNull);
  });

  test('moderators are offered the new commands, viewers are not', () {
    expect([
      for (final c in matchCommands('/ann', moderator: true)) c.name,
    ], contains('announce'));
    expect(matchCommands('/ann'), isEmpty);
    expect([
      for (final c in matchCommands('/sh', moderator: true)) c.name,
    ], containsAll(['shoutout', 'shield', 'shieldoff']));
  });

  test('/pin is still refused as not in this app', () {
    expect(_problem('/pin abc'), contains('not available'));
  });
}
