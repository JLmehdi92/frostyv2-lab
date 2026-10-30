import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/release_notes.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/link_router.dart';
import 'package:onset/widgets/launch/onset_mark.dart';
import 'package:onset/widgets/motion/haptics.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:provider/provider.dart';

/// The pieces of the release notes page,
/// shared by its phone and tablet layouts.

TextStyle _inter(
  double size, {
  FontWeight weight = FontWeight.w400,
  double? spacing,
  double? height,
  Color? color,
  bool tabular = false,
}) {
  final style = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: spacing,
    height: height,
    color: color,
  );
  return tabular ? OnsetType.tabular(style) : style;
}

/// "WHAT'S NEW": 10.5/800, tracked 0.12 em, in the signal colour.
class ReleaseEyebrow extends StatelessWidget {
  const ReleaseEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: _inter(
      10.5,
      weight: FontWeight.w800,
      spacing: 1.26,
      color: SettingsColors.accentOf(context),
    ),
  );
}

/// "EARLIER VERSIONS", "VERSIONS": a list's label.
class ReleaseListLabel extends StatelessWidget {
  const ReleaseListLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text.toUpperCase(),
      style: _inter(
        11,
        weight: FontWeight.w600,
        spacing: 1.54,
        color: SettingsColors.of(context).secondary,
      ),
    ),
  );
}

/// "Release notes open by themselves after an update to a new version."
class ReleaseFootnote extends StatelessWidget {
  const ReleaseFootnote({super.key});

  @override
  Widget build(BuildContext context) => Text(
    'Release notes open by themselves after an update to a new version.',
    style: _inter(
      12.5,
      height: 1.5,
      color: SettingsColors.of(context).tertiary,
    ),
  );
}

/// The version's pill: "v1.1.0", in the signal colour for the latest
/// version, quiet for an older one.
class ReleaseVersionPill extends StatelessWidget {
  const ReleaseVersionPill(this.label, {super.key, required this.latest});

  final String label;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: latest ? SettingsColors.accentOf(context) : colors.tile,
        borderRadius: BorderRadius.circular(OnsetTokens.radiusPill),
        border: latest
            ? null
            : Border.all(
                color: colors.switchRing,
                width: OnsetTokens.hairlineWidth,
              ),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: _inter(
          12,
          weight: latest ? FontWeight.w800 : FontWeight.w700,
          spacing: -0.12,
          tabular: true,
          color: latest ? SettingsColors.onAccentOf(context) : colors.text,
        ),
      ),
    );
  }
}

/// The signal-coloured pill of the one main action ("Got it").
class ReleasePrimaryButton extends StatelessWidget {
  const ReleasePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 48,
    this.fontSize = 15,
    this.expand = true,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;
  final double fontSize;

  /// Takes the whole width (the phone's bar) or only its label's.
  final bool expand;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: label,
    // The detector's own tap is excluded with its subtree: say it here.
    onTap: onPressed,
    excludeSemantics: true,
    child: PressScale(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SettingsColors.accentOf(context),
            borderRadius: BorderRadius.circular(OnsetTokens.radiusPill),
          ),
          child: Text(
            label,
            style: _inter(
              fontSize,
              weight: FontWeight.w700,
              color: SettingsColors.onAccentOf(context),
            ),
          ),
        ),
      ),
    ),
  );
}

/// "You were on 1.0.2", with [after] following it.
class ReleaseWasOn extends StatelessWidget {
  const ReleaseWasOn(
    this.version, {
    super.key,
    this.after = '',
    this.fontSize = 14,
    this.maxLines,
  });

  final String version;
  final String after;
  final double fontSize;

  /// Cut with an ellipsis past this many lines (the tablet's header: one).
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return Text.rich(
      TextSpan(
        text: 'You were on ',
        children: [
          TextSpan(
            text: version,
            style: OnsetType.tabular(TextStyle(color: colors.body)),
          ),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: _inter(fontSize, height: 1.5, color: colors.secondary),
    );
  }
}

/// The phone's "Just updated" opening: the ONSET tile with a check, "WHAT'S
/// NEW IN 1.1.0", "Updated to 1.1.0", and the version it came from.
class ReleaseFreshHero extends StatelessWidget {
  const ReleaseFreshHero({super.key, required this.to, this.from});

