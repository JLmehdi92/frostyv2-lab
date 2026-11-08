import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_community_service.dart';
import 'package:onset/models/shoutout_profile.dart';
import 'package:onset/screens/channel/chat/chat.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/channel/chat/widgets/shoutout_card.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

import '../../../helpers/chat_widget_harness.dart';

class _MockCommunity extends Mock implements TwitchCommunityService {}

const _notice = ShoutoutNotice(
  id: 's1',
  targetId: '2',
  targetLogin: 'target',
  targetName: 'Target',
);

void main() {
  late StreamController<ShoutoutNotice> shoutouts;
  late List<String> profiles;

  setUp(() {
    shoutouts = StreamController<ShoutoutNotice>.broadcast();
    profiles = [];
  });

  tearDown(() => shoutouts.close());

  Future<void> pump(
    WidgetTester tester,
    TwitchCommunityService? service,
  ) async {
    final store = chatWidgetStore();
    when(() => store.shoutoutRequests).thenAnswer((_) => shoutouts.stream);
    when(() => store.channelName).thenReturn('somechannel');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ChannelEventsStore?>.value(value: null),
          Provider<TwitchCommunityService?>.value(value: service),
        ],
        child: MaterialApp(
          theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
          home: Scaffold(
            body: Chat(
              chatStore: store,
              onAddChat: () {},
              openUserCard:
                  (context, {required ChatStore chatStore, required user}) =>
                      profiles.add(user.login),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a shoutout opens its card, and Profile the user card', (
    tester,
  ) async {
    final service = _MockCommunity();
    when(
      () => service.getShoutoutProfile(
        channelLogin: any(named: 'channelLogin'),
        targetLogin: any(named: 'targetLogin'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer(
      (_) async => const ShoutoutProfile(
        id: '2',
        login: 'target',
        displayName: 'Target',
      ),
    );
    await pump(tester, service);

    shoutouts.add(_notice);
    await tester.pumpAndSettle();
    expect(find.byType(ShoutoutCard), findsOneWidget);
    verify(
      () => service.getShoutoutProfile(
        channelLogin: 'somechannel',
        targetLogin: 'target',
        authToken: any(named: 'authToken'),
      ),
    ).called(1);

    await tester.tap(find.byKey(ShoutoutCard.profileKey));
    await tester.pumpAndSettle();
    expect(find.byType(ShoutoutCard), findsNothing);
    expect(profiles, ['target']);
  });

  testWidgets('without the service, the user card opens as before', (
    tester,
  ) async {
    await pump(tester, null);

    shoutouts.add(_notice);
    await tester.pumpAndSettle();

    expect(find.byType(ShoutoutCard), findsNothing);
    expect(profiles, ['target']);
  });
}
