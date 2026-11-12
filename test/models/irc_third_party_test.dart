import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/cheermote.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/third_party_cosmetics.dart';
import 'package:onset/screens/channel/chat/widgets/ffz_modified_emote.dart';
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

  Future<List<InlineSpan>> render(
    WidgetTester tester,
    String text, {
    double? nameContrast,
    bool selectable = false,
  }) async {
    late List<InlineSpan> spans;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              spans = IRCMessage.fromString('$_line$text').generateSpan(
                context,
                assetsStore: assets,
                badgeScale: 1,
                emoteScale: 1,
                launchExternal: false,
                nameContrast: nameContrast,
              );
              final line = Text.rich(TextSpan(children: spans));
              return selectable ? SelectionArea(child: line) : line;
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
    expect(find.text('Fan'), findsOneWidget);
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

  testWidgets('room FFZ badges are added to the user’s FFZ badges, once', (
    tester,
  ) async {
    const global = ChatBadge(
      name: 'FFZ Developer',
      url: 'https://cdn.ffz.net/badge/4x.png',
      color: '#FF0000',
      type: BadgeType.ffz,
    );
    const room = ChatBadge(
      name: 'Channel helper',
      url: 'https://cdn.ffz.net/badge3/4x.png',
      color: '#0000FF',
      type: BadgeType.ffz,
    );
    when(() => assets.userToFFZBadges).thenReturn({
      '42': [global],
    });
    when(() => assets.ffzRoomBadgesFor('42')).thenReturn([global, room]);

    await render(tester, 'hello');

    final urls = tester
        .widgetList<OnsetCachedNetworkImage>(
          find.byType(OnsetCachedNetworkImage),
        )
        .map((image) => image.imageUrl);
    expect(urls, [global.url, room.url]);
  });

  testWidgets('a painted name is one text, measured once', (tester) async {
    PaintedName.clearMeasurements();
    when(() => assets.paintFor('42')).thenReturn(_paint);

    await render(tester, 'hello');
    await render(tester, 'hello again');

    expect(
      find.descendant(
        of: find.byType(PaintedName),
        matching: find.byType(RichText),
      ),
      findsOneWidget,
    );
    expect(find.byType(ShaderMask), findsNothing);
    expect(PaintedName.measuredCount, 1);
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(PaintedName),
        matching: find.byType(Text),
      ),
    );
    expect(text.style!.foreground!.shader, isNotNull);
    expect(text.style!.shadows, _paint.shadows);
  });

  testWidgets('a painted name can be selected with the message', (
    tester,
  ) async {
    when(() => assets.paintFor('42')).thenReturn(_paint);

    await render(tester, 'hello', selectable: true);

    final name = tester.widget<RichText>(
      find.descendant(
        of: find.byType(PaintedName),
        matching: find.byType(RichText),
      ),
    );
    expect(name.selectionRegistrar, isNotNull);
  });

  testWidgets('a paint too dark to read falls back to the readable color', (
    tester,
  ) async {
    when(() => assets.paintFor('42')).thenReturn(
      const NamePaint(
        id: 'dark',
        kind: NamePaintKind.linearGradient,
        stops: [
          NamePaintStop(0, Color(0xFF000010)),
          NamePaintStop(1, Color(0xFF000033)),
        ],
      ),
    );

    final spans = await render(tester, 'hello', nameContrast: 4.5);

    expect(find.byType(PaintedName), findsNothing);
    final name = spans.whereType<TextSpan>().firstWhere((s) => s.text == 'Fan');
    expect(name.style!.color, const Color(0xFFFF0000));
  });

  testWidgets('a readable paint is kept with readable colors on', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 300));
    when(() => assets.paintFor('42')).thenReturn(_paint);

    await render(tester, 'hello', nameContrast: 1.5);

    expect(find.byType(PaintedName), findsOneWidget);
  });

  test('paint images are decoded at a bounded height', () {
    final bounded =
        PaintedName.boundedPaintImage(const AssetImage('x.png')) as ResizeImage;
    expect(bounded.height, PaintedName.paintImageHeight);
    expect(bounded.width, isNull);
  });

  testWidgets('an animated FFZ modifier animates the emote under it', (
    tester,
  ) async {
    when(() => assets.emoteToObject).thenReturn({
      'KEKW': _emote('KEKW'),
      'ffzSpin': _emote(
        'ffzSpin',
        zeroWidth: true,
        flags: FfzModifier.hidden | FfzModifier.rotate,
      ),
    });

    await render(tester, 'KEKW ffzSpin');

    final modified = tester.widget<FfzModifiedEmote>(
      find.byType(FfzModifiedEmote),
    );
    expect(modified.modifiers & FfzModifier.rotate, FfzModifier.rotate);
    expect(modified.animate, isTrue);
    expect(find.byType(OnsetCachedNetworkImage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an emote is decoded at its drawn size, not its file size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    when(() => assets.emoteToObject).thenReturn({'pet': _emote('pet')});

    await render(tester, 'pet');

    final image = tester.widget<OnsetCachedNetworkImage>(
      find.byType(OnsetCachedNetworkImage),
    );
    expect(image.memCacheHeight, (image.height! * 3).ceil());
    expect(image.memCacheWidth, isNull);
  });
}
