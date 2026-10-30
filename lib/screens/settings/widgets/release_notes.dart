import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Replaces the bundled notes in tests.
  static Future<String> Function()? debugSource;

  /// The release notes' Markdown (assets/release-notes.md), or null when it
  /// cannot be read. Never throws.
  static Future<String?> read() async {
    try {
      return await (debugSource ??
          () => rootBundle.loadString('assets/release-notes.md'))();
    } catch (e) {
      debugPrint('Release notes unreadable: ${e.runtimeType}');
      return null;
    }
  }

  /// The release notes' Markdown; unreadable notes read as none (no
  /// entries). Never throws.
  static Future<String> load() async => await read() ?? '';

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

  @override
  void initState() {
    super.initState();
    ReleaseNotes.load()
        .then((markdown) {
          if (!mounted) return;
          setState(() => _data = parseReleaseEntries(markdown));
        })
        // Defensive (load never throws): never leave the page loading.
        .catchError((Object e) {
          debugPrint('Release notes page: ${e.runtimeType}');
          if (mounted) setState(() => _data = const ReleaseNotesData());
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
    return SettingsScaffold(title: 'Release notes', onBack: _close, body: body);
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: ReleaseEyebrow("WHAT'S NEW"),
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
            title: featured == 0 ? 'Earlier versions' : 'Other versions',
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
                    label: 'Got it',
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
                      to == null ? "WHAT'S NEW" : "WHAT'S NEW IN $to",
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        to == null ? 'Release notes' : 'Updated to $to',
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
                        label: 'Got it',
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: ReleaseListLabel('Versions'),
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

/// "January 9, 2026": the date under a version.
final _date = RegExp(r'^[A-Z][a-z]+ \d{1,2}, \d{4}$');

/// Reads the release notes' Markdown (assets/release-notes.md): versions,
/// their dates, sections, points, rules; anything else stays a paragraph.
List<ReleaseNotesBlock> parseReleaseNotes(String markdown) {
  final blocks = <ReleaseNotesBlock>[];
  final lines = markdown.split(RegExp(r'\r?\n'));
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
/// points are counted ("2 new · 3 improvements · 1 fix").
enum ReleaseSectionKind {
  added('new', 'new'),
  improved('improvement', 'improvements'),
  fixed('fix', 'fixes'),
  other('change', 'changes');

  const ReleaseSectionKind(this.one, this.many);

  final String one;
  final String many;

  /// "Bug Fixes", "Bugfixes", "New", "Features", "Improvements",
  /// "Changed"…, in any case (a fix first: "Fixes for the new player");
  /// any other name (or none) is [other].
  static ReleaseSectionKind of(String? title) {
    final name = title?.trim().toLowerCase() ?? '';
    if (name.contains('fix')) return fixed;
    if (_added.hasMatch(name)) return added;
    if (_improved.hasMatch(name)) return improved;
    return other;
  }

  static final _added = RegExp(r'\b(new|features?|added)\b');
  static final _improved = RegExp(r'\b(improvements?|improved|changed)\b');
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
  final String? date;

  /// The paragraphs before its first section.
  final List<String> notes;
  final List<ReleaseEntrySection> sections;

  late final bool _numbered = _digit.hasMatch(version);
  static final _digit = RegExp(r'^\d');

  /// "v1.1.0" (a heading that is not a version number stays as written).
  String get label => _numbered ? 'v$version' : version;

  /// "ONSET 1.1.0".
  String get name => _numbered ? 'ONSET $version' : version;

  /// "2 new · 3 improvements · 1 fix": its points by kind, empty without
  /// any. Read once.
  late final String summary = _summary();

  String _summary() {
    final counts = <ReleaseSectionKind, int>{};
    for (final section in sections) {
      counts.update(
        section.kind,
        (n) => n + section.count,
        ifAbsent: () => section.count,
      );
    }
    return [
      for (final kind in ReleaseSectionKind.values)
        if ((counts[kind] ?? 0) > 0)
          '${counts[kind]} ${counts[kind] == 1 ? kind.one : kind.many}',
    ].join(' · ');
  }
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
