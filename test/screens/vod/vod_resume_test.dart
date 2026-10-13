import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:frosty/screens/vod/vod_resume.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_vod_controller.dart';

void main() {
  late VodResumeRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = VodResumeRepository();
  });

  group('VodResumeRepository', () {
    test('saves and reads a position', () async {
      await repo.save('1', positionSec: 600, lengthSec: 3600);

      final entry = await repo.entry('1');
      expect(entry?.positionSec, 600);
      expect(entry?.lengthSec, 3600);
      expect(entry?.finished, isFalse);
      expect(entry?.progress, closeTo(600 / 3600, 1e-9));
    });

    test('the first 30 seconds are not worth a save', () async {
      await repo.save('1', positionSec: 29, lengthSec: 3600);

      expect(await repo.entry('1'), isNull);
    });

    test('near the end the video counts as finished', () async {
      await repo.save('1', positionSec: 600, lengthSec: 3600);
      await repo.save('1', positionSec: 3575, lengthSec: 3600);

      final entry = await repo.entry('1');
      expect(entry?.finished, isTrue);
      expect(entry?.positionSec, 0);
    });

    test('keeps the 300 most recent videos', () async {
      for (var i = 0; i < 305; i++) {
        await repo.save('$i', positionSec: 100, lengthSec: 3600);
      }

      final all = await repo.snapshot();
      expect(all, hasLength(300));
      expect(all.containsKey('0'), isFalse);
      expect(all.containsKey('304'), isTrue);
    });

    test('corrupted data reads as empty and is replaced', () async {
      SharedPreferences.setMockInitialValues({'vod_resume_v1': '{nope'});
      repo = VodResumeRepository();

      expect(await repo.snapshot(), isEmpty);
      await repo.save('1', positionSec: 100, lengthSec: 3600);
      expect((await repo.entry('1'))?.positionSec, 100);
    });

    test('wrongly typed entries are skipped', () async {
      SharedPreferences.setMockInitialValues({
        'vod_resume_v1': jsonEncode({
          '1': {'p': 'x', 'l': 10, 'u': 1},
          '2': {'p': 120, 'l': 3600, 'u': 2},
        }),
      });
      repo = VodResumeRepository();

      expect((await repo.snapshot()).keys, ['2']);
    });
  });

  group('startPositionFor', () {
    test('a deep link wins', () {
      expect(
        startPositionFor(
          saved: const VodResumeEntry(positionSec: 600, lengthSec: 3600),
          deepLink: const Duration(minutes: 2),
        ),
        const Duration(minutes: 2),
      );
    });

    test('resumes 30 seconds before the saved position', () {
      expect(
        startPositionFor(
          saved: const VodResumeEntry(positionSec: 600, lengthSec: 3600),
        ),
        const Duration(seconds: 570),
      );
      expect(
        startPositionFor(
          saved: const VodResumeEntry(positionSec: 20, lengthSec: 3600),
        ),
        Duration.zero,
      );
    });

    test('a finished or unknown video starts at the beginning', () {
      expect(
        startPositionFor(
          saved: const VodResumeEntry(
            positionSec: 0,
            lengthSec: 3600,
            finished: true,
          ),
        ),
        Duration.zero,
      );
      expect(startPositionFor(), Duration.zero);
    });
  });

  group('VodResumeController', () {
    late FakeVodController player;
    late VodResumeController controller;

    setUp(() {
      player = FakeVodController()
        ..position = const Duration(minutes: 10)
        ..duration = const Duration(hours: 1);
      controller = VodResumeController(
        vodId: '1',
        player: () => player,
        repository: repo,
        interval: const Duration(milliseconds: 30),
      )..start();
    });

    tearDown(() => controller.cancel());

    Future<int?> saved() async => (await repo.entry('1'))?.positionSec;

    test('saves periodically only while playing', () async {
      player.status = VodPlaybackStatus.paused;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(await saved(), isNull);

      player.status = VodPlaybackStatus.playing;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(await saved(), 600);
    });

    test('saves when playback pauses', () async {
      player.status = VodPlaybackStatus.playing;
      player.position = const Duration(minutes: 12);

      player.status = VodPlaybackStatus.paused;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(await saved(), 720);
    });

    test('saves when the app goes to the background', () async {
      await controller.save();

      expect(await saved(), 600);
    });

    test('closing saves the last position', () async {
      player.position = const Duration(minutes: 15);

      await controller.close();

      expect(await saved(), 900);
    });

    test('nothing is saved before the video started', () async {
      player.status = VodPlaybackStatus.loading;
      player.position = Duration.zero;

      await controller.close();

      expect(await saved(), isNull);
    });
  });
}