  final String to;
  final String? from;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final ground = Theme.of(context).scaffoldBackgroundColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Row(
            spacing: 14,
            children: [
              SizedBox.square(
                dimension: 52,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const ExcludeSemantics(
                      child: OnsetMarkTile(size: 52, radius: 15),
                    ),
                    Positioned(
                      right: -5,
                      bottom: -5,
                      child: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ground,
                          shape: BoxShape.circle,
                          border: Border.all(color: ground, width: 2),
                        ),
                        child: SettingsGlyph(
                          SettingsGlyphKind.check,
                          size: 14,
                          strokeWidth: 2.8,
                          color: SettingsColors.accentOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    ReleaseEyebrow("WHAT'S NEW IN $to"),
                    Semantics(
                      header: true,
                      child: Text(
                        'Updated to $to',
                        style: _inter(
                          24,
                          weight: FontWeight.w800,
                          spacing: -0.72,
                          height: 1.1,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (from case final from?)
            ReleaseWasOn(from, after: '. Here is what changed since then.'),
        ],
      ),
    );
  }
}

/// One section of a version: its glyph, its name and how many points it
/// has, then its points.
class ReleaseSectionView extends StatelessWidget {
  const ReleaseSectionView(this.section, {super.key, this.gap = 10});

  final ReleaseEntrySection section;

  /// Between the heading and the points (12 in a tablet's card).
  final double gap;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final title = section.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        if (title != null)
          Row(
            spacing: 10,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.tile,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.cardRing,
                    width: OnsetTokens.hairlineWidth,
                  ),
                ),
                child: SettingsGlyph(
                  section.kind.glyph,
                  size: 15,
                  color: colors.tileIcon,
                ),
              ),
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _inter(
                      13,
                      weight: FontWeight.w700,
                      spacing: 0.78,
                      color: colors.body,
                    ),
                  ),
                ),
              ),
              Text(
                '${section.count}',
                semanticsLabel: section.count == 1
                    ? '1 point'
                    : '${section.count} points',
                style: _inter(
                  12,
                  weight: FontWeight.w600,
                  tabular: true,
                  color: colors.tertiary,
                ),
              ),
            ],
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            for (final item in section.items)
              switch (item) {
                ReleasePoint() => ReleasePointView(item),
                ReleaseParagraph(:final text) => ReleaseRichText(
                  text,
                  style: _inter(14, height: 1.55, color: colors.secondary),
                ),
                _ => const SizedBox.shrink(),
              },
          ],
        ),
      ],
    );
  }
}

/// A point: a dot (a ring for a point under a point), its platform tag, its
/// text.
class ReleasePointView extends StatelessWidget {
  const ReleasePointView(this.point, {super.key});

  final ReleasePoint point;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final sub = point.level > 0;
    return Padding(
      padding: EdgeInsets.only(left: sub ? 16 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 9),
            decoration: BoxDecoration(
              color: sub ? null : colors.tertiary,
              shape: BoxShape.circle,
              border: sub ? Border.all(color: colors.tertiary) : null,
            ),
          ),
          Expanded(
            child: ReleaseRichText(
              point.text,
              platform: point.platform,
              style: _inter(14, height: 1.5, color: colors.body),
            ),
          ),
        ],
      ),
    );
  }
}

/// A link, `**bold**` or `` `code` ``.
final _inlinePattern = RegExp(
  r'\[([^\]]+)\]\(([^)\s]+)\)|\*\*([^*]+)\*\*|`([^`]+)`',
);

/// [href] when it is a web link (http or https, with a host): only those
/// are ever opened from the notes.
Uri? releaseLinkOf(String href) {
  final uri = Uri.tryParse(href);
  if (uri == null ||
      !(uri.isScheme('http') || uri.isScheme('https')) ||
      uri.host.isEmpty) {
    return null;
  }
  return uri;
}

/// [text] with its `**bold**`, `` `code` ``, and `[label](url)` links
/// tappable when they are web links (any other scheme is its label, as
/// text). The [platform] tag ("iOS", "Android") comes first.
class ReleaseRichText extends StatefulWidget {
  const ReleaseRichText(
    this.text, {
    super.key,
    required this.style,
    this.platform,
  });

  final String text;
  final TextStyle style;
  final String? platform;

  @override
  State<ReleaseRichText> createState() => _ReleaseRichTextState();
}

class _ReleaseRichTextState extends State<ReleaseRichText> {
  /// One recognizer per link, kept until the text goes.
  final _links = <String, TapGestureRecognizer>{};

