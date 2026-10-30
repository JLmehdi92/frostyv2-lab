import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/telemetry.dart';
import 'package:onset/services/telemetry_consent.dart';

/// The "Share crash logs and analytics" setting drives Firebase collection
/// wherever it changes: the settings switch, the onboarding, a reset.
void main() {
  late DebugPrintCallback savedPrint;
  late SettingsStore settings;

  setUp(() {
    // Firebase "up" without a real app: its failures are only printed.
    savedPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    Telemetry.debugReset(firebaseUp: true);
    settings = SettingsStore.fromJson({});
  });

  tearDown(() {
    debugPrint = savedPrint;
    Telemetry.debugReset();
  });

  test('a debug build never collects, whatever the switch says', () {
    // Tests run in debug mode.
    expect(firebaseCollectionFor(true), isFalse);
    expect(firebaseCollectionFor(false), isFalse);
    expect(firebaseCollectionFor(true, debug: false), isTrue);
    expect(firebaseCollectionFor(false, debug: false), isFalse);
  });

  test('a saved opt-in collects from launch, the default does not', () {
    syncFirebaseCollection(settings, debug: false)();
    expect(Telemetry.collecting, isFalse);

    syncFirebaseCollection(
      SettingsStore.fromJson({'shareCrashLogsAndAnalytics': true}),
      debug: false,
    )();
    expect(Telemetry.collecting, isTrue);
  });

  test('the switch turns collection on and off at once', () {
    final dispose = syncFirebaseCollection(settings, debug: false);
    addTearDown(dispose.call);

    settings.shareCrashLogsAndAnalytics = true;
    expect(Telemetry.collecting, isTrue);
    settings.shareCrashLogsAndAnalytics = false;
    expect(Telemetry.collecting, isFalse);
  });

  test('resetting the settings while opted in stops collection', () {
    settings.shareCrashLogsAndAnalytics = true;
    final dispose = syncFirebaseCollection(settings, debug: false);
    addTearDown(dispose.call);
    expect(Telemetry.collecting, isTrue);

    settings.resetAllSettings();
    expect(Telemetry.collecting, isFalse);

    settings.shareCrashLogsAndAnalytics = true;
    settings.resetOtherSettings();
    expect(Telemetry.collecting, isFalse);
  });

  test('in a debug build the switch does not turn collection on', () {
    final dispose = syncFirebaseCollection(settings);
    addTearDown(dispose.call);

    settings.shareCrashLogsAndAnalytics = true;
    expect(Telemetry.collecting, isFalse);
  });
}
