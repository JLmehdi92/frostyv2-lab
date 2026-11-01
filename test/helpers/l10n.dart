import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/theme.dart';

/// The French locale, for tests.
const fr = Locale('fr');

/// The English locale, for tests.
const en = Locale('en');

var _interLoaded = false;

/// Loads the bundled Inter faces under the family the app asks for, so
/// text is measured (and drawn, in screenshots) as on a device: tests
/// otherwise lay text out in a test font whose letters are all the same
/// width, which hides French running longer than English.
Future<void> loadInter() async {
  if (_interLoaded) return;
  final loader = FontLoader(OnsetTokens.bodyFamily);
  final faces = Directory(
    'assets/fonts',
  ).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'));
  for (final face in faces) {
    final bytes = face.readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
  _interLoaded = true;
}

/// Shows [locale] for the rest of the test, as LocaleSync does in the app
/// ([L10n.current], `Intl.defaultLocale`), and puts both back after it.
Future<void> useLocale(Locale locale) async {
  final previousIntl = Intl.defaultLocale;
  final previous = Locale(L10n.current.localeName);
  addTearDown(() {
    L10n.use(previous);
    Intl.defaultLocale = previousIntl;
  });
  await initializeDateFormatting(locale.languageCode);
  L10n.use(locale);
}

/// Pumps [child] in an app showing [locale] (French by default), in a
/// [size] window with text scaled by [textScale], in the real Inter font.
///
/// [wrap] puts the app under what the child needs (providers). Nothing
/// leaks into the next test: the window, [L10n] and `Intl.defaultLocale`
/// are put back.
Future<void> pumpLocalized(
  WidgetTester tester,
  Widget child, {
  Locale locale = fr,
  Size size = const Size(390, 844),
  double textScale = 1,
  ThemeMode themeMode = ThemeMode.dark,
  Widget Function(Widget app)? wrap,
  NavigatorObserver? observer,
}) async {
  await tester.runAsync(loadInter);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await useLocale(locale);
  final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
  final app = MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: themes.light,
    darkTheme: themes.dark,
    themeMode: themeMode,
    navigatorObservers: [?observer],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: child,
  );
  await tester.pumpWidget(wrap?.call(app) ?? app);
}

/// The English texts the screen shows while it should be in French: every
/// drawn text, and every label a screen reader reads (`Semantics` labels,
/// values and hints, `Tooltip` messages), equal to an English message that
/// French words differently.
///
/// A message matches on its fixed text around its placeholders, in any case
/// (labels are also shown in capitals); a message with plurals or selects
/// matches on each combination of its branches, wherever they sit in it.
///
/// A text is no leak when the French of the same message also gives it (in
/// any case), or when it is exactly, case included, a French text of any
/// message ("LIVE", the badge, is no leak of "Live", the tab). An English
/// message that French also uses as is, case included (the endonym
/// "English"), is not looked for.
///
/// A text is also read in pieces, since screens compose: each piece
/// between separators (`·`, a dash, a colon, a comma, a sentence's end, a
/// line break, a bullet, brackets and quotes, a double space: "2 445
/// spectateurs · Offline", "Prediction, Qui gagne ?", "Passage au lecteur
/// web. Twitch refused this stream.", "« Offline »"), and each span of a
/// `Text.rich` (a stats row's label beside its value). A piece is a leak
/// when it is a whole English message of two words or five letters at
/// least that French words differently, and that no French message holds
/// as is ([_pieceChecks]): a short word French shares ("Message",
/// "Points") cannot be told apart, and stays unchecked.
///
/// A text is also caught when it holds an English message of two words and
/// eight letters at least that French never uses, inside French words with
/// no separator around it ("Vous devez Log in to whisper"), and when it
/// holds an English command word between brackets (`<color>`, `[reason]`
/// in a French help line).
///
/// [content] is what the test put on screen as Twitch's or viewers' own
/// words (a chat message, an IRC NOTICE kept as Twitch sends it, a stream
/// title): never translated, so never a leak. Each is taken out of the
/// texts it shows in before they are read, the rest of the line still
/// checked ("bob: Reconnect", with "Reconnect" a viewer's message, leaves
/// "bob: "). An item that is an English message of the app
/// ([isAppEnglish]) fails the test: passed as content, it would hide that
/// very leak.
List<String> englishLeaks(
  WidgetTester tester, {
  Iterable<String> content = const [],
}) {
  final words = [
    for (final text in content)
      if (text.trim().isNotEmpty) text,
  ]..sort((a, b) => b.length.compareTo(a.length));
  for (final text in words) {
    if (isAppEnglish(text)) {
      fail(
        '"$text" is an English message of the app, not Twitch\'s or '
        'viewers\' words: it cannot be passed as content.',
      );
    }
  }
  String? app(String text) {
    var rest = text;
    for (final piece in words) {
      rest = rest.replaceAll(piece, '\n');
    }
    return RegExp(r'\p{L}{2}', unicode: true).hasMatch(rest) ? rest : null;
  }

  return [
    for (final text in shownTexts(tester))
      if (app(text) case final shown? when _isEnglishLeak(shown)) text,
    for (final (:whole, :piece) in _spanPieces(tester, app))
      if (app(whole) case final shown?
          when !_isEnglishLeak(shown) && _isEnglishPiece(piece.trim()))
        '$whole [$piece]',
  ];
}

