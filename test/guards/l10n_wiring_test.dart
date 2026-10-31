import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app's `MaterialApp` (lib/main.dart) loads the translations, says
/// which languages it has, follows the language setting, resolves the
/// device's language, and keeps [L10n] in step (LocaleSync in its builder).
/// Without any of them the app would show English, or fail, in French.
void main() {
  const required = {
    'localizationsDelegates',
    'supportedLocales',
    'locale',
    'localeListResolutionCallback',
  };

  test('the checker sees a missing setting and a missing LocaleSync', () {
    const wired = '''
Widget build() => MaterialApp(
  locale: a,
  supportedLocales: b,
  localizationsDelegates: c,
  localeListResolutionCallback: (d, _) => e,
  builder: (context, child) => LocaleSync(child: child!),
);
''';
    expect(wiringProblems(wired, required), isEmpty);
    expect(wiringProblems(wired.replaceFirst('  locale: a,\n', ''), required), [
      'MaterialApp without locale:',
    ]);
    expect(
      wiringProblems(
        wired.replaceFirst('LocaleSync(child: child!)', 'child!'),
        required,
      ),
      ['MaterialApp.builder without LocaleSync'],
    );
    expect(wiringProblems('void main() {}', required), [
      'no MaterialApp found',
    ]);
  });

  test('lib/main.dart wires the localizations', () {
    expect(
      wiringProblems(File('lib/main.dart').readAsStringSync(), required),
      isEmpty,
    );
  });
}

/// What the `MaterialApp`s of [source] miss: one of [named], or LocaleSync
/// in their builder.
List<String> wiringProblems(String source, Set<String> named) {
  final finder = _MaterialApps();
  parseString(content: source, throwIfDiagnostics: false).unit.accept(finder);
  if (finder.found.isEmpty) return ['no MaterialApp found'];
  final problems = <String>[];
  for (final arguments in finder.found) {
    final names = {
      for (final argument in arguments.arguments)
        if (argument is NamedExpression) argument.name.label.name: argument,
    };
    for (final name in named) {
      if (!names.containsKey(name)) problems.add('MaterialApp without $name:');
    }
    final builder = names['builder']?.expression.toSource() ?? '';
    if (!builder.contains('LocaleSync(')) {
      problems.add('MaterialApp.builder without LocaleSync');
    }
  }
  return problems;
}

class _MaterialApps extends RecursiveAstVisitor<void> {
  final found = <ArgumentList>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && node.methodName.name == 'MaterialApp') {
      found.add(node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName;
    if (name.type.name.lexeme == 'MaterialApp' && name.name == null) {
      found.add(node.argumentList);
    }
    super.visitInstanceCreationExpression(node);
  }
}
