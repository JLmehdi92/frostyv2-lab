import 'dart:convert';
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
/// is left out too; it and the desktop contents list must list exactly the
/// section headings. The article may only use the few tags, attributes and
/// classes the page needs, so nothing in it can be hidden from the reader
/// while still counting as policy text.
///
/// The policies also name the app's settings and buttons, in bold, so a reader
/// can find them. Every bold run that is not declared as plain emphasis must be
/// a real label (each part of a "Settings › Other" path on its own): a value in
/// `lib/l10n/app_fr.arb` for the French policy; a value in
/// `lib/l10n/app_en.arb`, or a string literal in `lib/`, for the English one.
/// The English labels the French policy gives after its own
/// (« Share crash logs and analytics » en anglais) are held to the English rule.
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
<aside class="toc-col"><nav class="toc toc-d"><p class="toc-h">On this page</p>
<ol><li><a href="#a-section">1. A section</a></li></ol></nav></aside>
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
<div class="tbl tbl-2" role="region" tabindex="0" aria-label="What · Where"><table><thead><tr><th>What</th><th>Where</th></tr></thead>
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
      expect(markupProblems(page, 'page.html'), isEmpty);
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

    test('finds two link targets swapped', () {
      expect(
        linkDifference(
          markdown,
          page
              .replaceFirst('href="https://example.com"', 'href="#swap"')
              .replaceFirst(
                'href="https://example.org"',
                'href="https://example.com"',
              )
              .replaceFirst('href="#swap"', 'href="https://example.org"'),
          'page.html',
        ),
        isNotNull,
      );
    });

    test('refuses markup that can hide text or fake a link', () {
      const hiders = [
        '<p hidden>X</p>',
        '<p style="display:none">X</p>',
        '<p aria-hidden="true">X</p>',
        '<p class="skip">X</p>',
        '<details><summary>More</summary>X</details>',
        '<noscript>X</noscript>',
        '<template>X</template>',
        '<p><del>X</del></p>',
        "<p><a data-href=\"mailto:me@example.com\" href='mailto:evil@example.net'>X</a></p>",
        '<p><a>X</a></p>',
      ];
      for (final hider in hiders) {
        expect(
          markupProblems(
            page.replaceFirst(
              '<h2 id="a-section">',
              '$hider\n<h2 id="a-section">',
            ),
            'page.html',
          ),
          isNotEmpty,
          reason: hider,
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

    test('checks the desktop contents list too', () {
      expect(
        tocProblems(
          page.replaceFirst(
            '<ol><li><a href="#a-section">1. A section</a></li></ol></nav></aside>',
            '<ol><li><a href="#a-section">1. Old name</a></li></ol></nav></aside>',
          ),
          'page.html',
        ),
        isNotEmpty,
      );
      expect(
        tocProblems(
          page.replaceFirst(
            '<ol><li><a href="#a-section">1. A section</a></li></ol></nav></aside>',
            '<ol></ol></nav></aside>',
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

    test('finds a setting label the app does not have', () {
      bool known(String label) => const {
        'Settings',
        'Other',
        'Privacy',
        'Share crash logs and analytics',
      }.contains(label);
      const policy =
          '**Effective date:** today. Turn on **Share crash logs and '
          'analytics** in **Settings › Other › Privacy**.';
      expect(
        labelProblems(policy, 'p.md', {'Effective date:'}, known),
        isEmpty,
      );
      expect(
        labelProblems(
          policy.replaceFirst('Privacy', 'Privacy & data'),
          'p.md',
          {'Effective date:'},
          known,
        ),
        [contains('"Privacy & data"')],
      );
      // A label hidden inside a declared emphasis run is not excused: the
      // declaration must match the whole run, and a stale one is reported.
      expect(
        labelProblems(policy, 'p.md', {'Effective date:', 'Gone.'}, known),
        [contains('"Gone."')],
      );
      expect(
        englishCitations(
          '**Partager** (« Share crash logs and analytics » en anglais), '
          '(« Show BTTV emotes » et « Show BTTV badges » en anglais), '
          '« jeton web »',
        ),
        [
          'Share crash logs and analytics',
          'Show BTTV emotes',
          'Show BTTV badges',
        ],
      );
    });

    test(
      'finds a settings path the app does not have and odd « en anglais »',
      () {
        final paths = {'Settings › Other', 'Settings › Other › Privacy'};
        expect(
          pathProblems(
            '**Settings › Other › Privacy** and **Settings › Other**',
            'p.md',
            paths,
          ),
          isEmpty,
        );
        expect(pathProblems('**Settings › Video › Privacy**', 'p.md', paths), [
          contains('"Settings › Video › Privacy"'),
        ]);
        expect(
          unrecognisedEnAnglais(
            '**A** (« Show 7TV emotes » en anglais). Elle est aussi disponible '
            '[en anglais](PRIVACY.md).',
          ),
          isEmpty,
        );
        expect(
          unrecognisedEnAnglais('**A** (Show 7TV emotes en anglais).'),
          hasLength(1),
        );
        expect(
          unrecognisedEnAnglais('**A** (« Show 7TV emotes », en anglais).'),
          hasLength(1),
        );
      },
    );

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

      expect(markupProblems(htmlSource, entry.value), isEmpty);
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

  test('the policies cite only real settings paths', () {
    final fr = arbMap('lib/l10n/app_fr.arb');
    final en = arbMap('lib/l10n/app_en.arb');
    Set<String> resolve(Map<String, String> arb) => {
      for (final path in settingsPaths)
        path.map((key) => arb[key] ?? '(missing $key)').join(' › '),
    };
    final frPaths = resolve(fr);
    final enPaths = resolve(en);
    expect(
      frPaths.any((p) => p.contains('(missing')),
      isFalse,
      reason: '$frPaths',
    );
    expect(
      enPaths.any((p) => p.contains('(missing')),
      isFalse,
      reason: '$enPaths',
    );

    // Each entry of a path is built by that page (or by a settings widget the
    // page imports).
    final structure = <String>[];
    for (final path in settingsPaths.where((p) => p.length == 3)) {
      final pageFile = File(settingsPageFiles[path[1]]!);
      final page = pageFile.readAsStringSync();
      final widgets = RegExp(
        r"import 'package:onset/(screens/settings/widgets/[\w/]+\.dart)';",
      ).allMatches(page).map((m) => File('lib/${m[1]}').readAsStringSync());
      final code = [page, ...widgets].join('\n');
      if (!RegExp('\\b${path[2]}\\b').hasMatch(code)) {
        structure.add(
          '${path[2]} is not on the page built by ${pageFile.path}',
        );
      }
    }

    final frPolicy = File('PRIVACY.fr.md').readAsStringSync();
    final enPolicy = File('PRIVACY.md').readAsStringSync();
    final cited = boldRuns(frPolicy).where((r) => r.contains(' › ')).length;
    expect(cited, greaterThan(4), reason: 'the check must see the paths');
    final problems = [
      ...structure,
      ...pathProblems(frPolicy, 'PRIVACY.fr.md', frPaths),
      ...pathProblems(enPolicy, 'PRIVACY.md', enPaths),
      for (final c in englishCitations(frPolicy))
        if (c.contains(' › ') && !enPaths.contains(c))
          'PRIVACY.fr.md: English path "$c" is not one of the app\'s settings paths',
      for (final odd in unrecognisedEnAnglais(frPolicy))
        'PRIVACY.fr.md: « en anglais » not written as « Label » en anglais: "$odd"',
    ];
    if (problems.isNotEmpty) fail(problems.join('\n'));
  });

  test('the policies name only settings the app has', () {
    final fr = arbValues('lib/l10n/app_fr.arb');
    final en = arbValues('lib/l10n/app_en.arb');
    final libSource = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');
    bool englishKnown(String label) =>
        en.contains(label) ||
        libSource.contains("'$label'") ||
        libSource.contains('"$label"');

    final enPolicy = File('PRIVACY.md').readAsStringSync();
    final frPolicy = File('PRIVACY.fr.md').readAsStringSync();
    // The check must be looking at labels, not at an empty match.
    expect(fr.length, greaterThan(100));
    expect(en.length, greaterThan(100));
    for (final (name, text) in [
      ('PRIVACY.md', enPolicy),
      ('PRIVACY.fr.md', frPolicy),
    ]) {
      final labels = boldRuns(
        text,
      ).where((r) => !notAppLabels[name]!.contains(r)).toList();
      expect(labels.length, greaterThan(20), reason: name);
    }
    final citations = englishCitations(frPolicy);
    expect(citations.length, greaterThan(10));

    final problems = [
      ...labelProblems(
        frPolicy,
        'PRIVACY.fr.md',
        notAppLabels['PRIVACY.fr.md']!,
        fr.contains,
      ),
      ...labelProblems(
        enPolicy,
        'PRIVACY.md',
        notAppLabels['PRIVACY.md']!,
        englishKnown,
      ),
      for (final c in citations)
        if (!c.split(' › ').every(englishKnown))
          'PRIVACY.fr.md: English label "$c" is not in app_en.arb or lib/',
    ];
    if (problems.isNotEmpty) {
      fail(
        'A policy names a setting or button the app does not show. Copy the '
        "label exactly from the app's strings, or, if the bold text is not a "
        'label, declare it in notAppLabels.\n${problems.join('\n')}',
      );
    }
  });
}

/// The settings paths the policies may cite, as ARB keys: the settings title,
/// a page, and optionally an entry on that page. Each page's entries are
/// checked against the page's own code, so a path cannot name an entry that
/// lives elsewhere in the app.
const settingsPaths = [
  ['settingsTitle', 'settingsPageVideo'],
  ['settingsTitle', 'settingsPageVideo', 'webTokenTitle'],
  ['settingsTitle', 'settingsPageOther'],
  ['settingsTitle', 'settingsPageOther', 'settingsClearCache'],
  ['settingsTitle', 'settingsPageOther', 'settingsPrivacy'],
];

/// The code that builds each settings page.
const settingsPageFiles = {
  'settingsPageVideo': 'lib/screens/settings/video_settings.dart',
  'settingsPageOther': 'lib/screens/settings/other_settings.dart',
};

/// Every bold run that reads as a settings path (it contains " › ") and is
/// not one of [paths].
List<String> pathProblems(String markdown, String name, Set<String> paths) => [
  for (final run in boldRuns(markdown))
    if (run.contains(' › ') && !paths.contains(run))
      '$name: settings path "$run" is not one of the app\'s settings paths',
];

/// Every « en anglais » the citation format does not account for: the only
/// other allowed use is the sentence pointing to the English policy.
List<String> unrecognisedEnAnglais(String markdown) {
  var flat = _flat(
    markdown.replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!),
  );
  flat = flat
      .replaceAll(RegExp(r'((?:«[^»]+»(?: et |, ))*«[^»]+») en anglais'), '')
      .replaceAll('aussi disponible en anglais', '');
  return [for (final m in RegExp(r'.{0,40}en anglais').allMatches(flat)) m[0]!];
}

/// The string values of an ARB file by key, whitespace collapsed.
Map<String, String> arbMap(String path) {
  final map = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in map.entries)
      if (!e.key.startsWith('@') && e.value is String)
        e.key: _flat(e.value as String),
  };
}

/// Bold runs that are not labels of the app: emphasis, lead-ins, the services
/// in the network table, and labels of other software (Android's own
/// settings, Twitch's website). Each entry must still occur in its policy.
const notAppLabels = {
  'PRIVACY.md': {
    'Effective date:',
    'no account system of its own',
    'no ads of its own',
    'does not sell or rent any data',
    'on your device',
    'no crash reports, analytics, or performance data',
    'ONSET token service',
    'Twitch',
    'Amazon IVS player',
    'Twitch web player',
    '7TV',
    'BetterTTV',
    'FrankerFaceZ',
    'recent-messages.robotty.de',
    'GIPHY',
    'GitHub',
    'Google Firebase',
    'Google Play',
    'Off by default.',
    'While it is off, no crash reports, analytics, or performance data are '
        'sent.',
    'While it is on, the app sends',
    ':',
    'Crash reports (Crashlytics):',
    'Analytics (Google Analytics for Firebase):',
    'Performance (Performance Monitoring):',
    'What is not included.',
    'Legal basis.',
    'Google as processor.',
    'On your device:',
    'Firebase',
    'Twitch and other services:',
    "Clear the app's data",
    'uninstall',
    'Turn off',
    'Hosting:',
    'Visit statistics:',
    'Language choice:',
    'Legal basis:',
    'Nothing else:',
  },
  'PRIVACY.fr.md': {
    'Date d’entrée en vigueur :',
    'aucun système de compte à lui',
    'aucune publicité de son fait',
    'ne vend ni ne loue aucune donnée',
    'sur votre appareil',
    'aucun rapport de plantage, aucune statistique ni donnée de performance',
    'Service de jetons d’ONSET',
    'Twitch',
    'Lecteur Amazon IVS',
    'Lecteur web de Twitch',
    '7TV',
    'BetterTTV',
    'FrankerFaceZ',
    'recent-messages.robotty.de',
    'GIPHY',
    'GitHub',
    'Google Firebase',
    'Google Play',
    'Désactivé par défaut.',
    'Réglage désactivé, aucun rapport de plantage, aucune statistique ni '
        'donnée de performance n’est envoyé.',
    'Réglage activé, l’application envoie',
    'Rapports de plantage (Crashlytics) :',
    'Statistiques (Google Analytics for Firebase) :',
    'Performances (Performance Monitoring) :',
    'Ce qui n’en fait pas partie.',
    'Base légale.',
    'Google, sous-traitant.',
    'Sur votre appareil :',
    'Firebase',
    'Twitch et les autres services :',
    'Effacer les données de l’application',
    'désinstaller',
    'Hébergement :',
    'Statistiques de visite :',
    'Choix de la langue :',
    'Base légale :',
    'Rien d’autre :',
  },
};

/// Whitespace collapsed, French no-break spaces included.
String _flat(String s) =>
    s.replaceAll(RegExp(r'[\s\u00a0\u202f]+'), ' ').trim();

/// The text of every `**bold**` run, in order.
List<String> boldRuns(String markdown) => RegExp(
  r'\*\*([\s\S]+?)\*\*',
).allMatches(markdown).map((m) => _flat(m.group(1)!)).toList();

/// The English labels a French policy gives after its own, written
/// « A » en anglais or « A » et « B » en anglais.
List<String> englishCitations(String markdown) {
  final flat = _flat(markdown);
  return [
    for (final m in RegExp(
      r'((?:«[^»]+»(?: et |, ))*«[^»]+») en anglais',
    ).allMatches(flat))
      for (final q in RegExp(r'«\s*([^»]+?)\s*»').allMatches(m.group(1)!))
        q.group(1)!,
  ];
}

/// Every bold run not declared in [notLabels] whose parts are not all
/// [known], and every declaration that no longer matches a bold run.
List<String> labelProblems(
  String markdown,
  String name,
  Set<String> notLabels,
  bool Function(String label) known,
) {
  final runs = boldRuns(markdown);
  return [
    for (final run in runs)
      if (!notLabels.contains(run))
        for (final part in run.split(' › '))
          if (!known(part)) '$name: label "$part" (in **$run**) is unknown',
    for (final d in notLabels)
      if (!runs.contains(d)) '$name: declared emphasis "$d" is not in the text',
  ];
}

/// The string values of an ARB file, whitespace collapsed.
Set<String> arbValues(String path) {
  final map = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in map.entries)
      if (!e.key.startsWith('@') && e.value is String) _flat(e.value as String),
  };
}

/// A Markdown link to the other policy file (it works on GitHub) opens that
/// policy's page on the site; every other target is kept as written.
const policyPages = {'PRIVACY.md': '/privacy', 'PRIVACY.fr.md': '/fr/privacy'};
String _pageTarget(String target) => policyPages[target] ?? target;

/// Code spans the pages show as links, with their targets. Any other code
/// span, such as the example address `https://api.twitch.tv`, stays code.
const linkedCode = {
  'https://github.com/JLmehdi92/onset': 'https://github.com/JLmehdi92/onset',
  'PRIVACY.md': 'https://github.com/JLmehdi92/ONSET/blob/main/PRIVACY.md',
};

final _mdLink = RegExp(
  r'!?\[[^\]]*\]\(([^)\s]+)[^)]*\)'
  r'|<(https?://[^>]+)>'
  r'|(https?://[^\s<>()`|]+[^\s<>()`|.,;:])'
  r'|([\w.+-]+@[\w-]+(?:\.[\w-]+)+)',
);
final _email = RegExp(r'^[\w.+-]+@[\w-]+(?:\.[\w-]+)+$');
final _tocBlock = RegExp(
  r'<details\b[^>]*\bclass="[^"]*\btoc\b[^"]*"[^>]*>[\s\S]*?</details>',
);
final _deskToc = RegExp(
  r'<nav\b[^>]*\bclass="[^"]*\btoc-d\b[^"]*"[^>]*>[\s\S]*?</nav>',
);
final _anchor = RegExp(r'<a\s(?:[^>]*?\s)?href="([^"]*)"[^>]*>([\s\S]*?)</a>');

/// The link targets of a Markdown file as GitHub shows them, in reading
/// order, plus the targets the page adds: `mailto:` for each address and
/// [linkedCode].
List<String> markdownLinkTargets(String markdown) {
  final targets = <String>[];
  final text = markdown.replaceAll('\r\n', '\n');
  var last = 0;
  void prose(String s) {
    for (final m in _mdLink.allMatches(s)) {
      final email = m.group(4);
      targets.add(
        email != null
            ? 'mailto:$email'
            : _pageTarget((m.group(1) ?? m.group(2) ?? m.group(3))!),
      );
    }
  }

  for (final m in RegExp(r'`([^`]+)`').allMatches(text)) {
    prose(text.substring(last, m.start));
    final span = m.group(1)!;
    if (linkedCode.containsKey(span)) {
      targets.add(linkedCode[span]!);
    } else if (_email.hasMatch(span)) {
      targets.add('mailto:$span');
    }
    last = m.end;
  }
  prose(text.substring(last));
  return targets;
}

/// The `href` of every link in a fragment, in order, entities decoded.
List<String> htmlLinkTargets(String fragment) => _anchor
    .allMatches(fragment)
    .map((m) => decodeEntities(m.group(1)!))
    .toList();

/// Null when the article links to exactly the Markdown's targets, in the
/// same order, otherwise where the two lists first differ.
String? linkDifference(String markdown, String html, String name) {
  final expected = markdownLinkTargets(markdown);
  final actual = htmlLinkTargets(policyBody(html, name));
  final n = expected.length < actual.length ? expected.length : actual.length;
  var i = 0;
  while (i < n && expected[i] == actual[i]) {
    i++;
  }
  if (i == expected.length && i == actual.length) return null;
  String at(List<String> l) => i < l.length ? l[i] : '(no more links)';
  return '$name: its links no longer match the policy (${expected.length} '
      'expected, ${actual.length} found). Link ${i + 1}:\n'
      '  Policy: ${at(expected)}\n'
      '  Page:   ${at(actual)}';
}

const _allowedTags = {
  'a', 'code', 'div', 'h1', 'h2', 'li', 'p', 'strong', 'table', 'tbody', //
  'td', 'th', 'thead', 'tr', 'ul',
};
const _allowedAttributes = {
  'aria-label', 'class', 'data-label', 'href', 'id', 'role', 'scope', //
  'tabindex',
};
const _allowedClasses = {'tbl tbl-2', 'tbl tbl-3'};

/// What in the article (contents block left out) could hide text or fake a
/// link: a tag, attribute or class the page does not use there, an attribute
/// value without double quotes, or a link without an `href`.
List<String> markupProblems(String html, String name) {
  final problems = <String>[];
  final tags = RegExp(r'<(/?)([a-zA-Z][\w-]*)([^>]*)>');
  final attributes = RegExp(
    r'''\s+([^\s=>]+)(?:\s*=\s*("[^"]*"|'[^']*'|[^\s>]+))?''',
  );
  for (final m in tags.allMatches(policyBody(html, name))) {
    final tag = m.group(2)!.toLowerCase();
    if (!_allowedTags.contains(tag)) {
      problems.add('$name: <$tag> inside the policy');
      continue;
    }
    if (m.group(1)!.isNotEmpty) continue;
    var hasHref = false;
    for (final a in attributes.allMatches(m.group(3)!)) {
      final attribute = a.group(1)!.toLowerCase();
      final value = a.group(2);
      if (!_allowedAttributes.contains(attribute)) {
        problems.add('$name: $attribute= on <$tag>');
      } else if (value == null || !value.startsWith('"')) {
        problems.add(
          '$name: $attribute on <$tag> without a double-quoted value',
        );
      } else if (attribute == 'class' &&
          !_allowedClasses.contains(value.substring(1, value.length - 1))) {
        problems.add('$name: class $value on <$tag>');
      }
      if (attribute == 'href') hasHref = true;
    }
    if (tag == 'a' && !hasHref) problems.add('$name: a link without href');
  }
  return problems;
}

/// What is wrong with the two contents lists, if anything. The block inside
/// the article (optional) and the desktop list (required) may each hold a
/// short label and links to the policy's own headings, labelled with their
/// exact text, each once and in order, and nothing else.
List<String> tocProblems(String html, String name) {
  final article = policyArticle(html, name);
  final heads = RegExp(r'<h2\b[^>]*\bid="([^"]+)"[^>]*>([\s\S]*?)</h2>')
      .allMatches(article.replaceAll(_tocBlock, ' '))
      .map((h) => '#${h.group(1)} ${_visibleText(h.group(2)!)}')
      .toList();
  final problems = <String>[];
  final blocks = _tocBlock.allMatches(article).toList();
  if (blocks.length > 1) problems.add('$name: more than one contents block');
  for (final b in blocks) {
    problems.addAll(
      _listProblems(
        b.group(0)!,
        heads,
        '$name, contents in the policy',
        RegExp(r'<summary\b[\s\S]*?</summary>'),
      ),
    );
  }
  final desk = _deskToc.allMatches(html).toList();
  if (desk.length != 1) {
    problems.add(
      '$name: expected one desktop contents list (.toc-d), found '
      '${desk.length}',
    );
  } else {
    problems.addAll(
      _listProblems(
        desk.single.group(0)!,
        heads,
        '$name, desktop contents',
        RegExp(r'<p\b[^>]*\bclass="toc-h"[^>]*>[\s\S]*?</p>'),
      ),
    );
  }
  return problems;
}

List<String> _listProblems(
  String block,
  List<String> heads,
  String where,
  RegExp label,
) {
  final problems = <String>[];
  final links = _anchor
      .allMatches(block)
      .map((a) => '${a.group(1)} ${_visibleText(a.group(2)!)}')
      .toList();
  if (links.join('\n') != heads.join('\n')) {
    problems.add(
      '$where must list exactly the section headings, found:\n'
      '  ${links.join('\n  ')}',
    );
  }
  final labelMatch = label.firstMatch(block);
  if (labelMatch != null && _visibleText(labelMatch.group(0)!).length > 40) {
    problems.add('$where: its label is too long to be a label');
  }
  final rest = _visibleText(
    block.replaceAll(_anchor, ' ').replaceAll(label, ' '),
  );
  if (rest.isNotEmpty) problems.add('$where: text outside its links: $rest');
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
