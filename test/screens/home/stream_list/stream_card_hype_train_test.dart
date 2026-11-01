import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_card_pill.dart';
import 'package:onset/screens/home/stream_list/large_stream_card.dart';
import 'package:onset/screens/home/stream_list/stream_card.dart';
import 'package:onset/theme.dart';

const _stream = StreamTwitch(
  '1',
  'login',
  'Name',
  '1',
  'Game',
  'Title',
  10,
  '2026-10-13T15:00:00Z',
  'https://static-cdn.jtvnw.net/previews-ttv/live_user_login-{width}x{height}.jpg',
);

Future<void> pump(WidgetTester tester, Widget card) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(extensions: const [OnsetColors.light]),
    home: Scaffold(body: SingleChildScrollView(child: card)),
  ),
);

void main() {
  testWidgets('a card shows the pill only with a running train', (
    tester,
  ) async {
    await pump(
      tester,
      const StreamCard(
        streamInfo: _stream,
        showThumbnail: true,
        hypeTrain: HtCardStatus(level: 4, variant: HtVariant.treasure),
      ),
    );
    expect(find.byType(HypeTrainCardPill), findsOneWidget);
    expect(find.text('Treasure Train level 4'), findsOneWidget);

    await pump(
      tester,
      const StreamCard(streamInfo: _stream, showThumbnail: true),
    );
    expect(find.byType(HypeTrainCardPill), findsNothing);
  });

  testWidgets('the large card too', (tester) async {
    await pump(
      tester,
      const LargeStreamCard(
        streamInfo: _stream,
        showThumbnail: true,
        hypeTrain: HtCardStatus(level: 9, isAllTimeHigh: true),
      ),
    );

    expect(find.text('All-time record · Level 9'), findsOneWidget);
  });

  testWidgets("Twitch's indicator: a 12 sp footnote and a green train", (
    tester,
  ) async {
    Future<Color?> trainTint(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Center(
              child: HypeTrainCardPill(status: HtCardStatus(level: 4)),
            ),
          ),
        ),
      );
      // Past the app's theme animation.
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text('Hype Train level 4'));
      expect(text.style?.fontSize, 12);
      final icon = find.byIcon(Icons.train_rounded);
      expect(tester.getSize(icon).width, 15);
      return tester.widget<Icon>(icon).color;
    }

    expect(
      await trainTint(ThemeData(brightness: Brightness.light)),
      const Color(0xFF0E8661),
    );
    expect(
      await trainTint(ThemeData(brightness: Brightness.dark)),
      const Color(0xFF15C08B),
    );
  });

  testWidgets('a long indicator fits a small thumbnail', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 90,
              child: Stack(
                children: [
                  SizedBox(width: 90, height: 50),
                  PositionedDirectional(
                    start: 0,
                    bottom: 0,
                    child: HypeTrainCardPill(
                      status: HtCardStatus(
                        level: 12,
                        variant: HtVariant.goldenKappa,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the thumbnail preview is named for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      const StreamCard(streamInfo: _stream, showThumbnail: true),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Name stream preview')),
      matchesSemantics(
        label: 'Name stream preview',
        isImage: true,
        hasLongPressAction: true,
        onLongPressHint: 'enlarge',
      ),
    );
    semantics.dispose();
  });
}
