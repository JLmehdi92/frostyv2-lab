import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/screens/channel/chat/details/stores/chat_details_store.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockChatAssetsStore extends Mock implements ChatAssetsStore {}

/// A socket the test feeds and closes, like the server would.
class FakeSocket implements WebSocketChannel {
  FakeSocket(this.uri);

  final Uri uri;
  final incoming = StreamController<dynamic>();
  final sent = <dynamic>[];
  late final _sink = _FakeSink(this);
  int? _closeCode;

  void receive(String data) => incoming.add(data);

  /// The server dropped the connection.
  Future<void> drop() => incoming.close();

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();

  // The chat store only reads, writes and closes.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this.socket);

  final FakeSocket socket;

  @override
  void add(dynamic data) => socket.sent.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.drain<void>();

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    socket._closeCode = closeCode ?? 1000;
  }

  @override
  Future<void> get done => Future.value();
}

/// A chat store of channel `channel` (id 12345) on fake sockets, appended
/// to [sockets] as it connects.
ChatStore createTestChatStore({
  required SettingsStore settings,
  required List<FakeSocket> sockets,
  MockTwitchApi? api,
}) {
  final twitchApi = api ?? MockTwitchApi();
  final auth = MockAuthStore();
  when(() => auth.isLoggedIn).thenReturn(false);
  when(() => auth.token).thenReturn(null);
  when(() => auth.headersTwitch).thenReturn({});
  when(() => auth.user).thenReturn(UserStore(twitchApi: twitchApi));
  final assets = MockChatAssetsStore();
  when(() => assets.init()).thenAnswer((_) async {});
  when(() => assets.showEmoteMenu).thenReturn(false);
  when(() => assets.sevenTvEmoteSetId).thenReturn(null);
  when(
    () => assets.assetsFuture(
      channelId: any(named: 'channelId'),
      headers: any(named: 'headers'),
      onEmoteError: any(named: 'onEmoteError'),
      onBadgeError: any(named: 'onBadgeError'),
      showTwitchEmotes: any(named: 'showTwitchEmotes'),
      showTwitchBadges: any(named: 'showTwitchBadges'),
      show7TVEmotes: any(named: 'show7TVEmotes'),
      showBTTVEmotes: any(named: 'showBTTVEmotes'),
      showBTTVBadges: any(named: 'showBTTVBadges'),
      showFFZEmotes: any(named: 'showFFZEmotes'),
      showFFZBadges: any(named: 'showFFZBadges'),
    ),
  ).thenAnswer((_) async {});
  return ChatStore(
    twitchApi: twitchApi,
    auth: auth,
    chatDetailsStore: ChatDetailsStore(
      twitchApi: twitchApi,
      channelName: 'channel',
    ),
    assetsStore: assets,
    settings: settings,
    channelName: 'channel',
    channelId: '12345',
    displayName: 'Channel',
    connectSocket: (uri) {
      final socket = FakeSocket(uri);
      sockets.add(socket);
      return socket;
    },
  );
}
