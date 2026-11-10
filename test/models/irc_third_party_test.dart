import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/cheermote.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/third_party_cosmetics.dart';
import 'package:onset/screens/channel/chat/widgets/painted_name.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';

import '../helpers/chat_message_harness.dart';

const _line =
    '@display-name=Fan;user-id=42;color=#FF0000 '
    ':fan!fan@fan.tmi.twitch.tv PRIVMSG #c :';

const _paint = NamePaint(
  id: 'p',
  kind: NamePaintKind.linearGradient,
  stops: [
    NamePaintStop(0, Color(0xFFC8FF3D)),
    NamePaintStop(1, Color(0xFF3DC8FF)),
  ],
  shadows: [Shadow(color: Color(0xFF101010), blurRadius: 1)],
);

Emote _emote(String name, {int flags = 0, bool zeroWidth = false}) => Emote(
  name: name,
  zeroWidth: zeroWidth,
  url: 'https://cdn.example/$name.webp',
  type: EmoteType.ffzGlobal,
  modifierFlags: flags,
);

void main() {
  late MockChatAssetsStore assets;

  setUp(() {
    assets = MockChatAssetsStore();
    when(() => assets.cheermotes).thenReturn(Cheermotes.empty);
    when(() => assets.emoteToObject).thenReturn({});
    when(() => assets.twitchBadgesToObject).thenReturn({});
    when(() => assets.userToFFZBadges).thenReturn({});
    when(() => assets.userTo7TVBadges).thenReturn({});
    when(() => assets.userToBTTVBadges).thenReturn({});
  });

  Future<List<InlineSpan>> render(WidgetTester tester, String text) async {
    late List<InlineSpan> spans;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              spans = IRCMessage.fromString('$_line$text').generateSpan(
                context,
                assetsStore: assets,
                badgeScale: 1,
                emoteScale: 1,
                launchExternal: false,
                nameContrast: null,
              );
              return Text.rich(TextSpan(children: spans));
            },
          ),
        ),
      ),
    );
    return spans;
  }

  testWidgets('a 7TV paint draws the name, tappable', (tester) async {
    when(() => assets.paintFor('42')).thenReturn(_paint);

    await render(tester, 'hello');

    final painted = tester.widget<PaintedName>(find.byType(PaintedName));
    expect(painted.text, 'Fan');
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.text('Fan'), findsNWidgets(2));
  });

  testWidgets('without a paint the name stays plain text', (tester) async {
    final spans = await render(tester, 'hello');

    expect(find.byType(PaintedName), findsNothing);
    final name = spans.whereType<TextSpan>().firstWhere((s) => s.text == 'Fan');
    expect(name.style!.color, const Color(0xFFFF0000));
  });

  testWidgets('a sender’s personal emote is drawn for their message only', (
    tester,
  ) async {
    when(
      () => assets.personalEmotesFor('42'),
    ).thenReturn({'myPet': _emote('myPet')});

    final spans = await render(tester, 'look myPet');

    final images = [
      for (final span in spans.whereType<WidgetSpan>())
        ...find
            .descendant(
              of: find.byWidget(span.child),
              matching: find.byType(OnsetCachedNetworkImage),
            )
            .evaluate()
            .map((e) => (e.widget as OnsetCachedNetworkImage).imageUrl),
    ];
    expect(images, ['https://cdn.example/myPet.webp']);
  });

  testWidgets('channel emotes win over a personal emote of the same name', (
    tester,
  ) async {
    when(() => assets.emoteToObject).thenReturn({'pet': _emote('channelPet')});
    when(
      () => assets.personalEmotesFor('42'),
    ).thenReturn({'pet': _emote('myPet')});

    await render(tester, 'pet');

    final urls = tester
        .widgetList<OnsetCachedNetworkImage>(
          find.byType(OnsetCachedNetworkImage),
        )
        .map((image) => image.imageUrl);
    expect(urls, ['https://cdn.example/channelPet.webp']);
  });

  testWidgets('an FFZ flip modifier flips the emote and hides itself', (
    tester,
  ) async {
    when(() => assets.emoteToObject).thenReturn({
      'base': _emote('base'),
      'ffzX': _emote(
        'ffzX',
        zeroWidth: true,
        flags: FfzModifier.hidden | FfzModifier.flipX,
      ),
    });

    await render(tester, 'base ffzX');

    final urls = tester
        .widgetList<OnsetCachedNetworkImage>(
          find.byType(OnsetCachedNetworkImage),
        )
        .map((image) => image.imageUrl);
    expect(urls, ['https://cdn.example/base.webp']);
    final flip = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byType(OnsetCachedNetworkImage),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(flip.transform.entry(0, 0), -1);
  });

  testWidgets('an FFZ grow modifier widens the emote', (tester) async {
    when(() => assets.emoteToObject).thenReturn({
      'base': Emote(
        name: 'base',
        zeroWidth: false,
        width: 28,
        height: 28,
        url: 'https://cdn.example/base.webp',
        type: EmoteType.ffzGlobal,
      ),
      'ffzW': _emote(
        'ffzW',
        zeroWidth: true,
        flags: FfzModifier.hidden | FfzModifier.growX,
      ),
    });

    await render(tester, 'base ffzW');

    final base = tester.widget<OnsetCachedNetworkImage>(
      find.byType(OnsetCachedNetworkImage),
    );
    expect(base.width, 56);
    expect(base.fit, BoxFit.fill);
  });

  testWidgets('a stack without modifiers draws as before', (tester) async {
    when(() => assets.emoteToObject).thenReturn({
      'base': _emote('base'),
      'over': _emote('over', zeroWidth: true),
    });

    await render(tester, 'base over');

    final images = tester
        .widgetList<OnsetCachedNetworkImage>(
          find.byType(OnsetCachedNetworkImage),
        )
        .toList();
    expect(images.map((image) => image.imageUrl), [
      'https://cdn.example/base.webp',
      'https://cdn.example/over.webp',
    ]);
    expect(images.every((image) => image.fit == null), isTrue);
    expect(
      find.ancestor(
        of: find.byType(OnsetCachedNetworkImage),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });
}