  @override
  void didUpdateWidget(ReleaseRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  void _clear() {
    for (final link in _links.values) {
      link.dispose();
    }
    _links.clear();
  }

  void _open(Uri uri) {
    final external = context.read<SettingsStore>().launchUrlExternal;
    unawaited(
      LinkRouter.open(uri.toString(), launchExternal: external).catchError(
        (Object e) => debugPrint('Release notes link: ${e.runtimeType}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final accent = SettingsColors.accentOf(context);
    final text = widget.text;
    final spans = <InlineSpan>[
      if (widget.platform case final platform?)
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            height: 18,
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: colors.tile,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: colors.buttonRing,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
            // Centred, yet as wide as its name: the container's own
            // alignment would stretch the tag across the whole line.
            child: Align(
              widthFactor: 1,
              child: Text(
                platform,
                style: _inter(
                  10,
                  weight: FontWeight.w600,
                  spacing: 0.2,
                  color: colors.secondary,
                ),
              ),
            ),
          ),
        ),
    ];
    var start = 0;
    for (final match in _inlinePattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      if (match.group(1) case final label?) {
        final uri = releaseLinkOf(match.group(2)!);
        if (uri == null) {
          spans.add(TextSpan(text: label));
        } else {
          final link = _links.putIfAbsent(
            uri.toString(),
            () => TapGestureRecognizer()..onTap = () => _open(uri),
          );
          spans.add(
            TextSpan(
              text: label,
              style: TextStyle(
                color: accent,
                decoration: TextDecoration.underline,
                decorationColor: accent,
              ),
              recognizer: link,
            ),
          );
        }
      } else if (match.group(3) case final bold?) {
        spans.add(
          TextSpan(
            text: bold,
            style: TextStyle(fontWeight: FontWeight.w700, color: colors.text),
          ),
        );
      } else {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: colors.tile,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: colors.trackRing,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
              child: Text(
                match.group(4)!,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: _inter(
                  13,
                  weight: FontWeight.w500,
                  tabular: true,
                  color: colors.text,
                ),
              ),
            ),
          ),
        );
      }
      start = match.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return Text.rich(TextSpan(children: spans), style: widget.style);
  }
}

/// A version's paragraphs (its note), 14/1.55 in the secondary grey.
class ReleaseNotesParagraphs extends StatelessWidget {
  const ReleaseNotesParagraphs(this.paragraphs, {super.key});

  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      for (final paragraph in paragraphs)
        ReleaseRichText(
          paragraph,
          style: _inter(
            14,
            height: 1.55,
            color: SettingsColors.of(context).secondary,
          ),
        ),
    ],
  );
}

/// The phone's card of the latest version: its pill, "Latest", its date,
/// "ONSET 1.1.0", its counts, its note and its sections.
class ReleaseLatestCard extends StatelessWidget {
  const ReleaseLatestCard(this.entry, {super.key, this.latest = true});

  final ReleaseEntry entry;

  /// The newest entry ("Latest", the signal pill); false when an update
  /// leads with an older entry than one already written.
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.cardRing,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 18,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Row(
                spacing: 8,
                children: [
                  ReleaseVersionPill(entry.label, latest: latest),
                  if (latest)
                    Text(
                      'Latest',
                      style: _inter(
                        12,
                        weight: FontWeight.w600,
                        color: colors.body,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      entry.date ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: _inter(12.5, color: colors.secondary),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      entry.name,
                      style: _inter(
                        20,
                        weight: FontWeight.w700,
                        spacing: -0.4,
                        color: colors.text,
                      ),
                    ),
                  ),
                  if (entry.summary.isNotEmpty)
                    Text(
                      entry.summary,
                      style: _inter(
                        12.5,
                        tabular: true,
                        color: colors.tertiary,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (entry.notes.isNotEmpty) ReleaseNotesParagraphs(entry.notes),
          for (final section in entry.sections) ReleaseSectionView(section),
        ],
      ),
    );
  }
}

/// A version's line in a list: "v1.0.2  November 3, 2026" over its counts.
class _VersionLines extends StatelessWidget {
  const _VersionLines({
    required this.entry,
    this.latest = false,
    this.selected,
  });

  final ReleaseEntry entry;

  /// The tablet's "LATEST" chip.
  final bool latest;

