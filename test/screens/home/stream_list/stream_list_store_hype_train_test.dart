import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/home/stream_list/stream_list_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

class MockHypeTrainService extends Mock implements TwitchHypeTrainService {}

StreamTwitch stream(String id) =>
    StreamTwitch(id, 'login$id', 'Name$id', '1', 'Game', 'Title', 10, '', '');

void main() {
  late MockTwitchApi api;
  late MockAuthStore auth;
  late MockHypeTrainService hypeTrains;
  late SettingsStore settings;

  setUp(() {
    api = MockTwitchApi();
    auth = MockAuthStore();
    hypeTrains = MockHypeTrainService();
    settings = SettingsStore.fromJson({});
    final user = MockUserStore();
    when(() => auth.user).thenReturn(user);
    when(() => user.details).thenReturn(const UserTwitch('me', 'me', 'Me', ''));
    when(() => user.blockedUsers).thenReturn(ObservableList());
    when(
      () => api.getFollowedStreams(
        id: any(named: 'id'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => StreamsTwitch([stream('1'), stream('2')], {}));
    when(
      () => api.getTopStreams(cursor: any(named: 'cursor')),
    ).thenAnswer((_) async => StreamsTwitch([stream('3')], {}));
    when(
      () => hypeTrains.getActiveStatuses(any()),
    ).thenAnswer((_) async => {'2': const HtCardStatus(level: 4)});
  });

  Future<ListStore> build(ListType type) async {
    final store = ListStore(
      authStore: auth,
      settingsStore: settings,
      twitchApi: api,
      listType: type,
      hypeTrainService: hypeTrains,
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return store;
  }

  test('the followed list knows which streams run a train', () async {
    final store = await build(ListType.followed);

    expect(store.hypeTrains['2']!.level, 4);
    expect(store.hypeTrains['1'], isNull);
    final asked = verify(
      () => hypeTrains.getActiveStatuses(captureAny()),
    ).captured.last;
    expect(asked, containsAll(['1', '2']));
  });

  test('other lists do not ask', () async {
    final store = await build(ListType.top);

    expect(store.hypeTrains, isEmpty);
    verifyNever(() => hypeTrains.getActiveStatuses(any()));
  });

  test('nothing is asked with the setting off', () async {
    settings.showHypeTrain = false;
    final store = await build(ListType.followed);

    expect(store.hypeTrains, isEmpty);
    verifyNever(() => hypeTrains.getActiveStatuses(any()));
  });
}
