import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/locale_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android 13+'s per-app language and the app's stay the same, both ways.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('onset/locale-test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  // What the system holds ('' the device's); null: no per-app language.
  String? system;
  // The device's own languages, as the system's tags.
  String? device;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    system = '';
    device = 'en-US';
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'set') system = call.arguments as String;
      return switch (call.method) {
        'get' => system,
        'systemLocales' => device,
        _ => null,
      };
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  LocaleBridge bridge({bool supported = true}) =>
      LocaleBridge(channel: channel, supported: supported);

  test('tags and languages', () {
    expect(LocaleBridge.tagOf(AppLanguage.system), '');
    expect(LocaleBridge.tagOf(AppLanguage.fr), 'fr');
    expect(LocaleBridge.languageOf(''), AppLanguage.system);
    expect(LocaleBridge.languageOf('fr-CA'), AppLanguage.fr);
    expect(LocaleBridge.languageOf('en-GB,fr'), AppLanguage.en);
    expect(LocaleBridge.languageOf('de'), isNull);
  });

  test('the app tells the system its language, then adopts one picked in '
      'the system', () async {
    final settings = SettingsStore.fromJson({'appLanguage': 'fr'});
    final adopt = await syncSystemLanguage(settings, bridge());
    // Never told before: the app's own choice wins and is told.
    expect(system, 'fr');
    expect(settings.appLanguage, AppLanguage.fr);

    // Unchanged: nothing adopted.
    await adopt();
    expect(settings.appLanguage, AppLanguage.fr);

    // The viewer picks English in the system's settings, then comes back.
    system = 'en';
    await adopt();
    expect(settings.appLanguage, AppLanguage.en);

    // Then the device's language there.
    system = '';
    await adopt();
    expect(settings.appLanguage, AppLanguage.system);
  });

  test('a change made in the system while the app was closed is adopted at '
      'start', () async {
    final first = SettingsStore.fromJson({'appLanguage': 'en'});
    await syncSystemLanguage(first, bridge());
    expect(system, 'en');

    system = 'fr';
    final next = SettingsStore.fromJson({'appLanguage': 'en'});
    await syncSystemLanguage(next, bridge());
    expect(next.appLanguage, AppLanguage.fr);
    expect(system, 'fr');
  });

  test('a language picked in the app is told to the system', () async {
    await bridge().push(AppLanguage.fr);
    expect(system, 'fr');
    await bridge().push(AppLanguage.system);
    expect(system, '');
    expect(await bridge().changedInSystem(), isNull);
  });

  test('a regional pick in the system is adopted as its language and '
      'kept there', () async {
    final settings = SettingsStore.fromJson({'appLanguage': 'en'});
    final adopt = await syncSystemLanguage(settings, bridge());
    expect(system, 'en');

    // « Français (Canada) » picked in the system's settings.
    system = 'fr-CA';
    await adopt();
    expect(settings.appLanguage, AppLanguage.fr);
    // main.dart's reaction tells the system the app's language: the
    // system's own pick stays.
    calls.clear();
    await bridge().push(settings.appLanguage);
    expect(system, 'fr-CA');
    expect(calls.where((call) => call.method == 'set'), isEmpty);
    // Nothing more to adopt, nothing sent on later resumes.
    await adopt();
    await adopt();
    expect(settings.appLanguage, AppLanguage.fr);
    expect(calls.where((call) => call.method == 'set'), isEmpty);

    // Another language picked in the app replaces it.
    await bridge().push(AppLanguage.en);
    expect(system, 'en');
  });

  test("the device's own languages: what System gives", () async {
    device = 'fr-CA,en-US';
    final local = bridge();
    expect(local.lastSystemLocales, isNull);
    expect(await local.systemLocales(), const [
      Locale('fr', 'CA'),
      Locale('en', 'US'),
    ]);
    expect(local.lastSystemLocales, const [
      Locale('fr', 'CA'),
      Locale('en', 'US'),
    ]);
    device = '';
    expect(await local.systemLocales(), isNull);
    device = null;
    expect(await local.systemLocales(), isNull);
    // The last answer is kept.
    expect(local.lastSystemLocales, const [
      Locale('fr', 'CA'),
      Locale('en', 'US'),
    ]);

    expect(LocaleBridge.localeOfTag('zh-Hant-TW'), const Locale('zh', 'TW'));
    expect(LocaleBridge.localeOfTag('es-419'), const Locale('es', '419'));
    expect(LocaleBridge.localeOfTag('FR'), const Locale('fr'));
    expect(LocaleBridge.localeOfTag(' '), isNull);
    expect(LocaleBridge.localeOfTag('und!'), isNull);

    // Nothing asked where the system does not answer (iOS).
    calls.clear();
    expect(await bridge(supported: false).systemLocales(), isNull);
    expect(calls, isEmpty);
  });

  test('nothing without a per-app language (before Android 13, iOS)', () async {
    system = null;
    final settings = SettingsStore.fromJson({'appLanguage': 'fr'});
    final adopt = await syncSystemLanguage(settings, bridge());
    await adopt();
    expect(settings.appLanguage, AppLanguage.fr);

    calls.clear();
    final ios = bridge(supported: false);
    await ios.push(AppLanguage.en);
    expect(await ios.changedInSystem(), isNull);
    expect(calls, isEmpty);
  });

  test('a failing channel is logged, never thrown', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'boom'),
    );
    await bridge().push(AppLanguage.fr);
    expect(await bridge().changedInSystem(), isNull);
    expect(await bridge().systemLocales(), isNull);
  });
}
