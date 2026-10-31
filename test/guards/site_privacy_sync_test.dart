import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The privacy policy pages on onsetapp.app must say exactly what the
/// policies in the repository say: `site/privacy.html` mirrors `PRIVACY.md`
/// and `site/fr/privacy.html` mirrors `PRIVACY.fr.md`, word for word, and
/// their links go where the policies' links go.
///
/// Only the policy itself is compared: the text of the page's
/// `<article class="policy">` (tags dropped, entities decoded) against the
/// Markdown file's plain text (syntax dropped, link text kept), whitespace
/// collapsed on both sides. The top bar, language switch and footer sit
/// outside the article and are ignored. The contents block inside the article
/// is left out too, after checking that it only lists the section headings.
/// Nothing inside the article may be hidden (`hidden`, `style=`,
/// `aria-hidden`), so the compared text is the text a reader sees.
void main() {
  group('the guard', () {
    const markdown = '''
# Policy

**Effective date:** 1 May 2026

Text that wraps
over two lines, with `code`, a [link](https://example.com) and
https://example.org. Write to `me@example.com`; an address such as
`https://api.example.com` is only an example.

## 1. A section

- First item, **bold
  across lines**.
- Second item.

| What | Where |
|---|---|
| Tokens | Encrypted storage (`flutter_secure_storage`) |
| Images | |
''';

    const page = '''
<!doctype html><html lang="en"><body>
<header class="bar"><a href="/">ONSET</a></header>
<nav class="lang"><a href="/privacy">English</a> · <a href="/fr/privacy">Français</a></nav>
<article class="policy" id="policy" tabindex="-1">
<h1 id="policy-title">Policy</h1>
<p><strong>Effective date:</strong> 1 May 2026</p>
<p>Text that wraps over two lines, with <code>code</code>, a
<a href="https://example.com">link</a> and
<a href="https://example.org">https://example.org</a>. Write to
<a href="mailto:me@example.com">me@example.com</a>; an address such as
<code>https://api.example.com</code> is only an example.</p>
<details class="toc toc-m" id="contents"><summary>On this page<span aria-hidden="true">+</span></summary>
<nav><ol><li><a href="#a-section">1. A section</a></li></ol></nav></details>
<h2 id="a-section">1. A section</h2>
<ul><li>First item, <strong>bold across lines</strong>.</li>
<li>Second item.</li></ul>
<div class="tbl"><table><thead><tr><th>What</th><th>Where</th></tr></thead>
<tbody><tr><th scope="row">Tokens</th><td data-label="Where">Encrypted storage (<code>flutter_secure_storage</code>)</td></tr>
<tr><th scope="row">Images</th><td data-label="Where"></td></tr></tbody></table></div>
</article>
<footer class="foot">Privacy policy &middot; contact</footer>
</body></html>
''';

    test('reads the Markdown and the page alike, chrome left out', () {
      final md = markdownPlainText(markdown);
      final html = htmlPolicyText(page, 'page.html');
      expect(md, startsWith('Policy Effective date: 1 May 2026 Text that'));
      expect(html, isNot(contains('English')));
      expect(html, isNot(contains('ONSET')));
      expect(html, isNot(contains('On this page')));
      expect(firstDifference(md, html), isNull);
      expect(linkDifference(markdown, page, 'page.html'), isNull);
      expect(hiddenContent(page, 'page.html'), isEmpty);
      expect(tocProblems(page, 'page.html'), isEmpty);
    });

    test('finds a single changed word and names it', () {
      final md = markdownPlainText(markdown);
      final html = htmlPolicyText(
        page.replaceFirst('Second item.', 'Third item.'),
        'page.html',
      );
      final diff = firstDifference(md, html);
      expect(diff, isNotNull);
      expect(diff, contains('Second'));
      expect(diff, contains('Third'));
    });

    test('finds a dropped sentence and a dropped table row', () {
      final md = markdownPlainText(markdown);
      expect(
        firstDifference(
          md,
          htmlPolicyText(
            page.replaceFirst('<li>Second item.</li>', ''),
            'page.html',
          ),
        ),
        isNotNull,
      );
      expect(
        firstDifference(
          md,
          htmlPolicyText(
            page.replaceFirst(
              '<tr><th scope="row">Images</th><td data-label="Where"></td></tr>',
              '',
            ),
            'page.html',
          ),
        ),
        isNotNull,
      );
    });

    test(
      'finds a link that goes elsewhere, a missing one and an extra one',
      () {
        final retargeted = linkDifference(
          markdown,
          page.replaceFirst('mailto:me@example.com', 'mailto:you@example.net'),
          'page.html',
        );
        expect(retargeted, contains('mailto:me@example.com'));
        expect(retargeted, contains('mailto:you@example.net'));
        expect(
          linkDifference(
            markdown,
            page.replaceFirst(
              'href="https://example.org"',
              'href="https://x.y"',
            ),
            'page.html',
          ),
          contains('https://x.y'),
        );
        expect(
          linkDifference(
            markdown,
            page.replaceFirst(
              '<code>https://api.example.com</code>',
              '<a href="https://api.example.com">https://api.example.com</a>',
            ),
            'page.html',
          ),
          contains('https://api.example.com'),
        );
        expect(
          linkDifference(
            markdown,
            page.replaceFirst('<a href="https://example.com">link</a>', 'link'),
            'page.html',
          ),
          contains('https://example.com'),
        );
      },
    );

    test('refuses hidden content inside the article', () {
      for (final attribute in [
        'hidden',
        'style="display:none"',
        'aria-hidden="true"',
      ]) {
        expect(
          hiddenContent(
            page.replaceFirst('<li>Second item.</li>', '<li $attribute>X</li>'),
            'page.html',
          ),
          isNotEmpty,
          reason: attribute,
        );
      }
    });

    test('lets the contents block list only the section headings', () {
      expect(
        tocProblems(
          page.replaceFirst(
            '<li><a href="#a-section">1. A section</a></li>',
            '<li><a href="#a-section">1. A section</a></li>'
                '<li>Data is shared with partners.</li>',
          ),
          'page.html',
        ),
        isNotEmpty,
      );
      expect(
        tocProblems(
          page.replaceFirst(
            '<a href="#a-section">1. A section</a>',
            '<a href="https://example.net">1. A section</a>',
          ),
          'page.html',
        ),
        isNotEmpty,
      );
    });

    test('decodes entities', () {
      expect(
        htmlPolicyText(
          '<article class="policy"><p>A &amp; B &lt;c&gt; &#8250; '
              '&#x2019; &quot;d&quot; &nbsp;e</p></article>',
          'page.html',
        ),
        'A & B <c> › ’ "d" e',
      );
    });

    test('refuses a page without the policy article', () {
      expect(
        () => htmlPolicyText('<main><p>Nothing</p></main>', 'page.html'),
        throwsA(isA<StateError>()),
      );
    });
  });

  const pairs = {
    'PRIVACY.md': 'site/privacy.html',
    'PRIVACY.fr.md': 'site/fr/privacy.html',
  };

  for (final entry in pairs.entries) {
    test('${entry.value} says exactly what ${entry.key} says', () {
      final mdSource = File(entry.key).readAsStringSync();
      final htmlSource = File(entry.value).readAsStringSync();
      final md = markdownPlainText(mdSource);
      final html = htmlPolicyText(htmlSource, entry.value);

      // The guard must be looking at the whole policy, not an empty match.
      expect(md.length, greaterThan(10000), reason: entry.key);
      final headings = RegExp(
        r'^## ',
        multiLine: true,
      ).allMatches(mdSource.replaceAll('\r\n', '\n')).length;
      expect(headings, greaterThan(10), reason: entry.key);
      expect(
        RegExp(r'<h2\b').allMatches(policyBody(htmlSource, entry.value)),
        hasLength(headings),
        reason: '${entry.value} has a different number of sections',
      );
      expect(
        htmlLinkTargets(policyBody(htmlSource, entry.value)).length,
        greaterThan(10),
        reason: entry.value,
      );

      expect(hiddenContent(htmlSource, entry.value), isEmpty);
      expect(tocProblems(htmlSource, entry.value), isEmpty);
      final links = linkDifference(mdSource, htmlSource, entry.value);
      if (links != null) fail(links);
      final diff = firstDifference(md, html);
      if (diff != null) {
        fail(
          '${entry.value} no longer matches ${entry.key}. Mirror every '
          'change to the policy in the page.\n$diff',
        );
      }
    });
  }
}

