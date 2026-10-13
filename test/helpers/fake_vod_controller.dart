import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:mobx/mobx.dart';

/// A [VodPlayerController] whose state tests set directly; every command is
/// recorded in [calls].
class FakeVodController implements VodPlayerController {
  final calls = <String>[];

  final _status = Observable(VodPlaybackStatus.paused);
  final _position = Observable(const Duration(minutes: 10));
  final _duration = Observable(const Duration(hours: 1));
  final _rate = Observable(1.0);
  final _overlay = Observable(true);
  final _muted = Observable(false);

  set status(VodPlaybackStatus value) =>
      runInAction(() => _status.value = value);
  set position(Duration value) => runInAction(() => _position.value = value);
  set overlayVisible(bool value) => runInAction(() => _overlay.value = value);
  set duration(Duration value) => runInAction(() => _duration.value = value);

  @override
  VodPlaybackStatus get status => _status.value;
  @override
  VodPlaybackProblem? problem;
  @override
  Duration get position => _position.value;
  @override
  Duration get duration => _duration.value;
  @override
  Duration buffered = Duration.zero;
  @override
  int get positionSeconds => position.inSeconds;
  @override
  bool get paused =>
      status != VodPlaybackStatus.playing &&
      status != VodPlaybackStatus.buffering;
  @override
  bool get ended => status == VodPlaybackStatus.ended;
  @override
  double get playbackRate => _rate.value;
  @override
  List<String> qualities = const ['Auto', '1080p60', '720p60'];
  @override
  String quality = 'Auto';
  @override
  bool get muted => _muted.value;
  @override
  double volume = 1;
  @override
  bool get overlayVisible => _overlay.value;
  @override
  bool isInPipMode = false;
  @override
  Future<void> ready = Future.value();
  @override
  void Function()? onFatalError;

  @override
  void play() => calls.add('play');
  @override
  void pause() => calls.add('pause');
  @override
  void togglePlay() => calls.add('togglePlay');
  @override
  void seekTo(Duration target) => calls.add('seekTo ${target.inSeconds}');
  @override
  void seekBy(Duration delta) => calls.add('seekBy ${delta.inSeconds}');
  @override
  void setPlaybackRate(double rate) {
    calls.add('rate $rate');
    runInAction(() => _rate.value = rate);
  }

  @override
  void setQuality(String quality) => calls.add('quality $quality');
  @override
  void toggleMute() {
    calls.add('toggleMute');
    runInAction(() => _muted.value = !_muted.value);
  }

  @override
  void setVolume(double volume) => calls.add('volume $volume');
  @override
  void handleVideoTap() => calls.add('tap');
  @override
  void showOverlay() => calls.add('showOverlay');
  @override
  void requestPictureInPicture() => calls.add('pip');
  @override
  void onPipEntered() {}
  @override
  void onPipExited() {}
  @override
  Future<Duration?> currentPositionForSave() async => position;
  @override
  void setFocused(bool focused) => calls.add('focused $focused');

  @override
  void dispose() => calls.add('dispose');
}
