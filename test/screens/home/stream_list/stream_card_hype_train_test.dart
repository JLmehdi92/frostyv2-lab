import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_card_pill.dart';
import 'package:frosty/screens/home/stream_list/large_stream_card.dart';
import 'package:frosty/screens/home/stream_list/stream_card.dart';
import 'package:frosty/theme.dart';

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
    theme: ThemeData(extensions: const [FrostyColors.light]),
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
    expect(find.text('LVL 4'), findsOneWidget);

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

    expect(find.text('LVL 9'), findsOneWidget);
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