/// Whether [text] is, whole and in any case, an English message of the
/// app with no placeholder (or one branch of its plurals and selects) that
/// French words differently: never Twitch's or viewers' own words.
/// (Twitch's own sentences may hold an app's words, « slow mode » in its
/// NOTICE, or end like a message with a placeholder, « 30 seconds »: only
/// a whole fixed message tells the app's text apart.)
bool isAppEnglish(String text) =>
    !_leakChecks.frenchValues.contains(text) &&
    _englishFixed.contains(text.trim().toLowerCase());

/// Every English message and branch with no placeholder, lower case
/// ([isAppEnglish]).
final Set<String> _englishFixed = () {
  final english =
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, Object?>;
  return {
    for (final MapEntry(:key, :value) in english.entries)
      if (!key.startsWith('@') && value is String)
        for (final variant in _variants(value))
          if (!variant.contains(_hole) && variant.trim().isNotEmpty)
            variant.trim().toLowerCase(),
  };
}();

/// Whether [text], shown on a French screen, is English (see
/// [englishLeaks]), whole or in a piece. Worked out once per text: the
/// screens show the same texts at every scroll step.
bool _isEnglishLeak(String text) => _leakVerdicts.putIfAbsent(
  text,
  () =>
      _findsEnglish(text, _leakChecks.checks, _leakChecks.anyEnglish) ||
      textPieces(
        text,
      ).any((piece) => piece != text && _isEnglishPiece(piece)) ||
      _holdsEnglish(text),
);

/// Whether [text] holds, inside other words, an English message French
/// never uses, or an English command word between brackets
/// ([englishLeaks]).
bool _holdsEnglish(String text) {
  if (_leakChecks.frenchValues.contains(text)) return false;
  if (_leakChecks.anyInline?.hasMatch(text) ?? false) return true;
  for (final match in _bracketed.allMatches(text)) {
    final word = (match[1] ?? match[2])!.trim().toLowerCase();
    if (_leakChecks.commandWords.contains(word)) return true;
  }
  return false;
}

/// A word between angle or square brackets (`<color>`, `[reason]`): what a
/// command's usage asks for.
final _bracketed = RegExp(r'<([^<>\n]{2,30})>|\[([^\[\]\n]{2,30})\]');

final _leakVerdicts = <String, bool>{};

