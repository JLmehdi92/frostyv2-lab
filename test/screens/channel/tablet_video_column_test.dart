import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/tablet_video_column.dart';

/// Stands in for the player: counts how often its state is created, the way
/// a recreated player would restart its stream.
class _PlayerProbe extends StatefulWidget {
  const _PlayerProbe({super.key});

  static var created = 0;

  @override
  State<_PlayerProbe> createState() => _PlayerProbeState();
}

class _PlayerProbeState extends State<_PlayerProbe> {
  @override
  void initState() {
    super.initState();
    _PlayerProbe.created++;
  }

  @override
  Widget build(BuildContext context) {
    final below = TabletInfoBelow.maybeOf(context);
    return ColoredBox(
      color: Colors.black,
      child: Text('info below: $below', textDirection: TextDirection.ltr),
    );
  }
}

void main() {
  const playerKey = ValueKey('player');
  const infoKey = ValueKey('info');

  setUp(() => _PlayerProbe.created = 0);

  /// A tablet's landscape layout: the video column beside a chat that takes
  /// [chatWidth] of the [screen]'s width.
  Future<void> pump(
    WidgetTester tester, {
    required Size screen,
    required double chatWidth,
    bool fill = false,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: TabletVideoColumn(
                  fill: fill,
                  video: const _PlayerProbe(key: playerKey),
                  info: const SizedBox.expand(key: infoKey),
                ),
              ),
              SizedBox(width: screen.width * chatWidth),
            ],
          ),
        ),
      ),
    );
  }

  Size playerSize(WidgetTester tester) => tester.getSize(find.byKey(playerKey));

  group('1280 × 800 landscape', () {
    testWidgets('with room, the info area stands under a full-width video', (
      tester,
    ) async {
      await pump(tester, screen: const Size(1280, 800), chatWidth: 0.25);
      // 960 wide → a 540 high video, 260 left for the info area.
      expect(playerSize(tester), const Size(960, 540));
      expect(find.byKey(infoKey), findsOneWidget);
      expect(tester.getRect(find.byKey(infoKey)).top, 540);
      expect(find.text('info below: true'), findsOneWidget);
    });

    testWidgets('filling the picture gives the video the whole column', (
      tester,
    ) async {
      await pump(
        tester,
        screen: const Size(1280, 800),
        chatWidth: 0.25,
        fill: true,
      );
      expect(playerSize(tester), const Size(960, 800));
      expect(find.byKey(infoKey), findsNothing);
      expect(find.text('info below: false'), findsOneWidget);
    });
  });

  group('1280 × 600 landscape (a short window)', () {
    testWidgets('without room the video takes the whole column height', (
      tester,
    ) async {
      // 1024 wide at the narrowest chat → 576 high, which leaves less than
      // the info area's minimum: no info area, the video gets all 600 dp
      // (the player letterboxes its 16:9 picture inside, never stretched).
      await pump(tester, screen: const Size(1280, 600), chatWidth: 0.2);
      expect(playerSize(tester), const Size(1024, 600));
      expect(find.byKey(infoKey), findsNothing);
      expect(find.text('info below: false'), findsOneWidget);
    });

    testWidgets('a wider chat brings the info area back, same player', (
      tester,
    ) async {
      await pump(tester, screen: const Size(1280, 600), chatWidth: 0.2);
      expect(find.byKey(infoKey), findsNothing);

      // Dragging the divider: 0.45 → 704 wide, 396 high, 204 left.
      await pump(tester, screen: const Size(1280, 600), chatWidth: 0.45);
      expect(playerSize(tester), const Size(704, 396));
      expect(find.byKey(infoKey), findsOneWidget);
      expect(find.text('info below: true'), findsOneWidget);

      // And narrower again: gone, the video takes the height back.
      await pump(tester, screen: const Size(1280, 600), chatWidth: 0.2);
      expect(playerSize(tester), const Size(1024, 600));
      expect(find.byKey(infoKey), findsNothing);

      // The player was never rebuilt from scratch.
      expect(_PlayerProbe.created, 1);
    });

    testWidgets('a chat at its expanded half keeps the info area', (
      tester,
    ) async {
      // 640 wide → 360 high, 240 left.
      await pump(tester, screen: const Size(1280, 480 + 120), chatWidth: 0.5);
      expect(playerSize(tester), const Size(640, 360));
      expect(find.byKey(infoKey), findsOneWidget);
    });
  });

  testWidgets('the boundary: the info area needs its full minimum', (
    tester,
  ) async {
    // 1024 wide → 576 high; 696 leaves exactly 120, 695 one dp short.
    await pump(tester, screen: const Size(1280, 696), chatWidth: 0.2);
    expect(playerSize(tester), const Size(1024, 576));
    expect(find.byKey(infoKey), findsOneWidget);

    await pump(tester, screen: const Size(1280, 695), chatWidth: 0.2);
    expect(playerSize(tester), const Size(1024, 695));
    expect(find.byKey(infoKey), findsNothing);
    expect(_PlayerProbe.created, 1);
  });
}
