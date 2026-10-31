import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/vod/widgets/video_kit.dart';

import '../../../helpers/l10n.dart';

void main() {
  testWidgets('the standard hint, in the language on screen', (tester) async {
    await pumpLocalized(
      tester,
      const Scaffold(body: VideoListEmpty(message: 'Aucune vidéo')),
    );
    expect(
      find.text(lookupAppLocalizations(fr).videoListEmptyHint),
      findsOneWidget,
    );
    expect(find.text(VideoListEmpty.defaultHint), findsNothing);
  });

  testWidgets('a hint of its own, or none', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              VideoListEmpty(message: 'A', hint: 'Own hint'),
              VideoListEmpty(message: 'B', hint: null),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Own hint'), findsOneWidget);
    expect(find.text(L10n.english.videoListEmptyHint), findsNothing);
    expect(find.byType(Text), findsNWidgets(3));
  });
}