/// Whether [piece], a part of a longer text, is an English message
/// ([englishLeaks]).
bool _isEnglishPiece(String piece) => _pieceVerdicts.putIfAbsent(
  piece,
  () => _findsEnglish(piece, _leakChecks.pieceChecks, _leakChecks.anyPiece),
);

final _pieceVerdicts = <String, bool>{};

bool _findsEnglish(String text, List<_LeakCheck> checks, RegExp? any) {
  if (any == null || _leakChecks.frenchValues.contains(text)) return false;
  // Most texts match no English message: one pass over all of them first.
  if (!any.hasMatch(text)) return false;
  return checks.any(
    (check) =>
        check.english.any((pattern) => pattern.hasMatch(text)) &&
        !check.french.any((pattern) => pattern.hasMatch(text)),
  );
}

/// Where [textPieces] cuts a text: `·`, a dash, a colon, a comma, a
/// semicolon, a sentence's end before a space, a line break, a bullet,
/// brackets, quotes, a vertical bar, two spaces or more.
final _pieceSeparators = RegExp(
  r'\s*[·•|—–:,;()\[\]«»“”"\n]\s*|[.!?…]\s+|[\s\u00a0\u202f]{2,}',
);

/// The pieces of [text] [englishLeaks] reads apart: cut at
/// [_pieceSeparators], trimmed of spaces and closing marks, each with two
/// letters at least.
List<String> textPieces(String text) => [
  for (final raw in text.split(_pieceSeparators))
    if (raw.replaceAll(RegExp(r'^[\s\u00a0\u202f.!?…]+|[\s\u00a0\u202f]+$'), '')
        case final piece
        when RegExp(r'\p{L}{2}', unicode: true).hasMatch(piece))
      piece,
];

/// Each span of each `Text.rich` that has several ([englishLeaks]), with
/// the whole text it is in; [app] is what of a span the app wrote (the
/// content taken out), null for nothing.
Iterable<({String whole, String piece})> _spanPieces(
  WidgetTester tester,
  String? Function(String text) app,
) sync* {
  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    final spans = <String>[];
    widget.text.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span.text!);
      return true;
    });
    if (spans.length < 2) continue;
    final whole = widget.text.toPlainText();
    for (final span in spans) {
      final written = app(span);
      if (written == null) continue;
      for (final piece in textPieces(written)) {
        yield (whole: whole, piece: piece);
      }
    }
  }
}

typedef _LeakCheck = ({List<RegExp> english, List<RegExp> french});

