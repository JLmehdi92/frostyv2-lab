import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The channel screen cannot be pumped in a test (live chat sockets, the
/// native player, some twenty services), so these guard how it is put
/// together: the behaviour each part relies on is tested with the part.
void main() {
  final source = File(
    'lib/screens/channel/channel.dart',
  ).readAsStringSync().replaceAll('\r\n', '\n');

  test('one content warning, keyed, around the video in every layout', () {
    // Built in one place only, with the key that carries its state from a
    // layout to the next (content_warning_gate_test: "one keyed gate").
    expect('ContentWarningGate('.allMatches(source), hasLength(1));
    expect(source, contains('key: _contentGateKey,'));
    // Portrait / side chat, and full screen (a saved choice: a channel can
    // open straight into it).
    expect(source, contains('final video = gated('));
    expect(
      RegExp(
        r'settingsStore\.fullScreen\s*(//[^\n]*\n\s*)*\? gated\(',
      ).hasMatch(source),
      isTrue,
      reason: 'the full-screen layout must be under the warning',
    );
  });

  test('the warning holds picture-in-picture and the mini player', () {
    expect(source, contains('_videoStore.setContentGated(active);'));
    expect(source, contains('onPipAction: (_) => pipPlayPause(_videoStore),'));
    expect(
      RegExp(
        r'void _minimizeToMiniPlayer\(\) \{\n(\s*//[^\n]*\n)*\s*if \(_contentGateUp\) return;',
      ).hasMatch(source),
      isTrue,
    );
  });

  test('the video stats are drawn in full screen too', () {
    expect('statsLayer'.allMatches(source).length, greaterThanOrEqualTo(4));
  });
}
