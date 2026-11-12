import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

class CustomCacheManager {
  static const key = 'libCachedImageData';
  static final _repo = CacheObjectProvider(databaseName: key);
  static final instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 10000,
      repo: _repo,
    ),
  );

  static const sweepDelay = Duration(seconds: 10);
  static const sweepMinAge = Duration(hours: 1);

  static void scheduleOrphanSweep({
    @visibleForTesting Future<void> Function()? sweep,
  }) {
    final run = sweep ?? () => removeOrphanedCacheFiles(minAge: sweepMinAge);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Timer(sweepDelay, () => unawaited(run())),
    );
  }

  static Future<void> removeOrphanedCacheFiles({
    Duration minAge = Duration.zero,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/$key');
      if (!await cacheDir.exists()) return;
      await _repo.open();
      final cachedObjects = await _repo.getAllObjects();
      await deleteOrphans(
        cacheDir,
        cachedObjects.map((e) => e.relativePath).toSet(),
        olderThan: DateTime.now().subtract(minAge),
      );
    } catch (e) {
      debugPrint('Cache sweep failed: ${e.runtimeType}');
    }
  }

  @visibleForTesting
  static Future<void> deleteOrphans(
    Directory cacheDir,
    Set<String> known, {
    required DateTime olderThan,
  }) async {
    final files = await cacheDir
        .list(recursive: true)
        .where((entry) => entry is File)
        .cast<File>()
        .toList();
    for (final file in files) {
      if (known.contains(file.path.split('$key/').last)) continue;
      try {
        if ((await file.lastModified()).isAfter(olderThan)) continue;
        await file.delete();
      } on FileSystemException catch (e) {
        debugPrint('Cache file not swept: ${e.runtimeType}');
      }
    }
  }
}