  /// The tablet's choice (null on the phone's list).
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final tablet = selected != null;
    final version = Text(
      entry.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _inter(
        16,
        weight: selected ?? false ? FontWeight.w800 : FontWeight.w700,
        spacing: -0.16,
        tabular: true,
        color: !tablet || selected! ? colors.text : colors.body,
      ),
    );
    final date = entry.date == null
        ? null
        : Text(
            entry.date!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _inter(12.5, color: colors.secondary),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: tablet ? 4 : 3,
      children: [
        if (tablet)
          Row(
            spacing: 8,
            children: [
              Flexible(child: version),
              if (latest)
                Container(
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SettingsColors.accentOf(context),
                    borderRadius: BorderRadius.circular(OnsetTokens.radiusPill),
                  ),
                  child: Text(
                    'LATEST',
                    style: _inter(
                      10.5,
                      weight: FontWeight.w800,
                      spacing: 0.42,
                      color: SettingsColors.onAccentOf(context),
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  entry.date ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: _inter(12.5, color: colors.secondary),
                ),
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 10,
            children: [
              Flexible(child: version),
              if (date != null) Flexible(child: date),
            ],
          ),
        if (entry.summary.isNotEmpty)
          Text(
            entry.summary,
            style: _inter(12.5, tabular: true, color: colors.tertiary),
          ),
      ],
    );
  }
}

/// What the screen reader says for a version's row.
String _rowLabel(ReleaseEntry entry, {bool latest = false}) => [
  entry.label,
  if (latest) 'Latest',
  ?entry.date,
  if (entry.summary.isNotEmpty) entry.summary,
].join(', ');

/// The phone's "Earlier versions": one row per version, each opening in
/// place to show its note and sections.
class ReleaseEarlierVersions extends StatelessWidget {
  const ReleaseEarlierVersions({
    super.key,
    this.title = 'Earlier versions',
    required this.entries,
    required this.indexes,
    required this.open,
    required this.onToggle,
  });

  final String title;

  /// Every entry of the notes, and the positions of those listed here.
  final List<ReleaseEntry> entries;
  final List<int> indexes;

