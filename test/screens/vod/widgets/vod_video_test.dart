import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/stores/caption_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/stores/ivs_vod_store.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:frosty/screens/vod/widgets/vod_video.dart';
import 'package:mocktail/mocktail.dart';

class MockIvsVodStore extends Mock implements IvsVodStore {}

void main() {
  late MockIvsVodStore store;

  setUp(() {
    store = MockIvsVodStore();
    when(() => store.textureId).thenReturn(1);
    when(() => store.status).thenReturn(VodPlaybackStatus.playing);
    // Captions off: no line over the picture.
    when(() => store.captions).thenReturn(
      CaptionStore(
        settings: SettingsStore.fromJson({}),
        invoke: (_, [_]) async {},
      ),
    );
  });

  /// The video on a 3:2 tablet screen, as in full screen.
  Future<Size> pictureSize(WidgetTester tester, {bool fill = false}) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 1500,
            height: 1000,
            child: VodVideo(store: store, fillScreen: fill),
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(Texture));
  }

  testWidgets('fit keeps 16:9 with bars instead of stretching', (
    tester,
  ) async {
    final size = await pictureSize(tester);

    expect(size.width, 1500);
    expect(size.height, closeTo(1500 * 9 / 16, 0.01));
  });

  testWidgets('fill keeps 16:9 and crops the sides', (tester) async {
    final size = await pictureSize(tester, fill: true);

    expect(size.height, 1000);
    expect(size.width, closeTo(1000 * 16 / 9, 0.01));
  });
}
