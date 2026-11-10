import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_followed_categories_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/followed_category.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/user.dart';
import 'package:onset/widgets/follow/follow_actions.dart';

class _MockService extends Mock implements TwitchViewerActionsService {}

class _MockApi extends Mock implements TwitchApi {}

class _MockCategories extends Mock implements TwitchFollowedCategoriesService {}

StreamTwitch _stream(String id, {String gameId = '509658'}) =>
    StreamTwitch(id, 'c$id', 'C$id', gameId, 'Just Chatting', '', 10, '', '');

StreamsTwitch _streams(List<StreamTwitch> data) =>
    StreamsTwitch(data, const {});

void main() {
  late _MockApi api;
  late _MockCategories categories;
  String? token;
  String? viewer;
  late FollowActions actions;
  late int connects;
  late String? Function() connectedToken;
  late DateTime clock;

  setUp(() {
    connects = 0;
    clock = DateTime.utc(2026, 11, 10);
    connectedToken = () => token;
    api = _MockApi();
    categories = _MockCategories();
    token = 'tok';
    viewer = '77';
    actions = FollowActions(
      service: _MockService(),
      api: api,
      categories: categories,
      webToken: () => token,
      viewerId: () => viewer,
      now: () => clock,
      connectWebSession: () async {
        connects++;
        token = connectedToken();
        return token != null && token!.isNotEmpty;
      },
    );
  });

  test('connecting fetches a missing web session once per tap', () async {
    token = null;
    connectedToken = () => 'fresh';
    expect(await actions.connectWebSession(), isTrue);
    expect(connects, 1);
    expect(await actions.connectWebSession(), isTrue);
    expect(connects, 1);
  });

  test('connecting reports a session it could not get', () async {
    token = null;
    connectedToken = () => null;
    expect(await actions.connectWebSession(), isFalse);
  });

  test('a logged-out viewer never connects', () async {
    token = null;
    viewer = null;
    expect(await actions.connectWebSession(), isFalse);
    expect(connects, 0);
    expect(actions.isSignedIn, isFalse);
  });

  test('following in the app needs the web token and a viewer', () {
    expect(actions.canFollowInApp, isTrue);
    token = '';
    expect(actions.canFollowInApp, isFalse);
    token = 'tok';
    viewer = null;
    expect(actions.canFollowInApp, isFalse);
  });

  test('a channel follow state comes from helix and fails to null', () async {
    when(
      () => api.isFollowing(userId: '77', broadcasterId: '5'),
    ).thenAnswer((_) async => true);
    expect(await actions.followsChannel('5'), isTrue);
    when(
      () => api.isFollowing(userId: '77', broadcasterId: '6'),
    ).thenThrow(Exception('down'));
    expect(await actions.followsChannel('6'), isNull);
    viewer = null;
    expect(await actions.followsChannel('5'), isNull);
  });

  test('the channel follow state never needs the web session', () async {
    token = null;
    when(
      () => api.isFollowing(userId: '77', broadcasterId: '5'),
    ).thenAnswer((_) async => true);
    when(
      () => api.getUser(userLogin: 'five'),
    ).thenAnswer((_) async => const UserTwitch('5', 'five', 'Five', ''));
    expect(await actions.followsChannel('5'), isTrue);
    expect(await actions.channelFollowState('five'), (
      id: '5',
      following: true,
    ));
  });

  test('without a web session the category state is unknown', () async {
    token = null;
    expect(await actions.followsCategory('509658'), isNull);
    verifyNever(
      () =>
          categories.getFollowedCategories(authToken: any(named: 'authToken')),
    );
  });

  test(
    'a failed connect waits a minute before loading twitch.tv again',
    () async {
      token = null;
      connectedToken = () => null;
      expect(await actions.connectWebSession(), isFalse);
      expect(await actions.connectWebSession(), isFalse);
      expect(connects, 1);
      clock = clock.add(const Duration(seconds: 61));
      expect(await actions.connectWebSession(), isFalse);
      expect(connects, 2);
    },
  );

  test('a category is followed when Twitch lists it', () async {
    when(() => categories.getFollowedCategories(authToken: 'tok')).thenAnswer(
      (_) async => const [
        FollowedCategory(id: '509658', name: 'Just Chatting'),
      ],
    );
    expect(await actions.followsCategory('509658'), isTrue);
    expect(await actions.followsCategory('1'), isFalse);
  });

  test('an unreadable list leaves the category state unknown', () async {
    when(
      () => categories.getFollowedCategories(authToken: 'tok'),
    ).thenAnswer((_) async => null);
    expect(await actions.followsCategory('509658'), isNull);
  });

  test('suggestions are live channels of the same category the viewer '
      'does not follow yet', () async {
    when(
      () => api.getStreamsByIds(userIds: ['1000']),
    ).thenAnswer((_) async => _streams([_stream('1000')]));
    when(() => api.getStreamsUnderCategory(gameId: '509658')).thenAnswer(
      (_) async => _streams([
        _stream('1000'),
        _stream('1'),
        _stream('2'),
        for (var i = 3; i < 12; i++) _stream('$i'),
      ]),
    );
    when(
      () => api.getFollowedStreams(id: '77', first: 100, quiet: true),
    ).thenAnswer((_) async => _streams([_stream('2')]));

    final suggestions = await actions.suggestionsAfterFollowing('1000');
    expect(suggestions.map((s) => s.userId), ['1', '3', '4', '5', '6']);
  });

  test('an offline channel or a failure suggests nothing', () async {
    when(
      () => api.getStreamsByIds(userIds: ['1000']),
    ).thenAnswer((_) async => _streams(const []));
    expect(await actions.suggestionsAfterFollowing('1000'), isEmpty);

    when(() => api.getStreamsByIds(userIds: ['1000'])).thenThrow(Exception());
    expect(await actions.suggestionsAfterFollowing('1000'), isEmpty);
  });
}
