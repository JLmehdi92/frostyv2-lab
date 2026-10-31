import 'dart:convert';
import 'dart:io';

/// Reads the ARB files and the ICU messages in them, for the l10n tests.

/// An ARB file's entries, in file order (keys starting with `@` included).
Map<String, Object?> readArb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

/// The message keys of [arb], in file order (no `@` metadata).
List<String> messageKeys(Map<String, Object?> arb) => [
  for (final key in arb.keys)
    if (!key.startsWith('@')) key,
];

const enArbPath = 'lib/l10n/app_en.arb';
const frArbPath = 'lib/l10n/app_fr.arb';

/// A parsed ICU message: its placeholders (simple and plural or select) and
/// the plain text of every branch.
class IcuMessage {
  IcuMessage._(this.source);

  final String source;

  /// Every argument named in the message, in order of first use.
  final arguments = <String>[];

  /// The plural and select arguments, with their branch selectors.
  final choices = <String, ({String kind, List<String> selectors})>{};

  /// The literal text, with each argument (and plural `#`) as `X`, one
  /// string per text run between ICU structure.
  final texts = <String>[];

  /// The literal text between arguments and ICU structure, without any
  /// marker: what the generated code must spell out.
  final fragments = <String>[];

  /// Parses [source] as an ICU message (gen-l10n's dialect: apostrophes
  /// are plain text). Throws [FormatException] when it is malformed.
  factory IcuMessage.parse(String source) {
    final message = IcuMessage._(source);
    final parser = _IcuParser(source, message);
    parser.parseMessage(inPlural: false);
    if (!parser.atEnd) {
      throw FormatException('Unexpected "}"', source, parser.index);
    }
    return message;
  }
}

class _IcuParser {
  _IcuParser(this.source, this.message);

  final String source;
  final IcuMessage message;
  var index = 0;

  bool get atEnd => index >= source.length;

  void _addArgument(String name) {
    if (!message.arguments.contains(name)) message.arguments.add(name);
  }

  /// Text and arguments up to an unmatched `}` or the end. In a plural
  /// branch, `#` is the count.
  void parseMessage({required bool inPlural}) {
    final text = StringBuffer();
    final fragment = StringBuffer();
    void cut() {
      if (fragment.isNotEmpty) message.fragments.add(fragment.toString());
      fragment.clear();
    }

    while (!atEnd) {
      final char = source[index];
      if (char == '}') break;
      if (char == '{') {
        index++;
        cut();
        _parseArgument();
        text.write('X');
        continue;
      }
      if (char == '#' && inPlural) {
        cut();
        text.write('X');
        index++;
        continue;
      }
      text.write(char);
      fragment.write(char);
      index++;
    }
    cut();
    message.texts.add(text.toString());
  }

  String _name() {
    final start = index;
    while (!atEnd && RegExp(r'[A-Za-z0-9_]').hasMatch(source[index])) {
      index++;
    }
    if (start == index) {
      throw FormatException('Argument name expected', source, index);
    }
    return source.substring(start, index);
  }

  void _skipSpaces() {
    while (!atEnd && source[index].trim().isEmpty) {
      index++;
    }
  }

  void _expect(String char) {
    _skipSpaces();
    if (atEnd || source[index] != char) {
      throw FormatException('"$char" expected', source, index);
    }
    index++;
  }

  void _parseArgument() {
    _skipSpaces();
    final name = _name();
    _addArgument(name);
    _skipSpaces();
    if (!atEnd && source[index] == '}') {
      index++;
      return;
    }
    _expect(',');
    _skipSpaces();
    final kind = _name();
    if (kind != 'plural' && kind != 'select' && kind != 'selectordinal') {
      throw FormatException('Unknown argument type "$kind"', source, index);
    }
    _expect(',');
    final selectors = <String>[];
    while (true) {
      _skipSpaces();
      if (atEnd) throw FormatException('Unclosed "$name"', source, index);
      if (source[index] == '}') {
        index++;
        break;
      }
      final start = index;
      while (!atEnd && !RegExp(r'[\s{}]').hasMatch(source[index])) {
        index++;
      }
      final selector = source.substring(start, index);
      if (selector.isEmpty) {
        throw FormatException('Selector expected', source, index);
      }
      selectors.add(selector);
      _expect('{');
      parseMessage(inPlural: kind != 'select');
      _expect('}');
    }
    if (selectors.isEmpty) {
      throw FormatException('"$name" has no branch', source, index);
    }
    message.choices[name] = (kind: kind, selectors: selectors);
  }
}
