import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

/// How long changes to the settings are gathered before they are written.
const kSettingsSaveDelay = Duration(milliseconds: 300);

/// Writes [settings] out as JSON through [write] whenever they change: at
/// most once per [delay], with the latest values, and at once when the app
/// leaves the screen, so a change is never lost to the app being closed.
///
/// A drag on the chat's divider or on a settings slider changes a setting
/// on every frame. Written at each change, the settings were encoded whole
/// on the UI thread and sent to the platform up to 144 times a second.
///
/// The consent to crash logs and analytics and the language are written at
/// once, never gathered: other isolates read them from disk (the go-live
/// worker turns its collection off on an opt-out), and they are rare.
///
/// Returns what stops it.
VoidCallback persistSettings(
  SettingsStore settings,
  void Function(String json) write, {
  Duration delay = kSettingsSaveDelay,
}) {
  String? written;
  void save() {
    final json = jsonEncode(settings);
    if (json == written) return;
    written = json;
    write(json);
  }

  final disposeReaction = autorun((_) => save(), delay: delay.inMilliseconds);
  final disposeImmediate = reaction(
    (_) => (
      settings.shareCrashLogsAndAnalytics,
      settings.telemetryConsentVersion,
      settings.appLanguage,
      settings.languagePromptVersion,
    ),
    (_) => save(),
  );
  final lifecycle = AppLifecycleListener(onHide: save, onPause: save);
  return () {
    disposeReaction();
    disposeImmediate();
    lifecycle.dispose();
    save();
  };
}
