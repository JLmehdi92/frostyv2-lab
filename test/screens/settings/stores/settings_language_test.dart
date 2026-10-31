import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

/// The language setting and its one-time question.
void main() {
  SettingsStore relaunch(SettingsStore store) => SettingsStore.fromJson(
    jsonDecode(jsonEncode(store.toJson())) as Map<String, dynamic>,
  );

  test('settings saved before it: the device\'s language, not yet asked', () {
    final store = SettingsStore.fromJson({});
    expect(store.appLanguage, AppLanguage.system);
    expect(store.languagePromptVersion, 0);
    expect(store.languagePromptVersion, lessThan(kLanguagePromptVersion));
  });

  test('a new store starts at the current question version', () {
    final store = SettingsStore();
    expect(store.appLanguage, AppLanguage.system);
    expect(store.languagePromptVersion, kLanguagePromptVersion);
  });

  test('a choice survives a relaunch and answers the question', () {
    final store = SettingsStore.fromJson({})..chooseLanguage(AppLanguage.fr);
    expect(store.appLanguage, AppLanguage.fr);
    expect(store.languagePromptVersion, kLanguagePromptVersion);
    final restored = relaunch(store);
    expect(restored.appLanguage, AppLanguage.fr);
    expect(restored.languagePromptVersion, kLanguagePromptVersion);
  });

  test('both are saved', () {
    final json = SettingsStore.fromJson({}).toJson();
    expect(json['appLanguage'], 'system');
    expect(json['languagePromptVersion'], 0);
  });

  test('an unknown saved language reads as the device\'s', () {
    final store = SettingsStore.fromJson({
      'appLanguage': 'de',
      'languagePromptVersion': 1,
    });
    expect(store.appLanguage, AppLanguage.system);
    expect(store.languagePromptVersion, 1);
  });

  test('no reset changes the language or asks again', () {
    final store = SettingsStore.fromJson({})..chooseLanguage(AppLanguage.en);
    store
      ..resetGeneralSettings()
      ..resetVideoSettings()
      ..resetChatSettings()
      ..resetOtherSettings()
      ..resetGlobalConfigs()
      ..resetAllSettings();
    expect(store.appLanguage, AppLanguage.en);
    expect(store.languagePromptVersion, kLanguagePromptVersion);
  });

  test('each language forces its locale; system forces none', () {
    expect(AppLanguage.system.locale, isNull);
    expect(AppLanguage.en.locale, const Locale('en'));
    expect(AppLanguage.fr.locale, const Locale('fr'));
  });
}
