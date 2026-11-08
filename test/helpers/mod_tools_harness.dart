import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/models/category.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/models/moderation.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_features.dart';
import 'package:onset/screens/channel/chat/mod_tools/stores/mod_tools_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';

import 'chat_message_harness.dart';

class MockModTwitchApi extends Mock implements TwitchApi {}

class MockModApi extends Mock implements TwitchModApi {}

class _MockAuth extends Mock implements AuthStore {}

class _MockUser extends Mock implements UserStore {}

typedef ModToolsHarness = ({
  MockChatStore chat,
  ModToolsStore tools,
  MockModTwitchApi api,
  MockModApi mod,
  List<ModerationCommand> commands,
});

final kHeldMessages = [
  HeldMessage(
    id: 'm-1',
    userId: '31',
    userName: 'NightOwl',
    text: 'is this link safe? example.com',
    reason: 'blocked_link',
    heldAt: DateTime.utc(2026, 11, 7, 18, 42),
  ),
  HeldMessage(
    id: 'm-2',
    userId: '32',
    userName: 'Pixel',
    text: 'that was a terrible play lol',
    reason: 'automod',
    category: 'bullying',
    level: 2,
    heldAt: DateTime.utc(2026, 11, 7, 18, 43),
  ),
];

Future<ModToolsHarness> modToolsHarness({
  bool broadcaster = false,
  Set<String>? scopes,
  SettingsStore? settings,
}) async {
  final api = MockModTwitchApi();
  final mod = MockModApi();
  final chat = fakeChatStore(settings: settings ?? SettingsStore.fromJson({}));
  final auth = _MockAuth();
  final user = _MockUser();
  final me = broadcaster
      ? const UserTwitch('12345', 'channel', 'Channel', '')
      : const UserTwitch('22', 'mira', 'Mira', '');
  when(() => user.details).thenReturn(me);
  when(() => auth.user).thenReturn(user);
  when(() => auth.isLoggedIn).thenReturn(true);
  when(() => chat.auth).thenReturn(auth);
  when(() => chat.twitchApi).thenReturn(api);
  when(() => chat.canModerate).thenReturn(true);
  when(() => api.moderation).thenReturn(mod);
  when(
    () => api.getTokenScopes(),
  ).thenAnswer((_) async => scopes ?? ModFeature.allScopes);
  when(
    () => mod.getShieldMode(
      broadcasterId: any(named: 'broadcasterId'),
      moderatorId: any(named: 'moderatorId'),
    ),
  ).thenAnswer((_) async => const ShieldModeStatus(isActive: false));
  final tools = ModToolsStore(
    twitchApi: api,
    broadcasterId: '12345',
    listenEvents: (topic) =>
        EventSubHandle.forTesting(topic, const Stream.empty(), () {}),
    onChatLine: (_, {actionLabel, onAction}) {},
  );
  await tools.start(me.id);
  when(() => chat.modTools).thenReturn(tools);
  when(() => chat.shieldModeActive).thenAnswer((_) => tools.shieldActive);
  final commands = <ModerationCommand>[];
  when(() => chat.moderate(any(), userId: any(named: 'userId'))).thenAnswer((
    invocation,
  ) async {
    commands.add(invocation.positionalArguments.first as ModerationCommand);
    return (ok: true, message: 'Done.');
  });
  return (chat: chat, tools: tools, api: api, mod: mod, commands: commands);
}

void stubModLists(MockModTwitchApi api, MockModApi mod) {
  when(
    () => mod.getRoleUsers(broadcasterId: '12345', role: ChannelRole.moderator),
  ).thenAnswer(
    (_) async => const [
      ChannelRoleUser(userId: '1', userLogin: 'mira', userName: 'Mira'),
      ChannelRoleUser(userId: '2', userLogin: 'nightowl', userName: 'NightOwl'),
    ],
  );
  when(
    () => mod.getRoleUsers(broadcasterId: '12345', role: ChannelRole.vip),
  ).thenAnswer(
    (_) async => const [
      ChannelRoleUser(userId: '3', userLogin: 'pixel', userName: 'Pixel'),
    ],
  );
  when(
    () => mod.getBlockedTerms(
      broadcasterId: '12345',
      moderatorId: any(named: 'moderatorId'),
    ),
  ).thenAnswer(
    (_) async => const [
      BlockedTerm(id: 't-1', text: 'free followers'),
      BlockedTerm(
        id: 't-2',
        text: 'spoiler',
        expiresAt: '2026-11-08T00:00:00Z',
      ),
    ],
  );
  when(
    () => mod.getPendingUnbanRequests(
      broadcasterId: '12345',
      moderatorId: any(named: 'moderatorId'),
    ),
  ).thenAnswer(
    (_) async => const [
      UnbanRequest(
        id: 'u-1',
        userId: '40',
        userLogin: 'rookie',
        userName: 'Rookie',
        text: 'I got carried away last night. It won’t happen again.',
        status: 'pending',
        createdAt: '2026-11-06T20:00:00Z',
      ),
    ],
  );
  when(() => mod.getPendingRedemptions(broadcasterId: '12345')).thenAnswer(
    (_) async => const [
      RewardRedemption(
        id: 'x-1',
        userLogin: 'pixel',
        userName: 'Pixel',
        reward: RedemptionReward(
          id: 'r-1',
          title: 'Pick the next map',
          cost: 2500,
        ),
        userInput: 'The lighthouse one',
        redeemedAt: '2026-11-07T18:30:00Z',
      ),
    ],
  );
  when(() => mod.getLatestPoll(broadcasterId: '12345')).thenAnswer(
    (_) async => const ChannelPoll(
      id: 'p-1',
      title: 'Which boss next?',
      status: 'ACTIVE',
      choices: [
        PollChoice(id: 'a', title: 'The Warden', votes: 128),
        PollChoice(id: 'b', title: 'Ember Queen', votes: 64),
      ],
    ),
  );
  when(() => mod.getLatestPrediction(broadcasterId: '12345')).thenAnswer(
    (_) async => const ChannelPrediction(
      id: 'pr-1',
      title: 'First try?',
      status: 'LOCKED',
      outcomes: [
        PredictionOutcome(
          id: 'o-1',
          title: 'Clean run',
          users: 42,
          channelPoints: 15000,
        ),
        PredictionOutcome(
          id: 'o-2',
          title: 'Needs retries',
          users: 17,
          channelPoints: 4200,
        ),
      ],
    ),
  );
  when(() => api.getChannel(userId: '12345')).thenAnswer(
    (_) async => const Channel(
      broadcasterId: '12345',
      broadcasterLogin: 'channel',
      broadcasterName: 'Channel',
      broadcasterLanguage: 'en',
      title: 'Speedrun practice, any%',
      gameId: '1',
      gameName: 'Celeste',
      tags: ['English', 'Speedrun'],
    ),
  );
  when(
    () => api.searchCategories(query: any(named: 'query')),
  ).thenAnswer((_) async => const CategoriesTwitch([], null));
}

Widget sheetHost(Widget sheet) => Scaffold(
  backgroundColor: const Color(0xFF141414),
  body: SafeArea(
    child: Align(alignment: Alignment.bottomCenter, child: sheet),
  ),
);
