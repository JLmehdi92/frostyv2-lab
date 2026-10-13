import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:frosty/screens/clips/clip_media_backend.dart';

/// A scripted [ClipMediaBackend] that records what the store asks of it.
class FakeClipBackend implements ClipMediaBackend {
  final calls = <String>[];
  final opened = <({String url, Duration start, bool play})>[];
  var disposed = false;

  final playingController = StreamController<bool>.broadcast(sync: true);
  final positionController = StreamController<Duration>.broadcast(sync: true);
  final durationController = StreamController<Duration>.broadcast(sync: true);
  final bufferController = StreamController<Duration>.broadcast(sync: true);
  final bufferingController = StreamController<bool>.broadcast(sync: true);
  final completedController = StreamController<bool>.broadcast(sync: true);
  final errorController = StreamController<String>.broadcast(sync: true);

  @override
  Stream<bool> get playing => playingController.stream;

  @override
  Stream<Duration> get position => positionController.stream;

  @override
  Stream<Duration> get duration => durationController.stream;

  @override
  Stream<Duration> get buffer => bufferController.stream;

  @override
  Stream<bool> get buffering => bufferingController.stream;

  @override
  Stream<bool> get completed => completedController.stream;

  @override
  Stream<String> get error => errorController.stream;

  @override
  Future<void> open(
    String url, {
    Duration start = Duration.zero,
    bool play = true,
  }) async {
    opened.add((url: url, start: start, play: play));
    calls.add('open');
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek ${position.inMilliseconds}');

  @override
  Future<void> setRate(double rate) async => calls.add('rate $rate');

  @override
  Future<void> setVolume(double volume) async => calls.add('volume $volume');

  @override
  Future<void> setLooping(bool looping) async => calls.add('loop $looping');

  @override
  Widget buildVideo({required bool fill}) =>
      SizedBox(key: ValueKey('fake-video-$fill'));

  @override
  Future<void> dispose() async {
    disposed = true;
    calls.add('dispose');
  }
}