/// Code spans the pages show as links, with their targets. Any other code
/// span, such as the example address `https://api.twitch.tv`, stays code.
const linkedCode = {
  'https://github.com/JLmehdi92/onset': 'https://github.com/JLmehdi92/onset',
  'PRIVACY.md': 'https://github.com/JLmehdi92/ONSET/blob/main/PRIVACY.md',
};

final _email = RegExp(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+');
final _bareUrl = RegExp(r'https?://[^\s<>()`|]+[^\s<>()`|.,;:]');
final _tocBlock = RegExp(
  r'<details\b[^>]*\bclass="[^"]*\btoc\b[^"]*"[^>]*>[\s\S]*?</details>',
);
final _anchor = RegExp(r'<a\b[^>]*?\bhref="([^"]*)"[^>]*>([\s\S]*?)</a>');

/// The link targets a Markdown file has once shown on GitHub, plus the
/// targets the page adds: `mailto:` for each address and [linkedCode].
List<String> markdownLinkTargets(String markdown) {
  final targets = <String>[];
  final text = markdown.replaceAll('\r\n', '\n');
  final code = RegExp(r'`([^`]+)`');
  var last = 0;
  void prose(String s) {
    s = s.replaceAllMapped(RegExp(r'!?\[[^\]]*\]\(([^)\s]+)[^)]*\)'), (m) {
      targets.add(m.group(1)!);
      return ' ';
    });
    s = s.replaceAllMapped(RegExp(r'<(https?://[^>]+)>'), (m) {
      targets.add(m.group(1)!);
      return ' ';
    });
    s = s.replaceAllMapped(_bareUrl, (m) {
      targets.add(m.group(0)!);
      return ' ';
    });
    targets.addAll(_email.allMatches(s).map((m) => 'mailto:${m.group(0)}'));
  }

  for (final m in code.allMatches(text)) {
    prose(text.substring(last, m.start));
    final span = m.group(1)!;
    if (linkedCode.containsKey(span)) {
      targets.add(linkedCode[span]!);
    } else if (_email.hasMatch(span) && _email.stringMatch(span) == span) {
      targets.add('mailto:$span');
    }
    last = m.end;
  }
  prose(text.substring(last));
  return targets;
}

/// The `href` of every link in a fragment, entities decoded.
List<String> htmlLinkTargets(String fragment) => _anchor
    .allMatches(fragment)
    .map((m) => decodeEntities(m.group(1)!))
    .toList();

/// Null when the article links to exactly the Markdown's targets (as a
/// multiset), otherwise the targets missing from the page and the extra ones.
String? linkDifference(String markdown, String html, String name) {
  final expected = markdownLinkTargets(markdown);
  final actual = htmlLinkTargets(policyBody(html, name));
  final missing = [...expected];
  final extra = <String>[];
  for (final href in actual) {
    if (!missing.remove(href)) extra.add(href);
  }
  if (missing.isEmpty && extra.isEmpty) return null;
  return '$name: its links no longer match the policy.\n'
      '  Missing from the page: ${missing.isEmpty ? 'none' : missing.join(', ')}\n'
      '  Not in the policy:     ${extra.isEmpty ? 'none' : extra.join(', ')}';
}

/// The opening tags inside the article (contents block left out) that hide
/// or restyle what they hold.
List<String> hiddenContent(String html, String name) => RegExp(
  r'<[a-zA-Z][^>]*\s(?:hidden|style|aria-hidden)\b[^>]*>',
  caseSensitive: false,
).allMatches(policyBody(html, name)).map((m) => m.group(0)!).toList();

/// What is wrong with the contents block inside the article, if any: it may
/// hold a short summary and links to the policy's own headings, labelled with
/// their exact text, each once and in order, and nothing else.
List<String> tocProblems(String html, String name) {
  final article = policyArticle(html, name);
  final blocks = _tocBlock.allMatches(article).toList();
  if (blocks.isEmpty) return [];
  if (blocks.length > 1) return ['$name: more than one contents block'];
  final block = blocks.single.group(0)!;
  final heads = RegExp(r'<h2\b[^>]*\bid="([^"]+)"[^>]*>([\s\S]*?)</h2>')
      .allMatches(article.replaceAll(_tocBlock, ' '))
      .map((h) => '#${h.group(1)} ${_visibleText(h.group(2)!)}')
      .toList();
  final links = _anchor
      .allMatches(block)
      .map((a) => '${a.group(1)} ${_visibleText(a.group(2)!)}')
      .toList();
  final problems = <String>[];
  if (links.join('\n') != heads.join('\n')) {
    problems.add(
      '$name: the contents block must list exactly the section headings, '
      'found:\n  ${links.join('\n  ')}',
    );
  }
  final summary = RegExp(r'<summary\b[\s\S]*?</summary>').firstMatch(block);
  if (summary != null && _visibleText(summary.group(0)!).length > 40) {
    problems.add('$name: the contents summary is too long to be a label');
  }
  final rest = _visibleText(
    block
        .replaceAll(_anchor, ' ')
        .replaceAll(RegExp(r'<summary\b[\s\S]*?</summary>'), ' '),
  );
  if (rest.isNotEmpty) {
    problems.add('$name: text in the contents block outside its links: $rest');
  }
  return problems;
}

/// The article without its contents block.
String policyBody(String html, String name) =>
    policyArticle(html, name).replaceAll(_tocBlock, ' ');

/// The inner HTML of the page's single `<article class="policy">`.
String policyArticle(String html, String name) {
  final matches = RegExp(
    r'<article\b[^>]*\bclass="[^"]*\bpolicy\b[^"]*"[^>]*>([\s\S]*?)</article>',
  ).allMatches(html).toList();
  if (matches.length != 1) {
    throw StateError(
      '$name: expected one <article class="policy">, found '
      '${matches.length}',
    );
  }
  return matches.single.group(1)!;
}

const _blockTags =
    'address|article|aside|blockquote|br|caption|dd|details|div|dl|dt|'
    'figcaption|figure|footer|h[1-6]|header|hr|li|main|nav|ol|p|pre|section|'
    'summary|table|tbody|td|tfoot|th|thead|tr|ul';

/// The visible text of the policy article: block tags become spaces, inline
/// tags vanish, entities are decoded and whitespace is collapsed.
String htmlPolicyText(String html, String name) =>
    _visibleText(policyBody(html, name));

String _visibleText(String fragment) {
  var s = fragment;
  s = s.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  s = s.replaceAll(
    RegExp('</?(?:$_blockTags)\\b[^>]*>', caseSensitive: false),
    ' ',
  );
  s = s.replaceAll(RegExp(r'<[^>]*>'), '');
  return _collapse(decodeEntities(s));
}

const _named = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'middot': '·',
  'rsaquo': '›',
  'laquo': '«',
  'raquo': '»',
  'mdash': '—',
  'ndash': '–',
  'rsquo': '’',
  'lsquo': '‘',
  'hellip': '…',
};

