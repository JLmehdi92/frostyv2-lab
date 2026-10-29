import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/clips/stores/channel_clips_store.dart';
import 'package:onset/screens/clips/widgets/channel_clips_tab.dart';
import 'package:onset/screens/clips/widgets/clip_card.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/scroll_to_top_button.dart';

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
        theme: ThemeData(extensions: const [OnsetColors.light]),
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
    expect(find.text('Try again'), findsOneWidget);
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

  testWidgets('nested in a profile: the injectors, then the chips', (
    tester,
  ) async {
    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer(
      (_) async => ClipPage(items: List.filled(12, clip), hasMore: false),
    );
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChannelClipsTab(
            store: store,
            nested: true,
            leadingSlivers: const [
              SliverToBoxAdapter(
                child: SizedBox(height: 40, child: Text('injected')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final view = find.byType(CustomScrollView);
    expect(
      find.descendant(of: view, matching: find.text('injected')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: view, matching: find.text('All time')),
      findsOneWidget,
    );
    expect(tester.getTopLeft(find.text('7 days')).dy, greaterThanOrEqualTo(40));
    // They scroll with the clips, after the injected sliver.
    await tester.drag(view, const Offset(0, -300));
    await tester.pump();
    expect(find.text('7 days'), findsNothing);
  });

  testWidgets('a new period keeps the chips where they were and starts the '
      'clips from the top', (tester) async {
    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer(
      (_) async => ClipPage(items: List.filled(12, clip), hasMore: false),
    );
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChannelClipsTab(store: store, nested: true)),
      ),
    );
    await tester.pump();

    ScrollPosition chips() => Scrollable.of(
      tester.element(find.text('7 days')),
      axis: Axis.horizontal,
    ).position;
    ScrollPosition list() =>
        Scrollable.of(tester.element(find.byType(ClipCard).first)).position;

    // The chips scrolled sideways, then another period picked there,
    // which loads.
    final month = Completer<ClipPage>();
    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: ClipPeriod.lastMonth,
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) => month.future);
    chips().jumpTo(60);
    await tester.pump();
    await tester.tap(find.text('30 days'));
    await tester.pump();
    expect(find.byType(ClipCard), findsNothing);
    expect(chips().pixels, 60);
    month.complete(ClipPage(items: List.filled(12, clip), hasMore: false));
    await tester.pump();
    await tester.pump();
    expect(chips().pixels, 60);
    expect(store.period, ClipPeriod.lastMonth);

    // A refresh answered at once leaves the list where it is.
    list().jumpTo(400);
    await tester.pump();
    await store.refresh();
    await tester.pump();
    await tester.pump();
    expect(list().pixels, 400);

    // Another period starts it from the top.
    await store.select(period: ClipPeriod.allTime);
    await tester.pump();
    await tester.pump();
    expect(list().pixels, 0);
  });

  testWidgets('the scroll-to-top button only over listed clips', (
    tester,
  ) async {
    final first = Completer<ClipPage>();
    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) => first.future);
    await pump(tester);
    await tester.pump();
    // Loading: skeletons, no button.
    expect(find.byType(ScrollToTopButton), findsNothing);

    first.complete(const ClipPage(items: [], hasMore: false));
    await tester.pump();
    await tester.pump();
    expect(find.text('No clips for this period'), findsOneWidget);
    expect(find.byType(ScrollToTopButton), findsNothing);

    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => ClipPage(items: [clip], hasMore: false));
    await store.refresh();
    await tester.pump();
    expect(find.byType(ClipCard), findsOneWidget);
    expect(find.byType(ScrollToTopButton), findsOneWidget);
  });

  testWidgets('on its own screen, a new period starts the clips from the top', (
    tester,
  ) async {
    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer(
      (_) async => ClipPage(items: List.filled(12, clip), hasMore: false),
    );
    await pump(tester);
    await tester.pump();
    store.scrollController.jumpTo(400);
    await tester.pump();

    await store.select(sort: ClipSort.trending);
    await tester.pump();
    await tester.pump();
    expect(store.scrollController.offset, 0);

    // The same chip again changes nothing.
    store.scrollController.jumpTo(400);
    await tester.pump();
    await store.select(sort: ClipSort.trending);
    await tester.pump();
    await tester.pump();
    expect(store.scrollController.offset, 400);
  });
}
