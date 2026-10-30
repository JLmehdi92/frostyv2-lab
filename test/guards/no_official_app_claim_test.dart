import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ONSET plays with the Amazon IVS player, Twitch's video technology; it
/// does not claim to be, or to play like, the official Twitch app. No
/// "official Twitch app" anywhere in lib/, android/, the assets or the
/// privacy policies (nor its French wording there), and no "official app" in
/// a text the viewer reads.
void main() {
  group('the guard', () {
    test('finds a claim split over lines, in a comment or in a text', () {
      expect(
        claimsIn(
          "const a = 'Plays with the same player the official '\n"
          "    'Twitch app uses.';\n",
        ),
        isNotEmpty,
      );
      expect(
        claimsIn('/// the exact engine the official\n/// Twitch app uses\n'),
        isNotEmpty,
      );
      expect(
        claimsIn("const b = 'Plays faster, like the official app.';\n"),
        isNotEmpty,
      );
      expect(
        claimsIn('Streams play with the player of the official Twitch App.'),
        isNotEmpty,
      );
      expect(
        claimsIn("comme le fait l'application officielle de Twitch"),
        isNotEmpty,
      );
    });

    test('leaves notes on Twitch and the official API alone', () {
      expect(
        claimsIn(
          '/// Like the official app, a message without a sender is dropped.\n'
          "const c = 'Permissions through the official Twitch API.';\n",
        ),
        isEmpty,
      );
    });
  });

  test('no official Twitch app claim in lib/, android/ or the assets', () {
    final files = [
      ...Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'),
          ),
      ...Directory('assets')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => RegExp(r'\.(md|txt|json|html|svg)$').hasMatch(f.path)),
      ...Directory('android')
          .listSync(recursive: true)
          .whereType<File>()
          // Generated output (build/, .gradle/) is not ONSET's text.
          .where(
            (f) => !f.uri.pathSegments.any(
              (part) => part == 'build' || part == '.gradle',
            ),
          )
          .where((f) => RegExp(r'\.(kt|kts|xml|java)$').hasMatch(f.path)),
      File('PRIVACY.md'),
      File('PRIVACY.fr.md'),
    ];
    expect(files.where((f) => f.path.endsWith('.kt')), isNotEmpty);
    expect(files.where((f) => f.path.endsWith('.md')), isNotEmpty);
    expect(files.length, greaterThan(100));

    final found = [
      for (final file in files)
        for (final claim in claimsIn(file.readAsStringSync()))
          '${file.path}: $claim',
    ];
    expect(found, isEmpty, reason: found.join('\n'));
  });
}

final _officialTwitchApp = RegExp(
  r'official\s+twitch\s+app',
  caseSensitive: false,
);
final _officialApp = RegExp(r'official\s+app', caseSensitive: false);
final _officielleTwitch = RegExp(
  r'application\s+officielle\s+de\s+twitch',
  caseSensitive: false,
);

/// The claims in [source]: "official Twitch app" (or its French wording)
/// anywhere, "official app" in a string literal (adjacent literals joined).
List<String> claimsIn(String source) {
  final text = source
      .replaceAll('\r', '')
      // A comment or a text broken over lines reads as one.
      .replaceAll(RegExp(r"'\s*\n\s*'"), '')
      .replaceAll(RegExp(r'\n\s*(///?)?\s*'), ' ');
  final code = source
      .replaceAll('\r', '')
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n')
      .replaceAll(RegExp(r"'\s*\n\s*'"), '');
  return [
    for (final match in _officialTwitchApp.allMatches(text)) match[0]!,
    for (final match in _officielleTwitch.allMatches(text)) match[0]!,
    for (final literal in RegExp(r"'[^'\n]*'").allMatches(code))
      if (_officialApp.hasMatch(literal[0]!)) literal[0]!,
  ];
}
