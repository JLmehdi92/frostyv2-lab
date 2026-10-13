import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_clip_service.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/screens/clips/stores/channel_clips_store.dart';
import 'package:frosty/screens/clips/widgets/channel_clips_tab.dart';
import 'package:frosty/screens/clips/widgets/clip_card.dart';
import 'package:frosty/theme.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/clip_responses.dart';

class MockClipService extends Mock implements TwitchClipService {}

void main() {
  late MockClipService service;
  late ChannelClipsStore store;
  final clip = Clip.fromGql(clipNode);
  final orphan = Clip.fromGql(clipNodeOrphan);

  setUpAll(() {
    registerFallbackValue(ClipPeriod.lastWeek);
    registerFallbackValue(ClipSort.top);
  });

  setUp(() {
    service = MockClipService();
    store = ChannelClipsStore(login: 'xqc', clipService: service);
    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => ClipPage(items: [clip, orphan], hasMore: true));
  });

  tearDown(() => store.dispose());

  Future<void> pump(WidgetTester tester, {Size size = const Size(400, 800)}) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [FrostyColors.light]),
        home: Scaffold(body: ChannelClipsTab(store: store)),
      ),
    );
  }

  testWidgets('lists the clips with their details', (tester) async {
    await pump(tester);
    await tester.pump();

    expect(find.byType(ClipCard), findsNWidgets(2));
    expect(find.text('breakup advice'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^16(\.3)?K views$')), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
    expect(find.textContaining('Clipped by puertoricanporo'), findsOneWidget);
    expect(find.text('Showing the top 2 clips'), findsOneWidget);
  });

  testWidgets('a chip asks for that period', (tester) async {
    await pump(tester);
    await tester.pump();

    await tester.ensureVisible(find.text('All time'));
    await tester.tap(find.text('All time'));
    await tester.pump();
    await tester.pump();

    verify(
      () => service.getChannelClips(
        login: 'xqc',
        period: ClipPeriod.allTime,
        sort: ClipSort.top,
      ),
    ).called(1);
    await tester.ensureVisible(find.text('Trending'));
    await tester.tap(find.text('Trending'));
    await tester.pump();
    verify(
      () => service.getChannelClips(
        login: 'xqc',
        period: ClipPeriod.allTime,
        sort: ClipSort.trending,
      ),
    ).called(1);
  });

  testWidgets('an empty period says so; an error offers a retry', (
    tester,
  ) async {
    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => const ClipPage(items: [], hasMore: false));
    await pump(tester);
    await tester.pump();
    expect(find.text('No clips for this period'), findsOneWidget);

    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenThrow(const ClipApiException('server error'));
    await tester.tap(find.text('30 days'));
    await tester.pump();
    await tester.pump();
    expect(find.text("Couldn't load clips"), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets('a tablet shows the clips side by side', (tester) async {
    await pump(tester, size: const Size(1600, 1067));
    await tester.pump();

    final cards = find.byType(ClipCard);
    final first = tester.getRect(cards.at(0));
    final second = tester.getRect(cards.at(1));
    expect(second.top, first.top);
    expect(second.left, greaterThan(first.right - 1));
    expect(tester.takeException(), isNull);
  });
}
