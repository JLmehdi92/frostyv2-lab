import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/stores/up_next_store.dart';
import 'package:onset/screens/vod/widgets/up_next_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/l10n.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Vod video(String id, String title) => Vod(
    id: id,
    title: title,
    lengthSeconds: 3600,
    createdAt: DateTime.utc(2026, 10, 12),
    viewCount: 1,
    ownerId: '42',
    ownerLogin: 'streamer',
    ownerDisplayName: 'Streamer',
    gameId: '33',
  );

  for (final locale in sweepLocales) {
    testWidgets('the up next card fits a 320 dp phone at text ×1.5'
        '${sweepName(locale)}', (tester) async {
      final store = UpNextStore(
        current: video('1', 'Partie du matin'),
        channelVideos: () async => [video('2', 'Une autre partie')],
        similarVideos: (_) async => const [],
        savedPositions: () async => const {},
        autoplay: () => VodAutoplay.always,
        isMetered: () async => false,
        onPlay: (_) {},
      );
      addTearDown(store.dispose);
      await tester.runAsync(store.onEnded);
      await pumpLocalized(
        tester,
        Scaffold(
          body: Stack(children: [UpNextOverlay(store: store)]),
        ),
        locale: locale,
        size: const Size(320, 568),
        textScale: 1.5,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  }
}
