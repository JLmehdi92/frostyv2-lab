import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/overlay_chat_frame.dart';
import 'package:onset/screens/channel/chat/overlay_chat_placement.dart';

void main() {
  late OverlayChatPlacement placement;
  late List<bool> sides;

  Future<void> pump(WidgetTester tester, {bool handles = true}) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) => Row(
            children: [
              const Expanded(child: SizedBox()),
              OverlayChatFrame(
                width: 200,
                placement: placement,
                showHandles: handles,
                leftSide: false,
                onPlacementChanged: (next) => setState(() => placement = next),
                onLeftSideChanged: sides.add,
                child: const ColoredBox(
                  key: ValueKey('chat'),
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  setUp(() {
    placement = const OverlayChatPlacement(top: 0, height: 0.5);
    sides = [];
  });

  testWidgets('the chat takes its saved part of the height', (tester) async {
    await pump(tester);
    expect(
      tester.getSize(find.byKey(const ValueKey('chat'))),
      const Size(200, 200),
    );
  });

  testWidgets('dragged down, resized, then to the other side', (tester) async {
    await pump(tester);
    await tester.drag(
      find.byKey(const ValueKey('overlay-chat-move')),
      const Offset(0, 100),
    );
    await tester.pump();
    expect(placement.top, closeTo(0.25, 0.05));

    await tester.drag(
      find.byKey(const ValueKey('overlay-chat-resize')),
      const Offset(0, 40),
    );
    await tester.pump();
    expect(placement.height, closeTo(0.6, 0.05));

    await tester.drag(
      find.byKey(const ValueKey('overlay-chat-move')),
      const Offset(-500, 0),
    );
    await tester.pump();
    expect(sides, [true]);
  });

  testWidgets('no handles while the controls are hidden', (tester) async {
    await pump(tester, handles: false);
    expect(find.byKey(const ValueKey('overlay-chat-move')), findsNothing);
    expect(find.byTooltip('Resize chat'), findsNothing);
  });
}
