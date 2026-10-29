import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_watch_streak_service.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/home/stream_list/stream_list_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

class MockWatchStreakService extends Mock implements TwitchWatchStreakService {}

void main() {
  late MockTwitchApi api;
  late MockAuthStore auth;
  late MockWatchStreakService streaks;
  late SettingsStore settings;

  setUp(() {
    api = MockTwitchApi();
    auth = MockAuthStore();
    streaks = MockWatchStreakService();
    settings = SettingsStore.fromJson({});
    final user = MockUserStore();
    when(() => auth.user).thenReturn(user);
    when(() => auth.twitchWebToken).thenReturn('webtok');
    when(() => user.details).thenReturn(const UserTwitch('me', 'me', 'Me', ''));
    when(() => user.blockedUsers).thenReturn(ObservableList());
    when(
      () => api.getFollowedStreams(
        id: any(named: 'id'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => const StreamsTwitch([], {}));
    when(
      () => api.getTopStreams(cursor: any(named: 'cursor')),
    ).thenAnswer((_) async => const StreamsTwitch([], {}));
    when(
      () => streaks.getStreaks(authToken: any(named: 'authToken')),
    ).thenAnswer((_) async => {'7': 4});
  });

  Future<ListStore> build(ListType type) async {
    final store = ListStore(
      authStore: auth,
      settingsStore: settings,
      twitchApi: api,
      listType: type,
      watchStreakService: streaks,
    );
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return store;
  }

  test('the followed list knows the running streaks', () async {
    final store = await build(ListType.followed);

    expect(store.watchStreaks, {'7': 4});
    verify(() => streaks.getStreaks(authToken: 'webtok')).called(1);
  });

  test('a failure shows none and is not asked again soon', () async {
    when(
      () => streaks.getStreaks(authToken: any(named: 'authToken')),
    ).thenAnswer((_) async => null);
    final store = await build(ListType.followed);
    await store.refreshStreams();

    expect(store.watchStreaks, isEmpty);
    verify(
      () => streaks.getStreaks(authToken: any(named: 'authToken')),
    ).called(1);
  });

  test('signed out of twitch.tv or another list, nothing is asked', () async {
    when(() => auth.twitchWebToken).thenReturn(null);
    await build(ListType.followed);
    when(() => auth.twitchWebToken).thenReturn('webtok');
    await build(ListType.top);

    verifyNever(() => streaks.getStreaks(authToken: any(named: 'authToken')));
  });
}
