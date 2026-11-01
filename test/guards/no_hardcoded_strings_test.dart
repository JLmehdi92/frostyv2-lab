import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'hardcoded_strings.dart';
import 'l10n_allowlist.dart';
import 'l10n_baseline.dart';

/// Every text a viewer reads comes from the ARB files (lib/l10n), so it is
/// in French and in English. Files still being translated are counted in
/// l10n_baseline.dart, a ratchet that only goes down; what is never
/// translated (brands, Twitch's data) is in l10n_allowlist.dart, with why.
void main() {
  group('the scanner', () {
    List<String> texts(String source) => [
      for (final literal in flaggedIn(source)) literal.text,
    ];

    test('flags text in places that show it', () {
      expect(
        texts('''
import 'package:flutter/material.dart';

enum Tab { home('Home'); const Tab(this.label); final String label; }

class A extends StatelessWidget {
  const A({super.key, this.title = 'Default title'});
  final String title;
  @override
  Widget build(BuildContext context) => Column(children: [
    const Text('Hello'),
    Text('Signed in as \$name'),
    Tooltip(message: 'Close', child: Text(x ? 'On' : 'Off')),
    Semantics(label: 'Step', value: 'Step 1 of 4'),
    IconButton(tooltip: 'Back'.toUpperCase(), onPressed: null),
    Text.rich(TextSpan(text: 'Logged in as ')),
    SnackBar(content: Text('Link copied')),
    Thing(primaryLabel: 'Save'),
  ]);
}

const themeNames = ['System', 'Light'];
'''),
        unorderedEquals([
          'Home',
          'Default title',
          'Hello',
          'Signed in as {}',
          'Close',
          'On',
          'Off',
          'Step',
          'Step 1 of 4',
          'Back',
          'Logged in as ',
          'Link copied',
          'Save',
          'System',
          'Light',
        ]),
      );
    });

    test('flags sentences anywhere, joined across lines', () {
      expect(
        texts('''
const tip = 'Links to the full changelog are in '
    'the settings.';
String f(String name) => 'Could not open \$name channel';
'''),
        [
          'Links to the full changelog are in the settings.',
          'Could not open {} channel',
        ],
      );
    });

    test('flags the words inside an interpolation, not the frame', () {
      expect(
        texts("final x = Row(label: '\${pinned ? 'Unpin' : 'Pin'} \$name');"),
        ['Unpin', 'Pin'],
      );
    });

    test('leaves code alone', () {
      expect(
        texts(r'''
import 'package:onset/main.dart';
part 'a.g.dart';

@JsonKey(name: 'Display Name')
var a = 1;

void f(Map<String, dynamic> json, SharedPreferences prefs) {
  debugPrint('Could not load the page: $e');
  _log('subscribe polls failed: $e');
  _reportUnexpected(e, s, 'offline check at start');
  _reportRateTrouble(StateError('live rate stayed at 1.05x'), s);
  Telemetry.recordError(e, s, reason: 'go-live init failed');
  assert(x, 'This must never happen here');
  if (x == 'Some label') return;
  switch (y) { case 'Other words': break; }
  final z = switch (y) { 'Two words' => 1, _ => 2 };
  prefs.setString('first run', 'x');
  json['Some Key'];
  final m = {'Map key words': 1};
  RegExp(r'Latency To Broadcaster');
  Uri.https('www.twitch.tv', '/some path');
  const ValueKey('signing in');
  RouteSettings(name: 'Release Notes');
  const MethodChannel('onset/locale channel');
  throw StateError('No user here');
  throw ApiException('Unable to connect');
  Text('recent-messages.robotty.de');
  Text('https://twitch.tv/x');
  Text('assets/release-notes.md');
  Text(""" Multi line script with words """);
  Text('predictions-channel-v1');
  Text('LAST_DAY');
  Text('#C8FF3D');
  Text('v5.0.5');
  Text('$count');
}

class B {
  @override
  String toString() => 'B with words($a)';
}
'''),
        isEmpty,
      );
    });

    test('hole: text under a widget or call named …Error or …Exception', () {
      expect(
        texts('''
Widget a() => FeedError(child: Text('Something went wrong'));
void b() => _showError('Could not load clips now');
ApiException c() => UnauthorizedException('Please log in to continue');
ApiException d() => NotFoundException('Resource not found');
'''),
        [
          'Something went wrong',
          'Could not load clips now',
          'Please log in to continue',
          'Resource not found',
        ],
      );
      // A thrown one is code (its message is for logs).
      expect(texts("void e() => throw StateError('No user here');"), isEmpty);
    });

    test('hole: one word with trailing punctuation in a place that shows '
        'text', () {
      expect(
        texts('''
final a = Text('Loading...');
final b = Text('Error:');
final c = Text('Done.');
final d = Row(label: 'Viewers:');
'''),
        ['Loading...', 'Error:', 'Done.', 'Viewers:'],
      );
      // Still code: a dotted version, snake_case, a host.
      expect(
        texts('''
final a = Text('v5.0.5');
final b = Text('first_run');
final c = Text('twitch.tv');
'''),
        isEmpty,
      );
    });

    test('hole: literals handed to the project\'s own helpers that show '
        'text', () {
      expect(
        texts('''
void _tell(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
void _announce(String title, {required String detail}) =>
    _tell(context, '\$title: \$detail');
void f(BuildContext context) {
  _tell(context, 'Saved');
  _announce('Update', detail: 'Ready');
}
'''),
        ['Saved', 'Update', 'Ready'],
      );
    });

    test('hole: option lists, label maps and label getters', () {
      expect(
        texts('''
final a = SettingsListSelect(options: ['Small', 'Large'], selectedOption: 'Small');
const sizeLabels = {CaptionSize.small: 'Tiny'};
class B {
  String get label => 'Following';
  String title(int i) {
    return 'Welcome';
  }
}
'''),
        ['Small', 'Large', 'Small', 'Tiny', 'Following', 'Welcome'],
      );
    });

    test('hole: a local constant later shown as text', () {
      expect(
        texts('''
Widget a() {
  const w = 'Welcome';
  final x = flag ? 'Live' : 'Offline';
  return Column(children: [Text(w), Tooltip(message: x)]);
}
Widget b() {
  const id = 'channel';
  return Text(lookup(id));
}
'''),
        ['Welcome', 'Live', 'Offline'],
      );
    });

    test('hole: text returned by a helper whose result is shown', () {
      expect(
        texts(r'''
String viewersText(int n) => '$n viewers';
String _status(bool on) {
  if (on) return 'Live';
  return 'Offline';
}
String _key(int n) => 'row-$n';
Widget a(int n) => Column(children: [
  Text(viewersText(n)),
  Semantics(label: _status(true)),
  KeyedSubtree(key: ValueKey(_key(n)), child: const SizedBox()),
]);
'''),
        ['{} viewers', 'Live', 'Offline'],
      );
    });

    test('hole: single words as the values of a map read into text', () {
      expect(
        texts('''
const _kinds = {Kind.live: 'Live', Kind.vod: 'Video'};
const _routes = {Kind.live: 'livePage'};
class A {
  final Kind kind;
  Widget build(BuildContext context) =>
      Text(_kinds[kind]!, semanticsLabel: describe(_routes[kind]));
}
'''),
        ['Live', 'Video'],
      );
    });

    test('hole: text assigned to a field or a variable, in setState too', () {
      expect(
        texts('''
class Store {
  String? _error;
  String? message;
  void load() {
    _error = 'Failed';
    message ??= 'Try later';
  }
}
class _S extends State<W> {
  String msg = '';
  void f() => setState(() => msg = 'Failed');
  Widget build(BuildContext context) => Text(msg);
}
Widget a(bool b) {
  var t = 'Live';
  if (b) t = 'Offline';
  return Text(t);
}
void codes() {
  var mode = 'live';
  mode = 'offline';
  _status = 'connecting';
  send(mode);
}
'''),
        ['Failed', 'Try later', 'Failed', 'Live', 'Offline'],
      );
    });

    test('hole: labelOf and builder closures returning words', () {
      expect(
        texts('''
final a = SettingsListSelect(
  labelOf: (v) => switch (v) { K.a => 'Live', K.b => 'Offline' },
);
final b = Thing(textBuilder: (c) => 'Welcome');
final c = Thing(labelBuilder: (c) {
  return 'Hello';
});
final d = Thing(onTap: (c) => 'tapped');
'''),
        ['Live', 'Offline', 'Welcome', 'Hello'],
      );
    });

    test('hole: getters read as properties, extension getters too', () {
      expect(
        texts('''
class A {
  String get caption2 => 'Welcome';
  String get routeId => 'home';
  Widget build(BuildContext context) => Text(caption2);
}
enum K { a }
extension on K {
  String get word => 'Live';
}
Widget b(K k) => Text(k.word);
'''),
        ['Welcome', 'Live'],
      );
    });

    test('hole: joined lists, a list\'s first word, StringBuffer.write', () {
      expect(
        texts('''
Widget a(int n) => Column(children: [
  Text([n, 'Live'].join(' · ')),
  Text(['Welcome', 'Hi'].first),
]);
String b() {
  final out = StringBuffer();
  out.write('Live');
  out.writeln('Offline');
  return out.toString();
}
'''),
        ['Live', 'Welcome', 'Hi', 'Live', 'Offline'],
      );
    });

    test('hole: a positional constructor field shown as text', () {
      expect(
        texts('''
class Chip2 extends StatelessWidget {
  const Chip2(this.words, this.id, {super.key, this.caption2});
  final String words;
  final String id;
  final String? caption2;
  Widget build(BuildContext context) =>
      Column(children: [Text(words), Text(caption2 ?? ''), Key2(id)]);
}
class _Pill extends StatefulWidget {
  const _Pill(this.shown);
  final String shown;
}
class _PillState extends State<_Pill> {
  Widget build(BuildContext context) => Text(widget.shown);
}
final a = Chip2('Watch streak', 'row-id', caption2: 'Caption');
final b = const _Pill('Shown');
'''),
        ['Watch streak', 'Caption', 'Shown'],
      );
    });

    test('hole: sentences holding a semicolon or a brace, not code', () {
      expect(
        texts('''
const a = 'Slow mode; then wait';
const b = 'Press {Enter} to send';
const c = 'query { user(login: x) { id } }';
const d = 'body { margin: 0 }';
const e = 'if (a) { b; }';
const f = 'two words;';
'''),
        ['Slow mode; then wait', 'Press {Enter} to send'],
      );
    });

    test('hole: the keys of a map of screen-reader actions', () {
      expect(
        texts('''
Widget a(bool landscape) => VideoSurfaceSemantics(
  actions: {if (landscape) 'Change chat layout': cycle, 'Rewind': back},
  child: x,
);
Widget b() => Semantics(customSemanticsActions: {'Collapse': f}, child: x);
final c = {'Map key words': 1};
'''),
        ['Change chat layout', 'Rewind', 'Collapse'],
      );
    });

    test('hole: a word with one hyphen in a place that shows text', () {
      expect(
        texts('''
Widget a() => Column(children: [
  const Text('pop-up'),
  Tab(text: 'sign-in'),
  Tooltip(message: 'e-mail'),
]);
void b(Map<String, String> tags) {
  if (tags['msg-id'] == 'sub-gift') return;
  final kind = 'msg-id';
  send(kind);
}
'''),
        ['pop-up', 'sign-in', 'e-mail'],
      );
    });

    test('hole: a sentence with a colon or a bracket and a semicolon in a '
        'place that shows text', () {
      expect(
        texts('''
Widget a() => Column(children: [
  const Text('Note: this may take a while; please wait'),
  const Text('Slow mode (30s); followers only'),
]);
void b() => use('if (a) { b; }');
'''),
        [
          'Note: this may take a while; please wait',
          'Slow mode (30s); followers only',
        ],
      );
    });

    test('hole: a cascade write, a filtered list joined, +=', () {
      expect(
        texts(r'''
Widget a() {
  final b = StringBuffer()..write('Live')..writeln('Offline');
  return Text(b.toString());
}
Widget c(String t) =>
    Text(['Prediction', t].where((s) => s.isNotEmpty).join(', '));
Widget d(List<String?> t) => Text([...t, 'Poll'].nonNulls.join(', '));
Widget e(int n) {
  var t = '$n';
  t += ' watching';
  return Text(t);
}
'''),
        ['Live', 'Offline', 'Prediction', 'Poll', ' watching'],
      );
    });

    test('hole: record rows read back by destructuring', () {
      expect(
        texts('''
Widget a(String v) {
  final rows = <(String, String)>[('Latency', v), ('Buffer', v)];
  return Column(children: [for (final (label, value) in rows) Text(label)]);
}
Widget b(String v) => Column(children: [
  for (final (label, _) in [('Bitrate', v)]) Text(label),
]);
Widget c() {
  final rows = [('row-id', 1)];
  return Column(children: [for (final (id, n) in rows) Key2(id, n)]);
}
'''),
        ['Latency', 'Buffer', 'Bitrate'],
      );
    });

    test('says where a literal is and why', () {
      final [literal] = flaggedIn(
        "\n\nfinal t = Text('Hello');\n",
        path: 'lib/x.dart',
      );
      expect(literal.path, 'lib/x.dart');
      expect(literal.line, 3);
      expect(literal.reason, 'ui');
    });
  });

  group('the allow-list and the ratchet', () {
    const hello = FlaggedLiteral(
      path: 'lib/a.dart',
      line: 1,
      text: 'Hello',
      reason: 'ui',
    );
    const brand = FlaggedLiteral(
      path: 'lib/a.dart',
      line: 2,
      text: 'ONSET',
      reason: 'ui',
    );

    test('an allow-listed literal is not counted', () {
      expect(
        notAllowed(
          [hello, brand],
          {
            'lib/a.dart': {'ONSET': 'brand'},
          },
        )['lib/a.dart'],
        [hello],
      );
    });

    test('an allow-list entry matching nothing is stale', () {
      expect(
        staleAllowlistEntries(
          [hello],
          {
            'lib/a.dart': {'Gone': 'extracted'},
            'lib/gone.dart': {'ONSET': 'deleted file'},
          },
        ),
        ['lib/a.dart: Gone', 'lib/gone.dart: ONSET'],
      );
      expect(
        staleAllowlistEntries(
          [brand],
          {
            'lib/a.dart': {'ONSET': 'brand'},
          },
        ),
        isEmpty,
      );
    });

    test('a new file with literals fails', () {
      expect(ratchetProblems({'lib/new.dart': 1}, {}), hasLength(1));
    });

    test('more literals than the baseline fails', () {
      expect(
        ratchetProblems({'lib/a.dart': 3}, {'lib/a.dart': 2}).single,
        contains('allows 2'),
      );
    });

    test('fewer literals fails until the baseline is lowered', () {
      expect(
        ratchetProblems({'lib/a.dart': 1}, {'lib/a.dart': 2}).single,
        contains('lower it to 1'),
      );
    });

    test('a baseline entry for a clean or deleted file is stale', () {
      expect(ratchetProblems({'lib/a.dart': 0}, {'lib/a.dart': 2}), [
        contains('remove it'),
      ]);
      expect(ratchetProblems({}, {'lib/gone.dart': 2}), [
        contains('remove it'),
      ]);
    });

    test('equal counts pass', () {
      expect(
        ratchetProblems(
          {'lib/a.dart': 2, 'lib/clean.dart': 0},
          {'lib/a.dart': 2},
        ),
        isEmpty,
      );
    });
  });

  group('lib/', () {
    late List<FlaggedLiteral> flagged;
    late int fileCount;

    setUpAll(() {
      final files = scannedFiles();
      fileCount = files.length;
      final sources = {for (final file in files) file: file.readAsStringSync()};
      // The project's helpers that show text, found across lib/.
      final helpers = uiHelpersIn(sources.values);
      flagged = [
        for (final MapEntry(key: file, value: source) in sources.entries)
          ...flaggedIn(
            source,
            path: file.path.replaceAll('\\', '/'),
            helpers: helpers,
          ),
      ];
    });

    test('is read, generated code excepted', () {
      expect(fileCount, greaterThan(300));
      final paths = scannedFiles().map((f) => f.path.replaceAll('\\', '/'));
      expect(paths, contains('lib/main.dart'));
      expect(paths, contains('lib/l10n/l10n.dart'));
      expect(paths.where((p) => p.endsWith('.g.dart')), isEmpty);
      expect(
        paths.where((p) => p.contains('lib/l10n/app_localizations')),
        isEmpty,
      );
    });

    test('the allow-list has no stale entry', () {
      expect(staleAllowlistEntries(flagged, l10nAllowlist), isEmpty);
    });

    test(
      'each file has exactly the hard-coded strings its baseline allows',
      () {
        final left = notAllowed(flagged, l10nAllowlist);
        final counts = {
          for (final MapEntry(key: path, value: literals) in left.entries)
            path: literals.length,
        };
        final problems = ratchetProblems(counts, l10nBaseline);
        expect(
          problems,
          isEmpty,
          reason: [
            ...problems,
            for (final path in counts.keys)
              if (!l10nBaseline.containsKey(path))
                ...left[path]!.map((literal) => '$literal'),
          ].join('\n'),
        );
      },
    );

    test('the files translated so far stay clean', () {
      final left = notAllowed(flagged, l10nAllowlist);
      for (final path in _translated) {
        expect(File(path).existsSync(), isTrue, reason: '$path is gone');
        expect(left[path], isNull, reason: path);
        expect(l10nBaseline.containsKey(path), isFalse, reason: path);
      }
    });
  });
}

