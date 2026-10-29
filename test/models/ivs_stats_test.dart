import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/ivs_stats.dart';

void main() {
  group('IvsStats.fromEvent', () {
    test('parses a full stats payload', () {
      final stats = IvsStats.fromEvent({
        'type': 'stats',
        'bitrate': 6200000,
        'fps': 60,
        'dropped': 3,
        'decoded': 1200,
        'rendered': 1197,
        'bufferedMs': 1450,
        'lowLatency': true,
        'playbackRate': 1.05,
        'bandwidth': 18000000,
        'quality': {
          'name': '1080p60',
          'width': 1920,
          'height': 1080,
          'codecs': 'avc1.64002A,mp4a.40.2',
          'framerate': 60.0,
          'bitrate': 6000000,
        },
      });

      expect(stats.bitrate, 6200000);
      expect(stats.fps, 60);
      expect(stats.droppedFrames, 3);
      expect(stats.decodedFrames, 1200);
      expect(stats.renderedFrames, 1197);
      expect(stats.bufferedMs, 1450);
      expect(stats.lowLatency, isTrue);
      expect(stats.playbackRate, 1.05);
      expect(stats.bandwidth, 18000000);
      expect(stats.qualityName, '1080p60');
      expect(stats.width, 1920);
      expect(stats.height, 1080);
      expect(stats.codecs, 'avc1.64002A,mp4a.40.2');
      expect(stats.framerate, 60.0);
    });

    test('tolerates missing and null fields', () {
      final stats = IvsStats.fromEvent({
        'type': 'stats',
        'bitrate': null,
        'fps': 30,
      });

      expect(stats.bitrate, isNull);
      expect(stats.fps, 30);
      expect(stats.droppedFrames, isNull);
      expect(stats.bufferedMs, isNull);
      expect(stats.lowLatency, isNull);
      expect(stats.playbackRate, isNull);
      expect(stats.qualityName, isNull);
      expect(stats.width, isNull);
      expect(stats.codecs, isNull);
    });

    test('accepts doubles for integer fields and ints for doubles', () {
      final stats = IvsStats.fromEvent({
        'fps': 59.94,
        'bufferedMs': 1200.0,
        'playbackRate': 1,
        'quality': {'framerate': 30, 'width': 1280.0},
      });

      expect(stats.fps, 60);
      expect(stats.bufferedMs, 1200);
      expect(stats.playbackRate, 1.0);
      expect(stats.framerate, 30.0);
      expect(stats.width, 1280);
    });

    test('ignores wrongly typed values', () {
      final stats = IvsStats.fromEvent({
        'bitrate': 'fast',
        'lowLatency': 'yes',
        'quality': 'not a map',
      });

      expect(stats.bitrate, isNull);
      expect(stats.lowLatency, isNull);
      expect(stats.qualityName, isNull);
    });

    test('formats the resolution label', () {
      expect(
        IvsStats.fromEvent({
          'quality': {'width': 2560, 'height': 1440},
        }).resolution,
        '2560×1440',
      );
      expect(IvsStats.fromEvent({}).resolution, isNull);
    });
  });
}
