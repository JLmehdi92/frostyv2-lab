import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/vod/widgets/vod_info_strip.dart';

Vod _vod({bool recording = false, String? game = 'Chess'}) => Vod(
  id: '1',
  title: 'Big tournament',
  lengthSeconds: 3600,
  createdAt: DateTime.now().subtract(const Duration(days: 3)),
  viewCount: 12345,
  ownerId: '42',
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
  gameId: game == null ? null : '1',
  gameName: game,
  isRecording: recording,
);

void main() {
  Future<void> pump(WidgetTester tester, Vod vod) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: VodInfoStrip(vod: vod)),
    ),
  );

  testWidgets('shows title, age, views and category', (tester) async {
    await pump(tester, _vod());

    expect(find.text('Big tournament'), findsOneWidget);
    expect(find.text('3 days ago · 12,345 views'), findsOneWidget);
    expect(find.text('Chess'), findsOneWidget);
    expect(find.text('Recording'), findsNothing);
  });

  testWidgets('flags a recording and tolerates no category', (tester) async {
    await pump(tester, _vod(recording: true, game: null));

    expect(find.text('Recording'), findsOneWidget);
    expect(find.text('Chess'), findsNothing);
  });
}
