import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The channel screen's code without comments or white space, so the checks
/// below look at what it does, not at how it is written or explained.
String _code(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '')
    .replaceAll(RegExp(r'\s+'), '');

/// The channel screen cannot be pumped in a test (live chat sockets, the
/// native player, some twenty services), so these guard how it is put
/// together; what each part does is tested with the part
/// (content_warning_gate_test, the player stores' tests).
void main() {
  final code = _code(
    File('lib/screens/channel/channel.dart').readAsStringSync(),
  );

  int count(String needle) => needle.allMatches(code).length;

  test('one content warning, keyed, around the video in every layout', () {
    expect(count('ContentWarningGate('), 1);
    expect(code, contains('ContentWarningGate(key:_contentGateKey,'));
    // Portrait and side chat, and full screen (a saved choice: a channel
    // can open straight into it).
    expect(code, contains('finalvideo=gated('));
    expect(code, contains('settingsStore.fullScreen?gated('));
    expect(code, contains('onStateChanged:_onContentGate,'));
  });

  test('the player, PiP and the mini player follow the warning', () {
    expect(code, contains('_videoStore.setContentGate(gate);'));
    expect(code, contains('onPipAction:(_)=>pipPlayPause(_videoStore),'));
    expect(
      code,
      contains(
        'void_minimizeToMiniPlayer(){if(!_contentGate.allowsLeaving)return;',
      ),
    );
    // A fallback engine starts where the warning stands.
    expect(code, contains('..setContentGate(_contentGate);'));
  });

  test('the video stats are drawn in every layout', () {
    expect(count('Positioned.fill(child:statsLayer)'), 1);
    expect(count('children:[chrome,statsLayer,]'), 2);
  });
}
