import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/emotes.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/models/vod_comment.dart';
import 'package:frosty/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/vod_comment_to_irc.dart';
import 'package:frosty/screens/vod/widgets/vod_chat_message.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:mocktail/mocktail.dart';

class MockChatAssetsStore extends Mock implements ChatAssetsStore {}

final _createdAt = DateTime.utc(2026, 10, 12, 17);

IRCMessage _message({String text = 'hi ', String? viewer}) =>
    vodCommentToIrcMessage(
      VodComment(
        id: 'c1',
        offsetSeconds: 3723,
        fragments: [
          VodFragment(text: text),
          const VodFragment(text: 'Kappa', emoteId: '25'),
          const VodFragment(text: ' catJAM'),
        ],
        badges: const [],
        commenterId: '1',
        commenterLogin: 'viewer_one',
        commenterDisplayName: 'Viewer_One',
        color: '#FF4500',
      ),
      channelId: '42',
      channelLogin: 'streamer',
      vodCreatedAt: _createdAt,
      viewerLogin: viewer,
    );

void main() {
  late MockChatAssetsStore assets;
  late SettingsStore settings;

  setUp(() {
    assets = MockChatAssetsStore();
    settings = SettingsStore.fromJson({});
    when(() => assets.emoteToObject).thenReturn({
      'catJAM': const Emote(
        name: 'catJAM',
        zeroWidth: false,
        url: 'https://cdn.7tv.app/emote/x/3x.webp',
        staticUrl: 'https://cdn.7tv.app/emote/x/3x_static.webp',
        type: EmoteType.sevenTVChannel,
      ),
    });
    when(() => assets.twitchBadgesToObject).thenReturn({});
    when(() => assets.userToFFZBadges).thenReturn({});
    when(() => assets.userTo7TVBadges).thenReturn({});
    when(() => assets.userToBTTVBadges).thenReturn({});
    when(() => assets.ffzRoomInfo).thenReturn(null);
  });

  Future<void> pump(WidgetTester tester, IRCMessage message) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VodChatMessage(
              ircMessage: message,
              assetsStore: assets,
              settings: settings,
              vodCreatedAt: _createdAt,
            ),
          ),
        ),
      );

  List<InlineSpan> spans(WidgetTester tester) {
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final all = <InlineSpan>[];
    rich.text.visitChildren((span) {
      all.add(span);
      return true;
    });
    return all;
  }

  testWidgets('renders 7TV and Twitch emotes as images and the name colour', (
    tester,
  ) async {
    await pump(tester, _message());

    final all = spans(tester);
    expect(all.whereType<WidgetSpan>(), hasLength(2));
    final name = all.whereType<TextSpan>().firstWhere(
      (s) => s.text?.contains('Viewer_One') ?? false,
    );
    // Live chat adjusts user colours for contrast; it must still be a
    // reddish colour derived from #FF4500, not the default text colour.
    final color = name.style!.color!;
    expect(color.r, greaterThan(color.g));
    expect(color.r, greaterThan(color.b));
  });

  testWidgets('emotes stand still when animations are off', (tester) async {
    List<String> urls() => tester
        .widgetList<FrostyCachedNetworkImage>(
          find.byType(FrostyCachedNetworkImage),
        )
        .map((image) => image.imageUrl)
        .toList();

    await pump(tester, _message());
    expect(urls(), contains('https://cdn.7tv.app/emote/x/3x.webp'));

    settings.animateEmotes = false;
    await pump(tester, _message());
    expect(
      urls(),
      containsAll([
        'https://cdn.7tv.app/emote/x/3x_static.webp',
        'https://static-cdn.jtvnw.net/emoticons/v2/25/static/dark/3.0',
      ]),
    );
  });

  testWidgets('timestamps show the video time when enabled', (tester) async {
    settings.timestampType = TimestampType.twentyFour;
    await pump(tester, _message());

    final texts = spans(tester).whereType<TextSpan>().map((s) => s.text);
    expect(texts, contains('1:02:03 '));
  });

  testWidgets('a mention of the viewer is highlighted', (tester) async {
    await pump(tester, _message(text: 'yo me_myself ', viewer: 'me_myself'));

    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(VodChatMessage),
        matching: find.byType(Container),
      ),
    );
    expect(box.decoration, isA<BoxDecoration>());
  });

  testWidgets('long press offers to copy the message', (tester) async {
    await pump(tester, _message());

    await tester.longPress(find.byType(VodChatMessage));
    await tester.pumpAndSettle();

    expect(find.text('Copy message'), findsOneWidget);
  });
}
