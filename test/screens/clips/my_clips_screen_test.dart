import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/clips/my_clips_screen.dart';
import 'package:onset/screens/clips/widgets/clip_card.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

import '../../fixtures/clip_responses.dart';

class MockClipService extends Mock implements TwitchClipService {}

class MockTwitchApi extends Mock implements TwitchApi {}

void main() {
  late MockClipService clips;
  late MockTwitchApi helix;
  final clip = Clip.fromGql(clipNode);

  setUpAll(() {
    registerFallbackValue(ClipPeriod.lastWeek);
    registerFallbackValue(ClipSort.top);
  });

  setUp(() {
    clips = MockClipService();
    helix = MockTwitchApi();
    when(
      () => clips.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => ClipPage(items: [clip], hasMore: false));
  });

  Future<void> pump(WidgetTester tester, {Size size = const Size(400, 800)}) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<TwitchClipService>.value(value: clips),
          Provider<TwitchApi>.value(value: helix),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [OnsetColors.dark]),
          home: const MyClipsScreen(login: 'Viewer', userId: '7'),
        ),
      ),
    );
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('my channel first, then the clips I made', (tester) async {
    when(
      () => clips.getCuratedClips(
        curatorId: '7',
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => ClipPage(items: [clip, clip], hasMore: false));
    await pump(tester);
    await frames(tester);

    expect(find.text('My clips'), findsOneWidget);
    expect(find.byType(ClipCard), findsOneWidget);
    verify(
      () => clips.getChannelClips(
        login: 'Viewer',
        period: ClipPeriod.lastWeek,
        sort: ClipSort.top,
      ),
    ).called(1);
    expect(find.text('Pick dates'), findsOneWidget);

    await tester.tap(find.text('Clipped by me'));
    await frames(tester);
    expect(find.byType(ClipCard), findsNWidgets(2));
    expect(find.text('Pick dates'), findsNothing);
  });

  testWidgets('clips I made that fail say so', (tester) async {
    when(
      () => clips.getCuratedClips(
        curatorId: any(named: 'curatorId'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenThrow(const ApiException('server error'));
    await pump(tester);
    await frames(tester);
    await tester.tap(find.text('Clipped by me'));
    await frames(tester);
    expect(find.text('Couldn’t load clips.'), findsOneWidget);
  });

  test('manage points at the clip manager', () {
    expect(
      MyClipsScreen.manageUrl('Viewer').toString(),
      'https://dashboard.twitch.tv/u/viewer/content/clips',
    );
  });
}
