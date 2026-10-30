import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_followed_categories_service.dart';
import 'package:onset/models/followed_category.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

class MockCategoriesService extends Mock
    implements TwitchFollowedCategoriesService {}

const _category = FollowedCategory(id: '1', name: 'Chess', viewers: 40);

void main() {
  late MockTwitchApi api;
  late MockAuthStore auth;
  late MockCategoriesService categories;
  late SettingsStore settings;

  setUp(() {
    api = MockTwitchApi();
    auth = MockAuthStore();
    categories = MockCategoriesService();
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
      () =>
          categories.getFollowedCategories(authToken: any(named: 'authToken')),
    ).thenAnswer((_) async => [_category]);
  });

  Future<ListStore> build(ListType type) async {
    final store = ListStore(
      authStore: auth,
      settingsStore: settings,
      twitchApi: api,
      listType: type,
      followedCategoriesService: categories,
    );
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return store;
  }

  test('the followed list shows the followed categories', () async {
    final store = await build(ListType.followed);

    expect(store.followedCategories.single.name, 'Chess');
    verify(
      () => categories.getFollowedCategories(authToken: 'webtok'),
    ).called(1);
  });

  test('without the web token nothing is asked', () async {
    when(() => auth.twitchWebToken).thenReturn(null);
    final store = await build(ListType.followed);

    expect(store.followedCategories, isEmpty);
    verifyNever(
      () =>
          categories.getFollowedCategories(authToken: any(named: 'authToken')),
    );
  });

  test('a failure hides the section and is not asked again soon', () async {
    when(
      () =>
          categories.getFollowedCategories(authToken: any(named: 'authToken')),
    ).thenAnswer((_) async => null);
    final store = await build(ListType.followed);
    await store.refreshStreams();
    await store.refreshStreams();

    expect(store.followedCategories, isEmpty);
    verify(
      () =>
          categories.getFollowedCategories(authToken: any(named: 'authToken')),
    ).called(1);
  });

  test('a refresh asks again after a success', () async {
    final store = await build(ListType.followed);
    when(
      () =>
          categories.getFollowedCategories(authToken: any(named: 'authToken')),
    ).thenAnswer((_) async => const []);
    await store.refreshStreams();

    expect(store.followedCategories, isEmpty);
  });

  test('other lists do not ask', () async {
    final store = await build(ListType.top);

    expect(store.followedCategories, isEmpty);
    verifyNever(
      () =>
          categories.getFollowedCategories(authToken: any(named: 'authToken')),
    );
  });
}
