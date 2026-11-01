import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'arb.dart';

/// The English style of app_en.arb (docs/L10N.md, "English style guide"):
/// the curly apostrophe and quotes, the ellipsis character, "log in" (never
/// "sign in"), sentence case, and error messages that end as sentences.
void main() {
  group('the checker', () {
    test('accepts well-written English', () {
      for (final (message, description) in [
        ('Couldn’t load clips.', 'Error message. A list failed.'),
        ('Go to channel “{query}”', ''),
        ('Connecting to chat…', ''),
        ('Log in to chat, see followed streams, and more.', ''),
        ('Open Settings › General on Twitch', ''),
        ('Followers-only chat · must follow for {duration}', ''),
        ('Use /ban <user> [reason] to ban someone', ''),
        ('WHAT’S NEW IN {version}', ''),
        ('Shared Hype Train', ''),
        ('Golden Kappa Train starting!', ''),
        ('Paste the “auth-token” cookie from twitch.tv', ''),
        ('{count, plural, one{# clip} other{# clips}}', ''),
        (
          '{subject, select, clip{This clip is gone.} other{This video is '
              'gone.}}',
          'Error message. Over the player.',
        ),
        ('Couldn’t whisper (unexpected error).', 'Error message. Chat.'),
        ('Try again!', 'Error message. A retry.'),
        ('Ready?', 'Error message. A question.'),
      ]) {
        expect(
          englishStyleProblems(message, description: description),
          isEmpty,
          reason: message,
        );
      }
    });

    test('catches each mistake', () {
      for (final (message, description) in [
        ("Couldn't load clips.", ''),
        ('Couldn‘t load clips.', ''),
        ('Couldn`t load clips.', ''),
        ('Go to channel "{query}"', ''),
        ("Removed '{word}'", ''),
        ('Connecting to chat...', ''),
        ('Sign in to chat', ''),
        ('Twitch did not sign you in.', ''),
        ('Signing you in…', ''),
        ('You are signed in', ''),
        ('Edit Chat Filters', ''),
        ('Watch Streak Expiring', ''),
        ('Wi-Fi Only', ''),
        ('{count, plural, one{# Clip} other{# Clips}}', ''),
        ('Couldn’t load clips', 'Error message. A list failed.'),
        (
          '{subject, select, clip{This clip is gone.} other{This video is '
              'gone}}',
          'Error message. Over the player.',
        ),
        ('Couldn’t whisper: {reason}', 'Error message. Chat.'),
        ('Ends with a space ', ''),
        ('Two  spaces', ''),
      ]) {
        expect(
          englishStyleProblems(message, description: description),
          isNotEmpty,
          reason: message,
        );
      }
    });

    test('an error message ending with a sentence placeholder is listed', () {
      expect(
        englishStyleProblems(
          'Couldn’t whisper: {reason}',
          description: 'Error message. Chat.',
          endsWithSentence: true,
        ),
        isEmpty,
      );
    });
  });

  test('every key excused below is in app_en.arb and still needs it', () {
    final en = readArb(enArbPath);
    for (final key in [..._titleCaseKept.keys, ..._endsWithSentence.keys]) {
      expect(en.containsKey(key), isTrue, reason: '$key is not in app_en.arb');
    }
    for (final key in _titleCaseKept.keys) {
      final strict = englishStyleProblems(en[key]! as String);
      expect(
        strict.where((p) => p.startsWith('Title Case')),
        isNotEmpty,
        reason: '$key no longer needs _titleCaseKept',
      );
    }
    for (final key in _endsWithSentence.keys) {
      final description =
          (en['@$key']! as Map<String, Object?>)['description']! as String;
      expect(
        englishStyleProblems(en[key]! as String, description: description),
        isNotEmpty,
        reason: '$key no longer needs _endsWithSentence',
      );
    }
  });

  test('app_en.arb follows the English style', () {
    final en = readArb(enArbPath);
    final keys = messageKeys(en);
    expect(keys, isNotEmpty);
    var errors = 0;
    final problems = <String>[];
    for (final key in keys) {
      final description =
          (en['@$key']! as Map<String, Object?>)['description']! as String;
      if (description.startsWith('Error message.')) errors++;
      for (final problem in englishStyleProblems(
        en[key]! as String,
        description: description,
        titleCaseKept: _titleCaseKept.containsKey(key),
        endsWithSentence: _endsWithSentence.containsKey(key),
      )) {
        problems.add('$key: $problem');
      }
    }
    // The error rule must be looking at error messages.
    expect(errors, greaterThan(50));
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('assets/release-notes.md follows the English style', () {
    final lines = File('assets/release-notes.md').readAsLinesSync();
    final texts = [for (final line in lines) ?englishNotesText(line)];
    expect(texts, contains('October 29, 2026'));
    expect(texts.length, greaterThan(8));
    final problems = [
      for (final text in texts)
        for (final problem in englishStyleProblems(text)) '$problem in: $text',
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}

/// Values that keep a capital the checker reads as Title Case, by key, with
/// the reason.
const _titleCaseKept = {
  'channelWebFallback':
      'notice is a sentence of its own: "Switching" starts the next one.',
};

/// Error messages that end with a placeholder holding a full sentence of
/// its own (its punctuation included), by key, with the reason.
const _endsWithSentence = {
  'chatModFailed':
      'reason is a sentence (chatModNoUser, chatModCannotModerate, an API '
      'error) that ends the line with its own full stop.',
  'chatWhisperFailedBecause':
      'reason is an API error, worded as a sentence with its full stop.',
  'liveRefusedBecause':
      'reason is Twitch\'s own sentence, shown as Twitch wrote it.',
};

/// Names and words that keep their capital inside an English sentence.
const _properNouns = {
  'ONSET',
  'Twitch',
  'Hype',
  'Train',
  'Trains',
  'Meter',
  'Kappa',
  'Golden',
  'Treasure',
  'Community',
  'Mythic',
  'Shared',
  'Watch',
  'Streak',
  'Bits',
  'Bit',
  'Tier',
  'Prime',
  'Turbo',
  'AutoMod',
  'BetterTTV',
  'FrankerFaceZ',
  'Firebase',
  'GitHub',
  'Android',
  'iOS',
  'Amazon',
  'Wi-Fi',
  'WebView',
  'GIF',
  'GIFs',
  'Mbps',
  'English',
  'French',
  'Français',
  'Language',
  'Langue',
  'Noir',
  'Signal',
  // Option names, cited as they read on screen.
  'Standard',
  'Ultra',
  'Auto',
  'Full',
  'Subtle',
  // Twitch's chat colors, as the /color command takes them.
  'Blue',
  'Coral',
  'HotPink',
  // The two-factor sign-in's Android label, the policy and the PiP window.
  'Picture-in-picture',
};

/// The app's screens and sections, named as their titles read ("in
/// Settings › General", "from Profile").
const _screenNames = {
  'Home',
  'Browse',
  'Activity',
  'Profile',
  'Settings',
  'General',
  'Video',
  'Chat',
  'Other',
  'Following',
  'Live',
  'Clips',
  'Notifications',
  'About',
};

/// Names of several words cited as they read on screen: their capitals are
/// no Title Case.
const _namesOfWords = ['Live channels', 'Allow from this source'];

final _letter = RegExp(r'\p{L}', unicode: true);
final _upper = RegExp(r'^\p{Lu}', unicode: true);
final _allCaps = RegExp(r'^[\p{Lu}\d\W]+$', unicode: true);
final _signIn = RegExp(
  r'\bsign(?:s|ed|ing)?(?:[ -]?| (?:you|me|them|him|her|us) )(?:in|out)\b',
  caseSensitive: false,
);

/// What is wrong with the English [message] (an ICU message from the ARB).
/// [description] is its ARB description: an error message ("Error
/// message." in it) ends as a sentence. [titleCaseKept] and
/// [endsWithSentence] excuse a value listed above.
List<String> englishStyleProblems(
  String message, {
  String description = '',
  bool titleCaseKept = false,
  bool endsWithSentence = false,
}) {
  final problems = <String>[];
  if (message.trim() != message) problems.add('space at an edge');
  final IcuMessage icu;
  try {
    icu = IcuMessage.parse(message);
  } on FormatException catch (e) {
    return ['not ICU: ${e.message}'];
  }
  for (final run in icu.texts) {
    problems.addAll(_runProblems(run, titleCaseKept: titleCaseKept));
  }
  if (description.contains('Error message.') && !endsWithSentence) {
    problems.addAll(_errorEndProblems(message, icu));
  }
  return problems;
}

/// URLs and hosts are left alone.
final _url = RegExp(r'\S+://\S*|\b[a-z0-9-]+(?:\.[a-z0-9-]+)+\.[a-z]{2,}\b');

List<String> _runProblems(String text, {required bool titleCaseKept}) {
  final run = text.replaceAll(_url, 'X');
  final problems = <String>[];
  if (run.contains("'")) problems.add('straight apostrophe: use ’');
  if (RegExp('[ʼ‘′`]').hasMatch(run)) {
    problems.add('wrong apostrophe (ʼ ‘ ′ `): use ’');
  }
  if (run.contains('"')) problems.add('straight quotes: use “ ”');
  if (run.contains('...')) problems.add('three dots: use …');
  if (run.contains('  ')) problems.add('double space');
  if (_signIn.hasMatch(run)) problems.add('"sign in": write "log in"');
  if (!titleCaseKept) problems.addAll(_titleCaseProblems(run));
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
    if (token.startsWith('“') || token.startsWith('(“')) quoted = true;
    final word = token.replaceAll(RegExp(r'^[“(]+|[”),.!?;:…]+$'), '');
    final hasLetters = _letter.hasMatch(word);
    if (hasLetters && !sentenceStart && word != 'X') {
      final base = word.split('’').first;
      final named =
          _properNouns.contains(word) ||
          _properNouns.contains(base) ||
          _screenNames.contains(word) ||
          _screenNames.contains(base) ||
          quoted ||
          RegExp(r'\d').hasMatch(word) ||
          (word.length > 1 && _allCaps.hasMatch(word)) ||
          word.contains('X');
      if (_upper.hasMatch(word) && !named) {
        problems.add('Title Case "$word": English is sentence case');
      }
    }
    if (hasLetters || word == 'X') sentenceStart = false;
    if (token.contains('”')) quoted = false;
    if (RegExp(r'[.!?…:]$').hasMatch(token) ||
        const {'·', '—', '–', '›', '/', '+'}.contains(token)) {
      sentenceStart = true;
    }
  }
  return problems;
}

final _sentenceEnd = RegExp(r'[.!?…]$');

/// An error message ends with . ! ? or …: each branch when it ends with a
/// plural or select, and never with a bare placeholder.
List<String> _errorEndProblems(String message, IcuMessage icu) {
  final outer = icu.texts.last.trimRight();
  if (_sentenceEnd.hasMatch(outer)) return const [];
  if (!outer.endsWith('X')) {
    return ['error message: end it with a full stop'];
  }
  // The message ends with an argument: a choice's branches must each end
  // a sentence; a simple placeholder needs listing in _endsWithSentence.
  if (!message.trimRight().endsWith('}}')) {
    return ['error message ends with a placeholder: end it with a full stop'];
  }
  return [
    for (final branch in icu.texts.take(icu.texts.length - 1))
      if (!_sentenceEnd.hasMatch(branch.trimRight()))
        'error message: end the branch "$branch" with a full stop',
  ];
}

/// The English text a line of release-notes.md shows, Markdown taken out
/// (headings, bullets, [Android]/[iOS] tags, bold, code), or null for a line
/// that shows none (blank, a rule, an HTML comment, a version number).
String? englishNotesText(String line) {
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
