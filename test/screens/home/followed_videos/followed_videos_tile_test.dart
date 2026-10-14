import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/home/stream_list/stream_list_store.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockHypeTrainService extends Mock implements TwitchHypeTrainService {}

class MockUserStore extends Mock implements UserStore {}

void main() {
  testWidgets('the Following page offers the videos with nobody live', (
    tester,
  ) async {
    final api = MockTwitchApi();
    final auth = MockAuthStore();
    final user = MockUserStore();
    when(() => auth.user).thenReturn(user);
    when(() => user.details).thenReturn(const UserTwitch('7', 'me', 'Me', ''));
    when(() => user.blockedUsers).thenReturn(ObservableList());
    when(
      () => api.getFollowedStreams(
        id: any(named: 'id'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => const StreamsTwitch([], {}));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: auth),
          Provider<SettingsStore>.value(value: SettingsStore.fromJson({})),
          Provider<TwitchApi>.value(value: api),
          Provider<TwitchHypeTrainService>.value(value: MockHypeTrainService()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StreamsList(
              listType: ListType.followed,
              scrollController: ScrollController(),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(find.text('No followed streams'), findsOneWidget);
    expect(find.text('Followed videos'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
