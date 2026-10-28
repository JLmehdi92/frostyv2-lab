import 'package:frosty/models/channel.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/channel/video/player_controller.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mobx/mobx.dart';

/// A live stream as Helix sends it, for the channel screen's widgets.
StreamTwitch fakeStream({
  String userId = '42',
  String login = 'streamer',
  String name = 'Streamer',
  String title = 'ON TEST DOTA 2 AVEC @befreesh',
  String gameName = 'Dota 2',
  String gameId = '29595',
  int viewers = 2445,
  String language = 'fr',
}) => StreamTwitch(
  userId,
  login,
  name,
  gameId,
  gameName,
  title,
  viewers,
  DateTime.now()
      .toUtc()
      .subtract(const Duration(hours: 3, minutes: 12))
      .toIso8601String(),
  'https://static-cdn.jtvnw.net/previews-ttv/live_user_$login-{width}x{height}.jpg',
  language: language,
);

/// The channel as Helix describes it while it is offline.
const fakeOfflineChannel = Channel(
  broadcasterId: '42',
  broadcasterLogin: 'streamer',
  broadcasterName: 'Streamer',
  broadcasterLanguage: 'fr',
  title: 'Last stream',
  gameId: '29595',
  gameName: 'Dota 2',
);

/// A [PlayerController] whose state is observable (as the real engines'),
/// recording what the overlay asks of it.
class FakePlayer implements PlayerController {
  FakePlayer({
    SettingsStore? settings,
    StreamTwitch? stream,
    Channel? offline,
    String? latency = '2.1s',
  }) : settingsStore = settings ?? SettingsStore.fromJson({}) {
    _stream.value = stream;
    _offline.value = offline;
    _latency.value = latency;
  }

  @override
  final SettingsStore settingsStore;

  final _paused = Observable(false);
  final _overlayVisible = Observable(true);
  final _pip = Observable(false);
  final _stream = Observable<StreamTwitch?>(null);
  final _offline = Observable<Channel?>(null);
  final _latency = Observable<String?>(null);

  final calls = <String>[];

  set paused(bool value) => runInAction(() => _paused.value = value);
  set stream(StreamTwitch? value) => runInAction(() => _stream.value = value);
  set latencyText(String? value) => runInAction(() => _latency.value = value);
  set inPip(bool value) => runInAction(() => _pip.value = value);

  @override
  bool get paused => _paused.value;

  @override
  bool get overlayVisible => _overlayVisible.value;

  @override
  bool get isInPipMode => _pip.value;

  @override
  StreamTwitch? get streamInfo => _stream.value;

  @override
  Channel? get offlineChannelInfo => _offline.value;

  @override
  List<String> get availableStreamQualities => const ['Auto', '1080p60'];

  @override
  String get streamQuality => 'Auto';

  @override
  void setStreamQuality(String quality) => calls.add('quality $quality');

  @override
  Future<void> updateStreamQualities() async => calls.add('qualities');

  @override
  String? get latency => _latency.value;

  @override
  void handleVideoTap() => calls.add('tap');

  @override
  void handleToggleOverlay() => calls.add('toggleOverlay');

  @override
  void handlePausePlay() => calls.add('pausePlay');

  @override
  Future<void> handleRefresh() async => calls.add('refresh');

  @override
  void requestPictureInPicture() => calls.add('requestPip');

  @override
  void togglePictureInPicture() => calls.add('togglePip');

  @override
  void handleAppResume() => calls.add('resume');

  @override
  void dispose() => calls.add('dispose');
}
