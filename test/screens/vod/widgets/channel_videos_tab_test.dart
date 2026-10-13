import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/vod/stores/channel_videos_store.dart';
import 'package:frosty/screens/vod/vod_resume.dart';
import 'package:frosty/screens/vod/widgets/channel_videos_tab.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTwitchVodService extends Mock implements TwitchVodService {}

Vod _vod(String id) => Vod(
  id: id,
  title: 'v$id',
  lengthSeconds: 3600,
  createdAt: DateTime.utc(2026),
  viewCount: 1,
  ownerId: '42',
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
);

void main() {
  late MockTwitchVodService service;

  setUpAll(() => registerFallbackValue(VodType.archive));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VodResumeRepository.shared.resetQueue();
    service = MockTwitchVodService();
  });

  Future<ChannelVideosStore> pump(WidgetTester tester, List<Vod> videos) async {
    when(
      () => service.getChannelVideos(
        login: any(named: 'login'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => VodPage(items: videos, hasMore: false));
    final store = ChannelVideosStore(
      login: 'streamer',
      type: VodType.archive,
      vodService: service,
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChannelVideosTab(store: store, emptyMessage: 'No videos'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('loads on first show, with each video\'s progress', (
    tester,
  ) async {
    await tester.runAsync(
      () => VodResumeRepository.shared.save(
        '2',
        positionSec: 1800,
        lengthSec: 3600,
      ),
    );
    await pump(tester, [_vod('1'), _vod('2')]);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    final cards = tester.widgetList<VodCard>(find.byType(VodCard)).toList();
    expect(cards.map((c) => c.vod.id), ['1', '2']);
    expect(cards[0].progress, isNull);
    expect(cards[1].progress, closeTo(0.5, 0.01));
  });

  testWidgets('an empty channel says so', (tester) async {
    await pump(tester, []);
    expect(find.text('No videos'), findsOneWidget);
  });
}
