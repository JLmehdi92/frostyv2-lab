import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_directory_service.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/home/top/tags/tag_streams.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockDirectoryService extends Mock implements TwitchDirectoryService {}

void main() {
  late MockDirectoryService directory;

  setUpAll(() => registerFallbackValue(StreamSort.recent));

  setUp(() {
    directory = MockDirectoryService();
    when(
      () => directory.getTagStreams(
        tag: any(named: 'tag'),
        sort: any(named: 'sort'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) async => const StreamsTwitch([], {}));
  });

  Future<void> pumpApp(WidgetTester tester, Widget home) => tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SettingsStore>.value(value: SettingsStore.fromJson({})),
        Provider<AuthStore>.value(value: MockAuthStore()),
        Provider<TwitchApi>.value(value: MockTwitchApi()),
        Provider<TwitchDirectoryService>.value(value: directory),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [FrostyColors.light]),
        home: home,
      ),
    ),
  );

  testWidgets('the tag\'s live streams, in the picked order', (tester) async {
    await pumpApp(tester, const TagStreams(tag: 'Chill'));
    await tester.pump();

    expect(find.text('Chill'), findsOneWidget);
    expect(find.text('No live streams'), findsOneWidget);
    verify(
      () => directory.getTagStreams(tag: 'Chill', sort: StreamSort.viewersHigh),
    ).called(1);

    await tester.tap(find.byTooltip('Sort streams'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Viewers (low to high)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    verify(
      () => directory.getTagStreams(tag: 'Chill', sort: StreamSort.viewersLow),
    ).called(1);
  });

  testWidgets('only Twitch tags open a page', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Column(
          children: [
            TextButton(
              onPressed: () => TagStreams.open(context, 'two words'),
              child: const Text('bad'),
            ),
            TextButton(
              onPressed: () => TagStreams.open(context, 'Speedrun'),
              child: const Text('good'),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('bad'));
    await tester.pump();
    expect(find.byType(TagStreams), findsNothing);

    await tester.tap(find.text('good'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TagStreams), findsOneWidget);
  });
}