/// The messages [englishLeaks] looks for, read once from the ARB files:
/// every one for whole texts ([checks], all in one in [anyEnglish]), and
/// those a piece of a text can be told by ([pieceChecks], in [anyPiece]).
final ({
  List<_LeakCheck> checks,
  List<_LeakCheck> pieceChecks,
  Set<String> frenchValues,
  RegExp? anyEnglish,
  RegExp? anyPiece,
  RegExp? anyInline,
  Set<String> commandWords,
})
_leakChecks = () {
  final english =
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, Object?>;
  final french =
      jsonDecode(File('lib/l10n/app_fr.arb').readAsStringSync())
          as Map<String, Object?>;
  final frenchValues = {
    for (final MapEntry(:key, :value) in french.entries)
      if (!key.startsWith('@') && value is String) ...[
        value,
        // A select's branches, each shown whole ("Activés").
        ..._variants(value).where((v) => !v.contains(_hole)),
      ],
  };
  // Every French text, lower case: an English piece found in it is a
  // word French uses too.
  final frenchCorpus = [
    for (final MapEntry(:key, :value) in french.entries)
      if (!key.startsWith('@') && value is String)
        ..._variants(value).map((v) => v.replaceAll(_hole, '\n')),
  ].join('\n').toLowerCase();
  bool inFrench(String words) => RegExp(
    '(?<![\\p{L}\\d])${RegExp.escape(words.toLowerCase())}(?![\\p{L}\\d])',
    unicode: true,
  ).hasMatch(frenchCorpus);

  final frenchLower = {for (final value in frenchValues) value.toLowerCase()};
  final checks = <_LeakCheck>[];
  final pieceChecks = <_LeakCheck>[];
  final inline = <String>{};
  final commandWords = <String>{};
  for (final MapEntry(:key, :value) in english.entries) {
    if (key.startsWith('@') || value is! String) continue;
    // Shown as is in French too (an endonym): it cannot be told apart.
    if (frenchValues.contains(value)) continue;
    // A word a command's usage shows between brackets ("color", "user").
    if (!value.contains('{') &&
        RegExp(r'^[a-z][a-z ]{1,28}$').hasMatch(value) &&
        !frenchLower.contains(value)) {
      commandWords.add(value);
    }
    // Fixed words of two or more and eight letters or more that no French
    // text holds: found inside any text.
    for (final variant in _variants(value)) {
      for (final part in variant.split(_hole)) {
        final words = part.replaceAll(
          RegExp(r'^[\s\p{P}]+|[\s\p{P}]+$', unicode: true),
          '',
        );
        if (RegExp(r'\p{L}+', unicode: true).allMatches(words).length >= 2 &&
            RegExp(r'\p{L}', unicode: true).allMatches(words).length >= 8 &&
            !inFrench(words)) {
          inline.add(words);
        }
      }
    }
    final englishPatterns = shownPatterns(value);
    if (englishPatterns.isEmpty) continue;
    final frenchPatterns = shownPatterns(french[key]! as String);
    checks.add((english: englishPatterns, french: frenchPatterns));
    final telling = [
      for (final variant in _variants(value))
        if (_tellsAPiece(variant, inFrench)) shownPatterns(variant),
    ].expand((patterns) => patterns).toList();
    if (telling.isNotEmpty) {
      pieceChecks.add((english: telling, french: frenchPatterns));
    }
  }
  RegExp? anyOf(List<_LeakCheck> checks) => checks.isEmpty
      ? null
      : RegExp(
          [
            for (final check in checks)
              for (final pattern in check.english) '(?:${pattern.pattern})',
          ].join('|'),
          caseSensitive: false,
          dotAll: true,
        );
  return (
    checks: checks,
    pieceChecks: pieceChecks,
    frenchValues: frenchValues,
    anyEnglish: anyOf(checks),
    anyPiece: anyOf(pieceChecks),
    anyInline: inline.isEmpty
        ? null
        : RegExp(
            '(?<![\\p{L}\\d])(?:${[for (final words in inline) words.split(RegExp(r'\s+')).map(RegExp.escape).join(r'[\s\u00a0]+')].join('|')})(?![\\p{L}\\d])',
            caseSensitive: false,
            unicode: true,
          ),
    commandWords: commandWords,
  );
}();

/// Whether a piece of a text that is [variant] (an English message's,
/// [_hole] for its placeholders) tells English: two words or five letters
/// of its own at least, and words French does not use as they are
/// ([inFrench] finds every fixed part of it in a French message:
/// "Message", "Points", "Notifications").
bool _tellsAPiece(String variant, bool Function(String words) inFrench) {
  final fixed = [
    for (final part in variant.split(_hole))
      if (part.replaceAll(RegExp(r'^[\s\p{P}]+|[\s\p{P}]+$', unicode: true), '')
          case final words when RegExp(r'\p{L}', unicode: true).hasMatch(words))
        words,
  ];
  if (fixed.isEmpty) return false;
  final joined = fixed.join(' ');
  final letters = RegExp(r'\p{L}', unicode: true).allMatches(joined).length;
  final words = RegExp(r'\p{L}+', unicode: true).allMatches(joined).length;
  if (letters < 5 && words < 2) return false;
  return !fixed.every(inFrench);
}

