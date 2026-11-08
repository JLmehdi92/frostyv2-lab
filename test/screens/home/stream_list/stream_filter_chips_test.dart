import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/home/stream_list/streams_list.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/onset_chip.dart';
import 'package:provider/provider.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

void main() {
  testWidgets('tag chips filter the list; clear brings it back', (
    tester,
  ) async {
    final api = MockTwitchApi();
    final auth = MockAuthStore();
    final user = MockUserStore();
    when(() => auth.user).thenReturn(user);
    when(() => user.blockedUsers).thenReturn(ObservableList());
    final settings = SettingsStore.fromJson({});
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer(
      (invocation) async => StreamsTwitch(
        invocation.namedArguments[#language] == 'de'
            ? const []
            : const [
                StreamTwitch(
                  '1',
                  'one',
                  'Streamer One',
                  '1',
                  'Game',
                  'Title',
                  10,
                  '',
                  '',
                  tags: ['Chill'],
                ),
                StreamTwitch(
                  '2',
                  'two',
                  'Streamer Two',
                  '1',
                  'Game',
                  'Title',
                  10,
                  '',
                  '',
                  tags: ['Speedrun'],
                ),
              ],
        const {},
      ),
    );
    tester.view
      ..physicalSize = const Size(600, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: auth),
          Provider<SettingsStore>.value(value: settings),
          Provider<TwitchApi>.value(value: api),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [OnsetColors.dark]),
          home: Scaffold(
            body: StreamsList(
              listType: ListType.top,
              scrollController: ScrollController(),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Streamer Two'), findsOneWidget);
    await tester.tap(find.widgetWithText(OnsetChip, 'Chill'));
    await tester.pump();
    expect(find.text('Streamer Two'), findsNothing);
    expect(find.text('Streamer One'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.text('Streamer Two'), findsOneWidget);
    expect(find.text('Clear filters'), findsNothing);
  });
}
