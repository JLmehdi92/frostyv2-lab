import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';

/// The native side speaks the app's languages: Android's notification
/// channels and actions take their words from Dart (the ARB files), the
/// vendored Picture-in-picture plugin has French for each of its texts, and
/// the languages the system offers (Android's per-app language list, iOS's
/// localizations) are exactly the app's.
void main() {
  final supported = {
    for (final locale in AppLocalizations.supportedLocales) locale.languageCode,
  };

  group('the Kotlin scanner', () {
    test('finds an English word in a channel or an action', () {
      expect(
        englishInNativeLabels('''
manager.createNotificationChannel(
    NotificationChannel(CHANNEL_ID, "Playback", NotificationManager.IMPORTANCE_LOW),
)
val toggle = action(android.R.drawable.ic_media_pause, "Pause", ACTION_PAUSE)
'''),
        ['NotificationChannel: "Playback"', 'action: "Pause"'],
      );
    });

    test('leaves words from Dart alone', () {
      expect(
        englishInNativeLabels('''
NotificationChannel(CHANNEL_ID, labels.channel, NotificationManager.IMPORTANCE_LOW)
action(android.R.drawable.ic_media_play, labels.play, ACTION_PLAY)
private fun action(icon: Int, label: String, intentAction: String) =
    Notification.Action.Builder(Icon.createWithResource(this, icon), label, pending(intentAction))
'''),
        isEmpty,
      );
    });
  });

  test('no English word in a notification channel or action of the app', () {
    final files = Directory('android/app/src/main/kotlin')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.kt'))
        .toList();
    expect(files, isNotEmpty);
    final calls = <String>[];
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final found in englishInNativeLabels(source)) {
        calls.add('${file.path}: $found');
      }
    }
    expect(calls, isEmpty);
    // The media notification is one of them, so the scanner has something
    // to read.
    expect(
      File(
        'android/app/src/main/kotlin/app/onset/BackgroundAudioService.kt',
      ).readAsStringSync(),
      allOf(contains('NotificationChannel('), contains('action(')),
    );
  });

  test('the Picture-in-picture plugin has French for each of its texts', () {
    const res = 'packages/simple_pip_mode/android/src/main/res';
    final english = androidStrings(File('$res/values/strings.xml'));
    final french = androidStrings(File('$res/values-fr/strings.xml'));
    expect(english, isNotEmpty);
    expect(french.keys, unorderedEquals(english.keys));
    for (final MapEntry(:key, :value) in french.entries) {
      expect(value.trim(), isNotEmpty, reason: key);
      expect(value, isNot(english[key]), reason: key);
      expect(value, isNot(contains("'")), reason: '$key: use ’');
    }
  });

  test("Android's per-app language list is the app's languages", () {
    final config = File(
      'android/app/src/main/res/xml/locales_config.xml',
    ).readAsStringSync();
    final listed = {
      for (final match in RegExp(
        r'<locale\s+android:name="([^"]+)"',
      ).allMatches(config))
        match[1]!,
    };
    expect(listed, supported);
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:localeConfig="@xml/locales_config"'),
    );
  });

  test("iOS lists the app's languages", () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final localizations = RegExp(
      r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);
    expect(localizations, isNotNull);
    expect({
      for (final match in RegExp(
        r'<string>([^<]+)</string>',
      ).allMatches(localizations![1]!))
        match[1]!,
    }, supported);
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final regions = RegExp(
      r'knownRegions = \((.*?)\);',
      dotAll: true,
    ).firstMatch(project);
    expect(regions, isNotNull);
    final known = {
      for (final part in regions![1]!.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    };
    expect(known, containsAll(supported));
  });
}

/// The string literals with words in [source]'s `NotificationChannel(…)`
/// and `action(…)` calls (their names and labels must come from Dart), as
/// `call: "literal"`.
List<String> englishInNativeLabels(String source) {
  final found = <String>[];
  for (final match in RegExp(
    r'\b(NotificationChannel|action)\s*\(',
  ).allMatches(source)) {
    // The call's arguments, to its closing parenthesis.
    var depth = 1;
    var i = match.end;
    while (i < source.length && depth > 0) {
      final char = source[i];
      if (char == '(') depth++;
      if (char == ')') depth--;
      i++;
    }
    final arguments = source.substring(match.end, i - 1);
    for (final literal in RegExp(r'"([^"\\]*)"').allMatches(arguments)) {
      if (RegExp(r'[A-Za-z]{2,}').hasMatch(literal[1]!)) {
        found.add('${match[1]}: "${literal[1]}"');
      }
    }
  }
  return found;
}

/// The `<string name="…">…</string>` entries of an Android resource file.
Map<String, String> androidStrings(File file) => {
  for (final match in RegExp(
    r'<string\s+name="([^"]+)"\s*>(.*?)</string>',
    dotAll: true,
  ).allMatches(file.readAsStringSync()))
    match[1]!: match[2]!,
};
