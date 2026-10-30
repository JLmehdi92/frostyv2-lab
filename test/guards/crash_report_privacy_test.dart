import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Crash reports must not identify the viewer: no user id, and no custom
/// key, log line or error reason built from a login, a channel, a user id,
/// a token, a message or an address (which can carry any of them).
///
/// Every call in `lib/` is inspected, commented code left out.
void main() {
  group('the guard', () {
    test('finds each planted leak', () {
      const planted = [
        r'Telemetry.setUserIdentifier(authStore.user.details!.id);',
        r"Telemetry.setCustomKey('channel', 'x');",
        r"Telemetry.setCustomKey('state', channelName);",
        r"Telemetry.log('reconnecting, channel=$channelName');",
        r"Telemetry.log('failed for ${authStore.user.details?.login}');",
        r"Telemetry.recordError(e, null, reason: 'IRC, channel=$channelName');",
        r"Telemetry.recordError(e, null, reason: 'GET ${uri.path}');",
        r"FirebaseCrashlytics.instance.log('direct');",
      ];
      for (final line in planted) {
        expect(
          violationsIn('void f() {\n  $line\n}\n', 'lib/planted.dart'),
          isNotEmpty,
          reason: line,
        );
      }
    });

    test('leaves commented code and plain reports alone', () {
      const planted = r'''
void fine(String channelName, Object e) {
  // Telemetry.setUserIdentifier(id);
  /// Telemetry.setCustomKey('channel', channelName);
  /* Telemetry.log('channel=$channelName');
     /* nested */ Telemetry.setUserIdentifier(id); */
  final url = 'https://example.com/a'; // a string with a slash pair
  Telemetry.setCustomKey('is_logged_in', true);
  Telemetry.log('reconnecting: attempt $retries');
  Telemetry.recordError(e, null, reason: 'moderation ${command.runtimeType}');
  Telemetry.recordError(e, null, reason: '/w');
}
''';
      expect(violationsIn(planted, 'lib/planted.dart'), isEmpty);
      final calls = telemetryCallsIn(stripComments(planted));
      expect(calls.map((c) => c.method), [
        'setCustomKey',
        'log',
        'recordError',
        'recordError',
      ]);
    });

    test('keeps a string that looks like a comment', () {
      expect(
        stripComments("a('https://x/y'); // b\nc(\"/*\"); /* d */ e();"),
        "a('https://x/y');     \nc(\"/*\");         e();",
      );
    });
  });

  test('no crash report identifies the viewer or the channel', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .toList();
    expect(files.length, greaterThan(100));

    final violations = <String>[];
    final counts = <String, int>{};
    for (final file in files) {
      final source = file.readAsStringSync();
      violations.addAll(violationsIn(source, file.path));
      for (final call in telemetryCallsIn(stripComments(source))) {
        counts[call.method] = (counts[call.method] ?? 0) + 1;
      }
    }

    // It saw the reports it is about.
    expect(counts['recordError'], greaterThanOrEqualTo(15));
    expect(counts['log'], greaterThanOrEqualTo(4));
    expect(counts['setCustomKey'], greaterThanOrEqualTo(1));
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

/// Names that hold, or can hold, who the viewer is or what they watch.
final _identifying = RegExp(
  'login|channel|user|token|message|email|name|uri|url|path|query|'
  'broadcaster|chatter|whisper|target',
  caseSensitive: false,
);

final _identifier = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*');

/// The leaks in [source], the Dart file at [path].
List<String> violationsIn(String source, String path) {
  final code = stripComments(source);
  final masked = maskStrings(code);
  final found = <String>[];
  final isTelemetry = path
      .replaceAll(r'\', '/')
      .endsWith('lib/services/telemetry.dart');

  for (final match in RegExp(
    r'\bsetUserIdentifier\b|\bsetUserProperty\b',
  ).allMatches(masked)) {
    found.add('$path: ${match[0]} sends a user identifier');
  }
  if (isTelemetry) {
    for (final _ in RegExp(r'\.setUserId\s*\(').allMatches(masked)) {
      found.add('$path: setUserId sends a user identifier');
    }
  } else {
    for (final match in RegExp(
      r'\bFirebase(Crashlytics|Analytics|Performance)\b',
    ).allMatches(masked)) {
      found.add('$path: ${match[0]} used outside Telemetry');
    }
  }

  for (final call in telemetryCallsIn(code)) {
    final args = call.arguments;
    final masked = maskStrings(args);
    String? checked;
    switch (call.method) {
      case 'setCustomKey':
        checked = args;
        final key = RegExp(r'''^\s*(['"])(.*?)\1''').firstMatch(args)?[2];
        if (key != null && _identifying.hasMatch(key)) {
          found.add('$path: custom key "$key"');
        }
      case 'log':
        checked = args;
      case 'recordError':
        final reason = RegExp(r'\breason\s*:').firstMatch(masked);
        if (reason != null) checked = args.substring(reason.end);
      case 'setUserIdentifier':
        break;
    }
    if (checked == null) continue;
    for (final name in _identifier.allMatches(maskStrings(checked))) {
      final word = name[0]!;
      if (word == 'reason') continue;
      if (_identifying.hasMatch(word)) {
        found.add('$path: Telemetry.${call.method} carries "$word"');
      }
    }
  }
  return found;
}

/// A `Telemetry.<method>(...)` call: its method and argument text.
typedef TelemetryCall = ({String method, String arguments});

/// The Telemetry calls in [code] (comments already stripped).
List<TelemetryCall> telemetryCallsIn(String code) {
  final masked = maskStrings(code);
  final calls = <TelemetryCall>[];
  for (final match in RegExp(
    r'\bTelemetry\.(setUserIdentifier|setCustomKey|log|recordError)\s*\(',
  ).allMatches(masked)) {
    var depth = 1;
    var i = match.end;
    for (; i < masked.length && depth > 0; i++) {
      final c = masked[i];
      if (c == '(' || c == '[' || c == '{') depth++;
      if (c == ')' || c == ']' || c == '}') depth--;
    }
    calls.add((method: match[1]!, arguments: code.substring(match.end, i - 1)));
  }
  return calls;
}

/// [source] with every comment turned into spaces (line breaks kept).
String stripComments(String source) => _scan(source, maskLiterals: false);

/// [code] with the literal text of every string turned into spaces; the
/// quotes and the interpolated code stay.
String maskStrings(String code) => _scan(code, maskLiterals: true);

String _scan(String s, {required bool maskLiterals}) {
  final out = StringBuffer();
  // Each entry: a string's delimiter (and whether it is raw), or null for
  // code (an interpolation's, with its brace depth).
  final strings = <({String delimiter, bool raw})?>[null];
  final braces = <int>[0];
  var i = 0;

  void blank(String text) => out.write(text.replaceAll(RegExp(r'[^\n]'), ' '));

  while (i < s.length) {
    final string = strings.last;
    if (string == null) {
      if (s.startsWith('//', i)) {
        final end = s.indexOf('\n', i);
        final stop = end == -1 ? s.length : end;
        blank(s.substring(i, stop));
        i = stop;
        continue;
      }
      if (s.startsWith('/*', i)) {
        var depth = 0;
        var j = i;
        while (j < s.length) {
          if (s.startsWith('/*', j)) {
            depth++;
            j += 2;
          } else if (s.startsWith('*/', j)) {
            depth--;
            j += 2;
            if (depth == 0) break;
          } else {
            j++;
          }
        }
        blank(s.substring(i, j));
        i = j;
        continue;
      }
      final raw = s[i] == 'r' && i + 1 < s.length && "'\"".contains(s[i + 1]);
      final q = raw ? i + 1 : i;
      if (q < s.length && (s[q] == "'" || s[q] == '"')) {
        final triple = s.startsWith(s[q] * 3, q);
        final delimiter = triple ? s[q] * 3 : s[q];
        out.write(s.substring(i, q + delimiter.length));
        i = q + delimiter.length;
        strings.add((delimiter: delimiter, raw: raw));
        braces.add(0);
        continue;
      }
      if (s[i] == '{') braces.last++;
      if (s[i] == '}') {
        if (braces.last == 0 && strings.length > 1) {
          // The end of an interpolation: back in its string.
          strings.removeLast();
          braces.removeLast();
          out.write('}');
          i++;
          continue;
        }
        braces.last--;
      }
      out.write(s[i]);
      i++;
      continue;
    }

    if (s.startsWith(string.delimiter, i)) {
      out.write(string.delimiter);
      i += string.delimiter.length;
      strings.removeLast();
      braces.removeLast();
      continue;
    }
    if (!string.raw && s[i] == r'\' && i + 1 < s.length) {
      final escape = s.substring(i, i + 2);
      maskLiterals ? blank(escape) : out.write(escape);
      i += 2;
      continue;
    }
    if (!string.raw && s.startsWith(r'${', i)) {
      out.write(r'${');
      i += 2;
      strings.add(null);
      braces.add(0);
      continue;
    }
    if (!string.raw && s[i] == r'$') {
      final name = _identifier.matchAsPrefix(s, i + 1);
      if (name != null) {
        out.write('\$${name[0]}');
        i = name.end;
        continue;
      }
    }
    maskLiterals ? blank(s[i]) : out.write(s[i]);
    i++;
  }
  return out.toString();
}
