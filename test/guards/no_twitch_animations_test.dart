import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The on-screen celebrations are ONSET's own particles: no Lottie or
/// third-party animation ships.
void main() {
  test('no Lottie animation ships in assets/animations', () {
    final dir = Directory('assets/animations');
    final json = dir.existsSync()
        ? dir.listSync().where((f) => f.path.endsWith('.json')).toList()
        : const <FileSystemEntity>[];
    expect(json, isEmpty);
  });

  test('nothing in lib/ imports the lottie package', () {
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            file.readAsStringSync().contains('package:lottie/'))
          file.path,
    ];
    // The walk has to see the code it vouches for.
    expect(
      Directory('lib').listSync(recursive: true).whereType<File>().length,
      greaterThan(100),
    );
    expect(offenders, isEmpty);
  });

  test('pubspec declares neither lottie nor the animations folder', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      isNot(contains(RegExp(r'^\s*lottie\s*:', multiLine: true))),
    );
    expect(pubspec, isNot(contains('assets/animations')));
    // The sparks the particles draw are declared.
    for (final spark in ['lime', 'mint', 'white', 'dot']) {
      expect(pubspec, contains('assets/celebrations/spark_$spark.png'));
    }
  });
}
