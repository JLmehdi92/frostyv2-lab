import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/settings_persistence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  double chatWidthOf(String json) =>
      (jsonDecode(json) as Map<String, dynamic>)['chatWidth'] as double;

  test('a drag on the chat divider writes the settings a few times, not on '
      'every frame, and ends on its last value', () {
    fakeAsync((async) {
      final settings = SettingsStore.fromJson({});
      final writes = <String>[];
      final stop = persistSettings(settings, writes.add);
      async.elapse(const Duration(seconds: 1));
      expect(writes, hasLength(1));
      writes.clear();

      // One second of dragging at 60 frames a second.
      for (var frame = 0; frame < 60; frame++) {
        settings.chatWidth = 0.3 + frame * 0.002;
        async.elapse(const Duration(milliseconds: 16));
      }
      async.elapse(const Duration(seconds: 1));

      // Before: one write per frame, 60 here (144 a second on a 144 Hz
      // tablet), each encoding every setting on the UI thread.
      expect(writes.length, lessThanOrEqualTo(5));
      expect(chatWidthOf(writes.last), closeTo(0.3 + 59 * 0.002, 1e-9));
      stop();
    });
  });

  test('a change just before the app leaves the screen is written at once', () {
    fakeAsync((async) {
      final settings = SettingsStore.fromJson({});
      final writes = <String>[];
      final stop = persistSettings(settings, writes.add);
      async.elapse(const Duration(seconds: 1));
      writes.clear();

      settings.chatWidth = 0.42;
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(writes, hasLength(1));
      expect(chatWidthOf(writes.single), 0.42);

      // Nothing new to write when the delay is up.
      async.elapse(const Duration(seconds: 1));
      expect(writes, hasLength(1));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      stop();
    });
  });

  test('stopping writes what is still pending', () {
    fakeAsync((async) {
      final settings = SettingsStore.fromJson({});
      final writes = <String>[];
      final stop = persistSettings(settings, writes.add);
      async.elapse(const Duration(seconds: 1));
      writes.clear();
      settings.chatWidth = 0.37;
      stop();
      expect(chatWidthOf(writes.single), 0.37);
    });
  });

  // Read from disk by other isolates (the go-live worker checks the consent
  // there) and on the next start: written at once, never gathered.
  for (final (name, change) in <(String, void Function(SettingsStore))>[
    ('the crash logs consent', (s) => s.shareCrashLogsAndAnalytics = false),
    ('the consent version', (s) => s.telemetryConsentVersion = 9999),
    ('the language', (s) => s.appLanguage = AppLanguage.fr),
    ('the language question', (s) => s.languagePromptVersion = 9999),
  ]) {
    test('$name is written at once', () {
      fakeAsync((async) {
        final settings = SettingsStore.fromJson({})
          ..shareCrashLogsAndAnalytics = true;
        final writes = <String>[];
        final stop = persistSettings(settings, writes.add);
        async.elapse(const Duration(seconds: 1));
        writes.clear();

        change(settings);
        // Before: nothing until the 300 ms were up.
        expect(writes, hasLength(1));
        final expected = SettingsStore.fromJson({})
          ..shareCrashLogsAndAnalytics = true;
        change(expected);
        expect(writes.single, jsonEncode(expected));

        // Nothing written twice when the delay is up.
        async.elapse(const Duration(seconds: 1));
        expect(writes, hasLength(1));
        stop();
      });
    });
  }
}
