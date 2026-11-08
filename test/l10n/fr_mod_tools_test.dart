import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_compose_sheets.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_list_sheets.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_queue_sheets.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_tools_sheet.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/shield_mode_indicator.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/user_card_mod_panel.dart';

import '../helpers/l10n.dart';
import '../helpers/mod_tools_harness.dart';

const _content = [
  'NightOwl',
  'Pixel',
  'Mira',
  'Rookie',
  'Ana',
  'is this link safe? example.com',
  'that was a terrible play lol',
  'I got carried away last night. It won’t happen again.',
  'free followers',
  'spoiler',
  'Pick the next map',
  'The lighthouse one',
  'Which boss next?',
  'The Warden',
  'Ember Queen',
  'First try?',
  'Clean run',
  'Needs retries',
  'Speedrun practice, any%',
  'Celeste',
  'English',
  'Speedrun',
];

typedef _Screen = ({
  String name,
  bool broadcaster,
  Widget Function(ModToolsHarness h) build,
  Future<void> Function(WidgetTester tester)? open,
});

final _screens = <_Screen>[
  (
    name: 'mod tools, owner',
    broadcaster: true,
    build: (h) => ModToolsSheet(chatStore: h.chat),
    open: null,
  ),
  (
    name: 'mod tools, moderator',
    broadcaster: false,
    build: (h) => ModToolsSheet(chatStore: h.chat),
    open: null,
  ),
  (
    name: 'AutoMod queue',
    broadcaster: false,
    build: (h) {
      runInAction(
        () => h.tools.heldMessages.addAll([
          kHeldMessages.first,
          kHeldMessages.last.withStatus(HeldMessageStatus.approved),
        ]),
      );
      return AutoModQueueSheet(tools: h.tools);
    },
    open: null,
  ),
  (
    name: 'mod actions, empty',
    broadcaster: false,
    build: (h) => ModActionLogSheet(tools: h.tools),
    open: null,
  ),
  (
    name: 'moderators',
    broadcaster: true,
    build: (h) => RoleListSheet(chatStore: h.chat, role: ChannelRole.moderator),
    open: null,
  ),
  (
    name: 'VIPs',
    broadcaster: true,
    build: (h) => RoleListSheet(chatStore: h.chat, role: ChannelRole.vip),
    open: null,
  ),
  (
    name: 'blocked terms',
    broadcaster: false,
    build: (h) => BlockedTermsSheet(chatStore: h.chat),
    open: null,
  ),
  (
    name: 'unban requests',
    broadcaster: false,
    build: (h) => UnbanRequestsSheet(chatStore: h.chat),
    open: null,
  ),
  (
    name: 'unban decision',
    broadcaster: false,
    build: (h) => UnbanRequestsSheet(chatStore: h.chat),
    open: (tester) async {
      await tester.tap(find.byType(OutlinedButton).last);
      await tester.pumpAndSettle();
    },
  ),
  (
    name: 'reward requests',
    broadcaster: true,
    build: (h) => RedemptionsSheet(chatStore: h.chat),
    open: null,
  ),
  (
    name: 'announcement',
    broadcaster: false,
    build: (h) => AnnounceSheet(chatStore: h.chat),
    open: null,
  ),
  (
    name: 'poll in progress',
    broadcaster: true,
    build: (h) => PollSheet(chatStore: h.chat),
    open: null,
  ),
  (
    name: 'prediction locked',
    broadcaster: true,
    build: (h) => PredictionSheet(chatStore: h.chat),
    open: null,
  ),
  (
    name: 'stream info',
    broadcaster: true,
    build: (h) => StreamInfoSheet(chatStore: h.chat),
    open: null,
  ),
  (
    name: 'card actions, owner',
    broadcaster: true,
    build: (h) => UserCardModActions(
      chatStore: h.chat,
      login: 'ana',
      userId: '33',
      name: 'Ana',
      isModerator: true,
      isVip: false,
    ),
    open: null,
  ),
  (
    name: 'card pills',
    broadcaster: false,
    build: (h) {
      h.tools
        ..noteClearChat('33', 600)
        ..noteSuspicion('33', SuspiciousStatus.restricted);
      return UserCardModPills(tools: h.tools, userId: '33');
    },
    open: null,
  ),
  (
    name: 'shield pill',
    broadcaster: false,
    build: (h) {
      h.tools.noteShieldMode(true);
      return ShieldModeIndicator(chatStore: h.chat);
    },
    open: null,
  ),
  (
    name: 'ad break dialog',
    broadcaster: true,
    build: (h) => Builder(
      builder: (context) => TextButton(
        onPressed: () => showCommercialDialog(context),
        child: const Text('⋯'),
      ),
    ),
    open: (tester) async {
      await tester.tap(find.text('⋯'));
      await tester.pumpAndSettle();
    },
  ),
];

void main() {
  setUpAll(() {
    registerFallbackValue(const ClearChatCommand());
  });

  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';
      for (final locale in sweepLocales) {
        final name = sweepName(locale);
        for (final screen in _screens) {
          testWidgets('${screen.name}, $at$name', (tester) async {
            final h = await modToolsHarness(broadcaster: screen.broadcaster);
            stubModLists(h.api, h.mod);
            await pumpLocalized(
              tester,
              sheetHost(screen.build(h)),
              locale: locale,
              size: size,
              textScale: scale,
            );
            await tester.pumpAndSettle();
            await screen.open?.call(tester);
            await expectFrenchThroughout(
              tester,
              '${screen.name}, $at',
              content: _content,
            );
          });
        }
      }
    }
  }
}
