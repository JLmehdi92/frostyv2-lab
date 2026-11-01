import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/widgets/release_notes_parts.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/haptics.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/motion/staggered_entrance.dart';

/// The release notes.
///
/// From Settings: the latest version in a card, the earlier ones in a list
/// that opens in place (phone), or a version list beside the chosen
/// version's details (tablet). Opened by itself after an update
/// ([updatedTo]): "Updated to x.y.z", the version it came from when known,
/// and "Got it", which closes the page like back. No entries: "No release
/// notes yet".
class ReleaseNotes extends StatefulWidget {
  static const routeName = 'ReleaseNotes';

  /// The English notes, the reference every translation follows.
  static const englishAsset = 'assets/release-notes.md';

  /// The French translation of [englishAsset], version for version.
  static const frenchAsset = 'assets/release-notes.fr.md';

  /// Replaces the bundled English notes in tests.
  static Future<String> Function()? debugSource;

  /// Replaces the bundled French notes in tests. While [debugSource] is set
  /// and this is not, French reads as missing (the English stand-in is
  /// used), so a test's notes are never mixed with the bundled ones.
  static Future<String> Function()? debugFrenchSource;

  /// The release notes' Markdown in the language of [locale] (English, the
  /// reference, when none is given), or null when they cannot be read.
  /// Notes missing in that language fall back to English. Never throws.
  static Future<String?> read([Locale? locale]) async {
    if (locale?.languageCode == 'fr') {
      final french = await _readSource(
        debugFrenchSource ??
            (debugSource == null
                ? () => rootBundle.loadString(frenchAsset)
                : () async => throw StateError('no French test notes')),
      );
      if (french != null && french.trim().isNotEmpty) return french;
    }
    return _readSource(
      debugSource ?? () => rootBundle.loadString(englishAsset),
    );
  }

  static Future<String?> _readSource(Future<String> Function() source) async {
    try {
      return await source();
    } catch (e) {
      debugPrint('Release notes unreadable: ${e.runtimeType}');
      return null;
    }
  }

  /// The release notes' Markdown in the language of [locale] (see [read]);
  /// unreadable notes read as none (no entries). Never throws.
  static Future<String> load([Locale? locale]) async =>
      await read(locale) ?? '';

  const ReleaseNotes({super.key, this.updatedTo, this.updatedFrom});

  /// The version now installed, when the notes open by themselves after an
  /// update ("Just updated"); null when opened from Settings.
  final String? updatedTo;

  /// The version the update came from, when known.
  final String? updatedFrom;

  @override
  State<ReleaseNotes> createState() => _ReleaseNotesState();
}

class _ReleaseNotesState extends State<ReleaseNotes> {
  /// Null while the notes load.
  ReleaseNotesData? _data;

  /// Phone: the other versions open in place (by position in the notes:
  /// two entries may carry the same version).
  final _open = <int>{};

  /// Tablet: the version chosen (by position), null until one is picked.
  /// Kept in this state, it survives a rotation or a phone-sized window in
  /// between.
  int? _selected;

  final _phoneScroll = ScrollController();
  final _asideScroll = ScrollController();
  final _detailScroll = ScrollController();

  bool get _fresh => widget.updatedTo != null;

  /// The language the notes were last read in.
  Locale? _locale;

