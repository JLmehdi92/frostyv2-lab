import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/cheermote.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/widgets/frosty_cached_network_image.dart';

class MockChatAssetsStore extends Mock implements ChatAssetsStore {}

const _cdn = 'https://d3aqoihi2n8ty8.cloudfront.net/actions/cheer';

final _cheermotes = Cheermotes.fromHelix({
  'data': [
    {
      'prefix': 'Cheer',
      'tiers': [
        for (final (min, color) in [(1, '#979797'), (100, '#9c3ee8')])
          {
            'min_bits': min,
            'color': color,
            'images': {
              for (final theme in ['dark', 'light'])
                theme: {
                  'animated': {'2': '$_cdn/$theme/animated/$min/2.gif'},
                  'static': {'2': '$_cdn/$theme/static/$min/2.png'},
                },
            },
          },
      ],
    },
  ],
});

void main() {
  late MockChatAssetsStore assets;

  setUp(() {
    assets = MockChatAssetsStore();
    when(() => assets.cheermotes).thenReturn(_cheermotes);
    when(() => assets.emoteToObject).thenReturn({});
    when(() => assets.twitchBadgesToObject).thenReturn({});
    when(() => assets.userToFFZBadges).thenReturn({});
    when(() => assets.userTo7TVBadges).thenReturn({});
    when(() => assets.userToBTTVBadges).thenReturn({});
    when(() => assets.ffzRoomInfo).thenReturn(null);
  });

  Future<List<InlineSpan>> render(WidgetTester tester, String line) async {
    late List<InlineSpan> spans;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(
          builder: (context) {
            spans = IRCMessage.fromString(line).generateSpan(
              context,
              assetsStore: assets,
              badgeScale: 1,
              emoteScale: 1,
              launchExternal: false,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return spans;
  }

  List<String> images(List<InlineSpan> spans) => [
    for (final span in spans.whereType<WidgetSpan>())
      if (span.child case Semantics(
        child: final FrostyCachedNetworkImage image,
      ))
        image.imageUrl,
  ];

  testWidgets('a cheer draws its tier image and amount', (tester) async {
    final spans = await render(
      tester,
      '@bits=250;display-name=Fan :fan!fan@fan.tmi.twitch.tv PRIVMSG #c '
      ':Cheer150 Cheer100 gg',
    );

    expect(images(spans), [
      '$_cdn/dark/animated/100/2.gif',
      '$_cdn/dark/animated/100/2.gif',
    ]);
    final amount = spans.whereType<TextSpan>().firstWhere(
      (s) => s.text == '150',
    );
    expect(amount.style?.color, const Color(0xFF9C3EE8));

    // Spaced like words: ": [img]150 [img]100 gg".
    final message = spans.skipWhile((s) => !(s is TextSpan && s.text == ':'));
    expect(
      [
        for (final span in message)
          span is WidgetSpan ? '[img]' : (span as TextSpan).text,
      ].join(),
      ': [img]150 [img]100 gg',
    );
  });

  testWidgets('outside a cheer it is just text', (tester) async {
    final spans = await render(
      tester,
      '@display-name=Fan :fan!fan@fan.tmi.twitch.tv PRIVMSG #c :Cheer100',
    );
    expect(images(spans), isEmpty);
  });
}
