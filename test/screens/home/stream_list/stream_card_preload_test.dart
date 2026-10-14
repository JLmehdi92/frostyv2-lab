import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_stream_service.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/home/stream_list/large_stream_card.dart';
import 'package:frosty/screens/home/stream_list/stream_card.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/services/playback_preloader.dart';
import 'package:frosty/theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockTwitchStreamService extends Mock implements TwitchStreamService {}

const _stream = StreamTwitch(
  '1',
  'login',
  'Name',
  '1',
  'Game',
  'Title',
  10,
  '2026-10-13T15:00:00Z',
  'https://static-cdn.jtvnw.net/previews-ttv/live_user_login-{width}x{height}.jpg',
);

void main() {
  late MockTwitchStreamService service;
  late PlaybackPreloader previous;

  setUp(() {
    service = MockTwitchStreamService();
    when(() => service.preload(any())).thenAnswer((_) async {});
    previous = PlaybackPreloader.instance;
    PlaybackPreloader.instance = PlaybackPreloader(service, isAndroid: true);
  });

  tearDown(() => PlaybackPreloader.instance = previous);

  for (final (name, card) in [
    ('stream card', const StreamCard(streamInfo: _stream, showThumbnail: true)),
    (
      'large stream card',
      const LargeStreamCard(streamInfo: _stream, showThumbnail: true),
    ),
  ]) {
    testWidgets('pressing a $name preloads its token', (tester) async {
      await tester.pumpWidget(
        Provider<SettingsStore>.value(
          value: SettingsStore.fromJson({}),
          child: MaterialApp(
            theme: ThemeData(extensions: const [FrostyColors.light]),
            home: Scaffold(body: SingleChildScrollView(child: card)),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Title').first),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.cancel();

      verify(() => service.preload('login')).called(1);
    });
  }
}
