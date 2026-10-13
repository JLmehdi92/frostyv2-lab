import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// The media engine a clip plays on, so the clip store is testable without
/// libmpv. Volume is 0–1.
abstract class ClipMediaBackend {
  Stream<bool> get playing;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<Duration> get buffer;
  Stream<bool> get buffering;
  Stream<bool> get completed;
  Stream<String> get error;

  Future<void> open(String url, {Duration start = Duration.zero, bool play});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> setLooping(bool looping);

  /// The video surface, letterboxed or ([fill]) cropped to fill.
  Widget buildVideo({required bool fill});

  Future<void> dispose();
}

/// Plays a clip's MP4 on media_kit (libmpv). A player of its own, with the
/// default configuration: the live player's low-latency settings are never
/// shared with it.
class MediaKitClipBackend implements ClipMediaBackend {
  MediaKitClipBackend() : _player = Player() {
    _video = VideoController(_player);
  }

  final Player _player;
  late final VideoController _video;

  @override
  Stream<bool> get playing => _player.stream.playing;

  @override
  Stream<Duration> get position => _player.stream.position;

  @override
  Stream<Duration> get duration => _player.stream.duration;

  @override
  Stream<Duration> get buffer => _player.stream.buffer;

  @override
  Stream<bool> get buffering => _player.stream.buffering;

  @override
  Stream<bool> get completed => _player.stream.completed;

  @override
  Stream<String> get error => _player.stream.error;

  @override
  Future<void> open(
    String url, {
    Duration start = Duration.zero,
    bool play = true,
  }) => _player.open(Media(url, start: start), play: play);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume((volume * 100).clamp(0, 100).toDouble());

  @override
  Future<void> setLooping(bool looping) => _player.setPlaylistMode(
    looping ? PlaylistMode.single : PlaylistMode.none,
  );

  @override
  Widget buildVideo({required bool fill}) => Video(
    controller: _video,
    controls: NoVideoControls,
    fit: fill ? BoxFit.cover : BoxFit.contain,
  );

  @override
  Future<void> dispose() => _player.dispose();
}
