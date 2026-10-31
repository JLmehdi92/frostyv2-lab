import 'package:flutter_test/flutter_test.dart';

import 'arb.dart';

/// French typography in app_fr.arb (the rules of docs' style guide): narrow
/// no-break space (U+202F) before ; ! ? and %, no-break space (U+00A0)
/// before : and inside « », the curly apostrophe, the ellipsis character,
/// no space before . , …, no inclusive-writing dot, sentence case.
void main() {
  group('the checker', () {
    test('accepts well-set French', () {
      for (final message in [
        'Bienvenue !',
        'Compte connecté : {name}',
        'Un problème ? Réessayez.',
        '50 %',
        'Il est 14:05',
        'Durée {minutes}:{seconds}',
        'Le mode «\u00A0lent\u00A0» est actif',
        'L’app d’ONSET pour Twitch',
        'Encore quelques réglages…',
        'Connectez-vous avec Twitch',
        'Le Hype Train de Twitch',
        'Non connecté · vous pourrez vous connecter plus tard',
        'Changez-la dans Paramètres › Général, depuis l’onglet Profil',
        'La rubrique «\u00A0Autres\u00A0» des paramètres',
        '{count, plural, one{# chaîne} other{# chaînes}}',
      ]) {
        expect(frenchTypographyProblems(message), isEmpty, reason: message);
      }
    });

    test('catches each mistake', () {
      for (final message in [
        'Bienvenue !',
        'Bienvenue!',
        'Compte : {name}',
        'Compte: {name}',
        '50 %',
        'Pourquoi ?',
        'Le mode «lent» est actif',
        'Le mode « lent » est actif',
        "L'app",
        'Le mode "lent"',
        'Encore quelques réglages...',
        'Fin .',
        'Un  espace double',
        ' Espace au début',
        'Espace à la fin ',
        'La 2ème fois',
        'Connecté·e',
        'Points de Chaîne',
        'Dans les Paramètres de la Chaîne',
        '{count, plural, one{# chaîne!} other{# chaînes}}',
      ]) {
        expect(frenchTypographyProblems(message), isNotEmpty, reason: message);
      }
    });
  });

  test('app_fr.arb is well set', () {
    final fr = readArb(frArbPath);
    final keys = messageKeys(fr);
    expect(keys, isNotEmpty);
    final problems = [
      for (final key in keys)
        for (final problem in frenchTypographyProblems(fr[key]! as String))
          '$key: $problem',
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}

/// Names and words that keep their capital inside a French sentence.
const _properNouns = {
  'Twitch',
  'ONSET',
  'Hype',
  'Train',
  'Kappa',
  'Bits',
  'Prime',
  'Gaming',
  'Turbo',
  'BetterTTV',
  'FrankerFaceZ',
  'Firebase',
  'Crashlytics',
  'GitHub',
  'Android',
  'Wi-Fi',
  'Amazon',
  'Inter',
  'English',
  'Français',
  'Language',
  'Langue',
};

/// The app's screens and sections, named as their titles read (« dans
/// Paramètres › Général », « l’onglet Profil »).
const _screenNames = {
  'Accueil',
  'Parcourir',
  'Activité',
  'Profil',
  'Paramètres',
  'Général',
  'Autres',
};

final _letter = RegExp(r'\p{L}', unicode: true);
final _upper = RegExp(r'^\p{Lu}', unicode: true);
final _allCaps = RegExp(r'^[\p{Lu}\d\W]+$', unicode: true);

/// What is wrong with the French [message] (an ICU message from the ARB).
List<String> frenchTypographyProblems(String message) {
  final problems = <String>[];
  if (message.trim() != message) problems.add('space at an edge');
  final IcuMessage icu;
  try {
    icu = IcuMessage.parse(message);
  } on FormatException catch (e) {
    return ['not ICU: ${e.message}'];
  }
  for (final run in icu.texts) {
    problems.addAll(_runProblems(run));
  }
  return problems;
}

List<String> _runProblems(String run) {
  final problems = <String>[];
  for (var i = 0; i < run.length; i++) {
    final char = run[i];
    final before = i > 0 ? run[i - 1] : '';
    final after = i + 1 < run.length ? run[i + 1] : '';
    if (';!?%'.contains(char) &&
        before != ' ' &&
        !(char != '%' && '!?'.contains(before) && before.isNotEmpty)) {
      problems.add('"$char" needs a narrow no-break space (U+202F) before');
    }
    if (char == ':' && before != ' ') {
      final timeLike =
          RegExp(r'[\dX]').hasMatch(before) && RegExp(r'[\dX]').hasMatch(after);
      if (!timeLike) {
        problems.add('":" needs a no-break space (U+00A0) before');
      }
    }
    if (char == '«' && after != ' ') {
      problems.add('"«" needs a no-break space (U+00A0) after');
    }
    if (char == '»' && before != ' ') {
      problems.add('"»" needs a no-break space (U+00A0) before');
    }
  }
  if (run.contains("'")) problems.add('straight apostrophe: use ’');
  if (run.contains('"')) problems.add('straight quotes: use « »');
  if (run.contains('...')) problems.add('three dots: use …');
  if (run.contains('  ')) problems.add('double space');
  if (RegExp(r'\s[.,…]').hasMatch(run)) problems.add('space before . , or …');
  if (RegExp(r'\d\s?i?[eè]me').hasMatch(run)) {
    problems.add('"2ème": write 2e, 3e');
  }
  if (RegExp(r'\p{L}·\p{L}', unicode: true).hasMatch(run)) {
    problems.add('inclusive-writing dot: rephrase');
  }
  problems.addAll(_titleCaseProblems(run));
  return problems;
}

/// A capital inside a sentence, on a word that is no name: Title Case.
List<String> _titleCaseProblems(String run) {
  final tokens = run.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  final problems = <String>[];
  var sentenceStart = true;
  var quoted = false;
  for (final token in tokens) {
    if (token.startsWith('«') || token.startsWith('“')) quoted = true;
    final word = token.replaceAll(RegExp(r'^[«“(]+|[»”),.!?;:…]+$'), '');
    final hasLetters = _letter.hasMatch(word);
    if (hasLetters && !sentenceStart && word != 'X') {
      final named =
          _properNouns.contains(word) ||
          _screenNames.contains(word) ||
          quoted ||
          _properNouns.contains(word.split('’').first) ||
          RegExp(r'\d').hasMatch(word) ||
          (word.length > 1 && _allCaps.hasMatch(word));
      if (_upper.hasMatch(word) && !named) {
        problems.add('Title Case "$word": French titles are sentence case');
      }
    }
    if (hasLetters || word == 'X') sentenceStart = false;
    if (token.contains('»') || token.contains('”')) quoted = false;
    if (RegExp(r'[.!?…]$').hasMatch(token) ||
        const {'·', '—', '–', '›'}.contains(token)) {
      sentenceStart = true;
    }
  }
  return problems;
}
