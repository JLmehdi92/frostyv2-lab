import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// The scanner of `no_hardcoded_strings_test.dart`: which string literals
/// of `lib/` read like text a viewer sees, and so belong in the ARB files.
///
/// A literal is flagged when it has two letters in a row and is either in a
/// place that shows text (the argument of `Text`, a `label:`, a `tooltip:`,
/// a default `title`, an enum's constructor argument...) or reads like a
/// sentence (two words or more) anywhere. Code is left alone: directives,
/// annotations, logs, asserts, exceptions, `RegExp`, `Uri`, keys, route
/// names, platform channels, preferences keys, map keys and indexes,
/// comparisons and `case` patterns, URLs, hosts, asset paths and
/// triple-quoted strings (scripts, queries).

/// One flagged literal.
class FlaggedLiteral {
  const FlaggedLiteral({
    required this.path,
    required this.line,
    required this.text,
    required this.reason,
  });

  final String path;
  final int line;

  /// Its text, each interpolation shown as `{}` (how the allow-list names
  /// it).
  final String text;

  /// 'ui' (a place that shows text) or 'sentence'.
  final String reason;

  @override
  String toString() => '$path:$line [$reason] $text';
}

/// The Dart files the guard reads: `lib/`, without generated code.
List<File> scannedFiles([String root = 'lib']) {
  final files =
      Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.g.dart'))
          .where((f) => !_generatedL10n.hasMatch(f.path.replaceAll('\\', '/')))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

final _generatedL10n = RegExp(r'(^|/)lib/l10n/app_localizations[^/]*\.dart$');

/// The literals of [source] (the file at [path]) that read like UI text.
List<FlaggedLiteral> flaggedIn(String source, {String path = 'source.dart'}) {
  final result = parseString(
    content: source,
    path: path,
    throwIfDiagnostics: false,
  );
  final visitor = _Visitor(path, result.lineInfo);
  result.unit.accept(visitor);
  return visitor.found;
}

/// [flagged] grouped by file, without what [allowlist] lets through.
Map<String, List<FlaggedLiteral>> notAllowed(
  Iterable<FlaggedLiteral> flagged,
  Map<String, Map<String, String>> allowlist,
) {
  final byFile = <String, List<FlaggedLiteral>>{};
  for (final literal in flagged) {
    if (allowlist[literal.path]?.containsKey(literal.text) ?? false) continue;
    byFile.putIfAbsent(literal.path, () => []).add(literal);
  }
  return byFile;
}

/// The allow-list entries that let nothing through: a file without the
/// literal flagged (it was extracted or rewritten), or no such file.
List<String> staleAllowlistEntries(
  Iterable<FlaggedLiteral> flagged,
  Map<String, Map<String, String>> allowlist,
) {
  final seen = {for (final literal in flagged) (literal.path, literal.text)};
  return [
    for (final MapEntry(key: path, value: texts) in allowlist.entries)
      for (final text in texts.keys)
        if (!seen.contains((path, text))) '$path: $text',
  ];
}

/// What breaks the ratchet: [counts] (literals left per file) must equal
/// [baseline] exactly. A file over its count, or with literals and no
/// count, fails; a file under its count fails too, until the baseline is
/// lowered to lock the progress in; a count for a file that is clean (or
/// gone) is stale.
List<String> ratchetProblems(
  Map<String, int> counts,
  Map<String, int> baseline,
) {
  final problems = <String>[];
  for (final MapEntry(key: path, value: count) in counts.entries) {
    final allowed = baseline[path];
    if (count == 0) continue;
    if (allowed == null) {
      problems.add(
        '$path: $count hard-coded string(s) in a file the baseline does not '
        'list: move them to lib/l10n/app_en.arb and app_fr.arb',
      );
    } else if (count > allowed) {
      problems.add(
        '$path: $count hard-coded strings, the baseline allows $allowed: '
        'move the new ones to the ARB files',
      );
    } else if (count < allowed) {
      problems.add(
        '$path: $count hard-coded strings, under the baseline\'s $allowed: '
        'lower it to $count in test/guards/l10n_baseline.dart',
      );
    }
  }
  for (final MapEntry(key: path, value: allowed) in baseline.entries) {
    if ((counts[path] ?? 0) == 0) {
      problems.add(
        '$path: clean (or gone), but the baseline still allows $allowed: '
        'remove it from test/guards/l10n_baseline.dart',
      );
    }
  }
  return problems;
}

const _placeholder = '\u{FFFC}';
final _letters = RegExp(r'\p{L}{2,}', unicode: true);
final _codeToken = RegExp(r'^[\w-]+[:_/.][\w-]+(?:[:_/.][\w-]+)*$');
final _codeChars = RegExp(r'[{};=`\\]');
final _host = RegExp(r'^[a-z0-9-]+(?:\.[a-z0-9-]+)+(?:/\S*)?$');
final _snakeOrDotted = RegExp(r'^[\w.:/-]*[_.:/][\w.:/-]*$');
final _kebab = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+){2,}$');

/// Variables holding UI text by name (`themeNames`, `_notes`).
final _uiVariable = RegExp(
  r'(names|Names|labels|Labels|label|Label|titles|Titles|notes|Notes)$',
);