/// Every text [tester]'s screen shows a viewer: drawn text (with its
/// spans' screen-reader labels, and `SelectableText`), the texts of each
/// row read together (a number and its word drawn apart, "2 445" +
/// " watching"), and what a screen reader reads from `Semantics` (label,
/// value, hint, tooltip, attributed or not) and `Tooltip` (message).
Set<String> shownTexts(WidgetTester tester) => {
  for (final widget in tester.widgetList<RichText>(find.byType(RichText)))
    widget.text.toPlainText(),
  for (final widget in tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  ))
    ?(widget.data ?? widget.textSpan?.toPlainText()),
  ..._rowTexts(tester),
  for (final widget in tester.widgetList<Semantics>(find.byType(Semantics)))
    ...[
      widget.properties.label,
      widget.properties.value,
      widget.properties.hint,
      widget.properties.tooltip,
      widget.properties.hintOverrides?.onTapHint,
      widget.properties.hintOverrides?.onLongPressHint,
      widget.properties.increasedValue,
      widget.properties.decreasedValue,
      widget.properties.attributedLabel?.string,
      widget.properties.attributedValue?.string,
      widget.properties.attributedHint?.string,
      widget.properties.attributedIncreasedValue?.string,
      widget.properties.attributedDecreasedValue?.string,
      for (final action
          in widget.properties.customSemanticsActions?.keys ??
              const <CustomSemanticsAction>[])
        action.label,
    ].nonNulls.where((text) => text.trim().isNotEmpty),
  for (final widget in tester.widgetList<Tooltip>(find.byType(Tooltip)))
    ?(widget.message ?? widget.richMessage?.toPlainText()),
};

/// The text of each horizontal [Flex] (a `Row`) or [Wrap] drawing more
/// than one text: its texts in order, joined as they stand side by side. A
/// number and its word in two `Text`s ("2 445" and " watching") read as
/// one.
Iterable<String> _rowTexts(WidgetTester tester) sync* {
  for (final element
      in find.byWidgetPredicate((w) => w is Flex || w is Wrap).evaluate()) {
    final direction = switch (element.widget) {
      Flex(:final direction) || Wrap(:final direction) => direction,
      _ => Axis.vertical,
    };
    if (direction != Axis.horizontal) continue;
    final texts = <String>[];
    void visit(Element child) {
      if (child.widget case RichText(:final text)) {
        texts.add(text.toPlainText());
        return;
      }
      child.visitChildren(visit);
    }

    element.visitChildren(visit);
    if (texts.length > 1) yield texts.join();
  }
}

/// Punctuation a screen may add after a message: [shownPatterns] lets it
/// follow.
const _trailing = r'[\s.,;:!?…)»\u00a0\u202f]*';

/// Stands for a placeholder (or a plural's `#`) in [_variants].
const _hole = '\u{FFFC}';

/// What [message] can show, as patterns matching the whole text: each
/// combination of its plural and select branches ([_variants]), with each
/// placeholder as any text, and any closing punctuation added after it
/// ("Couldn't load clips." for "Couldn't load clips"). A variant with fewer than three letters of its
/// own around its placeholders ("{scale}x") cannot be told from the data it
/// shows, and gives no pattern.
List<RegExp> shownPatterns(String message) {
  final patterns = <RegExp>[];
  for (final variant in _variants(message)) {
    final fixed = variant.split(_hole);
    if (fixed.length > 1 &&
        RegExp(r'\p{L}', unicode: true).allMatches(fixed.join()).length < 3) {
      continue;
    }
    // Whatever the case: group labels and eyebrows are shown in capitals.
    patterns.add(
      RegExp(
        '^${fixed.map(RegExp.escape).join('.+')}$_trailing\$',
        caseSensitive: false,
        dotAll: true,
      ),
    );
  }
  return patterns;
}

