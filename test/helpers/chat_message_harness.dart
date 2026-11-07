import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableMap, ObservableSet;
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/cheermote.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/channel/chat/widgets/chat_message.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';

class MockChatStore extends Mock implements ChatStore {}

class MockChatAssetsStore extends Mock implements ChatAssetsStore {}

/// A chat store with no emotes or badges, for drawing a [ChatMessage] of the
/// channel `channel` (id 12345, display name `Channel`).
MockChatStore fakeChatStore({
  SettingsStore? settings,
  Map<String, UserTwitch>? channelIdToUserTwitch,
  ObservableMap<String, UserTwitch>? channelProfiles,
}) {
  final assets = MockChatAssetsStore();
  when(() => assets.cheermotes).thenReturn(Cheermotes.empty);
  when(() => assets.emoteToObject).thenReturn({});
  when(() => assets.twitchBadgesToObject).thenReturn({});
  when(() => assets.userToFFZBadges).thenReturn({});
  when(() => assets.userTo7TVBadges).thenReturn({});
  when(() => assets.userToBTTVBadges).thenReturn({});
  when(() => assets.ffzRoomInfo).thenReturn(null);
  when(() => assets.showEmoteMenu).thenReturn(false);
  when(() => assets.channelIdToUserTwitch).thenReturn(
    channelProfiles ?? ObservableMap.of(channelIdToUserTwitch ?? {}),
  );

  final store = MockChatStore();
  final revealed = ObservableSet<String>();
  when(() => store.settings).thenReturn(settings ?? SettingsStore.fromJson({}));
  when(() => store.assetsStore).thenReturn(assets);
  when(() => store.channelId).thenReturn('12345');
  when(() => store.channelName).thenReturn('channel');
  when(() => store.displayName).thenReturn('Channel');
  when(() => store.revealedMessageIds).thenReturn(revealed);
  when(() => store.revealMessage(any())).thenAnswer((invocation) {
    revealed.add(invocation.positionalArguments.first as String);
  });
  when(() => store.canModerate).thenReturn(false);
  final revealedFiltered = ObservableSet<String>();
  when(() => store.revealedFilteredMessageIds).thenReturn(revealedFiltered);
  when(() => store.revealFilteredMessage(any())).thenAnswer((invocation) {
    revealedFiltered.add(invocation.positionalArguments.first as String);
  });
  when(() => store.updateNotification(any())).thenReturn(null);
  when(() => store.userCardRequests).thenAnswer((_) => const Stream.empty());
  return store;
}

/// Draws [message] in the dark theme, at the top of the screen.
Future<void> pumpChatMessage(
  WidgetTester tester,
  IRCMessage message,
  ChatStore store,
) async {
  const themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
  await tester.pumpWidget(
    MaterialApp(
      theme: themes.dark,
      home: Scaffold(
        body: ListView(
          children: [ChatMessage(ircMessage: message, chatStore: store)],
        ),
      ),
    ),
  );
}

/// Records what the app writes to the clipboard.
List<String> captureClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}
