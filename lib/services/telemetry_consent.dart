import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/telemetry.dart';

/// Whether Firebase collects, for the "Share crash logs and analytics"
/// setting [shared]: never in a [debug] build, so development never
/// pollutes the data.
bool firebaseCollectionFor(bool shared, {bool debug = kDebugMode}) =>
    shared && !debug;

/// Turns the Firebase collection on or off, as the setting says (see
/// [firebaseCollectionFor]). Nothing without Firebase (see [Telemetry]).
void setFirebaseCollection(bool shared, {bool debug = kDebugMode}) =>
    Telemetry.setCollectionEnabled(firebaseCollectionFor(shared, debug: debug));

/// Keeps the Firebase collection in step with [settings]: applied at once,
/// then on every change of the setting, wherever it is made (the settings
/// switch, the onboarding, a settings reset). The returned function stops
/// it.
ReactionDisposer syncFirebaseCollection(
  SettingsStore settings, {
  bool debug = kDebugMode,
}) => reaction<bool>(
  (_) => settings.shareCrashLogsAndAnalytics,
  (shared) => setFirebaseCollection(shared, debug: debug),
  fireImmediately: true,
);
