import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/vod/widgets/video_card_layout.dart';

void main() {
  testWidgets('shows the fallback, chips, lines and taps through', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoCardLayout(
            thumbnailUrl: null,
            fallbackIcon: Icons.movie_outlined,
            lengthLabel: '0:30',
            topChips: const [VideoCardChip(child: Text('1.2K views'))],
            title: 'A clip',
            subtitle: 'Just Chatting',
            details: '3 days ago',
            footer: const Text('Clipped by someone'),
            onTap: () => taps++,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    for (final text in [
      '0:30',
      '1.2K views',
      'A clip',
      'Just Chatting',
      '3 days ago',
      'Clipped by someone',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }

    await tester.tap(find.text('A clip'));
    expect(taps, 1);
  });
}
