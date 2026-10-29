import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

/// The release notes (board MiseAJour): each version with its date, its
/// sections and their points, a platform tag where a point is for one.
class ReleaseNotes extends StatefulWidget {
  static const routeName = 'ReleaseNotes';

  /// Replaces the bundled notes in tests.
  static Future<String> Function()? debugSource;

  /// The release notes' Markdown (assets/release-notes.md).
  static Future<String> load() =>
      (debugSource ?? () => rootBundle.loadString('assets/release-notes.md'))();

  const ReleaseNotes({super.key});

  @override
  State<ReleaseNotes> createState() => _ReleaseNotesState();
}

class _ReleaseNotesState extends State<ReleaseNotes> {
  final _scrollController = ScrollController();

  /// One recognizer per link, made once and kept until the page goes.
  final _links = <String, TapGestureRecognizer>{};
  List<ReleaseNotesBlock> _blocks = const [];

  @override
  void initState() {
    super.initState();

    ReleaseNotes.load().then((changelog) {
      if (!mounted) return;
      setState(() => _blocks = parseReleaseNotes(changelog));
    });
  }

  @override
  void dispose() {
    for (final link in _links.values) {
      link.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _open(String href) => launchSettingsLink(
    href,
    external: context.read<SettingsStore>().launchUrlExternal,
  );

  /// [text] with its `[label](url)` links tappable, its `**bold**` and
  /// `` `code` `` drawn as such.
  TextSpan _inline(String text, TextStyle style, Color linkColor) {
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _inlinePattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      if (match.group(1) case final label?) {
        final href = match.group(2)!;
        final link = _links.putIfAbsent(
          href,
          () => TapGestureRecognizer()..onTap = () => _open(href),
        );
        spans.add(
          TextSpan(
            text: label,
            style: TextStyle(
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
            ),
            recognizer: link,
          ),
        );
      } else if (match.group(3) case final bold?) {
        spans.add(
          TextSpan(
            text: bold,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: match.group(4),
            style: OnsetType.tabular(const TextStyle()),
          ),
        );
      }
      start = match.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return TextSpan(style: style, children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final accent = SettingsColors.accentOf(context);
    final padding = MediaQuery.paddingOf(context);
    final body = TextStyle(
      fontFamily: OnsetTokens.bodyFamily,
      fontSize: 14,
      height: 1.5,
      color: colors.body,
    );

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(
          "WHAT'S NEW",
          style: TextStyle(
            fontFamily: OnsetTokens.bodyFamily,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.26,
            color: accent,
          ),
        ),
      ),
    ];
    for (final block in _blocks) {
      children.add(switch (block) {
        ReleaseVersion(:final version, :final date) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 12,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    version,
                    style: TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: colors.text,
                    ),
                  ),
                ),
              ),
              if (date != null)
                Text(
                  date,
                  style: TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 12.5,
                    color: colors.secondary,
                  ),
                ),
            ],
          ),
        ),
        ReleaseSection(:final title) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: OnsetTokens.bodyFamily,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.78,
                color: colors.body,
              ),
            ),
          ),
        ),
        ReleasePoint(:final text, :final platform, :final level) => Padding(
          padding: EdgeInsets.only(bottom: 8, left: level * 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 9),
                decoration: BoxDecoration(
                  color: colors.tertiary,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (platform != null)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            height: 18,
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.tile,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: colors.buttonRing,
                                width: OnsetTokens.hairlineWidth,
                              ),
                            ),
                            child: Text(
                              platform,
                              style: TextStyle(
                                fontFamily: OnsetTokens.bodyFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colors.secondary,
                              ),
                            ),
                          ),
                        ),
                      _inline(text, body, accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ReleaseRule() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(
            height: OnsetTokens.hairlineWidth,
            thickness: OnsetTokens.hairlineWidth,
            color: colors.hairline,
          ),
        ),
        ReleaseParagraph(:final text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text.rich(_inline(text, body, accent)),
        ),
      });
    }

    return SettingsScaffold(
      title: 'Release notes',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              20 + padding.left,
              padding.top + 18,
              20 + padding.right,
              padding.bottom + 28,
            ),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// A link, `**bold**` or `` `code` ``.
final _inlinePattern = RegExp(
  r'\[([^\]]+)\]\(([^)\s]+)\)|\*\*([^*]+)\*\*|`([^`]+)`',
);

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
    if (line.isEmpty) continue;
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

/// Whether the release notes open by themselves at launch: only after an
/// update to a new major.minor version (never on a first launch, when
/// [lastShown] is null), and only when [notes] have an entry for [current]
/// ("## v1.1.0" or "## 1.1.0").
bool shouldShowReleaseNotes({
  required String? lastShown,
  required String current,
  required String notes,
}) {
  if (lastShown == null) return false;
  String majorMinor(String version) => version.split('.').take(2).join('.');
  if (majorMinor(lastShown) == majorMinor(current)) return false;
  return parseReleaseNotes(notes).whereType<ReleaseVersion>().any(
    (entry) => entry.version.replaceFirst(RegExp('^v'), '') == current,
  );
}