String decodeEntities(String s) => s.replaceAllMapped(
  RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);'),
  _decodeEntity,
);

String _decodeEntity(Match m) {
  final e = m.group(1)!;
  if (e.startsWith('#x') || e.startsWith('#X')) {
    return String.fromCharCode(int.parse(e.substring(2), radix: 16));
  }
  if (e.startsWith('#')) {
    return String.fromCharCode(int.parse(e.substring(1)));
  }
  final named = _named[e];
  if (named == null) {
    throw StateError('Unknown HTML entity &$e; - add it to the guard.');
  }
  return named;
}

/// The plain text of a Markdown file as GitHub shows it: headings, list
/// markers, table pipes and separator rows, bold, italics and code ticks are
/// dropped; link and image text is kept; whitespace is collapsed.
String markdownPlainText(String markdown) {
  final lines = <String>[];
  for (var line in markdown.replaceAll('\r\n', '\n').split('\n')) {
    if (RegExp(r'^\s*\|?[\s:|-]*-[\s:|-]*$').hasMatch(line) &&
        line.contains('|')) {
      continue;
    }
    line = line.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '');
    line = line.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '');
    if (line.trimLeft().startsWith('|')) {
      line = line.trim();
      line = line.substring(1);
      if (line.endsWith('|')) line = line.substring(0, line.length - 1);
      line = line.replaceAll('|', ' ');
    }
    lines.add(line);
  }
  final text = lines.join('\n');

  // Code spans are kept verbatim; the rest loses its inline syntax.
  final out = StringBuffer();
  final code = RegExp(r'`([^`]+)`');
  var last = 0;
  for (final m in code.allMatches(text)) {
    out
      ..write(_inline(text.substring(last, m.start)))
      ..write(m.group(1));
    last = m.end;
  }
  out.write(_inline(text.substring(last)));
  return _collapse(out.toString());
}

