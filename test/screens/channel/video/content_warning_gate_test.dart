import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/channel.dart';
import 'package:frosty/screens/channel/video/content_warning_gate.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

Channel _channel(List<String> labels) => Channel(
  broadcasterId: '1',
  broadcasterLogin: 'streamer',
  broadcasterName: 'Streamer',
  broadcasterLanguage: 'en',
  title: 'Title',
  gameId: '1',
  gameName: 'Game',
  contentClassificationLabels: labels,
);

void main() {
  late MockTwitchApi api;
  late SettingsStore settings;

  setUp(() {
    AcceptedContentWarnings.reset();
    api = MockTwitchApi();
    settings = SettingsStore.fromJson({});
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<TwitchApi>.value(value: api),
        Provider<SettingsStore>.value(value: settings),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ContentWarningGate(
            userId: '1',
            displayName: 'Streamer',
            child: Text('VIDEO'),
          ),
        ),
      ),
    ),
  );

  testWidgets('a labeled channel is covered until accepted', (tester) async {
    when(
      () => api.getChannel(userId: '1'),
    ).thenAnswer((_) async => _channel(['SexualThemes']));

    await pump(tester);
    await tester.pump();

    expect(find.text('Start watching'), findsOneWidget);
    expect(find.textContaining('Sexual Themes'), findsOneWidget);

    await tester.tap(find.text('Start watching'));
    await tester.pump();
    expect(find.text('Start watching'), findsNothing);
    expect(AcceptedContentWarnings.has('1'), isTrue);
  });

  testWidgets('no labels, no warning', (tester) async {
    when(
      () => api.getChannel(userId: '1'),
    ).thenAnswer((_) async => _channel([]));
    await pump(tester);
    await tester.pump();
    expect(find.text('Start watching'), findsNothing);
  });

  testWidgets('already accepted this session: never asks again', (
    tester,
  ) async {
    AcceptedContentWarnings.add('1');
    await pump(tester);
    await tester.pump();
    expect(find.text('Start watching'), findsNothing);
    verifyNever(() => api.getChannel(userId: any(named: 'userId')));
  });

  testWidgets('with the setting off, it never fetches or warns', (
    tester,
  ) async {
    settings.warnMatureContent = false;
    await pump(tester);
    await tester.pump();
    expect(find.text('Start watching'), findsNothing);
    verifyNever(() => api.getChannel(userId: any(named: 'userId')));
  });

  testWidgets('a failed fetch plays instead of blocking', (tester) async {
    when(
      () => api.getChannel(userId: '1'),
    ).thenThrow(const ApiException('offline'));
    await pump(tester);
    await tester.pump();
    expect(find.text('Start watching'), findsNothing);
    expect(find.text('VIDEO'), findsOneWidget);
  });
}