/// Callees whose arguments are never UI text.
const _exemptClasses = {
  'RegExp',
  'Uri',
  'Key',
  'ValueKey',
  'ObjectKey',
  'PageStorageKey',
  'GlobalKey',
  'GlobalObjectKey',
  'LabeledGlobalKey',
  'RouteSettings',
  'MethodChannel',
  'EventChannel',
  'BasicMessageChannel',
  'OptionalMethodChannel',
  'FlutterErrorDetails',
  'ErrorDescription',
  'ErrorSummary',
  'ErrorHint',
  'DateFormat',
  'NumberFormat',
  'AssetImage',
  'Locale',
  'Telemetry',
  'FirebaseCrashlytics',
  'FirebaseAnalytics',
  'FirebasePerformance',
  'Intl',
  'Process',
  'Platform',
};

const _exemptMethods = {
  'debugPrint',
  'debugPrintStack',
  'print',
  'log',
  'recordError',
  'recordFlutterError',
  'setCustomKey',
  'logEvent',
  'logScreenView',
  'newTrace',
  'newHttpMetric',
  'invokeMethod',
  'invokeListMethod',
  'invokeMapMethod',
  'runJavaScript',
  'runJavaScriptReturningResult',
  'addJavaScriptChannel',
  'removeJavaScriptChannel',
  'fromEnvironment',
  'getString',
  'setString',
  'getBool',
  'setBool',
  'getInt',
  'setInt',
  'getDouble',
  'setDouble',
  'getStringList',
  'setStringList',
  'containsKey',
  'contains',
  'startsWith',
  'endsWith',
  'replaceAll',
  'replaceFirst',
  'replaceAllMapped',
  'split',
  'indexOf',
  'lastIndexOf',
  'matchAsPrefix',
  'hasMatch',
  'firstMatch',
  'allMatches',
  'padLeft',
  'padRight',
  'parse',
  'tryParse',
};

/// Named arguments that never carry UI text (even when their name looks
/// like it).
const _exemptNames = {
  'key',
  'debugLabel',
  'restorationId',
  'fontFamily',
  'package',
  'identifier',
  'name',
  'tag',
  'heroTag',
  'reason',
  'routeName',
  'scheme',
  'host',
  'path',
  'query',
  'fragment',
  'userAgent',
  'mimeType',
  'contentType',
  'method',
};

const _uiNames = {
  'label',
  'tooltip',
  'title',
  'subtitle',
  'message',
  'hint',
  'hintText',
  'semanticsLabel',
  'semanticLabel',
  'description',
  'detail',
  'confirm',
  'cancel',
  'body',
  'groupLabel',
  'trailingTooltip',
  'text',
  'action',
  'emptyMessage',
  'placeholder',
  'header',
  'caption',
  'note',
  'summary',
  'heading',
  'eyebrow',
  'subject',
  'applicationName',
  'applicationLegalese',
  'status',
  'headline',
  'lead',
  'question',
  'prompt',
  'warning',
};

final _uiSuffix = RegExp(
  r'(Label|Text|Title|Subtitle|Tooltip|Message|Hint|Detail|Description)$',
);

/// Callees whose positional arguments show text.
const _uiPositional = {
  'Text',
  'SelectableText',
  'SheetSectionLabel',
  'ReleaseVersionPill',
};

/// Methods that keep a literal UI text (`'First launch'.toUpperCase()`).
const _transparentMethods = {'toUpperCase', 'toLowerCase', 'trim'};

