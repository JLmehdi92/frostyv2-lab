import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/moderation.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/moderation.dart';

class _MockTwitchApi extends Mock implements TwitchApi {}

class _MockModApi extends Mock implements TwitchModApi {}

void main() {
  late _MockTwitchApi api;
  late _MockModApi mod;

  ChatModeration as(String moderatorId) =>
      ChatModeration(api: api, broadcasterId: '11', moderatorId: moderatorId);

  setUpAll(() {
    registerFallbackValue(AnnouncementColor.primary);
    registerFallbackValue(ChannelRole.moderator);
  });

  setUp(() {
    api = _MockTwitchApi();
    mod = _MockModApi();
    when(() => api.moderation).thenReturn(mod);
    when(
      () => api.getUser(userLogin: 'kai'),
    ).thenAnswer((_) async => const UserTwitch('33', 'kai', 'Kai', ''));
  });

  test('a moderator announces and gives a shoutout', () async {
    when(
      () => mod.sendAnnouncement(
        broadcasterId: '11',
        moderatorId: '22',
        message: 'hello',
        color: AnnouncementColor.green,
      ),
    ).thenAnswer((_) async {});
    when(
      () => mod.sendShoutout(
        broadcasterId: '11',
        moderatorId: '22',
        toBroadcasterId: '33',
      ),
    ).thenAnswer((_) async {});

    expect(
      await as(
        '22',
      ).run(const AnnounceCommand('hello', AnnouncementColor.green)),
      (ok: true, message: 'Announcement sent.'),
    );
    expect(await as('22').run(const ShoutoutCommand('kai')), (
      ok: true,
      message: 'Shoutout sent to Kai.',
    ));
  });

  test('a moderator is told the owner\'s commands are not theirs', () async {
    final outcome = await as('22').run(const RaidCommand('kai'));
    expect(outcome.ok, isFalse);
    expect(outcome.message, '/⁠raid only works in your own channel.');
    verifyNever(
      () => mod.startRaid(
        broadcasterId: any(named: 'broadcasterId'),
        toBroadcasterId: any(named: 'toBroadcasterId'),
      ),
    );
    final role = await as(
      '22',
    ).run(const RoleCommand('kai', ChannelRole.moderator, granted: true));
    expect(role.message, '/⁠mod only works in your own channel.');
  });

  test('the owner raids, adds roles and lists them', () async {
    when(
      () => mod.startRaid(broadcasterId: '11', toBroadcasterId: '33'),
    ).thenAnswer((_) async {});
    when(
      () => mod.setRole(
        broadcasterId: '11',
        userId: '33',
        role: ChannelRole.vip,
        granted: true,
      ),
    ).thenAnswer((_) async {});
    when(
      () => mod.getRoleUsers(broadcasterId: '11', role: ChannelRole.moderator),
    ).thenAnswer(
      (_) async => const [
        ChannelRoleUser(userId: '1', userLogin: 'mira', userName: 'Mira'),
        ChannelRoleUser(userId: '2', userLogin: 'ana', userName: 'Ana'),
      ],
    );
    when(
      () => mod.getRoleUsers(broadcasterId: '11', role: ChannelRole.vip),
    ).thenAnswer((_) async => const []);

    expect(
      (await as('11').run(const RaidCommand('kai'))).message,
      'Preparing the raid on Kai.',
    );
    expect(
      (await as(
        '11',
      ).run(const RoleCommand('kai', ChannelRole.vip, granted: true))).message,
      'Kai is now a VIP.',
    );
    expect(
      (await as(
        '11',
      ).run(const RoleListCommand(ChannelRole.moderator))).message,
      'Moderators (2): Mira, Ana',
    );
    expect(
      (await as('11').run(const RoleListCommand(ChannelRole.vip))).message,
      'This channel has no VIPs.',
    );
  });

  test('a long role list is cut after 30 names', () {
    final names = [for (var i = 0; i < 40; i++) 'u$i'];
    final line = roleListLine(L10n.english, ChannelRole.moderator, names);
    expect(line, startsWith('Moderators (40): u0, u1'));
    expect(line, endsWith('u29…'));
  });

  test('shield mode, an ad break and a marker say how it went', () async {
    when(
      () => mod.setShieldMode(
        broadcasterId: '11',
        moderatorId: '11',
        active: true,
      ),
    ).thenAnswer((_) async => const ShieldModeStatus(isActive: true));
    when(
      () => mod.startCommercial(broadcasterId: '11', seconds: 60),
    ).thenAnswer((_) async => const CommercialStart(length: 60));
    when(() => mod.createMarker(broadcasterId: '11')).thenAnswer((_) async {});

    expect(
      (await as('11').run(const ShieldCommand(on: true))).message,
      'Shield mode is on.',
    );
    expect(
      (await as('11').run(const CommercialCommand(60))).message,
      'Ad break started (1 minute).',
    );
    expect(
      (await as('11').run(const MarkerCommand(''))).message,
      'Stream marker added.',
    );
  });

  test('monitor and restrict name the user', () async {
    when(
      () => mod.setSuspiciousStatus(
        broadcasterId: '11',
        moderatorId: '22',
        userId: '33',
        status: SuspiciousStatus.restricted,
      ),
    ).thenAnswer((_) async {});
    when(
      () => mod.setSuspiciousStatus(
        broadcasterId: '11',
        moderatorId: '22',
        userId: '33',
        status: null,
      ),
    ).thenAnswer((_) async {});

    expect(
      (await as('22').run(
        const SuspicionCommand('kai', SuspiciousStatus.restricted, on: true),
      )).message,
      'Kai is now restricted.',
    );
    expect(
      (await as('22').run(
        const SuspicionCommand('kai', SuspiciousStatus.monitored, on: false),
      )).message,
      'Kai is no longer monitored.',
    );
  });

  test('a missing scope asks to log in again, a refusal says why', () async {
    when(
      () => mod.sendShoutout(
        broadcasterId: '11',
        moderatorId: '22',
        toBroadcasterId: '33',
      ),
    ).thenThrow(const UnauthorizedException('missing scope'));
    expect(
      (await as('22').run(const ShoutoutCommand('kai'))).message,
      'Log in again to moderate from this app.',
    );

    when(
      () => mod.cancelRaid(broadcasterId: '11'),
    ).thenThrow(const ApiException('no raid', 403));
    expect(
      (await as('11').run(const UnraidCommand())).message,
      'Couldn’t cancel the raid: Twitch says you can’t moderate this chat.',
    );
  });

  test('every new command is named for its failure line', () {
    expect(
      [
        for (final command in const [
          AnnounceCommand('x', AnnouncementColor.blue),
          ShoutoutCommand('a'),
          RoleListCommand(ChannelRole.vip),
          RoleCommand('a', ChannelRole.moderator, granted: false),
          ShieldCommand(on: false),
          MarkerCommand(''),
          CommercialCommand(30),
          RaidCommand('a'),
          UnraidCommand(),
          SuspicionCommand('a', SuspiciousStatus.monitored, on: true),
        ])
          moderationCommand(command),
      ],
      [
        'announce',
        'shoutout',
        'vips',
        'unmod',
        'shieldOff',
        'marker',
        'commercial',
        'raid',
        'unraid',
        'monitor',
      ],
    );
  });
}