/// The texts an ICU [message] can give: one per combination of the branches
/// of its plurals and selects, each placeholder and plural `#` written as
/// [_hole]. At most [limit] (a message is never near it).
List<String> _variants(String message, {int limit = 512}) {
  var results = <String>[''];
  void append(List<String> pieces) {
    results = [
      for (final head in results)
        for (final piece in pieces) head + piece,
    ];
    if (results.length > limit) {
      throw StateError('Too many variants in: $message');
    }
  }

  final text = StringBuffer();
  var i = 0;
  while (i < message.length) {
    final char = message[i];
    if (char != '{') {
      text.write(char);
      i++;
      continue;
    }
    final end = _closing(message, i);
    append([text.toString()]);
    text.clear();
    final inner = message.substring(i + 1, end);
    final choice = RegExp(
      r'^\s*\w+\s*,\s*(plural|select|selectordinal)\s*,',
    ).firstMatch(inner);
    if (choice == null) {
      append([_hole]);
    } else {
      final isPlural = choice.group(1) != 'select';
      final branches = <String>[];
      var j = choice.end;
      while (true) {
        final open = inner.indexOf('{', j);
        if (open < 0) break;
        final close = _closing(inner, open);
        var branch = inner.substring(open + 1, close);
        if (isPlural) branch = branch.replaceAll('#', _hole);
        branches.addAll(_variants(branch, limit: limit));
        j = close + 1;
      }
      append(branches);
    }
    i = end + 1;
  }
  append([text.toString()]);
  return results;
}

/// The index of the brace closing the one at [open] in [text].
int _closing(String text, int open) {
  var depth = 0;
  for (var i = open; i < text.length; i++) {
    if (text[i] == '{') depth++;
    if (text[i] == '}' && --depth == 0) return i;
  }
  throw FormatException('Unclosed brace', text, open);
}

/// The texts [tester]'s screen draws cut off without showing it: a
/// paragraph whose box is shorter than the lines it lays out (a banner of
/// fixed height under a two-line subtitle: the second line is cut in
/// half), even squeezed under a pixel; one that goes past its lines or its
/// width with nothing drawn to say so (`TextOverflow.clip`, the default);
/// and one whose lines an ancestor cuts off: a `ClipRect` (or rounded or
/// path clip) around an `OverflowBox` or an `Align` with a `heightFactor`
/// (what `SizeTransition` does), or a scroll view of fixed size that the
/// viewer cannot scroll. A text an ancestor hides whole (a collapsed
/// section) is not shown, so not cut. An ellipsis is visible, so a text
/// ending in one passes, unless its box is too short too
/// ([ellipsizedTexts] finds those where losing words is not acceptable).
///
/// Each is described with what it needs and what it has.
List<String> clippedTexts(WidgetTester tester) => [
  for (final element in find.byType(RichText).evaluate())
    if (element.renderObject case final RenderParagraph paragraph
        when paragraph.hasSize && paragraph.size.height > 0)
      ?(_clipOf(paragraph) ?? _ancestorClipOf(element, paragraph)),
];

String? _clipOf(RenderParagraph paragraph) {
  final size = paragraph.size;
  final text = paragraph.text.toPlainText();
  if (text.trim().isEmpty) return null;
  // The height its lines need at its width (within maxLines).
  final needed = paragraph.getMaxIntrinsicHeight(size.width);
  if (size.height + 0.5 < needed) {
    return '"$text": ${needed.toStringAsFixed(1)} px of lines in a '
        '${size.height.toStringAsFixed(1)} px box';
  }
  if (paragraph.overflow != TextOverflow.clip) return null;
  if (paragraph.didExceedMaxLines) {
    return '"$text": more than ${paragraph.maxLines} line(s), cut off with '
        'no ellipsis';
  }
  final wide = paragraph.getMaxIntrinsicWidth(double.infinity);
  if (!paragraph.softWrap && wide > size.width + 0.5) {
    return '"$text": ${wide.toStringAsFixed(1)} px wide in a '
        '${size.width.toStringAsFixed(1)} px box, cut off with no ellipsis';
  }
  return null;
}

