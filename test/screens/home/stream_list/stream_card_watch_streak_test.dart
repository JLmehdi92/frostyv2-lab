import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/stream.dart';
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
  tags: ['English'],
);

Future<void> pump(WidgetTester tester, Widget card) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(extensions: const [FrostyColors.light]),
    home: Scaffold(body: SingleChildScrollView(child: card)),
  ),
);

void main() {
  testWidgets("a followed card carries Twitch's streak, in green", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      const StreamCard(
        streamInfo: _stream,
        showThumbnail: true,
        watchStreak: 6,
      ),
    );

    expect(find.text('Streak 6'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Watch streak 6')), findsOneWidget);
    // The tags stay.
    expect(find.text('English'), findsOneWidget);

    await pump(
      tester,
      const StreamCard(streamInfo: _stream, showThumbnail: true),
    );
    expect(find.textContaining('Streak'), findsNothing);
    semantics.dispose();
  });

  testWidgets('the large card too', (tester) async {
    await pump(
      tester,
      const LargeStreamCard(
        streamInfo: _stream,
        showThumbnail: true,
        watchStreak: 12,
      ),
    );

    // On the hero, in its pill beside the channel.
    expect(find.text('Streak 12'), findsOneWidget);
  });
}
