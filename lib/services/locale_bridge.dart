import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the app's language and Android 13+'s per-app language (Settings ›
/// Apps › ONSET › Language) the same, both ways: a language picked in the
/// app is told to the system ([push]); one picked in the system is found
/// when the app starts or comes back ([changedInSystem]) and adopted.
///
/// Elsewhere (older Android, iOS) it does nothing: the native side answers
/// null, and the app's own setting is the only one.
class LocaleBridge {
  LocaleBridge({
    MethodChannel? channel,
    bool? supported,
    Future<SharedPreferences> Function()? prefs,
  }) : _channel = channel ?? const MethodChannel('onset/locale'),
       _supported = supported ?? Platform.isAndroid,
       _prefs = prefs ?? SharedPreferences.getInstance;

  static final shared = LocaleBridge();

  final MethodChannel _channel;
  final bool _supported;
  final Future<SharedPreferences> Function() _prefs;

  /// The system's tag the app last set or adopted ('' for the device's):
  /// a different one there was picked in the system's settings.
  static const _toldKey = 'system_app_language';

  /// [language]'s tag in the system: '' for the device's.
  @visibleForTesting
  static String tagOf(AppLanguage language) => switch (language) {
    AppLanguage.system => '',
    AppLanguage.en => 'en',
    AppLanguage.fr => 'fr',
  };

  /// The language a system [tag] means ('' the device's), null for one
  /// the app does not speak.
  @visibleForTesting
  static AppLanguage? languageOf(String tag) {
    if (tag.isEmpty) return AppLanguage.system;
    return switch (tag.split(RegExp('[-_,]')).first.toLowerCase()) {
      'en' => AppLanguage.en,
      'fr' => AppLanguage.fr,
      _ => null,
    };
  }

  /// Tells the system the app shows [language]. A language the system
  /// already gives, maybe for a region (« Français (Canada) », fr-CA,
  /// for French), is kept as the viewer picked it there. Failures are
  /// logged.
  Future<void> push(AppLanguage language) async {
    if (!_supported) return;
    try {
      final current = await _channel.invokeMethod<String>('get');
      final prefs = await _prefs();
      if (current != null && languageOf(current) == language) {
        await prefs.setString(_toldKey, current);
        return;
      }
      final tag = tagOf(language);
      await _channel.invokeMethod<void>('set', tag);
      await prefs.setString(_toldKey, tag);
    } catch (e) {
      debugPrint('Per-app language not set: $e');
    }
  }

  /// The device's own languages from the last [systemLocales] that
  /// answered, null before.
  List<Locale>? get lastSystemLocales => _lastSystemLocales;
  List<Locale>? _lastSystemLocales;

  /// The device's own languages, most preferred first: what System gives.
  /// On Android 13+ Flutter's list is the per-app language once the app
  /// set one, so the system is asked. Null where it does not answer (iOS,
  /// older Android before this version, a failure): Flutter's list is the
  /// device's there.
  Future<List<Locale>?> systemLocales() async {
    if (!_supported) return null;
    try {
      final tags = await _channel.invokeMethod<String>('systemLocales');
      final locales = [
        for (final tag in (tags ?? '').split(','))
          ?localeOfTag(tag),
      ];
      if (locales.isEmpty) return null;
      return _lastSystemLocales = locales;
    } catch (e) {
      debugPrint('System languages not read: $e');
      return null;
    }
  }

  /// The locale a BCP 47 [tag] names ("fr-CA", "zh-Hant-TW"): its language
  /// and region (the script is left out), null for a blank or malformed
  /// one.
  @visibleForTesting
  static Locale? localeOfTag(String tag) {
    final parts = tag.trim().split(RegExp('[-_]'));
    final language = parts.first.toLowerCase();
    if (!RegExp(r'^[a-z]{2,8}$').hasMatch(language)) return null;
    final region = parts
        .skip(1)
        .where((part) => RegExp(r'^([a-zA-Z]{2}|[0-9]{3})$').hasMatch(part))
        .firstOrNull;
    return Locale.fromSubtags(
      languageCode: language,
      countryCode: region?.toUpperCase(),
    );
  }

  /// The language picked in the system's settings since the app last
  /// told it one, or null: unchanged, never told (the app tells it
  /// first), not one the app speaks, or no per-app language here.
  Future<AppLanguage?> changedInSystem() async {
    if (!_supported) return null;
    try {
      final tag = await _channel.invokeMethod<String>('get');
      if (tag == null) return null;
      final prefs = await _prefs();
      final told = prefs.getString(_toldKey);
      if (told == null || told == tag) return null;
      final language = languageOf(tag);
      // Adopted: the system says what the app shows.
      await prefs.setString(_toldKey, tag);
      return language;
    } catch (e) {
      debugPrint('Per-app language not read: $e');
      return null;
    }
  }
}

/// Follows the per-app language both ways for [settings]: at start and on
/// each resume, a language picked in the system meanwhile is adopted;
/// otherwise, and on each change in the app, the app's is told to the
/// system. Returns the function to call on resume.
Future<Future<void> Function()> syncSystemLanguage(
  SettingsStore settings,
  LocaleBridge bridge,
) async {
  Future<void> adopt() async {
    final picked = await bridge.changedInSystem();
    if (picked != null && picked != settings.appLanguage) {
      settings.chooseLanguage(picked);
    }
  }

  await adopt();
  await bridge.push(settings.appLanguage);
  return adopt;
}