/// Whether [text] is words (an icon is one private-use glyph).
final _hasWords = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// The first ancestor of [element]'s [paragraph] that cuts its lines off
/// in part ([clippedTexts]), described; null when none does.
String? _ancestorClipOf(Element element, RenderParagraph paragraph) {
  final text = paragraph.text.toPlainText();
  if (!_hasWords.hasMatch(text)) return null;
  // Where the lines are drawn: the glyphs, not the whole box.
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(
      baseOffset: 0,
      extentOffset: paragraph.text
          .toPlainText(includeSemanticsLabels: false)
          .length,
    ),
  );
  if (boxes.isEmpty) return null;
  var lines = boxes.first.toRect();
  for (final box in boxes.skip(1)) {
    lines = lines.expandToInclude(box.toRect());
  }
  // Within its own box (a line's trailing space may hang past it; a box
  // too short is _clipOf's).
  lines = lines.intersect(Offset.zero & paragraph.size);
  if (lines.width <= 0 || lines.height <= 0) return null;
  // Only what draws the paragraph: an overlay's content (a menu) has
  // elements under its anchor, its render objects elsewhere.
  final drawnBy = <RenderObject>{};
  for (
    RenderObject? node = paragraph.parent;
    node != null;
    node = node.parent
  ) {
    drawnBy.add(node);
  }
  String? found;
  void check(RenderBox clip, String what) {
    if (found != null || !clip.hasSize || !drawnBy.contains(clip)) return;
    final shown = MatrixUtils.transformRect(
      paragraph.getTransformTo(clip),
      lines,
    );
    final room = Offset.zero & clip.size;
    final kept = shown.intersect(room);
    // Hidden whole (a collapsed section): not on screen, not cut.
    if (kept.width <= 0.5 || kept.height <= 0.5) return;
    if (kept.height + 0.5 < shown.height || kept.width + 0.5 < shown.width) {
      found =
          '"$text": ${shown.width.toStringAsFixed(1)}×'
          '${shown.height.toStringAsFixed(1)} px of lines, '
          '${kept.width.toStringAsFixed(1)}×'
          '${kept.height.toStringAsFixed(1)} px left by $what';
    }
  }

  element.visitAncestorElements((ancestor) {
    // A section still opening or closing is cut for a moment only.
    if (ancestor.widget case SizeTransition(
      :final sizeFactor,
    ) when sizeFactor.isAnimating && drawnBy.contains(ancestor.renderObject)) {
      return false;
    }
    // In a list the viewer scrolls, what is cut is scrolled out of sight:
    // nothing above it is checked.
    if (ancestor case StatefulElement(:final ScrollableState state)
        when drawnBy.contains(state.context.findRenderObject()) &&
            state.position.hasContentDimensions &&
            state.position.physics.shouldAcceptUserOffset(state.position)) {
      return false;
    }
    final render = ancestor.renderObject;
    if (render is! RenderBox || identical(render, paragraph)) return true;
    switch (render) {
      case RenderClipRect(:final clipBehavior) ||
              RenderClipRRect(:final clipBehavior) ||
              RenderClipPath(:final clipBehavior) ||
              RenderClipOval(:final clipBehavior)
          when clipBehavior != Clip.none:
        check(
          render,
          'a ${render.runtimeType} (${ancestor.widget.runtimeType})',
        );
      case RenderAbstractViewport()
          when ancestor is StatefulElement && ancestor.state is ScrollableState:
        break;
      case RenderAbstractViewport():
        final scrollable = ancestor.findAncestorStateOfType<ScrollableState>();
        if (scrollable != null &&
            scrollable.position.hasContentDimensions &&
            !scrollable.position.physics.shouldAcceptUserOffset(
              scrollable.position,
            )) {
          check(render, 'a scroll view the viewer cannot scroll');
        }
    }
    return found == null;
  });
  return found;
}

