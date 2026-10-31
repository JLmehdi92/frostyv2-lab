import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arb.dart';

/// Values that are the same in English and in French on purpose, by key.
/// An entry whose values differ is stale and fails.
const _sameInBothLanguages = {
  'languageNameEnglish': 'An endonym: English is always written "English".',
  'languageNameFrench': 'An endonym: French is always written "Français".',
  'languageChoiceSemantics': 'Bilingual on purpose, whatever is on screen.',
  'commonLiveBadge':
      'The badge word French viewers use as is; it fits its pill.',
  'onboardingPermissionChatTitle': '"Chat" is also the French word for it.',
  'onboardingPermissionClipsTitle': 'Twitch calls them "clips" in French.',
  'shellFeedClips': 'Twitch calls them "clips" in French.',
  'shellActivityNotifications': '"Notifications" is spelled the same.',
};

void main() {
  final en = readArb(enArbPath);
  final fr = readArb(frArbPath);
  final enKeys = messageKeys(en);
  final frKeys = messageKeys(fr);

  test('the files are read and hold messages', () {
    expect(en['@@locale'], 'en');
    expect(fr['@@locale'], 'fr');
    expect(enKeys, isNotEmpty);
  });

  test('French has the same keys as English, in the same order', () {
    expect(frKeys, enKeys);
  });

  test('French carries no metadata (English, the template, does)', () {
    expect(fr.keys.where((k) => k.startsWith('@') && k != '@@locale'), isEmpty);
  });

  test('every English message says where it shows', () {
    for (final key in enKeys) {
      final meta = en['@$key'];
      expect(meta, isA<Map<String, Object?>>(), reason: '@$key is missing');
      final description = (meta! as Map<String, Object?>)['description'];
      expect(description, isA<String>(), reason: '$key has no description');
      expect((description! as String).trim(), isNotEmpty, reason: key);
    }
    expect(
      en.keys.where(
        (k) =>
            k.startsWith('@') &&
            k != '@@locale' &&
            !en.containsKey(k.substring(1)),
      ),
      isEmpty,
      reason: 'metadata for a message that does not exist',
    );
  });

  test('no message is empty', () {
    for (final key in enKeys) {
      expect(en[key], isA<String>(), reason: key);
      expect((en[key]! as String).trim(), isNotEmpty, reason: 'en $key');
      expect(fr[key], isA<String>(), reason: key);
      expect((fr[key]! as String).trim(), isNotEmpty, reason: 'fr $key');
    }
  });

  test('every message is valid ICU', () {
    for (final key in enKeys) {
      for (final (lang, arb) in [('en', en), ('fr', fr)]) {
        expect(
          () => IcuMessage.parse(arb[key]! as String),
          returnsNormally,
          reason: '$lang $key',
        );
      }
    }
  });

  test('placeholders: declared, typed with an example, the same in French', () {
    for (final key in enKeys) {
      final english = IcuMessage.parse(en[key]! as String);
      final french = IcuMessage.parse(fr[key]! as String);
      final meta = en['@$key']! as Map<String, Object?>;
      final declared =
          (meta['placeholders'] as Map<String, Object?>?) ?? const {};
      expect(
        declared.keys.toSet(),
        english.arguments.toSet(),
        reason: '$key: declared placeholders differ from those used',
      );
      for (final MapEntry(key: name, value: spec) in declared.entries) {
        final placeholder = spec! as Map<String, Object?>;
        expect(placeholder['type'], isA<String>(), reason: '$key {$name}');
        expect(placeholder['example'], isNotNull, reason: '$key {$name}');
      }
      expect(
        french.arguments.toSet(),
        english.arguments.toSet(),
        reason: '$key: French uses other placeholders',
      );
    }
  });

  test('plurals: the same in both, with "other", and French "one"', () {
    for (final key in enKeys) {
      final english = IcuMessage.parse(en[key]! as String);
      final french = IcuMessage.parse(fr[key]! as String);
      expect(
        french.choices.keys.toSet(),
        english.choices.keys.toSet(),
        reason: key,
      );
      for (final MapEntry(key: name, value: choice)
          in english.choices.entries) {
        final frenchChoice = french.choices[name]!;
        expect(frenchChoice.kind, choice.kind, reason: '$key {$name}');
        expect(choice.selectors, contains('other'), reason: 'en $key');
        expect(frenchChoice.selectors, contains('other'), reason: 'fr $key');
        if (choice.kind == 'plural') {
          // French "one" is 0 and 1: "=1" alone would say "0 chaînes".
          expect(frenchChoice.selectors, contains('one'), reason: 'fr $key');
        }
      }
    }
  });

  test('French differs from English, except where it is the same word', () {
    final same = [
      for (final key in enKeys)
        if (en[key] == fr[key]) key,
    ];
    expect(
      same.where((k) => !_sameInBothLanguages.containsKey(k)),
      isEmpty,
      reason: 'untranslated, or missing from _sameInBothLanguages',
    );
    expect(
      _sameInBothLanguages.keys.where((k) => !same.contains(k)),
      isEmpty,
      reason: 'stale _sameInBothLanguages entries',
    );
  });

  group('the generated code is up to date', () {
    for (final (lang, arb) in [('en', en), ('fr', fr)]) {
      test('app_localizations_$lang.dart', () {
        final members = _generatedMembers(
          'lib/l10n/app_localizations_$lang.dart',
        );
        expect(
          members.keys.toSet(),
          enKeys.toSet(),
          reason: 'run flutter gen-l10n (or flutter pub get)',
        );
        for (final key in enKeys) {
          final message = IcuMessage.parse(arb[key]! as String);
          if (message.arguments.isNotEmpty) continue;
          expect(members[key], arb[key], reason: '$lang $key: regenerate');
        }
      });
    }

    test('the abstract class declares every message', () {
      final unit = parseString(
        content: File('lib/l10n/app_localizations.dart').readAsStringSync(),
      ).unit;
      final declared = {
        for (final declaration in unit.declarations)
          if (declaration is ClassDeclaration &&
              declaration.name.lexeme == 'AppLocalizations')
            for (final member in declaration.members)
              if (member is MethodDeclaration) member.name.lexeme,
      };
      expect(declared, containsAll(enKeys));
    });
  });
}

/// The members of the generated class in [path]: each getter with the
/// text it returns, each method (a message with placeholders) with null.
Map<String, String?> _generatedMembers(String path) {
  final unit = parseString(content: File(path).readAsStringSync()).unit;
  final members = <String, String?>{};
  for (final declaration in unit.declarations) {
    if (declaration is! ClassDeclaration) continue;
    for (final member in declaration.members) {
      if (member is! MethodDeclaration) continue;
      final body = member.body;
      final value =
          member.isGetter &&
              body is ExpressionFunctionBody &&
              body.expression is StringLiteral
          ? (body.expression as StringLiteral).stringValue
          : null;
      members[member.name.lexeme] = value;
    }
  }
  return members;
}
