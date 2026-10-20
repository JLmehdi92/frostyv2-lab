import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel/video/live_progress.dart';
import 'package:frosty/screens/vod/stores/channel_videos_store.dart';
import 'package:frosty/screens/vod/vod_resume.dart';
import 'package:frosty/screens/vod/widgets/channel_videos_tab.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTwitchVodService extends Mock implements TwitchVodService {}

Vod _vod(String id, {String? broadcastId}) => Vod(
  id: id,
  title: 'v$id',
  lengthSeconds: 3600,
  createdAt: DateTime.utc(2026),
  viewCount: 1,
  ownerId: '42',
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
  type: VodType.archive,
  broadcastId: broadcastId,
);

void main() {
  late MockTwitchVodService service;

  setUpAll(() => registerFallbackValue(VodType.archive));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VodResumeRepository.shared.resetQueue();
    LiveProgressRepository.shared.resetQueue();
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

  testWidgets('the viewer\'s own progress, live sessions included', (
    tester,
  ) async {
    when(() => service.viewerId).thenReturn(() => '11');
    await tester.runAsync(() async {
      await VodResumeRepository.shared.save(
        '1',
        positionSec: 900,
        lengthSec: 3600,
        viewer: '22',
      );
      await VodResumeRepository.shared.save(
        '2',
        positionSec: 1800,
        lengthSec: 3600,
        viewer: '11',
      );
      await LiveProgressRepository.shared.save(
        viewer: '11',
        streamId: '300',
        channelId: '42',
        startedAt: DateTime.utc(2026),
        offsetSec: 2700,
      );
      await LiveProgressRepository.shared.save(
        viewer: '22',
        streamId: '400',
        channelId: '42',
        startedAt: DateTime.utc(2026),
        offsetSec: 2700,
      );
    });
    await pump(tester, [
      _vod('1'),
      _vod('2', broadcastId: '200'),
      _vod('3', broadcastId: '300'),
      _vod('4', broadcastId: '400'),
    ]);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    final cards = tester.widgetList<VodCard>(find.byType(VodCard)).toList();
    expect(cards.map((c) => c.progress), [
      isNull,
      closeTo(0.5, 0.01),
      closeTo(0.75, 0.01),
      isNull,
    ]);
  });

  testWidgets('an empty channel says so', (tester) async {
    await pump(tester, []);
    expect(find.text('No videos'), findsOneWidget);
  });
}