/// The texts [tester]'s screen ends with an ellipsis: words lost where
/// losing them is not acceptable (a banner's subtitle, a countdown at the
/// end of a one-line bar, the channel's name in a placeholder). [within]
/// limits the search to part of the screen.
List<String> ellipsizedTexts(WidgetTester tester, {Finder? within}) => [
  for (final element
      in (within == null
              ? find.byType(RichText)
              : find.descendant(of: within, matching: find.byType(RichText)))
          .evaluate())
    if (element.renderObject case final RenderParagraph paragraph
        when paragraph.hasSize &&
            paragraph.overflow == TextOverflow.ellipsis &&
            (paragraph.didExceedMaxLines ||
                (!paragraph.softWrap &&
                    paragraph.getMaxIntrinsicWidth(double.infinity) >
                        paragraph.size.width + 0.5)))
      '"${paragraph.text.toPlainText()}" ends in an ellipsis',
];

/// The windows every French screen is checked in: two phones, a landscape
/// and a portrait tablet.
const frenchScreenSizes = [
  ('360x640', Size(360, 640)),
  ('390x844', Size(390, 844)),
  ('1280x854', Size(1280, 854)),
  ('854x1280', Size(854, 1280)),
];

/// The windows the channel screen's French surfaces are checked in: the
/// four above and a landscape phone.
const frenchChannelScreenSizes = [
  ...frenchScreenSizes,
  ('844x390', Size(844, 390)),
];

/// The text scales every French screen is checked at.
const frenchTextScales = [1.0, 1.3];

/// No overflow (nor any other exception), no English ([englishLeaks]) and
/// no text cut off without an ellipsis ([clippedTexts]) on what [tester]'s
/// screen shows, then on what each vertical list shows
/// when scrolled to its end. [where] names the screen in failures;
/// [content] is Twitch's or viewers' own words the screen shows
/// ([englishLeaks]).
Future<void> expectFrenchThroughout(
  WidgetTester tester,
  String where, {
  Iterable<String> content = const [],
}) async {
  void check(String step) {
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason:
          '$where, $step\n'
          '${exception is FlutterError ? exception.toStringDeep() : ''}',
    );
    expect(
      englishLeaks(tester, content: content),
      isEmpty,
      reason: '$where, $step',
    );
    expect(clippedTexts(tester), isEmpty, reason: '$where, $step');
  }

  check('at the top');
  final lists = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where((state) => state.axisDirection == AxisDirection.down)
      .toList();
  for (final (index, list) in lists.indexed) {
    var steps = 0;
    // A step can rebuild the page and drop a list (a feed's next page):
    // each step asks again whether it is still there.
    while (list.mounted &&
        list.position.pixels < list.position.maxScrollExtent &&
        steps++ < 80) {
      final position = list.position;
      position.jumpTo(
        math.min(
          position.maxScrollExtent,
          position.pixels + position.viewportDimension * 0.75,
        ),
      );
      await tester.pump();
      check('list $index, step $steps');
    }
  }
}

/// The parts of a [MaterialApp] that show [locale] (null: none, as the
/// English tests' bare apps) in the real Inter font with text at
/// [textScale]: call it before pumping, and pass what it gives to the app.
/// [builder] is the app's own builder, kept under the text scale.
Future<
  ({
    Locale? locale,
    List<Locale> supportedLocales,
    List<LocalizationsDelegate<Object?>>? delegates,
    TransitionBuilder? builder,
  })
>
localizedApp(
  WidgetTester tester, {
  Locale? locale,
  double textScale = 1,
  TransitionBuilder? builder,
}) async {
  if (locale == null) {
    return (
      locale: null,
      supportedLocales: const [Locale('en', 'US')],
      delegates: null,
      builder: builder,
    );
  }
  await tester.runAsync(loadInter);
  await useLocale(locale);
  return (
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    delegates: AppLocalizations.localizationsDelegates,
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: Builder(
        builder: (context) => builder?.call(context, child) ?? child!,
      ),
    ),
  );
}
