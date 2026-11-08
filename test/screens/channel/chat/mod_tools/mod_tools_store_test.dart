import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/models/moderation.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_features.dart';
import 'package:onset/screens/channel/chat/mod_tools/stores/mod_tools_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';

class _MockTwitchApi extends Mock implements TwitchApi {}

class _MockModApi extends Mock implements TwitchModApi {}

typedef _Line = ({String text, String? action, void Function()? onAction});

void main() {
  late _MockTwitchApi api;
  late _MockModApi mod;
  late Map<String, StreamController<EventSubTopicEvent>> topics;
  late List<EventSubTopic> listened;
  late List<_Line> lines;
  late bool showActions;

  ModToolsStore store() => ModToolsStore(
    twitchApi: api,
    broadcasterId: '11',
    listenEvents: (topic) {
      listened.add(topic);
      final controller = topics.putIfAbsent(
        topic.type,
        StreamController<EventSubTopicEvent>.broadcast,
      );
      return EventSubHandle.forTesting(topic, controller.stream, () {});
    },
    showActionsInChat: () => showActions,
    clock: () => DateTime.utc(2026, 11, 7, 10),
    onChatLine: (text, {actionLabel, onAction}) =>
        lines.add((text: text, action: actionLabel, onAction: onAction)),
  );

  void emit(String type, Map<String, Object?> event) =>
      topics[type]!.add(EventSubData(event));

  setUpAll(() => registerFallbackValue(AutoModDecision.allow));

  setUp(() {
    api = _MockTwitchApi();
    mod = _MockModApi();
    topics = {};
    listened = [];
    lines = [];
    showActions = true;
    when(() => api.moderation).thenReturn(mod);
    when(
      () => api.getTokenScopes(),
    ).thenAnswer((_) async => ModFeature.allScopes);
    when(
      () => mod.getShieldMode(
        broadcasterId: '11',
        moderatorId: any(named: 'moderatorId'),
      ),
    ).thenAnswer((_) async => const ShieldModeStatus(isActive: false));
  });

  test('logging in asks for every scope the mod tools use', () {
    final asked = AuthBase.loginScopes.split(' ').toSet();
    for (final feature in ModFeature.values) {
      expect(
        {...asked, ...AuthBase.channelToolScopes}.containsAll(feature.scopes),
        isTrue,
        reason: feature.name,
      );
    }
    expect(asked, hasLength(AuthBase.loginScopes.split(' ').length));
  });

  test('a moderator listens to the moderation topics as themselves', () async {
    final tools = store();
    await tools.start('22');
    expect(
      [for (final t in listened) t.type],
      [
        'channel.moderate',
        'channel.shield_mode.begin',
        'channel.shield_mode.end',
        'automod.message.hold',
        'automod.message.update',
      ],
    );
    expect(listened.first.condition, {
      'broadcaster_user_id': '11',
      'moderator_user_id': '22',
    });
    expect(tools.isBroadcaster, isFalse);
    expect(tools.canUse(ModFeature.autoMod), isTrue);
    expect(tools.canUse(ModFeature.polls), isFalse, reason: 'owner only');
    expect(tools.shows(ModFeature.polls), isFalse);
    expect(tools.needsLogin(ModFeature.polls), isFalse);
  });

  test('a login from before the mod tools is asked to log in again', () async {
    when(
      () => api.getTokenScopes(),
    ).thenAnswer((_) async => {'moderator:manage:banned_users', 'chat:read'});
    final tools = store();
    await tools.start('11');
    expect(tools.needsLogin(ModFeature.shieldMode), isTrue);
    expect(tools.needsLogin(ModFeature.polls), isTrue);
    expect(tools.canUse(ModFeature.bans), isTrue);
    expect(listened, isEmpty, reason: 'nothing the token could not receive');
  });

  test('unreadable scopes leave every tool off, without throwing', () async {
    when(() => api.getTokenScopes()).thenThrow(const NetworkException('down'));
    final tools = store();
    await tools.start('22');
    expect(tools.scopes, isEmpty);
    expect(tools.canUse(ModFeature.announcements), isFalse);
  });

  test('a mod action becomes a chat line and a log entry', () async {
    final tools = store();
    await tools.start('22');
    emit('channel.moderate', {
      'action': 'warn',
      'moderator_user_name': 'Mira',
      'warn': {'user_id': '33', 'user_name': 'Ana', 'reason': 'be nice'},
    });
    await pumpEventQueue();
    expect(lines.single.text, 'Mira warned Ana. Reason: “be nice”.');
    expect(tools.actions.single.action, 'warn');
    expect(tools.statusOf('33').warned, isTrue);

    showActions = false;
    emit('channel.moderate', {
      'action': 'ban',
      'moderator_user_name': 'Mira',
      'ban': {'user_id': '33', 'user_name': 'Ana'},
    });
    await pumpEventQueue();
    expect(lines, hasLength(1), reason: 'the setting is off');
    expect(tools.actions, hasLength(2));
    expect(tools.statusOf('33').banned, isTrue);
  });

  test('a malformed event costs that event only', () async {
    final tools = store();
    await tools.start('22');
    emit('channel.moderate', {'action': 'ban', 'ban': 'nonsense'});
    emit('automod.message.hold', {'message': 12});
    await pumpEventQueue();
    expect(tools.actions, isEmpty);
    expect(tools.heldMessages, isEmpty);
  });

  test('shield mode follows the events and is said once', () async {
    final tools = store();
    await tools.start('22');
    emit('channel.shield_mode.begin', {'moderator_user_name': 'Mira'});
    emit('channel.shield_mode.begin', {'moderator_user_name': 'Mira'});
    await pumpEventQueue();
    expect(tools.shieldActive, isTrue);
    expect([for (final l in lines) l.text], ['Mira turned shield mode on.']);
    emit('channel.shield_mode.end', {});
    await pumpEventQueue();
    expect(tools.shieldActive, isFalse);
    expect(lines.last.text, 'Shield mode is off.');
  });

  test('turning shield mode on goes through Helix', () async {
    when(
      () => mod.setShieldMode(
        broadcasterId: '11',
        moderatorId: '22',
        active: true,
      ),
    ).thenAnswer((_) async => const ShieldModeStatus(isActive: true));
    final tools = store();
    await tools.start('22');
    expect(await tools.setShieldMode(true), isNull);
    expect(tools.shieldActive, isTrue);

    when(
      () => mod.setShieldMode(
        broadcasterId: '11',
        moderatorId: '22',
        active: false,
      ),
    ).thenThrow(const ApiException('nope', 403));
    expect(
      await tools.setShieldMode(false),
      'Couldn’t turn shield mode off: Twitch says you can’t moderate this chat.',
    );
    expect(tools.shieldActive, isTrue);
  });

  test('a held message waits, is announced, and is resolved', () async {
    when(
      () => mod.resolveHeldMessage(
        moderatorId: '22',
        messageId: 'm-1',
        decision: AutoModDecision.allow,
      ),
    ).thenAnswer((_) async {});
    final tools = store();
    await tools.start('22');
    final requested = <ModToolsView>[];
    tools.requests.listen(requested.add);
    emit('automod.message.hold', {
      'message_id': 'm-1',
      'user_id': '33',
      'user_name': 'Ana',
      'message': {'text': 'hello'},
      'reason': 'automod',
    });
    emit('automod.message.hold', {
      'message_id': 'm-2',
      'user_id': '34',
      'user_name': 'Kai',
      'message': {'text': 'hey'},
      'reason': 'blocked_term',
    });
    await pumpEventQueue();
    expect(tools.pendingHeldCount, 2);
    expect(lines.first.text, 'AutoMod is holding a message from Ana.');
    expect(lines.first.action, 'Review');
    lines.first.onAction!();
    await pumpEventQueue();
    expect(requested, [ModToolsView.autoMod]);

    expect(await tools.resolveHeld('m-1', AutoModDecision.allow), isNull);
    emit('automod.message.update', {'message_id': 'm-2', 'status': 'Expired'});
    await pumpEventQueue();
    expect(tools.pendingHeldCount, 0);
    tools.clearResolvedHeld();
    expect(tools.heldMessages, isEmpty);
  });

  test('IRC bans and timeouts mark the user for the card', () {
    final tools = store();
    tools.noteClearChat('33', 600);
    expect(
      tools.statusOf('33').timedOutAt(DateTime.utc(2026, 11, 7, 10, 5)),
      isTrue,
    );
    expect(
      tools.statusOf('33').timedOutAt(DateTime.utc(2026, 11, 7, 10, 11)),
      isFalse,
    );
    tools.noteClearChat('33', null);
    expect(tools.statusOf('33').banned, isTrue);
    tools.noteClearChat(null, null);
    tools.noteSuspicion('34', SuspiciousStatus.restricted);
    expect(tools.statusOf('34').suspicion, SuspiciousStatus.restricted);
  });

  test('the owner reads a ban from Helix; a moderator never asks', () async {
    when(
      () => mod.getBan(broadcasterId: '11', userId: '33'),
    ).thenAnswer((_) async => const BannedUser(userId: '33', expiresAt: ''));
    final tools = store();
    await tools.start('22');
    await tools.loadBan('33');
    verifyNever(() => mod.getBan(broadcasterId: '11', userId: '33'));
    await tools.start('11');
    await tools.loadBan('33');
    expect(tools.statusOf('33').banned, isTrue);
  });

  test('the statuses kept are bounded, the latest kept', () {
    final tools = store();
    for (var i = 0; i < ModToolsBase.maxUserStatuses + 10; i++) {
      tools.noteClearChat('$i', null);
    }
    expect(tools.userStatuses, hasLength(ModToolsBase.maxUserStatuses));
    expect(tools.statusOf('0').banned, isFalse);
    expect(
      tools.statusOf('${ModToolsBase.maxUserStatuses + 9}').banned,
      isTrue,
    );
  });

  test('stopping cancels the topics and forgets the session', () async {
    final tools = store();
    await tools.start('22');
    tools.stop();
    expect(tools.moderatorId, isNull);
    expect(tools.canUse(ModFeature.autoMod), isFalse);
    tools.dispose();
  });

  test('a held message is sent to the queue once', () async {
    final tools = store();
    await tools.start('22');
    final event = {
      'message_id': 'm-1',
      'user_id': '33',
      'user_name': 'Ana',
      'message': {'text': 'hello'},
    };
    emit('automod.message.hold', event);
    emit('automod.message.hold', event);
    await pumpEventQueue();
    expect(tools.heldMessages, hasLength(1));
    expect(tools.heldMessages.single.status, HeldMessageStatus.pending);
  });
}
