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
  'lib/l10n/enum_labels.dart',
  'lib/l10n/l10n.dart',
  'lib/main.dart',
  'lib/screens/home/home.dart',
  'lib/screens/home/language_prompt.dart',
  'lib/screens/home/shell/onset_shell.dart',
  'lib/screens/home/shell/shell_glyph.dart',
  'lib/screens/home/shell/shell_pages.dart',
  'lib/screens/home/shell/shell_tabs.dart',
  'lib/screens/home/stores/home_store.dart',
  'lib/screens/onboarding/login_webview.dart',
  'lib/screens/onboarding/onboarding_accent_picker.dart',
  'lib/screens/onboarding/onboarding_flow.dart',
  'lib/screens/onboarding/onboarding_intro.dart',
  'lib/screens/onboarding/onboarding_language_choice.dart',
  'lib/screens/onboarding/onboarding_login.dart',
  'lib/screens/onboarding/onboarding_parts.dart',
  'lib/screens/onboarding/onboarding_setup.dart',
  'lib/screens/onboarding/onboarding_welcome.dart',
  'lib/screens/settings/widgets/language_setting.dart',
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
