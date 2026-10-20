import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel/video/live_progress.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:frosty/screens/vod/vod_resume.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_vod_controller.dart';

void main() {
  late VodResumeRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VodResumeRepository.shared.resetQueue();
    repo = VodResumeRepository.shared;
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

      expect(await repo.snapshot(), isEmpty);
      await repo.save('1', positionSec: 100, lengthSec: 3600);
      expect((await repo.entry('1'))?.positionSec, 100);
    });

    test('each account keeps its own positions', () async {
      await repo.save('1', positionSec: 600, lengthSec: 3600, viewer: '11');
      await repo.save('1', positionSec: 900, lengthSec: 3600, viewer: '22');

      expect((await repo.entry('1', viewer: '11'))?.positionSec, 600);
      expect((await repo.entry('1', viewer: '22'))?.positionSec, 900);
      expect(await repo.entry('1'), isNull, reason: 'logged out');
      expect(await repo.entry('1', viewer: '33'), isNull);
      expect((await repo.snapshot(viewer: '22'))['1']?.positionSec, 900);
      expect(await repo.snapshot(viewer: '33'), isEmpty);
    });

    test('positions saved before accounts were kept apart stay', () async {
      SharedPreferences.setMockInitialValues({
        'vod_resume_v1': jsonEncode({
          '1': {'p': 120, 'l': 3600, 'u': 1},
          '2': {'p': 240, 'l': 3600, 'u': 2},
        }),
      });
      await repo.save('2', positionSec: 480, lengthSec: 3600, viewer: '11');

      expect((await repo.entry('1', viewer: '11'))?.positionSec, 120);
      expect((await repo.entry('2', viewer: '11'))?.positionSec, 480);
      expect((await repo.entry('2'))?.positionSec, 240);
      final all = await repo.snapshot(viewer: '11');
      expect(all.map((id, e) => MapEntry(id, e.positionSec)), {
        '1': 120,
        '2': 480,
      });
    });

    test('an entry knows when it was saved', () async {
      final before = DateTime.now();
      await repo.save('1', positionSec: 600, lengthSec: 3600);

      final at = (await repo.entry('1'))!.updatedAt!;
      expect(at.isBefore(before.subtract(const Duration(seconds: 1))), isFalse);
    });

    test('wrongly typed entries are skipped', () async {
      SharedPreferences.setMockInitialValues({
        'vod_resume_v1': jsonEncode({
          '1': {'p': 'x', 'l': 10, 'u': 1},
          '2': {'p': 120, 'l': 3600, 'u': 2},
        }),
      });

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

  group('startPositionFor with the account and the live', () {
    final older = DateTime.utc(2026, 10, 19, 20);
    final newer = DateTime.utc(2026, 10, 20, 9);

    VodResumeEntry local(int position, {DateTime? at, bool finished = false}) =>
        VodResumeEntry(
          positionSec: position,
          lengthSec: 36000,
          finished: finished,
          updatedAt: at,
        );

    LiveProgressEntry live(int offset, {DateTime? at}) => LiveProgressEntry(
      streamId: '318071962212',
      channelId: '42',
      startedAt: DateTime.utc(2026, 10, 19, 18),
      offsetSec: offset,
      updatedAt: at ?? older,
    );

    Duration start({
      VodResumeEntry? saved,
      ViewingHistory? server,
      LiveProgressEntry? liveEntry,
      Duration? deepLink,
      int length = 36000,
    }) => startPositionFor(
      saved: saved,
      server: server,
      live: liveEntry,
      deepLink: deepLink,
      lengthSec: length,
    );

    test('the account position, as is, when nothing is saved here', () {
      expect(
        start(server: const ViewingHistory(positionSec: 5400)),
        const Duration(seconds: 5400),
      );
    });

    test('where the live was left, 30 s before, as a last resort', () {
      expect(start(liveEntry: live(7200)), const Duration(seconds: 7170));
      expect(start(liveEntry: live(20)), Duration.zero);
    });

    test('in order: link, this device, the account, the live', () {
      expect(
        start(
          deepLink: const Duration(seconds: 42),
          saved: local(600),
          server: const ViewingHistory(positionSec: 5400),
          liveEntry: live(7200),
        ),
        const Duration(seconds: 42),
      );
      expect(
        start(
          saved: local(600),
          server: const ViewingHistory(positionSec: 5400),
          liveEntry: live(7200),
        ),
        const Duration(seconds: 570),
      );
      expect(
        start(
          server: const ViewingHistory(positionSec: 5400),
          liveEntry: live(7200),
        ),
        const Duration(seconds: 5400),
      );
    });

    test('a later position wins over an earlier one', () {
      // Watched on another device since this one saved.
      expect(
        start(
          saved: local(600, at: older),
          server: ViewingHistory(positionSec: 5400, updatedAt: newer),
        ),
        const Duration(seconds: 5400),
      );
      expect(
        start(
          saved: local(600, at: newer),
          server: ViewingHistory(positionSec: 5400, updatedAt: older),
        ),
        const Duration(seconds: 570),
      );
      // Twitch did not take the live position (refused): ours is later.
      expect(
        start(
          server: ViewingHistory(positionSec: 300, updatedAt: older),
          liveEntry: live(7200, at: newer),
        ),
        const Duration(seconds: 7170),
      );
      // Without a time, the order decides.
      expect(
        start(
          server: const ViewingHistory(positionSec: 300),
          liveEntry: live(7200, at: newer),
        ),
        const Duration(seconds: 300),
      );
    });

    test('at the very end, or past it, the video starts over', () {
      expect(
        start(server: const ViewingHistory(positionSec: 35990)),
        Duration.zero,
      );
      expect(start(liveEntry: live(40000)), Duration.zero);
      expect(
        start(
          saved: local(0, finished: true, at: newer),
          liveEntry: live(900),
        ),
        Duration.zero,
      );
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

    /// The video played at least once (saves are skipped before that).
    void started() => player.status = VodPlaybackStatus.playing;

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
      started();
      player.position = const Duration(minutes: 12);

      player.status = VodPlaybackStatus.paused;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(await saved(), 720);
    });

    test('saves when the app goes to the background', () async {
      started();
      await controller.save();

      expect(await saved(), 600);
    });

    test('closing saves the last position', () async {
      started();
      player.position = const Duration(minutes: 15);

      await controller.close();

      expect(await saved(), 900);
    });

    test('leaving before the video started keeps the saved point', () async {
      await repo.save('1', positionSec: 900, lengthSec: 3600);
      player.status = VodPlaybackStatus.loading;
      player.position = const Duration(seconds: 870);

      await controller.close();

      expect(await saved(), 900, reason: 'not moved back by the -30 s start');
    });

    test('saves go to the viewer\'s account and entries', () async {
      final reported = <int>[];
      controller.cancel();
      controller = VodResumeController(
        vodId: '1',
        player: () => player,
        repository: repo,
        viewer: () => '11',
        report: (position) async {
          reported.add(position);
          return true;
        },
      )..start();

      await controller.save();
      expect(reported, isEmpty, reason: 'not started yet');

      started();
      await controller.close();

      expect(reported, [600]);
      expect((await repo.entry('1', viewer: '11'))?.positionSec, 600);
      expect(await repo.entry('1'), isNull);
    });

    test('every save is announced so lists can refresh', () async {
      final before = VodResumeRepository.changes.value;
      started();

      await controller.close();

      expect(VodResumeRepository.changes.value, greaterThan(before));
    });
  });
}