  /// The positions open.
  final Set<int> open;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ReleaseListLabel(title),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.cardRing,
              width: OnsetTokens.hairlineWidth,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (row, index) in indexes.indexed)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: row == 0
                            ? null
                            : Border(
                                top: BorderSide(
                                  color: colors.hairline,
                                  width: OnsetTokens.hairlineWidth,
                                ),
                              ),
                      ),
                      child: _EarlierRow(
                        key: ValueKey(index),
                        entry: entries[index],
                        open: open.contains(index),
                        onToggle: () => onToggle(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EarlierRow extends StatefulWidget {
  const _EarlierRow({
    super.key,
    required this.entry,
    required this.open,
    required this.onToggle,
  });

  final ReleaseEntry entry;
  final bool open;
  final VoidCallback onToggle;

  @override
  State<_EarlierRow> createState() => _EarlierRowState();
}

class _EarlierRowState extends State<_EarlierRow>
    with SingleTickerProviderStateMixin {
  /// Opening and closing: a critically damped 300 ms spring, picking up
  /// from wherever it is when tapped again.
  static final _spring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 300),
  );

  late final _progress = AnimationController.unbounded(
    vsync: this,
    value: widget.open ? 1 : 0,
  );

  @override
  void didUpdateWidget(_EarlierRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open == widget.open) return;
    final target = widget.open ? 1.0 : 0.0;
    if (reduceMotionOf(context)) {
      _progress.value = target;
      return;
    }
    // A spring settles within a tolerance: land exactly on the target, so a
    // closed body is dropped and an open one drawn without its clip.
    _progress
        .animateWith(
          SpringSimulation(
            _spring,
            _progress.value,
            target,
            _progress.velocity,
          ),
        )
        .then((_) {
          if (mounted) _progress.value = target;
        });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _toggle() {
    unawaited(Haptics.selection());
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final entry = widget.entry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          button: true,
          expanded: widget.open,
          label: _rowLabel(entry),
          onTap: _toggle,
          excludeSemantics: true,
          child: InkWell(
            onTap: _toggle,
            splashFactory: NoSplash.splashFactory,
            highlightColor: colors.pressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                child: Row(
                  spacing: 12,
                  children: [
                    Expanded(child: _VersionLines(entry: entry)),
                    AnimatedBuilder(
                      animation: _progress,
                      builder: (context, child) => Transform.rotate(
                        angle: _progress.value.clamp(0.0, 1.0) * math.pi,
                        child: child,
                      ),
                      child: SettingsGlyph(
                        SettingsGlyphKind.chevronDown,
                        strokeWidth: 2,
                        color: colors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _progress,
          builder: (context, child) {
            final value = _progress.value.clamp(0.0, 1.0);
            // Closed: not built at all (nor read by a screen reader).
            if (value == 0 && !widget.open) return const SizedBox.shrink();
            if (value == 1) return child!;
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: value,
                child: Opacity(
                  opacity: (value / 0.8).clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 18,
              children: [
                if (entry.notes.isNotEmpty) ReleaseNotesParagraphs(entry.notes),
                for (final section in entry.sections)
                  ReleaseSectionView(section),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A version in the tablet's list: 68 dp, tinted and ringed in the signal
/// colour when it is the one shown.
class ReleaseVersionRow extends StatelessWidget {
  const ReleaseVersionRow({
    super.key,
    required this.entry,
    required this.latest,
    required this.selected,
    required this.onTap,
  });

  final ReleaseEntry entry;
  final bool latest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final accent = SettingsColors.accentOf(context);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: _rowLabel(entry, latest: latest),
      onTap: onTap,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: settingsMotion(context, 220),
            curve: OnsetMotion.standard,
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: selected ? 0.10 : 0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accent.withValues(alpha: selected ? 0.45 : 0),
                width: OnsetTokens.hairlineWidth,
              ),
            ),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: _VersionLines(
                    entry: entry,
                    latest: latest,
                    selected: selected,
                  ),
                ),
                SettingsGlyph(
                  SettingsGlyphKind.chevronRight,
                  strokeWidth: 2,
                  color: selected ? accent : colors.tertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The tablet's details of one version: its pill and date, "ONSET 1.1.0",
/// its counts and note, its sections as cards (in two columns when there is
/// room), and Newer / Older.
class ReleaseDetail extends StatelessWidget {
  const ReleaseDetail({
    super.key,
    required this.entry,
    required this.latest,
    this.newer,
    this.older,
    required this.onNewer,
    required this.onOlder,
  });

  final ReleaseEntry entry;
  final bool latest;

  /// The versions next to it, and how to show them.
  final ReleaseEntry? newer;
  final ReleaseEntry? older;
  final VoidCallback onNewer;
  final VoidCallback onOlder;

  /// From this width the sections sit in two columns.
  static const twoColumnsFrom = 560.0;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 22,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Row(
              spacing: 10,
              children: [
                ReleaseVersionPill(entry.label, latest: latest),
                if (entry.date case final date?)
                  Flexible(
                    child: Text(
                      date,
                      style: _inter(13, color: colors.secondary),
                    ),
                  ),
              ],
            ),
            Semantics(
              header: true,
              child: Text(
                entry.name,
                style: _inter(
                  34,
                  weight: FontWeight.w800,
                  spacing: -1.19,
                  height: 1.05,
                  color: colors.text,
                ),
              ),
            ),
            if (entry.summary.isNotEmpty)
              Text(
                entry.summary,
                style: _inter(13, tabular: true, color: colors.tertiary),
              ),
            if (entry.notes.isNotEmpty) ReleaseNotesParagraphs(entry.notes),
          ],
        ),
        if (entry.sections.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                for (final section in entry.sections) _SectionCard(section),
              ];
              if (constraints.maxWidth < twoColumnsFrom || cards.length < 2) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 20,
                  children: cards,
                );
              }
              final split = balancedSplit([
                for (final section in entry.sections) _weight(section),
              ]);
              Widget column(List<Widget> children) => Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 20,
                  children: children,
                ),
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 20,
                children: [
                  column(cards.sublist(0, split)),
                  column(cards.sublist(split)),
                ],
              );
            },
          ),
        if (newer != null || older != null)
          Container(
            padding: const EdgeInsets.only(top: 18),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colors.hairline,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
            ),
            child: Row(
              children: [
                if (newer case final newer?)
                  _StepButton(
                    label: 'Newer',
                    version: newer.label,
                    forward: false,
                    onTap: onNewer,
                  ),
                const Spacer(),
                if (older case final older?)
                  _StepButton(
                    label: 'Older',
                    version: older.label,
                    forward: true,
                    onTap: onOlder,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Roughly how tall a section's card is, in lines.
  static double _weight(ReleaseEntrySection section) {
    var lines = section.title == null ? 1.0 : 3.0;
    for (final item in section.items) {
      final text = switch (item) {
        ReleasePoint(:final text) => text,
        ReleaseParagraph(:final text) => text,
        _ => '',
      };
      lines += 1 + text.length / 48;
    }
    return lines;
  }
}

/// Where to cut [weights] (kept in order) into two columns of about the same
/// height; the first column takes the extra, as CSS columns do. Always
/// leaves at least one in each column when there are two or more.
int balancedSplit(List<double> weights) {
  if (weights.length < 2) return weights.length;
  final total = weights.fold<double>(0, (sum, w) => sum + w);
  var best = 1;
  var bestGap = double.infinity;
  var left = 0.0;
  for (var cut = 1; cut < weights.length; cut++) {
    left += weights[cut - 1];
    final right = total - left;
    // The first column may be longer, never shorter, at the same gap.
    final gap = (left - right).abs() + (left < right ? 0.001 : 0);
    if (gap < bestGap) {
      bestGap = gap;
      best = cut;
    }
  }
  return best;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(this.section);

  final ReleaseEntrySection section;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.cardRing,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      child: ReleaseSectionView(section, gap: 12),
    );
  }
}

/// "‹ Newer v1.1.0" / "Older v1.0.1 ›".
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.version,
    required this.forward,
    required this.onTap,
  });

  final String label;
  final String version;
  final bool forward;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final chevron = SettingsGlyph(
      forward ? SettingsGlyphKind.chevronRight : SettingsGlyphKind.chevronLeft,
      strokeWidth: 2,
      color: colors.body,
    );
    return Semantics(
      container: true,
      button: true,
      label: '$label, $version',
      onTap: onTap,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 44,
            padding: EdgeInsets.only(
              left: forward ? 16 : 10,
              right: forward ? 10 : 16,
            ),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(OnsetTokens.radiusPill),
              border: Border.all(
                color: colors.buttonRing,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (!forward) chevron,
                Text(
                  label,
                  style: _inter(
                    13.5,
                    weight: FontWeight.w600,
                    color: colors.body,
                  ),
                ),
                Text(
                  version,
                  style: _inter(13.5, tabular: true, color: colors.tertiary),
                ),
                if (forward) chevron,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "No release notes yet", in a 24 dp panel on a tablet.
class ReleaseEmptyState extends StatelessWidget {
  const ReleaseEmptyState({super.key, required this.tablet});

  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final disc = tablet ? 96.0 : 88.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: disc,
          height: disc,
          margin: const EdgeInsets.only(bottom: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.card,
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.buttonRing,
              width: OnsetTokens.hairlineWidth,
            ),
          ),
          child: SettingsGlyph(
            SettingsGlyphKind.notes,
            size: tablet ? 38 : 34,
            color: colors.secondary,
          ),
        ),
        Semantics(
          header: true,
          child: Text(
            'No release notes yet',
            textAlign: TextAlign.center,
            style: _inter(
              tablet ? 22 : 20,
              weight: FontWeight.w700,
              spacing: tablet ? -0.44 : -0.3,
              color: colors.text,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tablet ? 380 : 280),
          child: Text(
            'What changes in each version of ONSET shows up here, and opens '
            'by itself after an update.',
            textAlign: TextAlign.center,
            style: _inter(14, height: 1.55, color: colors.secondary),
          ),
        ),
      ],
    );
  }
}

/// The tablet's round back button: 44 dp, on a card, ringed.
class ReleaseRoundBack extends StatelessWidget {
  const ReleaseRoundBack({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return IconButton(
      tooltip: 'Back',
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: colors.card,
        splashFactory: NoSplash.splashFactory,
        shape: CircleBorder(
          side: BorderSide(
            color: colors.buttonRing,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
      ),
      icon: SettingsGlyph(
        SettingsGlyphKind.chevronLeft,
        size: 22,
        strokeWidth: 2,
        color: colors.text,
      ),
    );
  }
}

/// A section kind's glyph: New ✦, Improvements ↗, Fixes 🔧, anything else a
/// neutral list.
extension ReleaseSectionGlyph on ReleaseSectionKind {
  SettingsGlyphKind get glyph => switch (this) {
    ReleaseSectionKind.added => SettingsGlyphKind.sparkle,
    ReleaseSectionKind.improved => SettingsGlyphKind.trendUp,
    ReleaseSectionKind.fixed => SettingsGlyphKind.wrench,
    ReleaseSectionKind.other => SettingsGlyphKind.list,
  };
}