bool _isUiName(String name) =>
    !_exemptNames.contains(name) &&
    (_uiNames.contains(name) || _uiSuffix.hasMatch(name));

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this.path, this.lines);

  final String path;
  final LineInfo lines;
  final found = <FlaggedLiteral>[];

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (node.parent is AdjacentStrings) return;
    _check(node, node.value, multiline: node.isMultiline);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    if (node.parent is! AdjacentStrings) {
      _check(node, _textOf(node), multiline: node.isMultiline);
    }
    for (final element in node.elements) {
      if (element is InterpolationExpression) element.expression.accept(this);
    }
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    final multiline = node.strings.any(
      (s) =>
          (s is SimpleStringLiteral && s.isMultiline) ||
          (s is StringInterpolation && s.isMultiline),
    );
    _check(node, node.strings.map(_textOf).join(), multiline: multiline);
    for (final string in node.strings) {
      if (string is StringInterpolation) {
        for (final element in string.elements) {
          if (element is InterpolationExpression) {
            element.expression.accept(this);
          }
        }
      }
    }
  }

  static String _textOf(StringLiteral node) => switch (node) {
    SimpleStringLiteral(:final value) => value,
    StringInterpolation(:final elements) => [
      for (final element in elements)
        element is InterpolationString ? element.value : _placeholder,
    ].join(),
    AdjacentStrings(:final strings) => strings.map(_textOf).join(),
  };

  void _check(StringLiteral node, String text, {required bool multiline}) {
    if (multiline || !_letters.hasMatch(text)) return;
    if (_textIsCode(text)) return;
    if (_contextIsCode(node)) return;
    final String reason;
    if (_inUiPlace(node)) {
      reason = 'ui';
    } else if (_sentenceLike(text)) {
      reason = 'sentence';
    } else {
      return;
    }
    final line = lines.getLocation(node.offset).lineNumber;
    found.add(
      FlaggedLiteral(
        path: path,
        line: line,
        text: text.replaceAll(_placeholder, '{}'),
        reason: reason,
      ),
    );
  }

  static bool _textIsCode(String text) {
    final t = text.trim();
    if (t.contains('://') || t.startsWith('mailto:')) return true;
    if (t.startsWith('assets/') || t.startsWith('packages/')) return true;
    if (_host.hasMatch(t)) return true;
    if (RegExp(r'^#[0-9A-Fa-f]{3,8}$').hasMatch(t)) return true;
    if (!t.contains(RegExp(r'\s')) &&
        (t.startsWith('/') ||
            _snakeOrDotted.hasMatch(t) ||
            _kebab.hasMatch(t))) {
      return true;
    }
    return false;
  }

  static bool _sentenceLike(String text) {
    if (_codeChars.hasMatch(text)) return false;
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => _letters.hasMatch(w) && !_codeToken.hasMatch(w));
    return words.length >= 2;
  }

  /// The names a call is known by: `Text`, `Uri.https` gives Uri and
  /// https, `prefs.setString` gives setString.
  static Set<String> _calleeNames(AstNode? call) {
    if (call is InstanceCreationExpression) {
      final name = call.constructorName;
      return {name.type.name.lexeme, ?name.name?.name};
    }
    if (call is MethodInvocation) {
      final target = call.target;
      return {
        call.methodName.name,
        if (target is SimpleIdentifier) target.name,
        if (target is PrefixedIdentifier) target.identifier.name,
      };
    }
    return const {};
  }

  static bool _exemptCallee(Set<String> names) => names.any(
    (n) =>
        _exemptClasses.contains(n) ||
        _exemptMethods.contains(n) ||
        n.endsWith('Exception') ||
        n.endsWith('Error'),
  );

  /// Walks up from [node] through what keeps its text as it is
  /// (parentheses, a branch of `?:`, `??`, `+`, an interpolation, a switch
  /// expression's result, a list, `.toUpperCase()`): the node it lands in
  /// and the child it came from.
  static (AstNode, AstNode?) _anchor(AstNode node) {
    AstNode child = node;
    var parent = node.parent;
    while (parent != null) {
      final transparent = switch (parent) {
        ParenthesizedExpression() ||
        InterpolationExpression() ||
        StringInterpolation() ||
        AdjacentStrings() ||
        AsExpression() ||
        ListLiteral() => true,
        ConditionalExpression(:final condition) => child != condition,
        BinaryExpression(:final operator) =>
          operator.lexeme == '??' || operator.lexeme == '+',
        SwitchExpressionCase(:final expression) => child == expression,
        SwitchExpression() => child is SwitchExpressionCase,
        MethodInvocation(:final target, :final methodName) =>
          child == target && _transparentMethods.contains(methodName.name),
        _ => false,
      };
      if (!transparent) break;
      child = parent;
      parent = parent.parent;
    }
    return (child, parent);
  }

  bool _contextIsCode(AstNode node) {
    final (child, anchor) = _anchor(node);
    switch (anchor) {
      case MapLiteralEntry(:final key) when key == child:
        return true;
      case IndexExpression(:final index) when index == child:
        return true;
      case BinaryExpression(:final operator)
          when operator.lexeme == '==' || operator.lexeme == '!=':
        return true;
      case NamedExpression(:final name)
          when _exemptNames.contains(name.label.name):
        return true;
      case DartPattern() || SwitchCase():
        return true;
      default:
        break;
    }
    for (AstNode? up = node.parent; up != null; up = up.parent) {
      switch (up) {
        case Directive() ||
            Annotation() ||
            AssertStatement() ||
            AssertInitializer() ||
            ThrowExpression():
          return true;
        case MethodDeclaration(:final name) when name.lexeme == 'toString':
          return true;
        case InstanceCreationExpression() || MethodInvocation():
          if (_exemptCallee(_calleeNames(up))) return true;
        default:
          break;
      }
    }
    return false;
  }

  bool _inUiPlace(AstNode node) {
    final (child, anchor) = _anchor(node);
    switch (anchor) {
      case NamedExpression(:final name):
        final label = name.label.name;
        if (label == 'value') {
          final call = anchor.parent?.parent;
          return _calleeNames(call).contains('Semantics');
        }
        return _isUiName(label);
      case ArgumentList():
        final call = anchor.parent;
        if (call is EnumConstantArguments) return true;
        return _calleeNames(call).any(_uiPositional.contains);
      case DefaultFormalParameter(:final defaultValue, :final parameter)
          when defaultValue == child:
        final name = parameter.name?.lexeme;
        return name != null && _isUiName(name);
      case VariableDeclaration(:final initializer, :final name)
          when initializer == child:
        return _uiVariable.hasMatch(name.lexeme);
      default:
        return false;
    }
  }
}
