import 'dart:io';

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
        'Voir https://www.twitch.tv/jltomy ou twitch.tv',
        'Le live\u00A0– sans pub\u00A0– reprend',
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
        'Bienvenue\u202F!Encore',
        'Pourquoi\u202F?Parce que',
        'Compte\u00A0:Viewer',
        'Bienvenue \u202F!',
        'Compte\u00A0 : nom',
        'Lʼapp',
        'L‘app',
        'L`app',
        'L′app',
        'Le live — sans pub — reprend',
        'Le live – sans pub – reprend',
        '{count, plural, one{# chaîne!} other{# chaînes}}',
      ]) {
        expect(frenchTypographyProblems(message), isNotEmpty, reason: message);
      }
    });
  });

  test('assets/release-notes.fr.md is well set', () {
    final lines = File('assets/release-notes.fr.md').readAsLinesSync();
    final texts = [for (final line in lines) ?frenchNotesText(line)];
    // The notes are read: a version, its date, sections and points.
    expect(texts, contains('29 octobre 2026'));
    expect(texts.length, greaterThan(8));
    final problems = [
      for (final text in texts)
        for (final problem in frenchTypographyProblems(text))
          '$problem in: $text',
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('the notes\' lines are read as French text, Markdown aside', () {
    expect(frenchNotesText('<!-- Note pour qui écrit -->'), isNull);
    expect(frenchNotesText('---'), isNull);
    expect(frenchNotesText('## v1.0.0'), isNull);
    expect(frenchNotesText('   '), isNull);
    expect(frenchNotesText('### Nouveautés'), 'Nouveautés');
    expect(
      frenchNotesText('- [Android] **Lecteur :** les lives'),
      'Lecteur : les lives',
    );
    expect(
      frenchNotesText('  - Dans `Paramètres › Vidéo` pour'),
      'Dans Paramètres › Vidéo pour',
    );
    // And a fault in them is caught.
    expect(
      frenchTypographyProblems(frenchNotesText("- l'accueil : ici")!),
      isNotEmpty,
    );
  });

  test('app_fr.arb is well set', () {
    final fr = readArb(frArbPath);
    final keys = messageKeys(fr);
    expect(keys, isNotEmpty);
    final problems = [
      for (final key in keys)
        for (final problem in frenchTypographyProblems(fr[key]! as String))
          if (!(_titleCaseKept.containsKey(key) &&
              problem.startsWith('Title Case')))
            '$key: $problem',
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('every key excused from sentence case still needs it', () {
    final fr = readArb(frArbPath);
    for (final key in _titleCaseKept.keys) {
      expect(
        frenchTypographyProblems(
          fr[key]! as String,
        ).where((p) => p.startsWith('Title Case')),
        isNotEmpty,
        reason: '$key no longer needs _titleCaseKept',
      );
    }
  });
}

/// Values that keep a capital the checker reads as Title Case, by key, with
/// the reason.
const _titleCaseKept = {
  'chatModActionWithReason':
      'line is a sentence of its own, with its full stop: « Motif » starts '
      'the next one.',
};

/// Names and words that keep their capital inside a French sentence.
const _properNouns = {
  'AutoMod',
  'Twitch',
  'ONSET',
  'Hype',
  'Train',
  'Trains',
  'Kappa',
  'Bits',
  'Bit',
  'Prime',
  'Gaming',
  'Turbo',
  'Drop',
  'Drops',
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
  'Internet',
  'WebView',
  // Android's French name for the floating video window.
  'Picture-in-picture',
  // The megabyte's symbol (« 38,0 Mo »), the megabit per second's.
  'Mo',
  'Mbit/s',
  // Twitch's own playful word for a clip being made.
  'Clipperino',
  // A Twitch name colour named after the Dodgers (« Bleu Dodger »).
  'Dodger',
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
  // Home's tabs.
  'Suivis',
  'Clips',
};

/// Names of several words, cited as they read on screen (« les onglets En
/// direct et Chaînes en direct », « la rubrique À propos »), and the
/// design's name: their capitals are no Title Case.
const _namesOfWords = [
  'Chaînes en direct',
  'En direct',
  'À propos',
  'Noir & Signal',
];

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

const _nnbsp = ' ';
const _nbsp = ' ';

/// URLs and hosts are left alone (their `:` and `/` are not French
/// punctuation).
final _url = RegExp(r'\S+://\S*|\b[a-z0-9-]+(?:\.[a-z0-9-]+)+\.[a-z]{2,}\b');

List<String> _runProblems(String text) {
  final run = text.replaceAll(_url, 'X');
  final problems = <String>[];
  for (var i = 0; i < run.length; i++) {
    final char = run[i];
    final before = i > 0 ? run[i - 1] : '';
    final after = i + 1 < run.length ? run[i + 1] : '';
    if (';!?%'.contains(char) &&
        before != _nnbsp &&
        !(char != '%' && '!?'.contains(before) && before.isNotEmpty)) {
      problems.add('"$char" needs a narrow no-break space (U+202F) before');
    }
    if (char == ':' && before != _nbsp) {
      final timeLike =
          RegExp(r'[\dX]').hasMatch(before) && RegExp(r'[\dX]').hasMatch(after);
      if (!timeLike) {
        problems.add('":" needs a no-break space (U+00A0) before');
      }
    }
    if (char == '«' && after != _nbsp) {
      problems.add('"«" needs a no-break space (U+00A0) after');
    }
    if (char == '»' && before != _nbsp) {
      problems.add('"»" needs a no-break space (U+00A0) before');
    }
  }
  // After ! ? ; : (not a time) and », a space before the next word.
  if (RegExp(r'[!?;»]\p{L}', unicode: true).hasMatch(run) ||
      RegExp(r'(?<![\dX]):\p{L}', unicode: true).hasMatch(run)) {
    problems.add('no space after ! ? ; : or »');
  }
  // A no-break space beside an ordinary one: one of them is wrong.
  if (RegExp('[ \t][$_nnbsp$_nbsp]|[$_nnbsp$_nbsp][ \t]').hasMatch(run)) {
    problems.add('an ordinary space next to a no-break one');
  }
  if (run.contains("'")) problems.add('straight apostrophe: use ’');
  if (RegExp('[ʼ‘′`]').hasMatch(run)) {
    problems.add('wrong apostrophe (ʼ ‘ ′ `): use ’');
  }
  if (run.contains('"')) problems.add('straight quotes: use « »');
  if (run.contains('...')) problems.add('three dots: use …');
  if (run.contains('  ')) problems.add('double space');
  if (RegExp(r'\s[.,…]').hasMatch(run)) problems.add('space before . , or …');
  // A dash between words: « – » after a no-break space, like everywhere
  // in the app (never the em dash).
  if (run.contains('—')) problems.add('em dash: use «$_nbsp– »');
  if (RegExp('[^$_nbsp]–\\s').hasMatch(run)) {
    problems.add('dash between words: write «$_nbsp– »');
  }
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
  var text = run;
  for (final name in _namesOfWords) {
    text = text.replaceAll(name, 'X');
  }
  final tokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
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

/// The French text a line of release-notes.fr.md shows, Markdown taken out
/// (headings, bullets, [Android]/[iOS] tags, bold, code), or null for a line
/// that shows none (blank, a rule, an HTML comment, a version number).
String? frenchNotesText(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty ||
      trimmed == '---' ||
      trimmed.startsWith('<!--') ||
      RegExp(r'^## v?\d').hasMatch(trimmed)) {
    return null;
  }
  final text = trimmed
      .replaceFirst(RegExp(r'^#+\s*'), '')
      .replaceFirst(RegExp(r'^[-*]\s+'), '')
      .replaceFirst(RegExp(r'^\[(Android|iOS)\]\s*'), '')
      .replaceAll('**', '')
      .replaceAll('`', '');
  return text.isEmpty ? null : text;
}