String _inline(String s) {
  s = s.replaceAllMapped(
    RegExp(r'!?\[([^\]]*)\]\([^)]*\)'),
    (m) => m.group(1)!,
  );
  s = s.replaceAllMapped(RegExp(r'<(https?://[^>]+)>'), (m) => m.group(1)!);
  s = s.replaceAll('**', '').replaceAll('__', '');
  s = s.replaceAllMapped(
    RegExp(r'(?<![\w*])\*(\S(?:[^*]*\S)?)\*(?![\w*])'),
    (m) => m.group(1)!,
  );
  s = s.replaceAllMapped(
    RegExp(r'(?<!\w)_(\S(?:[^_]*\S)?)_(?!\w)'),
    (m) => m.group(1)!,
  );
  s = s.replaceAllMapped(
    RegExp(r'\\([\\`*_{}\[\]()#+\-.!|])'),
    (m) => m.group(1)!,
  );
  return s;
}

String _collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Null when both texts are equal, otherwise where they first part ways,
/// with the surrounding words from each side.
String? firstDifference(String markdown, String html) {
  if (markdown == html) return null;
  final n = markdown.length < html.length ? markdown.length : html.length;
  var i = 0;
  while (i < n && markdown.codeUnitAt(i) == html.codeUnitAt(i)) {
    i++;
  }
  // Start the excerpt on a word boundary so the changed word reads whole.
  var start = i;
  while (start > 0 && markdown.codeUnitAt(start - 1) != 0x20) {
    start--;
  }
  start = start - 60 < 0 ? 0 : start - 60;
  String excerpt(String s) {
    final end = i + 80 > s.length ? s.length : i + 80;
    final prefix = start > 0 ? '...' : '';
    final suffix = end < s.length ? '...' : '';
    return '$prefix${s.substring(start, end)}$suffix';
  }

  final word = ' '.allMatches(markdown.substring(0, i)).length + 1;
  return 'First difference at character $i (word $word):\n'
      '  Markdown: ${excerpt(markdown)}\n'
      '  Page:     ${excerpt(html)}';
}
