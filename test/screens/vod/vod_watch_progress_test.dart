import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel/video/live_progress.dart';
import 'package:onset/screens/vod/vod_resume.dart';
import 'package:onset/screens/vod/vod_watch_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

Vod _vod(
  String id, {
  String? broadcastId,
  VodType type = VodType.archive,
  int length = 3600,
}) => Vod(
  id: id,
  title: 'v$id',
  lengthSeconds: length,
  createdAt: DateTime.utc(2026),
  viewCount: 1,
  ownerId: '42',
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
  type: type,
  broadcastId: broadcastId,
);

LiveProgressEntry _live(int offset) => LiveProgressEntry(
  streamId: 's',
  channelId: '42',
  startedAt: DateTime.utc(2026),
  offsetSec: offset,
  updatedAt: DateTime.utc(2026),
);

class _Probe extends StatefulWidget {
  const _Probe({required this.viewer});

  final String? viewer;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with VodWatchProgressMixin {
  @override
  String? get watchProgressViewer => widget.viewer;

  @override
  Widget build(BuildContext context) => Text(
    '${watchProgress.of(_vod('1')).progress}',
    textDirection: TextDirection.ltr,
  );
}

void main() {
  group('of', () {
    final progress = VodWatchProgress(
      resume: {
        '1': const VodResumeEntry(positionSec: 900, lengthSec: 3600),
        '2': const VodResumeEntry(
          positionSec: 3590,
          lengthSec: 3600,
          finished: true,
        ),
      },
      live: {'b3': _live(1800), 'b4': _live(9000), 'b5': _live(10)},
    );

    test('a saved position is the bar', () {
      final p = progress.of(_vod('1', broadcastId: 'b3'));
      expect(p.progress, closeTo(0.25, 0.001));
      expect(p.watched, isFalse);
    });

    test('watched to the end: no bar, marked watched', () {
      expect(progress.of(_vod('2')), (progress: null, watched: true));
    });

    test('a past broadcast not opened yet shows where the live was left', () {
      expect(
        progress.of(_vod('3', broadcastId: 'b3')).progress,
        closeTo(0.5, 0.001),
      );
      // Beyond its length: full, never more.
      expect(progress.of(_vod('4', broadcastId: 'b4')).progress, 1);
    });

    test('only past broadcasts with a length take the live progress', () {
      expect(
        progress.of(_vod('5', broadcastId: 'b5', type: VodType.highlight)),
        (progress: null, watched: false),
      );
      expect(
        progress.of(_vod('6', broadcastId: 'b5', length: 0)).progress,
        isNull,
      );
      expect(progress.of(_vod('7')).progress, isNull);
      expect(VodWatchProgress.none.of(_vod('1')).progress, isNull);
    });
  });

  group('load and the mixin', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      VodResumeRepository.shared.resetQueue();
      LiveProgressRepository.shared.resetQueue();
    });

    test('reads the viewer\'s own positions only', () async {
      await VodResumeRepository.shared.save(
        '1',
        positionSec: 1800,
        lengthSec: 3600,
        viewer: '11',
      );
      final mine = await VodWatchProgress.load(viewer: '11');
      final theirs = await VodWatchProgress.load(viewer: '22');
      expect(mine.of(_vod('1')).progress, closeTo(0.5, 0.001));
      expect(theirs.of(_vod('1')).progress, isNull);
    });

    testWidgets('a list reads them, and again when a save lands', (
      tester,
    ) async {
      await tester.pumpWidget(const _Probe(viewer: '11'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('null'), findsOneWidget);

      await tester.runAsync(
        () => VodResumeRepository.shared.save(
          '1',
          positionSec: 1800,
          lengthSec: 3600,
          viewer: '11',
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(find.text('0.5'), findsOneWidget);

      // Gone: the listener goes with it.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => VodResumeRepository.shared.save(
          '1',
          positionSec: 900,
          lengthSec: 3600,
          viewer: '11',
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
