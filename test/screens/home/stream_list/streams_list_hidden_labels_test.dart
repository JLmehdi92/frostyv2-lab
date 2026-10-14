import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/channel.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/home/stream_list/stream_list_store.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:frosty/theme.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

void main() {
  testWidgets('a list hidden in full says so and can show it', (tester) async {
    final api = MockTwitchApi();
    final auth = MockAuthStore();
    final user = MockUserStore();
    when(() => auth.user).thenReturn(user);
    when(() => user.blockedUsers).thenReturn(ObservableList());
    final settings = SettingsStore.fromJson({
      'hiddenContentLabels': ['MatureGame'],
    });
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer(
      (_) async => const StreamsTwitch([
        StreamTwitch('1', 'one', 'One', '1', 'Game', 'Title', 10, '', ''),
      ], {}),
    );
    when(() => api.getChannelsByIds(any())).thenAnswer(
      (_) async => {
        '1': const Channel(
          broadcasterId: '1',
          broadcasterLogin: 'one',
          broadcasterName: 'One',
          broadcasterLanguage: 'en',
          title: 'Title',
          gameId: '1',
          gameName: 'Game',
          contentClassificationLabels: ['MatureGame'],
        ),
      },
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: auth),
          Provider<SettingsStore>.value(value: settings),
          Provider<TwitchApi>.value(value: api),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [FrostyColors.light]),
          home: Scaffold(
            body: StreamsList(
              listType: ListType.top,
              scrollController: ScrollController(),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(find.text('Every stream here has a label you hide'), findsOneWidget);
    await tester.tap(find.text('Show them'));
    await tester.pump();

    expect(find.text('One'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
