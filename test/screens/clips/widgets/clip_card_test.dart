import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/clips/widgets/clip_card.dart';

final _clip = Clip(
  id: '1',
  slug: 'Slug',
  title: 'Wow',
  viewCount: 12,
  createdAt: DateTime.now().subtract(const Duration(days: 1)),
  durationSeconds: 30,
  broadcasterId: '42',
  broadcasterLogin: 'streamer',
  broadcasterDisplayName: 'Streamer',
  gameName: 'Celeste',
);

void main() {
  Future<void> pump(WidgetTester tester, Widget card) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));

  testWidgets('names the category, or the channel in a category list', (
    tester,
  ) async {
    await pump(tester, ClipCard(clip: _clip, onTap: () {}));
    expect(find.text('Celeste'), findsOneWidget);

    await pump(tester, ClipCard(clip: _clip, showChannel: true, onTap: () {}));
    expect(find.text('Streamer'), findsOneWidget);
    expect(find.text('Celeste'), findsNothing);
  });
}
