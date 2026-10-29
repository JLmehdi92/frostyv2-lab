import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:onset/models/irc.dart' show regexEmoji;
import 'package:onset/screens/settings/stores/settings_store.dart';

/// The invisible character some clients add to repeat a message; never
/// masked, as chat removes it.
const _invisible = '\u{E0000}';

/// One AutoMod rating from a message's IRC `flags` tag: the characters
/// [start] to [end] (included) and their level, 0 to 7, in each category.
class AutoModFlag {
  const AutoModFlag({
    required this.start,
    required this.end,
    this.identity = 0,
    this.sexual = 0,
    this.aggressive = 0,
    this.profanity = 0,
  });

  final int start;
  final int end;
  final int identity;
  final int sexual;
  final int aggressive;
  final int profanity;
}

/// The most ratings read from one tag.
const _maxFlags = 100;

/// The ratings of a `flags` tag, `start-end:A.n/I.n/P.n/S.n` separated by
/// commas, read like the official app: an entry without a readable range
/// is skipped, an unreadable level is no level.
List<AutoModFlag> parseAutoModFlags(String? tag) {
  if (tag == null || tag.isEmpty) return const [];
  final flags = <AutoModFlag>[];
  for (final entry in tag.split(',')) {
    if (flags.length == _maxFlags) break;
    final colon = entry.indexOf(':');
    if (colon < 0) continue;
    final range = entry.substring(0, colon).split('-');
    if (range.length != 2) continue;
    final start = int.tryParse(range[0]);
    final end = int.tryParse(range[1]);
    if (start == null || end == null) continue;
    var identity = 0, sexual = 0, aggressive = 0, profanity = 0;
    for (final level in entry.substring(colon + 1).split('/')) {
      final parts = level.split('.');
      if (parts.length < 2) continue;
      final value = int.tryParse(parts[1]);
      if (value == null) continue;
      switch (parts[0]) {
        case 'I':
          identity = value;
        case 'S':
          sexual = value;
        case 'A':
          aggressive = value;
        case 'P':
          profanity = value;
      }
    }
    flags.add(
      AutoModFlag(
        start: start,
        end: end,
        identity: identity,
        sexual: sexual,
        aggressive: aggressive,
        profanity: profanity,
      ),
    );
  }
  return flags;
}

/// The official app's personal chat filters ("Edit Chat Filters").
class ChatFilterSettings {
  const ChatFilterSettings({
    required this.enabled,
    required this.discrimination,
    required this.sexual,
    required this.harassment,
    required this.profanity,
  });

  /// The filters as set in [settings].
  factory ChatFilterSettings.of(SettingsStore settings) => ChatFilterSettings(
    enabled: settings.chatFiltersEnabled,
    discrimination: settings.chatFilterDiscrimination,
    sexual: settings.chatFilterSexual,
    harassment: settings.chatFilterHarassment,
    profanity: settings.chatFilterProfanity,
  );

  /// The level from which a category is hidden, as in the official app.
  static const threshold = 3;

  final bool enabled;
  final bool discrimination;
  final bool sexual;
  final bool harassment;
  final bool profanity;

  /// Whether the text [flag] rates is hidden (the official app's test, in
  /// its order: aggressive, identity, profanity, sexual).
  bool hides(AutoModFlag flag) =>
      enabled &&
      ((harassment && flag.aggressive >= threshold) ||
          (discrimination && flag.identity >= threshold) ||
          (profanity && flag.profanity >= threshold) ||
          (sexual && flag.sexual >= threshold));

  ChatFilterSettings copyWith({
    bool? enabled,
    bool? discrimination,
    bool? sexual,
    bool? harassment,
    bool? profanity,
  }) => ChatFilterSettings(
    enabled: enabled ?? this.enabled,
    discrimination: discrimination ?? this.discrimination,
    sexual: sexual ?? this.sexual,
    harassment: harassment ?? this.harassment,
    profanity: profanity ?? this.profanity,
  );

  @override
  bool operator ==(Object other) =>
      other is ChatFilterSettings &&
      other.enabled == enabled &&
      other.discrimination == discrimination &&
      other.sexual == sexual &&
      other.harassment == harassment &&
      other.profanity == profanity;

  @override
  int get hashCode =>
      Object.hash(enabled, discrimination, sexual, harassment, profanity);
}

/// [text] with what [settings] hide replaced by `mark`, one per UTF-16
/// unit, or null when nothing is hidden. `mark` is a private-use character
/// [text] does not contain, so a hidden unit is always told apart from the
/// text a chatter sent (icon fonts use that range too).
///
/// Positions count characters (code points), like the `emotes` tag. Like
/// the official app, a range is used only when `start < end` and it ends
/// in the text, and ranges are taken by start, one that starts inside the
/// previous one being skipped (hidden or not). Spaces, emojis and the
/// invisible repeat character stay, so the masked text splits into the
/// same words as [text].
({String text, String mark})? maskFilteredText(
  String text,
  List<AutoModFlag> flags,
  ChatFilterSettings settings,
) {
  if (flags.isEmpty || !settings.enabled) return null;
  // Where each code point starts, in UTF-16 units.
  final starts = <int>[];
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    final isLow = unit >= 0xDC00 && unit <= 0xDFFF;
    final afterHigh =
        i > 0 &&
        text.codeUnitAt(i - 1) >= 0xD800 &&
        text.codeUnitAt(i - 1) <= 0xDBFF;
    if (!(isLow && afterHigh)) starts.add(i);
  }
  final sorted = [...flags]..sort((a, b) => a.start.compareTo(b.start));
  final hidden = <(int, int)>[];
  var next = 0;
  for (final flag in sorted) {
    if (flag.start < 0 || flag.start >= flag.end || flag.end >= starts.length) {
      continue;
    }
    if (flag.start < next) continue;
    next = flag.end + 1;
    if (!settings.hides(flag)) continue;
    final endUnit = flag.end + 1 < starts.length
        ? starts[flag.end + 1]
        : text.length;
    hidden.add((starts[flag.start], endUnit));
  }
  if (hidden.isEmpty) return null;
  final mark = _absentMark(text);
  if (mark == null) return null;

  final out = StringBuffer();
  var offset = 0;
  var masked = false;
  for (final character in text.characters) {
    final from = offset;
    offset += character.length;
    final inside = hidden.any((r) => from < r.$2 && offset > r.$1);
    if (inside &&
        character.trim().isNotEmpty &&
        character != _invisible &&
        !regexEmoji.hasMatch(character)) {
      out.write(mark * character.length);
      masked = true;
    } else {
      out.write(character);
    }
  }
  return masked ? (text: out.toString(), mark: mark) : null;
}

/// A private-use character missing from [text], or null when it holds all
/// 6400 of them (it cannot: a chat message is at most 500 characters).
String? _absentMark(String text) {
  for (var unit = 0xE000; unit <= 0xF8FF; unit++) {
    final mark = String.fromCharCode(unit);
    if (!text.contains(mark)) return mark;
  }
  return null;
}
