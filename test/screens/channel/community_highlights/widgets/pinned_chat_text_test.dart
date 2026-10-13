import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/community_highlights.dart';
import 'package:frosty/models/emotes.dart';
import 'package:frosty/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:frosty/screens/channel/community_highlights/widgets/pinned_chat_text.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mocktail/mocktail.dart';

class MockChatAssetsStore extends Mock implements ChatAssetsStore {}

const _pin = PinnedChatMessage(
  id: 'pin',
  senderId: '7',
  senderLogin: 'mod',
  senderDisplayName: 'Mod',
  color: '#FF4500',
  text: 'rules Kappa catJAM',
  fragments: [
    PinnedFragment(text: 'rules '),
    PinnedFragment(text: 'Kappa', emoteId: '25'),
    PinnedFragment(text: ' catJAM'),
  ],
  badges: [],
);

void main() {
  late MockChatAssetsStore assets;

  setUp(() {
    assets = MockChatAssetsStore();
    when(() => assets.emoteToObject).thenReturn({
      'catJAM': const Emote(
        name: 'catJAM',
        zeroWidth: false,
        url: 'https://cdn.7tv.app/emote/x/3x.webp',
        type: EmoteType.sevenTVChannel,
      ),
    });
    when(() => assets.twitchBadgesToObject).thenReturn({});
    when(() => assets.userToFFZBadges).thenReturn({});
    when(() => assets.userTo7TVBadges).thenReturn({});
    when(() => assets.userToBTTVBadges).thenReturn({});
    when(() => assets.ffzRoomInfo).thenReturn(null);
  });

  testWidgets('renders like chat: name colour, Twitch and 7TV emotes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinnedChatText(
            pin: _pin,
            assetsStore: assets,
            settings: SettingsStore.fromJson({}),
            channelId: '42',
            channelLogin: 'streamer',
          ),
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final spans = <InlineSpan>[];
    rich.text.visitChildren((span) {
      spans.add(span);
      return true;
    });
    expect(spans.whereType<WidgetSpan>(), hasLength(2));
    final name = spans.whereType<TextSpan>().firstWhere(
      (s) => s.text?.contains('Mod') ?? false,
    );
    final color = name.style!.color!;
    expect(color.r, greaterThan(color.b));
    expect(
      spans.whereType<TextSpan>().map((s) => s.text).join(),
      contains('rules'),
    );
  });
}
