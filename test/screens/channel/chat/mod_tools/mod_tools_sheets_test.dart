import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/models/moderation.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_features.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_compose_sheets.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_list_sheets.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_queue_sheets.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_tools_sheet.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/shield_mode_indicator.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/user_card_mod_panel.dart';

import '../../../../helpers/l10n.dart';
import '../../../../helpers/mod_tools_harness.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(const ClearChatCommand());
    registerFallbackValue(AutoModDecision.allow);
  });

  Future<void> pump(WidgetTester tester, Widget sheet) async {
    await pumpLocalized(tester, sheetHost(sheet), locale: en);
    await tester.pumpAndSettle();
  }

  group('the hub', () {
    testWidgets('a moderator sees the live and chat tools only', (
      tester,
    ) async {
      final h = await modToolsHarness();
      await pump(tester, ModToolsSheet(chatStore: h.chat));
      expect(find.text('Mod tools'), findsOneWidget);
      expect(find.text('You moderate this channel'), findsOneWidget);
      expect(find.text('Shield mode'), findsOneWidget);
      expect(find.text('AutoMod queue'), findsOneWidget);
      expect(find.text('Blocked terms'), findsOneWidget);
      expect(find.text('Polls'), findsNothing);
      expect(find.text('Moderators'), findsNothing);
      expect(find.text('Permitted terms'), findsNothing);
    });

    testWidgets('the owner sees the channel tools', (tester) async {
      final h = await modToolsHarness(broadcaster: true);
      await pump(tester, ModToolsSheet(chatStore: h.chat));
      await tester.scrollUntilVisible(find.text('Run an ad'), 200);
      for (final row in [
        'Edit stream info',
        'Polls',
        'Predictions',
        'Reward requests',
        'Moderators',
        'VIPs',
        'Raid a channel',
        'Add a stream marker',
        'Run an ad',
      ]) {
        expect(find.text(row), findsOneWidget, reason: row);
      }
    });

    testWidgets('a login without the new scopes is asked to log in again', (
      tester,
    ) async {
      final h = await modToolsHarness(
        broadcaster: true,
        scopes: {'moderator:manage:banned_users'},
      );
      await pump(tester, ModToolsSheet(chatStore: h.chat));
      expect(find.text('Log in again to enable'), findsWidgets);
      expect(h.tools.needsLogin(ModFeature.shieldMode), isTrue);
    });

    testWidgets('the shield switch turns shield mode on through Helix', (
      tester,
    ) async {
      final h = await modToolsHarness();
      when(
        () => h.mod.setShieldMode(
          broadcasterId: '12345',
          moderatorId: '22',
          active: true,
        ),
      ).thenAnswer((_) async => const ShieldModeStatus(isActive: true));
      await pump(tester, ModToolsSheet(chatStore: h.chat));
      await tester.tap(find.text('Shield mode'));
      await tester.pumpAndSettle();
      expect(h.tools.shieldActive, isTrue);
      expect(find.text('Shield mode is on.'), findsOneWidget);
    });

    testWidgets('a raid asks for the channel, then for confirmation', (
      tester,
    ) async {
      final h = await modToolsHarness(broadcaster: true);
      await pump(tester, ModToolsSheet(chatStore: h.chat));
      await tester.scrollUntilVisible(find.text('Raid a channel'), 200);
      await tester.tap(find.text('Raid a channel'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '@Kai');
      await tester.pump();
      await tester.tap(find.text('Start raid'));
      await tester.pumpAndSettle();
      expect(h.commands.single, isA<RaidCommand>());
      expect((h.commands.single as RaidCommand).login, 'kai');
    });

    testWidgets('an ad break is confirmed with its length', (tester) async {
      final h = await modToolsHarness(broadcaster: true);
      await pump(tester, ModToolsSheet(chatStore: h.chat));
      await tester.scrollUntilVisible(find.text('Run an ad'), 200);
      await tester.tap(find.text('Run an ad'));
      await tester.pumpAndSettle();
      expect(find.text('Run an ad?'), findsOneWidget);
      await tester.tap(find.text('90s'));
      await tester.tap(find.text('Run ad'));
      await tester.pumpAndSettle();
      expect((h.commands.single as CommercialCommand).seconds, 90);
    });
  });

  testWidgets('the AutoMod queue allows a message and clears it', (
    tester,
  ) async {
    final h = await modToolsHarness();
    runInAction(() => h.tools.heldMessages.addAll(kHeldMessages));
    when(
      () => h.mod.resolveHeldMessage(
        moderatorId: '22',
        messageId: 'm-1',
        decision: AutoModDecision.allow,
      ),
    ).thenAnswer((_) async {});
    await pump(tester, AutoModQueueSheet(tools: h.tools));
    expect(find.text('is this link safe? example.com'), findsOneWidget);
    expect(find.textContaining('Blocked link'), findsOneWidget);
    expect(find.textContaining('AutoMod · level 2'), findsOneWidget);
    await tester.tap(find.text('Allow').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Allowed'), findsOneWidget);
    await tester.tap(find.text('Clear resolved'));
    await tester.pumpAndSettle();
    expect(find.text('is this link safe? example.com'), findsNothing);
    expect(h.tools.heldMessages, hasLength(1));
  });

  testWidgets('removing a moderator is confirmed first', (tester) async {
    final h = await modToolsHarness(broadcaster: true);
    stubModLists(h.api, h.mod);
    await pump(
      tester,
      RoleListSheet(chatStore: h.chat, role: ChannelRole.moderator),
    );
    expect(find.text('2 moderators'), findsOneWidget);
    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    expect(find.text('Remove moderator?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.commands, isEmpty);
    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    final command = h.commands.single as RoleCommand;
    expect((command.login, command.granted), ('mira', false));
  });

  testWidgets('an announcement is sent with its color', (tester) async {
    final h = await modToolsHarness();
    await pump(tester, AnnounceSheet(chatStore: h.chat));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Giveaway at 9!');
    await tester.tap(find.text('Green'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();
    final command = h.commands.single as AnnounceCommand;
    expect(
      (command.message, command.color),
      ('Giveaway at 9!', AnnouncementColor.green),
    );
  });

  testWidgets('a poll in progress can be ended', (tester) async {
    final h = await modToolsHarness(broadcaster: true);
    stubModLists(h.api, h.mod);
    when(() => h.mod.endPoll(broadcasterId: '12345', pollId: 'p-1')).thenAnswer(
      (_) async => const ChannelPoll(
        id: 'p-1',
        title: 'Which boss next?',
        status: 'TERMINATED',
        choices: [],
      ),
    );
    await pump(tester, PollSheet(chatStore: h.chat));
    expect(find.text('128 votes'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'End poll'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'End poll').last);
    await tester.pumpAndSettle();
    expect(find.text('Poll ended.'), findsOneWidget);
    expect(find.text('Start poll'), findsOneWidget);
  });

  testWidgets('a new poll needs a question and two choices', (tester) async {
    final h = await modToolsHarness(broadcaster: true);
    when(
      () => h.mod.getLatestPoll(broadcasterId: '12345'),
    ).thenAnswer((_) async => null);
    when(
      () => h.mod.createPoll(
        broadcasterId: '12345',
        title: 'Snack?',
        choices: ['Chips', 'Fruit'],
        duration: const Duration(minutes: 2),
      ),
    ).thenAnswer(
      (_) async => const ChannelPoll(
        id: 'p-2',
        title: 'Snack?',
        status: 'ACTIVE',
        choices: [PollChoice(id: 'a', title: 'Chips')],
      ),
    );
    await pump(tester, PollSheet(chatStore: h.chat));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Snack?');
    await tester.enterText(fields.at(1), 'Chips');
    await tester.pump();
    final start = find.widgetWithText(FilledButton, 'Start poll');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    await tester.enterText(fields.at(2), 'Fruit');
    await tester.pump();
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('Poll started.'), findsOneWidget);
  });

  testWidgets('a locked prediction is resolved after confirmation', (
    tester,
  ) async {
    final h = await modToolsHarness(broadcaster: true);
    stubModLists(h.api, h.mod);
    when(
      () => h.mod.endPrediction(
        broadcasterId: '12345',
        predictionId: 'pr-1',
        end: PredictionEnd.resolved,
        winningOutcomeId: 'o-1',
      ),
    ).thenAnswer(
      (_) async => const ChannelPrediction(
        id: 'pr-1',
        title: 'First try?',
        status: 'RESOLVED',
        outcomes: [],
      ),
    );
    await pump(tester, PredictionSheet(chatStore: h.chat));
    expect(find.text('PREDICTION LOCKED'), findsOneWidget);
    expect(find.text('Lock'), findsNothing);
    expect(find.text('42 predictors · 15,000 points'), findsOneWidget);
    await tester.tap(find.text('Pick as result').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('“Clean run” wins.'), findsOneWidget);
    await tester.tap(find.text('Confirm result'));
    await tester.pumpAndSettle();
    expect(find.text('Result confirmed.'), findsOneWidget);
  });

  testWidgets('a refund is confirmed, then leaves the list', (tester) async {
    final h = await modToolsHarness(broadcaster: true);
    stubModLists(h.api, h.mod);
    when(
      () => h.mod.resolveRedemption(
        broadcasterId: '12345',
        rewardId: 'r-1',
        redemptionId: 'x-1',
        decision: RedemptionDecision.canceled,
      ),
    ).thenAnswer((_) async {});
    await pump(tester, RedemptionsSheet(chatStore: h.chat));
    expect(find.text('Pick the next map · 2,500 points'), findsOneWidget);
    await tester.tap(find.text('Refund'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Refund'));
    await tester.pumpAndSettle();
    expect(find.text('Request refunded.'), findsOneWidget);
    expect(find.text('No requests waiting'), findsOneWidget);
  });

  testWidgets('an unban request is approved with a note', (tester) async {
    final h = await modToolsHarness();
    stubModLists(h.api, h.mod);
    when(
      () => h.mod.resolveUnbanRequest(
        broadcasterId: '12345',
        moderatorId: '22',
        requestId: 'u-1',
        approve: true,
        resolution: 'Welcome back',
      ),
    ).thenAnswer((_) async {});
    await pump(tester, UnbanRequestsSheet(chatStore: h.chat));
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Welcome back');
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();
    expect(find.text('Request from Rookie approved.'), findsOneWidget);
    expect(find.text('No unban requests'), findsOneWidget);
  });

  testWidgets('blocked terms: a short term is refused here', (tester) async {
    final h = await modToolsHarness();
    stubModLists(h.api, h.mod);
    await pump(tester, BlockedTermsSheet(chatStore: h.chat));
    expect(find.text('free followers'), findsOneWidget);
    expect(find.text('Temporary'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(
      find.text('A blocked term needs at least 2 characters.'),
      findsOneWidget,
    );
    verifyNever(
      () => h.mod.addBlockedTerm(
        broadcasterId: any(named: 'broadcasterId'),
        moderatorId: any(named: 'moderatorId'),
        text: any(named: 'text'),
      ),
    );
  });

  testWidgets('stream info saves the title, category and tags', (tester) async {
    final h = await modToolsHarness(broadcaster: true);
    stubModLists(h.api, h.mod);
    when(
      () => h.mod.updateStreamInfo(
        broadcasterId: '12345',
        title: 'Speedrun practice, any%',
        gameId: '1',
        tags: ['English'],
      ),
    ).thenAnswer((_) async {});
    await pump(tester, StreamInfoSheet(chatStore: h.chat));
    expect(find.text('Speedrun'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Speedrun'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Stream info saved.'), findsOneWidget);
  });

  testWidgets('the card shows a moderator what Twitch said of the user', (
    tester,
  ) async {
    final h = await modToolsHarness();
    h.tools
      ..noteClearChat('33', null)
      ..noteSuspicion('33', SuspiciousStatus.monitored);
    await pump(tester, UserCardModPills(tools: h.tools, userId: '33'));
    expect(find.text('Banned'), findsOneWidget);
    expect(find.text('Monitored'), findsOneWidget);
  });

  testWidgets('restricting from the card is confirmed first', (tester) async {
    final h = await modToolsHarness();
    await pump(
      tester,
      UserCardModActions(
        chatStore: h.chat,
        login: 'Ana',
        userId: '33',
        name: 'Ana',
        isModerator: false,
        isVip: false,
      ),
    );
    expect(find.text('Make moderator'), findsNothing, reason: 'owner only');
    await tester.tap(find.text('Restrict'));
    await tester.pumpAndSettle();
    expect(
      find.text('Only moderators will see messages from Ana.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Restrict'));
    await tester.pumpAndSettle();
    final command = h.commands.single as SuspicionCommand;
    expect(
      (command.login, command.status, command.on),
      ('ana', SuspiciousStatus.restricted, true),
    );
  });

  testWidgets('the shield pill shows while shield mode is on', (tester) async {
    final h = await modToolsHarness();
    await pump(tester, ShieldModeIndicator(chatStore: h.chat));
    expect(find.text('Shield mode on'), findsNothing);
    h.tools.noteShieldMode(true);
    await tester.pumpAndSettle();
    expect(find.text('Shield mode on'), findsOneWidget);
  });
}