/// Files whose texts are all in the ARB files: none may come back.
const _translated = [
  'lib/apis/base_api_client.dart',
  'lib/apis/twitch_directory_service.dart',
  'lib/l10n/api_errors.dart',
  'lib/l10n/enum_labels.dart',
  'lib/l10n/l10n.dart',
  'lib/main.dart',
  'lib/models/badges.dart',
  'lib/models/celebration.dart',
  'lib/models/clip.dart',
  'lib/models/community_highlight_event.dart',
  'lib/models/community_highlights.dart',
  'lib/models/community_points.dart',
  'lib/models/emotes.dart',
  'lib/models/hype_train.dart',
  'lib/models/hype_train_event.dart',
  'lib/models/irc.dart',
  'lib/models/user_notice.dart',
  'lib/models/user_notice_text.dart',
  'lib/models/vod.dart',
  'lib/models/watch_streak.dart',
  'lib/screens/activity/activity_screen.dart',
  'lib/screens/activity/stores/activity_store.dart',
  'lib/screens/channel/celebrations/celebration_art.dart',
  'lib/screens/channel/celebrations/celebration_overlay.dart',
  'lib/screens/channel/celebrations/onset_rocket.dart',
  'lib/screens/channel/celebrations/particles/celebration_particles.dart',
  'lib/screens/channel/celebrations/particles/celebration_sprites.dart',
  'lib/screens/channel/celebrations/particles/celebration_view.dart',
  'lib/screens/channel/celebrations/signal_pill.dart',
  'lib/screens/channel/celebrations/subtle_celebrations.dart',
  'lib/screens/channel/channel.dart',
  'lib/screens/channel/channel_info.dart',
  'lib/screens/channel/channel_top_overlays.dart',
  'lib/screens/channel/chat/chat.dart',
  'lib/screens/channel/chat/chat_commands.dart',
  'lib/screens/channel/chat/chat_delay_queue.dart',
  'lib/screens/channel/chat/chat_filters.dart',
  'lib/screens/channel/chat/chat_history.dart',
  'lib/screens/channel/chat/chat_restrictions.dart',
  'lib/screens/channel/chat/details/chat_details.dart',
  'lib/screens/channel/chat/details/chat_mode_controls.dart',
  'lib/screens/channel/chat/details/chat_modes.dart',
  'lib/screens/channel/chat/details/chat_users_list.dart',
  'lib/screens/channel/chat/details/stores/chat_details_store.dart',
  'lib/screens/channel/chat/emote_menu/emote_menu.dart',
  'lib/screens/channel/chat/emote_menu/emote_menu_panel.dart',
  'lib/screens/channel/chat/emote_menu/emote_menu_section.dart',
  'lib/screens/channel/chat/emote_menu/recent_emotes_panel.dart',
  'lib/screens/channel/chat/gift_bomb_tracker.dart',
  'lib/screens/channel/chat/held_messages.dart',
  'lib/screens/channel/chat/incoming_raid.dart',
  'lib/screens/channel/chat/moderation.dart',
  'lib/screens/channel/chat/moderation_notice.dart',
  'lib/screens/channel/chat/muted_words.dart',
  'lib/screens/channel/chat/stores/chat_assets_store.dart',
  'lib/screens/channel/chat/stores/chat_rules_store.dart',
  'lib/screens/channel/chat/stores/chat_store.dart',
  'lib/screens/channel/chat/stores/chat_tabs_store.dart',
  'lib/screens/channel/chat/widgets/add_chat_dialog.dart',
  'lib/screens/channel/chat/widgets/animated_scroll_border.dart',
  'lib/screens/channel/chat/widgets/channel_points_button.dart',
  'lib/screens/channel/chat/widgets/channel_points_sheet.dart',
  'lib/screens/channel/chat/widgets/chat_bottom_bar.dart',
  'lib/screens/channel/chat/widgets/chat_character_counter.dart',
  'lib/screens/channel/chat/widgets/chat_gif_image.dart',
  'lib/screens/channel/chat/widgets/chat_link_card.dart',
  'lib/screens/channel/chat/widgets/chat_message.dart',
  'lib/screens/channel/chat/widgets/chat_moderation_bar.dart',
  'lib/screens/channel/chat/widgets/chat_restriction_bar.dart',
  'lib/screens/channel/chat/widgets/chat_rules_sheet.dart',
  'lib/screens/channel/chat/widgets/chat_tabs.dart',
  'lib/screens/channel/chat/widgets/chat_user_modal.dart',
  'lib/screens/channel/chat/widgets/emote_text_span_builder.dart',
  'lib/screens/channel/chat/widgets/filtered_message_sheet.dart',
  'lib/screens/channel/chat/widgets/first_frame_image.dart',
  'lib/screens/channel/chat/widgets/gift_bomb_recipients.dart',
  'lib/screens/channel/chat/widgets/overlay_chat_scope.dart',
  'lib/screens/channel/chat/widgets/raid_welcome_card.dart',
  'lib/screens/channel/chat/widgets/reply_thread.dart',
  'lib/screens/channel/chat/widgets/user_card_info.dart',
  'lib/screens/channel/chat/widgets/user_notice_row.dart',
  'lib/screens/channel/community_highlights/gift_bomb_feed.dart',
  'lib/screens/channel/community_highlights/highlight_math.dart',
  'lib/screens/channel/community_highlights/highlight_reducers.dart',
  'lib/screens/channel/community_highlights/highlight_stack.dart',
  'lib/screens/channel/community_highlights/highlight_timings.dart',
  'lib/screens/channel/community_highlights/pinned_to_irc.dart',
  'lib/screens/channel/community_highlights/raid_departure.dart',
  'lib/screens/channel/community_highlights/raid_text.dart',
  'lib/screens/channel/community_highlights/stores/community_highlights_store.dart',
  'lib/screens/channel/community_highlights/widgets/gift_bomb_pin.dart',
  'lib/screens/channel/community_highlights/widgets/highlight_card_shell.dart',
  'lib/screens/channel/community_highlights/widgets/highlight_cards.dart',
  'lib/screens/channel/community_highlights/widgets/highlight_countdown.dart',
  'lib/screens/channel/community_highlights/widgets/highlight_slot.dart',
  'lib/screens/channel/community_highlights/widgets/incoming_raid_pin.dart',
  'lib/screens/channel/community_highlights/widgets/pinned_chat_text.dart',
  'lib/screens/channel/community_highlights/widgets/raid_avatar.dart',
  'lib/screens/channel/community_highlights/widgets/raid_card.dart',
  'lib/screens/channel/community_highlights/widgets/raid_heading_overlay.dart',
  'lib/screens/channel/hype_train/hype_train_clock.dart',
  'lib/screens/channel/hype_train/hype_train_math.dart',
  'lib/screens/channel/hype_train/hype_train_placement.dart',
  'lib/screens/channel/hype_train/hype_train_queue.dart',
  'lib/screens/channel/hype_train/hype_train_reducer.dart',
  'lib/screens/channel/hype_train/hype_train_sequence.dart',
  'lib/screens/channel/hype_train/hype_train_timings.dart',
  'lib/screens/channel/hype_train/stores/hype_train_store.dart',
  'lib/screens/channel/hype_train/widgets/effects/coin_unlock.dart',
  'lib/screens/channel/hype_train/widgets/effects/hype_train_avatar_stack.dart',
  'lib/screens/channel/hype_train/widgets/effects/merge_aura.dart',
  'lib/screens/channel/hype_train/widgets/effects/mythic_reveal.dart',
  'lib/screens/channel/hype_train/widgets/effects/rainbow_sweep.dart',
  'lib/screens/channel/hype_train/widgets/effects/rocket_launch.dart',
  'lib/screens/channel/hype_train/widgets/effects/speedlines.dart',
  'lib/screens/channel/hype_train/widgets/effects/trophy_burst.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_approaching_banner.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_banner.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_card_pill.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_copy.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_countdown.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_end_strip.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_level_pill.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_marquee.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_palette.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_pill_shell.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_progress_bar.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_sheet.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_slot.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_split_color.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_tokens.dart',
  'lib/screens/channel/hype_train/widgets/hype_train_video_pill.dart',
  'lib/screens/channel/landscape_chat_cycle.dart',
  'lib/screens/channel/portrait_split.dart',
  'lib/screens/channel/stores/channel_events_store.dart',
  'lib/screens/channel/stores/channel_info_store.dart',
  'lib/screens/channel/stores/create_clip_store.dart',
  'lib/screens/channel/tablet_video_column.dart',
  'lib/screens/channel/video/buffer_fallback.dart',
  'lib/screens/channel/video/caption_menu.dart',
  'lib/screens/channel/video/captions.dart',
  'lib/screens/channel/video/content_warning_gate.dart',
  'lib/screens/channel/video/create_clip_sheet.dart',
  'lib/screens/channel/video/ivs_player_config.dart',
  'lib/screens/channel/video/ivs_recovery.dart',
  'lib/screens/channel/video/ivs_stats_panel.dart',
  'lib/screens/channel/video/ivs_video.dart',
  'lib/screens/channel/video/latency_controller.dart',
  'lib/screens/channel/video/latency_pill.dart',
  'lib/screens/channel/video/latency_stats.dart',
  'lib/screens/channel/video/live_edge_guard.dart',
  'lib/screens/channel/video/live_progress.dart',
  'lib/screens/channel/video/live_state_watcher.dart',
  'lib/screens/channel/video/native_video.dart',
  'lib/screens/channel/video/overlay_common.dart',
  'lib/screens/channel/video/pinch_to_fill.dart',
  'lib/screens/channel/video/player_controller.dart',
  'lib/screens/channel/video/player_engine_resolver.dart',
  'lib/screens/channel/video/player_glyph.dart',
  'lib/screens/channel/video/quality_selection.dart',
  'lib/screens/channel/video/stores/caption_store.dart',
  'lib/screens/channel/video/stores/ivs_video_store.dart',
  'lib/screens/channel/video/stores/native_video_store.dart',
  'lib/screens/channel/video/stores/video_store.dart',
  'lib/screens/channel/video/stream_info_bar.dart',
  'lib/screens/channel/video/video.dart',
  'lib/screens/channel/video/video_overlay.dart',
  'lib/screens/channel/video/web_content_gate.dart',
  'lib/screens/channel/video/web_page_init.dart',
  'lib/screens/channel_profile/channel_profile_screen.dart',
  'lib/screens/channel_profile/stores/channel_profile_store.dart',
  'lib/screens/channel_profile/widgets/profile_about_tab.dart',
  'lib/screens/channel_profile/widgets/profile_header.dart',
  'lib/screens/channel_profile/widgets/profile_home_tab.dart',
  'lib/screens/channel_profile/widgets/profile_live_card.dart',
  'lib/screens/channel_profile/widgets/profile_parts.dart',
  'lib/screens/channel_profile/widgets/profile_schedule_tab.dart',
  'lib/screens/channel_profile/widgets/profile_videos_tab.dart',
  'lib/screens/clips/clip_media_backend.dart',
  'lib/screens/clips/clip_screen.dart',
  'lib/screens/clips/clips_feed_screen.dart',
  'lib/screens/clips/stores/channel_clips_store.dart',
  'lib/screens/clips/stores/clip_player_store.dart',
  'lib/screens/clips/stores/clips_feed_store.dart',
  'lib/screens/clips/widgets/channel_clips_tab.dart',
  'lib/screens/clips/widgets/clip_card.dart',
  'lib/screens/clips/widgets/clip_filter_bar.dart',
  'lib/screens/clips/widgets/clip_info_panel.dart',
  'lib/screens/clips/widgets/more_clips_sliver.dart',
  'lib/screens/home/continue_watching/continue_watching.dart',
  'lib/screens/home/continue_watching/stores/continue_watching_store.dart',
  'lib/screens/home/followed_videos/followed_videos_screen.dart',
  'lib/screens/home/followed_videos/stores/followed_videos_store.dart',
  'lib/screens/home/home.dart',
  'lib/screens/home/language_prompt.dart',
  'lib/screens/home/live_feed/live_feed.dart',
  'lib/screens/home/live_feed/live_preview.dart',
  'lib/screens/home/live_feed/stores/live_feed_store.dart',
  'lib/screens/home/search/featured_channel.dart',
  'lib/screens/home/search/search.dart',
  'lib/screens/home/search/search_results_categories.dart',
  'lib/screens/home/search/search_results_channels.dart',
  'lib/screens/home/search/search_results_videos.dart',
  'lib/screens/home/search/stores/search_store.dart',
  'lib/screens/home/search/stores/search_videos_store.dart',
  'lib/screens/home/shell/onset_shell.dart',
  'lib/screens/home/shell/shell_glyph.dart',
  'lib/screens/home/shell/shell_pages.dart',
  'lib/screens/home/shell/shell_tabs.dart',
  'lib/screens/home/stores/home_store.dart',
  'lib/screens/home/stream_list/expandable_section_header.dart',
  'lib/screens/home/stream_list/followed_categories_section.dart',
  'lib/screens/home/stream_list/large_stream_card.dart',
  'lib/screens/home/stream_list/offline_channel_card.dart',
  'lib/screens/home/stream_list/stores/stream_list_store.dart',
  'lib/screens/home/stream_list/stream_card.dart',
  'lib/screens/home/stream_list/stream_card_parts.dart',
  'lib/screens/home/stream_list/stream_sort_button.dart',
  'lib/screens/home/stream_list/stream_tags.dart',
  'lib/screens/home/stream_list/streams_list.dart',
  'lib/screens/home/stream_list/watch_streak_tag.dart',
  'lib/screens/home/top/browse_page.dart',
  'lib/screens/home/top/categories/categories.dart',
  'lib/screens/home/top/categories/category_card.dart',
  'lib/screens/home/top/categories/category_streams.dart',
  'lib/screens/home/top/categories/stores/categories_store.dart',
  'lib/screens/home/top/tags/tag_streams.dart',
  'lib/screens/onboarding/login_webview.dart',
  'lib/screens/onboarding/onboarding_accent_picker.dart',
  'lib/screens/onboarding/onboarding_flow.dart',
  'lib/screens/onboarding/onboarding_intro.dart',
  'lib/screens/onboarding/onboarding_language_choice.dart',
  'lib/screens/onboarding/onboarding_login.dart',
  'lib/screens/onboarding/onboarding_parts.dart',
  'lib/screens/onboarding/onboarding_setup.dart',
  'lib/screens/onboarding/onboarding_welcome.dart',
  'lib/screens/settings/account/account_settings.dart',
  'lib/screens/settings/account/blocked_users.dart',
  'lib/screens/settings/chat_settings.dart',
  'lib/screens/settings/general_settings.dart',
  'lib/screens/settings/notifications_settings.dart',
  'lib/screens/settings/other_settings.dart',
  'lib/screens/settings/profile_tab.dart',
  'lib/screens/settings/settings.dart',
  'lib/screens/settings/settings_master_detail.dart',
  'lib/screens/settings/stores/auth_store.dart',
  'lib/screens/settings/stores/settings_store.dart',
  'lib/screens/settings/stores/user_store.dart',
  'lib/screens/settings/video_settings.dart',
  'lib/screens/settings/widgets/accent_color_setting.dart',
  'lib/screens/settings/widgets/caption_style_setting.dart',
  'lib/screens/settings/widgets/chat_filters_setting.dart',
  'lib/screens/settings/widgets/external_browser_setting.dart',
  'lib/screens/settings/widgets/go_live_setting.dart',
  'lib/screens/settings/widgets/hidden_content_labels_setting.dart',
  'lib/screens/settings/widgets/language_setting.dart',
  'lib/screens/settings/widgets/mention_notification_setting.dart',
  'lib/screens/settings/widgets/release_notes.dart',
  'lib/screens/settings/widgets/release_notes_parts.dart',
  'lib/screens/settings/widgets/settings_glyph.dart',
  'lib/screens/settings/widgets/settings_kit.dart',
  'lib/screens/settings/widgets/settings_list_select.dart',
  'lib/screens/settings/widgets/settings_list_slider.dart',
  'lib/screens/settings/widgets/settings_list_switch.dart',
  'lib/screens/settings/widgets/settings_muted_words.dart',
  'lib/screens/settings/widgets/settings_page.dart',
  'lib/screens/settings/widgets/settings_twitch_web_token.dart',
  'lib/screens/settings/widgets/stream_language_setting.dart',
  'lib/screens/settings/widgets/theme_selection_setting.dart',
  'lib/screens/settings/widgets/update_check_tile.dart',
  'lib/screens/vod/channel_videos.dart',
  'lib/screens/vod/stores/channel_videos_store.dart',
  'lib/screens/vod/vod_overlay.dart',
  'lib/screens/vod/vod_time.dart',
  'lib/screens/vod/widgets/channel_videos_tab.dart',
  'lib/screens/vod/widgets/video_back_button.dart',
  'lib/screens/vod/widgets/video_card_layout.dart',
  'lib/screens/vod/widgets/video_kit.dart',
  'lib/screens/vod/widgets/vod_card.dart',
  'lib/screens/vod/widgets/vod_error_view.dart',
  'lib/screens/vod/widgets/vod_info_strip.dart',
  'lib/screens/whispers/whisper_conversation.dart',
  'lib/screens/whispers/whisper_kit.dart',
  'lib/screens/whispers/whisper_notice.dart',
  'lib/screens/whispers/whispers_screen.dart',
  'lib/services/notifications/activity_log.dart',
  'lib/services/realtime/twitch_eventsub_client.dart',
  'lib/utils/content_labels.dart',
  'lib/utils/irc_privmsg_builder.dart',
  'lib/utils/stream_languages.dart',
  'lib/widgets/accent_picker_controls.dart',
  'lib/widgets/adaptive_sliver_list.dart',
  'lib/widgets/alert_message.dart',
  'lib/widgets/blurred_container.dart',
  'lib/widgets/draggable_divider.dart',
  'lib/widgets/global_mini_player.dart',
  'lib/widgets/launch/launch_intro.dart',
  'lib/widgets/launch/onset_mark.dart',
  'lib/widgets/live_indicator.dart',
  'lib/widgets/motion/haptics.dart',
  'lib/widgets/motion/motion.dart',
  'lib/widgets/motion/press_scale.dart',
  'lib/widgets/motion/reduce_motion.dart',
  'lib/widgets/motion/rolling_number.dart',
  'lib/widgets/motion/signal_ping.dart',
  'lib/widgets/motion/staggered_entrance.dart',
  'lib/widgets/onset_alert_dialog.dart',
  'lib/widgets/onset_cached_network_image.dart',
  'lib/widgets/onset_chip.dart',
  'lib/widgets/onset_notification.dart',
  'lib/widgets/onset_photo_view_dialog.dart',
  'lib/widgets/onset_scrollbar.dart',
  'lib/widgets/onset_update_prompt.dart',
  'lib/widgets/profile_picture.dart',
  'lib/widgets/scroll_to_top_button.dart',
  'lib/widgets/settled_blur.dart',
  'lib/widgets/sheet/onset_panel.dart',
  'lib/widgets/sheet/onset_sheet.dart',
  'lib/widgets/sheet/sheet_glyph.dart',
  'lib/widgets/sheet/svg_path.dart',
  'lib/widgets/skeleton_loader.dart',
  'lib/widgets/state_glyph.dart',
  'lib/widgets/state_views.dart',
  'lib/widgets/twitch_web_page.dart',
  'lib/widgets/uptime.dart',
  'lib/widgets/user_actions_modal.dart',
];
