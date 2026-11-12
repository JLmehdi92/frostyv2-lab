import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/cache_manager.dart';

void main() {
  late Directory dir;

  setUp(() async {
    final root = await Directory.systemTemp.createTemp('sweep');
    dir = Directory('${root.path}/${CustomCacheManager.key}')..createSync();
  });

  tearDown(() => dir.parent.deleteSync(recursive: true));

  File file(String name, {required Duration age}) {
    final f = File('${dir.path}/$name')
      ..createSync(recursive: true)
      ..writeAsStringSync('x');
    f.setLastModifiedSync(DateTime.now().subtract(age));
    return f;
  }

  test(
    'keeps known and recent files, deletes old orphans, skips folders',
    () async {
      final known = file('known.jpg', age: const Duration(days: 2));
      final recent = file('recent.jpg', age: const Duration(minutes: 5));
      final old = file('old.jpg', age: const Duration(days: 2));
      final nested = file('sub/old.jpg', age: const Duration(days: 2));

      await CustomCacheManager.deleteOrphans(dir, {
        'known.jpg',
      }, olderThan: DateTime.now().subtract(CustomCacheManager.sweepMinAge));

      expect(known.existsSync(), isTrue);
      expect(recent.existsSync(), isTrue);
      expect(old.existsSync(), isFalse);
      expect(nested.existsSync(), isFalse);
      expect(Directory('${dir.path}/sub').existsSync(), isTrue);
    },
  );

  testWidgets('the sweep runs once the delay after the first frame ends', (
    tester,
  ) async {
    var runs = 0;
    CustomCacheManager.scheduleOrphanSweep(sweep: () async => runs++);
    expect(runs, 0);
    await tester.pumpWidget(const SizedBox());
    expect(runs, 0);
    await tester.pump(
      CustomCacheManager.sweepDelay - const Duration(seconds: 1),
    );
    expect(runs, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(runs, 1);
  });
}