  /// The latest read: an older one finishing after it is dropped.
  var _reading = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (locale == _locale) return;
    _locale = locale;
    _load(locale);
  }

  /// Reads the notes in [locale]'s language (the versions are the same in
  /// every language, so what is open or picked stays).
  void _load(Locale locale) {
    final read = ++_reading;
    ReleaseNotes.load(locale)
        .then((markdown) {
          if (!mounted || read != _reading) return;
          setState(() => _data = parseReleaseEntries(markdown));
        })
        // Defensive (load never throws): never leave the page loading.
        .catchError((Object e) {
          debugPrint('Release notes page: ${e.runtimeType}');
          if (mounted && read == _reading) {
            setState(() => _data = const ReleaseNotesData());
          }
        });
  }

  @override
  void dispose() {
    _phoneScroll.dispose();
    _asideScroll.dispose();
    _detailScroll.dispose();
    super.dispose();
  }

  void _close() => Navigator.maybePop(context);

  void _toggle(int index) => setState(() {
    if (!_open.remove(index)) _open.add(index);
  });

  /// The entry the page leads with: the newest, or after an update the
  /// newest entry of the installed major.minor (the notes may already hold
  /// a version newer than the build).
  int _featured(List<ReleaseEntry> entries) {
    final to = widget.updatedTo;
    if (to == null) return 0;
    final target = releaseMajorMinor(to);
    final index = entries.indexWhere(
      (entry) => releaseMajorMinor(entry.version) == target,
    );
    return index < 0 ? 0 : index;
  }

  /// The tablet's version shown.
  int _shown(List<ReleaseEntry> entries) {
    final selected = _selected;
    return selected != null && selected < entries.length
        ? selected
        : _featured(entries);
  }

  void _pick(int index) {
    final entries = _data?.entries ?? const <ReleaseEntry>[];
    if (index == _shown(entries)) return;
    unawaited(Haptics.selection());
    setState(() => _selected = index);
    if (_detailScroll.hasClients) _detailScroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final tablet = context.isLargeScreen;
    // The entrance plays once, when the notes arrive (the key changes then):
    // a later switch between the phone and tablet layouts shows at once.
    return StaggerScope(
      key: ValueKey(data != null),
      child: tablet ? _buildTablet(context, data) : _buildPhone(context, data),
    );
  }

  /// [child] entering [index] steps after the first, 6 dp up (the
  /// 60 ms steps when just updated, 40 ms from Settings).
  Widget _enter(int index, Widget child) => StaggeredEntrance(
    index: index,
    offset: 6,
    step: _fresh ? OnsetMotion.launchStaggerStep : OnsetMotion.staggerStep,
    child: child,
  );

  Widget _buildPhone(BuildContext context, ReleaseNotesData? data) {
    final entries = data?.entries ?? const <ReleaseEntry>[];
    final Widget body;
    if (data == null) {
      body = const SizedBox.shrink();
    } else if (entries.isEmpty) {
      // The padding under SettingsScaffold's header, read below it.
      body = Builder(
        builder: (context) {
          final padding = MediaQuery.paddingOf(context);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              32 + padding.left,
              padding.top,
              32 + padding.right,
              96 + padding.bottom,
            ),
            child: Center(
              child: _enter(0, const ReleaseEmptyState(tablet: false)),
            ),
          );
        },
      );
    } else {
      body = Builder(builder: (context) => _phoneNotes(context, data));
    }
    return SettingsScaffold(
      title: context.l10n.settingsReleaseNotes,
      onBack: _close,
      body: body,
    );
  }

  /// [context] is under SettingsScaffold: its padding includes the header.
  Widget _phoneNotes(BuildContext context, ReleaseNotesData data) {
    final padding = MediaQuery.paddingOf(context);
    final entries = data.entries;
    final featured = _featured(entries);
    final others = [
      for (var i = 0; i < entries.length; i++)
        if (i != featured) i,
    ];
    final to = widget.updatedTo;
    var step = 0;
    final children = <Widget>[
      if (to != null)
        _enter(step++, ReleaseFreshHero(to: to, from: widget.updatedFrom)),
      if (data.preamble.isNotEmpty)
        _enter(
          step++,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ReleaseSectionView(
              ReleaseEntrySection(title: null, items: data.preamble),
            ),
          ),
        ),
      _enter(
        step++,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            if (to == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ReleaseEyebrow(context.l10n.releaseNotesWhatsNew),
              ),
            ReleaseLatestCard(entries[featured], latest: featured == 0),
          ],
        ),
      ),
      if (others.isNotEmpty)
        _enter(
          step++,
          ReleaseEarlierVersions(
            // After an update the notes may hold a newer version too.
            title: featured == 0
                ? context.l10n.releaseNotesEarlierVersions
                : context.l10n.releaseNotesOtherVersions,
            entries: entries,
            indexes: others,
            open: _open,
            onToggle: _toggle,
          ),
        ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: ReleaseFootnote(),
      ),
    ];
    final list = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        // Everything is built (a few cards): a reader can search it, and
        // the earlier versions keep their state while scrolled away.
        child: SingleChildScrollView(
          controller: _phoneScroll,
          padding: EdgeInsets.fromLTRB(
            16 + padding.left,
            padding.top + 18,
            16 + padding.right,
            padding.bottom + (to != null ? 120 : 36),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 22,
            children: children,
          ),
        ),
      ),
    );
    if (to == null) return list;
    final ground = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      children: [
        Positioned.fill(child: list),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          // A gradient, never a blur (the page can open over a video).
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.34, 1],
                colors: [
                  ground.withValues(alpha: 0),
                  ground.withValues(alpha: 0.92),
                  ground,
                ],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16 + padding.left,
                28,
                16 + padding.right,
                24 + padding.bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 688),
                  child: ReleasePrimaryButton(
                    label: context.l10n.releaseNotesGotIt,
                    onPressed: _close,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTablet(BuildContext context, ReleaseNotesData? data) {
    final theme = Theme.of(context);
    final colors = SettingsColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    final to = widget.updatedTo;
    final entries = data?.entries ?? const <ReleaseEntry>[];
    final themed =
        theme.appBarTheme.systemOverlayStyle ??
        (theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark);

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        18 + padding.left,
        padding.top,
        28 + padding.right,
        0,
      ),
      child: SizedBox(
        height: 84,
        child: Row(
          spacing: 8,
          children: [
            ReleaseRoundBack(onPressed: _close),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    ReleaseEyebrow(
                      to == null
                          ? context.l10n.releaseNotesWhatsNew
                          : context.l10n.releaseNotesWhatsNewIn(version: to),
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        to == null
                            ? context.l10n.settingsReleaseNotes
                            : context.l10n.releaseNotesUpdatedTo(version: to),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: OnsetTokens.bodyFamily,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.84,
                          height: 1.1,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (to != null && data != null && entries.isNotEmpty)
              Flexible(
                child: _enter(
                  0,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: 16,
                    children: [
                      if (widget.updatedFrom case final from?)
                        Flexible(
                          child: ReleaseWasOn(
                            from,
                            fontSize: 13.5,
                            maxLines: 1,
                          ),
                        ),
                      ReleasePrimaryButton(
                        label: context.l10n.releaseNotesGotIt,
                        onPressed: _close,
                        height: 44,
                        fontSize: 14,
                        expand: false,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final Widget body;
    if (data == null) {
      body = const SizedBox.shrink();
    } else if (entries.isEmpty) {
      body = Padding(
        padding: EdgeInsets.fromLTRB(
          28 + padding.left,
          0,
          28 + padding.right,
          28 + padding.bottom,
        ),
        child: _enter(
          0,
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.well,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colors.cardRing,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Center(child: ReleaseEmptyState(tablet: true)),
            ),
          ),
        ),
      );
    } else {
      body = _tabletPanes(context, data);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: themed,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabletPanes(BuildContext context, ReleaseNotesData data) {
    final colors = SettingsColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    final entries = data.entries;
    final index = _shown(entries);
    final entry = entries[index];
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final duration = motionDuration(context, const Duration(milliseconds: 300));
    final reduced = reduceMotionOf(context);

    final aside = ListView(
      controller: _asideScroll,
      padding: EdgeInsets.only(top: 4, bottom: 28 + padding.bottom),
      children: [
        if (data.preamble.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: ReleaseSectionView(
              ReleaseEntrySection(title: null, items: data.preamble),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ReleaseListLabel(context.l10n.releaseNotesVersions),
        ),
        const SizedBox(height: 10),
        for (final (i, version) in entries.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: ReleaseVersionRow(
              entry: version,
              latest: i == 0,
              selected: i == index,
              onTap: () => _pick(i),
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: ReleaseFootnote(),
        ),
      ],
    );

    final detail = ListView(
      controller: _detailScroll,
      padding: EdgeInsets.fromLTRB(4, 4, 4, 40 + padding.bottom),
      children: [
        AnimatedSwitcher(
          duration: duration,
          switchInCurve: OnsetMotion.standard,
          // Only the version chosen is drawn: the one it replaces goes at
          // once, the new one rises in.
          layoutBuilder: (current, _) => current ?? const SizedBox.shrink(),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: reduced
                ? child
                : SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.008),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
          ),
          child: ReleaseDetail(
            key: ValueKey(index),
            entry: entry,
            latest: index == 0,
            newer: index > 0 ? entries[index - 1] : null,
            older: index < entries.length - 1 ? entries[index + 1] : null,
            onNewer: () => _pick(index - 1),
            onOlder: () => _pick(index + 1),
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 28 + padding.left,
        right: 28 + padding.right,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: wide ? 340 : 280, child: _enter(0, aside)),
          const SizedBox(width: 32),
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: SizedBox(
              width: 0.5,
              child: ColoredBox(color: colors.hairline),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(child: _enter(1, detail)),
        ],
      ),
    );
  }
}

/// A piece of the release notes.
sealed class ReleaseNotesBlock {
  const ReleaseNotesBlock();
}

/// "## v1.0.0" and the date written under it.
final class ReleaseVersion extends ReleaseNotesBlock {
  const ReleaseVersion(this.version, this.date);

  final String version;
  final String? date;
}

/// "### Bug Fixes".
final class ReleaseSection extends ReleaseNotesBlock {
  const ReleaseSection(this.title);

  final String title;
}

/// "- [iOS] Fixed …": a point, with the platform it is for; [level] 1 for
/// a point under a point.
final class ReleasePoint extends ReleaseNotesBlock {
  const ReleasePoint(this.text, {this.platform, this.level = 0});

  final String text;
  final String? platform;
  final int level;

  /// The same point with [more] at its end (a line wrapped in the source).
  ReleasePoint extended(String more) =>
      ReleasePoint('$text $more', platform: platform, level: level);
}

/// "---" between two versions.
final class ReleaseRule extends ReleaseNotesBlock {
  const ReleaseRule();
}

/// Any other line ("#### See all release notes at …").
final class ReleaseParagraph extends ReleaseNotesBlock {
  const ReleaseParagraph(this.text);

  final String text;
}

final _platformTag = RegExp(r'^\[(iOS|Android)\]\s*');

/// The spaces a date may be written with: a space, or the no-break ones
/// French typography puts there.
const _dateSpace = '[ \u00a0\u202f]';

/// "January 9, 2026", or in French "9 janvier 2026" (and "1er janvier
/// 2026"): the date under a version.
final _date = RegExp(
  '^(?:[A-Z][a-z]+ \\d{1,2}, \\d{4}'
  '|(?:1er|\\d{1,2})$_dateSpace(?:${_frenchMonths.join('|')})$_dateSpace'
  '\\d{4})\$',
);

/// The French months, as written in dates, January first.
const _frenchMonths = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// The English months, as written in dates, January first.
const _englishMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The day a version's [date] names ("October 29, 2026", "29 octobre
/// 2026"), or null when it does not read as one.
DateTime? releaseDay(String date) {
  final english = RegExp(
    r'^([A-Z][a-z]+) (\d{1,2}), (\d{4})$',
  ).firstMatch(date);
  final french = RegExp(
    '^(1er|\\d{1,2})$_dateSpace(\\p{L}+)$_dateSpace(\\d{4})\$',
    unicode: true,
  ).firstMatch(_composed(date));
  final (int? day, int month, int? year) = switch ((english, french)) {
    (final m?, _) => (
      int.tryParse(m[2]!),
      _englishMonths.indexOf(m[1]!) + 1,
      int.tryParse(m[3]!),
    ),
    (_, final m?) => (
      m[1] == '1er' ? 1 : int.tryParse(m[1]!),
      _frenchMonths.indexOf(m[2]!) + 1,
      int.tryParse(m[3]!),
    ),
    _ => (null, 0, null),
  };
  if (day == null || year == null || month == 0) return null;
  final result = DateTime(year, month, day);
  // "February 31" is no day.
  return result.month == month && result.day == day ? result : null;
}

/// [text] with the French letters an editor may write decomposed (an "e"
/// then a combining accent, as some keyboards and macOS file names do)
/// written as one character: what the parser and the screen expect.
String _composed(String text) {
  if (!text.contains(_combining)) return text;
  return text.replaceAllMapped(
    RegExp('([aeiouyAEIOUYcC])([\u0300\u0301\u0302\u0308\u0327])'),
    (match) => _composedLetters[match[0]] ?? match[0]!,
  );
}

final _combining = RegExp('[\u0300\u0301\u0302\u0308\u0327]');

/// The letters French writes with an accent, decomposed to composed.
const _composedLetters = {
  'a\u0300': 'à',
  'a\u0302': 'â',
  'e\u0300': 'è',
  'e\u0301': 'é',
  'e\u0302': 'ê',
  'e\u0308': 'ë',
  'i\u0302': 'î',
  'i\u0308': 'ï',
  'o\u0302': 'ô',
  'u\u0300': 'ù',
  'u\u0302': 'û',
  'u\u0308': 'ü',
  'y\u0308': 'ÿ',
  'c\u0327': 'ç',
  'A\u0300': 'À',
  'A\u0302': 'Â',
  'E\u0300': 'È',
  'E\u0301': 'É',
  'E\u0302': 'Ê',
  'E\u0308': 'Ë',
  'I\u0302': 'Î',
  'I\u0308': 'Ï',
  'O\u0302': 'Ô',
  'U\u0300': 'Ù',
  'U\u0302': 'Û',
  'U\u0308': 'Ü',
  'Y\u0308': 'Ÿ',
  'C\u0327': 'Ç',
};

/// Reads the release notes' Markdown (assets/release-notes.md): versions,
/// their dates, sections, points, rules; anything else stays a paragraph.
List<ReleaseNotesBlock> parseReleaseNotes(String markdown) {
  final blocks = <ReleaseNotesBlock>[];
  final lines = _composed(markdown).split(RegExp(r'\r?\n'));
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final line = raw.trim();
    // Blank lines, and one-line HTML comments (notes for whoever writes the
    // file, never shown).
    if (line.isEmpty || (line.startsWith('<!--') && line.endsWith('-->'))) {
      continue;
    }
    final indented = raw.startsWith(' ') || raw.startsWith('\t');
    final bullet = line.startsWith('- ') || line.startsWith('* ');
    final last = blocks.isEmpty ? null : blocks.last;
    if (indented && !bullet && last is ReleasePoint) {
      // A point wrapped over two lines.
      blocks[blocks.length - 1] = last.extended(line);
    } else if (line.startsWith('## ')) {
      // The date is the next written line, when it reads as one.
      String? date;
      var next = i + 1;
      while (next < lines.length && lines[next].trim().isEmpty) {
        next++;
      }
      if (next < lines.length && _date.hasMatch(lines[next].trim())) {
        date = lines[next].trim();
        i = next;
      }
      blocks.add(ReleaseVersion(line.substring(3).trim(), date));
    } else if (line.startsWith('### ')) {
      blocks.add(ReleaseSection(line.substring(4).trim()));
    } else if (line == '---' || line == '***') {
      blocks.add(const ReleaseRule());
    } else if (bullet) {
      final text = line.substring(2).trim();
      final tag = _platformTag.firstMatch(text);
      final level = indented ? 1 : 0;
      blocks.add(
        tag == null
            ? ReleasePoint(text, level: level)
            : ReleasePoint(
                text.substring(tag.end),
                platform: tag.group(1),
                level: level,
              ),
      );
    } else {
      blocks.add(ReleaseParagraph(line.replaceFirst(RegExp(r'^#+\s*'), '')));
    }
  }
  return blocks;
}

/// What a section is about, read from its name: its glyph and how its
/// points are counted ("2 new · 3 improvements · 1 fix", named in
/// lib/l10n/enum_labels.dart).
enum ReleaseSectionKind {
  added,
  improved,
  fixed,
  other;

  /// "Bug Fixes", "Bugfixes", "New", "Features", "Improvements",
  /// "Changed"…, in any case (a fix first: "Fixes for the new player");
  /// any other name (or none) is [other]. A French name reads as the
  /// English it translates: "Corrections", "Bogues corrigés" (fixed),
  /// "Nouveautés", "Fonctionnalités", "Ajouts" (added), "Améliorations",
  /// "Changements", "Modifications" (improved, as "Changed" is), a
  /// correction first too ("Améliorations et corrections" is fixed, as
  /// "Improvements and fixes" is).
  static ReleaseSectionKind of(String? title) {
    final name = title?.trim().toLowerCase() ?? '';
    if (_fixed.hasMatch(name) || _frenchFixed.hasMatch(name)) return fixed;
    if (_added.hasMatch(name) || _frenchAdded.hasMatch(name)) return added;
    if (_improved.hasMatch(name) || _frenchImproved.hasMatch(name)) {
      return improved;
    }
    return other;
  }

  /// A whole English word: "Fix", "Fixes", "Fixed", "Fixing", "Fixups",
  /// "Bugfixes", "Hotfix", "Corrections", not "Prefixes" (nor the French
  /// « Préfixes »).
  static final _fixed = RegExp(
    r'(?<!\p{L})(?:(?:bug|hot)?fix(?:es|ed|ing|ups?)?|corrections?)(?!\p{L})',
    unicode: true,
  );
  static final _added = RegExp(r'\b(new|features?|added)\b');
  static final _improved = RegExp(r'\b(improvements?|improved|changed)\b');

  /// A whole French word: "Correctifs", not "Incorrects".
  static RegExp _frenchWords(String words) =>
      RegExp('(?<![\\p{L}\\p{N}])($words)(?![\\p{L}\\p{N}])', unicode: true);

  static final _frenchFixed = _frenchWords(
    r'corrections?|correctifs?|corrigé(?:e|s|es)?',
  );
  static final _frenchAdded = _frenchWords(
    r'nouveautés?|nouveaux?|nouvelles?|fonctionnalités?|ajouts?'
    r'|ajouté(?:e|s|es)?',
  );
  static final _frenchImproved = _frenchWords(
    r'améliorations?|amélioré(?:e|s|es)?|changements?|modifications?'
    r'|modifié(?:e|s|es)?',
  );
}

/// A section of one version, with its points and paragraphs.
final class ReleaseEntrySection {
  const ReleaseEntrySection({required this.title, required this.items});

  /// Null for what is written under a version before any section.
  final String? title;

  /// [ReleasePoint]s and [ReleaseParagraph]s, in order.
  final List<ReleaseNotesBlock> items;

  ReleaseSectionKind get kind => ReleaseSectionKind.of(title);

  /// Its points (a point under a point is part of the one above).
  int get count =>
      items.whereType<ReleasePoint>().where((point) => point.level == 0).length;
}

/// One version of the notes.
final class ReleaseEntry {
  ReleaseEntry({
    required this.version,
    this.date,
    this.notes = const [],
    this.sections = const [],
  });

  /// As written after "## ", without its "v": "1.1.0".
  final String version;

  /// As written under the version: "October 29, 2026".
  final String? date;

  /// The day [date] names, null when it reads as none.
  late final DateTime? day = switch (date) {
    final date? => releaseDay(date),
    null => null,
  };

  /// The paragraphs before its first section.
  final List<String> notes;
  final List<ReleaseEntrySection> sections;

  late final bool _numbered = _digit.hasMatch(version);
  static final _digit = RegExp(r'^\d');

  /// "v1.1.0" (a heading that is not a version number stays as written).
  String get label => _numbered ? 'v$version' : version;

  /// "ONSET 1.1.0".
  String get name => _numbered ? 'ONSET $version' : version;

  /// Its points by kind (counted once), the kinds without any left out.
  late final Map<ReleaseSectionKind, int> counts = _counts();

  Map<ReleaseSectionKind, int> _counts() {
    final counts = <ReleaseSectionKind, int>{};
    for (final section in sections) {
      counts.update(
        section.kind,
        (n) => n + section.count,
        ifAbsent: () => section.count,
      );
    }
    counts.removeWhere((_, count) => count <= 0);
    return counts;
  }

  /// "2 new · 3 improvements · 1 fix": its points by kind, empty without
  /// any.
  String summary(AppLocalizations l) => [
    for (final kind in ReleaseSectionKind.values)
      if (counts[kind] case final count?) kind.count(l, count),
  ].join(' · ');
}

/// The notes read as versions ([entries], newest first) and anything
/// written before the first one ([preamble]: its points and paragraphs, a
/// heading read as a paragraph).
final class ReleaseNotesData {
  const ReleaseNotesData({this.preamble = const [], this.entries = const []});

  final List<ReleaseNotesBlock> preamble;
  final List<ReleaseEntry> entries;
}

/// "1.1" of "v1.1.3".
String releaseMajorMinor(String version) =>
    version.replaceFirst(RegExp('^v'), '').split('.').take(2).join('.');

/// [markdown] as [ReleaseNotesData] (see [parseReleaseNotes]).
ReleaseNotesData parseReleaseEntries(String markdown) {
  final preamble = <ReleaseNotesBlock>[];
  final entries = <ReleaseEntry>[];
  ReleaseVersion? version;
  var notes = <String>[];
  var sections = <ReleaseEntrySection>[];
  String? title;
  var items = <ReleaseNotesBlock>[];
  var inSection = false;

  void closeSection() {
    if (inSection && (title != null || items.isNotEmpty)) {
      sections.add(ReleaseEntrySection(title: title, items: items));
    }
    title = null;
    items = [];
    inSection = false;
  }

  void closeVersion() {
    closeSection();
    if (version case final version?) {
      entries.add(
        ReleaseEntry(
          version: version.version.replaceFirst(RegExp(r'^v(?=\d)'), ''),
          date: version.date,
          notes: notes,
          sections: sections,
        ),
      );
    }
    notes = [];
    sections = [];
  }

  for (final block in parseReleaseNotes(markdown)) {
    switch (block) {
      case ReleaseVersion():
        closeVersion();
        version = block;
      case ReleaseSection(title: final name):
        if (version == null) {
          preamble.add(ReleaseParagraph(name));
          continue;
        }
        closeSection();
        title = name;
        inSection = true;
      case ReleasePoint():
        if (version == null) {
          preamble.add(block);
          continue;
        }
        inSection = true;
        items.add(block);
      case ReleaseParagraph(:final text):
        if (version == null) {
          preamble.add(block);
        } else if (inSection) {
          items.add(block);
        } else {
          notes.add(text);
        }
      case ReleaseRule():
        break;
    }
  }
  closeVersion();
  return ReleaseNotesData(preamble: preamble, entries: entries);
}

/// Whether the release notes open by themselves at launch: only after an
/// update to a new major.minor version (never on a first launch, when
/// [lastShown] is null), and only when [notes] have an entry for that
/// version ("## v1.1.0", "## 1.1.2": any entry of [current]'s major.minor).
bool shouldShowReleaseNotes({
  required String? lastShown,
  required String current,
  required String notes,
}) {
  if (lastShown == null) return false;
  final target = releaseMajorMinor(current);
  if (releaseMajorMinor(lastShown) == target) return false;
  return parseReleaseNotes(notes).whereType<ReleaseVersion>().any(
    (entry) => releaseMajorMinor(entry.version) == target,
  );
}
