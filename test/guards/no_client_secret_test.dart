import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Twitch client secret lives in the token proxy (tool/token_proxy/),
/// never in the app: anything in an APK can be read back out of it.
void main() {
  // Spelled in pieces so this file does not match itself.
  final readsSecret = RegExp(
    'fromEnvironment'
    r"\(\s*['"
    '"]SECRET'
    r"['"
    '"]',
  );
  const clientSecret =
      'client'
      '_secret';

  List<File> dartFiles(String root) => [
    for (final entry in Directory(root).listSync(recursive: true))
      if (entry is File && entry.path.endsWith('.dart')) entry,
  ];

  test('no Dart file reads a SECRET define', () {
    final files = [
      ...dartFiles('lib'),
      ...dartFiles('test'),
      if (Directory('integration_test').existsSync())
        ...dartFiles('integration_test'),
    ];
    // The walk has to see the code it vouches for.
    expect(files.length, greaterThan(200));
    expect(files.map((f) => f.path), contains(endsWith('constants.dart')));

    final offenders = [
      for (final file in files)
        // This file spells the pattern out to test it.
        if (!file.path.endsWith('no_client_secret_test.dart') &&
            readsSecret.hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty);
  });

  test('the pattern does catch a SECRET define', () {
    expect(
      readsSecret.hasMatch("const s = String.fromEnvironment('SECRET');"),
      isTrue,
    );
  });

  test('nothing in lib/ names a client secret', () {
    final offenders = [
      for (final file in dartFiles('lib'))
        if (file.readAsStringSync().contains(clientSecret)) file.path,
    ];
    expect(dartFiles('lib').length, greaterThan(100));
    expect(offenders, isEmpty);
  });
}
