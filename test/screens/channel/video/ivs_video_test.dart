import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/ivs_video.dart';
import 'package:frosty/screens/channel/video/stores/ivs_video_store.dart';
import 'package:mocktail/mocktail.dart';

class MockIvsVideoStore extends Mock implements IvsVideoStore {}

void main() {
  late MockIvsVideoStore store;

  setUp(() {
    store = MockIvsVideoStore();
    when(() => store.textureId).thenReturn(1);
    when(() => store.fillScreen).thenReturn(false);
    when(() => store.status).thenReturn(IvsPlaybackStatus.playing);
    when(() => store.streamQuality).thenReturn('1080p60');
    when(() => store.caption).thenReturn(null);
  });

  /// The video on a 3:2 tablet screen, as in full screen.
  Future<Size> pictureSize(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 1500,
            height: 1000,
            child: IvsTextureVideo(videoStore: store),
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(Texture));
  }

  testWidgets('fit keeps 16:9 with bars instead of stretching', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final size = await pictureSize(tester);

    expect(size.width, 1500);
    expect(size.height, closeTo(1500 * 9 / 16, 0.01));
  });

  testWidgets('fill keeps 16:9 and crops the sides', (tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => store.fillScreen).thenReturn(true);

    final size = await pictureSize(tester);

    expect(size.height, 1000);
    expect(size.width, closeTo(1000 * 16 / 9, 0.01));
  });
}
