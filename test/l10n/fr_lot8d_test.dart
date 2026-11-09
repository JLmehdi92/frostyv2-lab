import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/clip_comment.dart';
import 'package:onset/models/recap.dart';
import 'package:onset/screens/channel_profile/widgets/profile_recaps_shelf.dart';
import 'package:onset/screens/clips/clip_story_screen.dart';
import 'package:onset/screens/clips/recap_screen.dart';
import 'package:onset/screens/clips/widgets/clip_comments_sheet.dart';
import 'package:onset/screens/clips/widgets/clip_info_panel.dart';
import 'package:onset/screens/settings/account/edit_profile.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';

import '../fixtures/clip_extras_payloads.dart';
import '../helpers/fake_vod_controller.dart';
import '../helpers/l10n.dart';
import '../screens/clips/clip_extras_widgets_test.dart'
    show clipFixture, commentActions, commentFixture, sheetHost;
import '../screens/settings/edit_profile_test.dart' show Calls, profileActions;

Recap _recap() => Recap.tryParse(recapNode())!;

const _content = [
  'Caster',
  'Clipper',
  'Superbe action',
  'Viewer1',
  'Viewer2',
  'Warzone night',
  'im down',
  'second',
  'Speedruns on weekends.',
  'YouTube',
  'https://youtube.com/@caster',
  '@caster',
  'A clip',
  'Call of Duty',
];

Widget _editProfilePage() => Builder(
  builder: (context) => SettingsScaffold(
    title: SettingsPageId.editProfile.title(context.l10n),
    body: EditProfile(actions: profileActions(Calls())),
  ),
);

Map<String, Widget Function()> lot8dScreens() => {
  'the clip comments': () => sheetHost(
    ClipCommentsSheet(
      load: (_) async => ClipCommentPage(
        items: [
          commentFixture('1'),
          commentFixture('2', collapsed: true, liked: true),
        ],
        cursor: 'next',
      ),
      actions: commentActions(),
    ),
  ),
  'the clip comments, follow first': () => sheetHost(
    ClipCommentsSheet(
      load: (_) async => const ClipCommentPage(items: []),
      actions: commentActions(
        eligibility: const ClipCommentEligibility(
          allowed: false,
          block: ClipCommentBlock.followTooRecent,
          requiredFollowMinutes: 10,
        ),
      ),
    ),
  ),
  'the clip details with the extras': () => Scaffold(
    body: SingleChildScrollView(
      child: ClipInfoPanel(
        clip: clipFixture('Slug'),
        onCopyLink: () {},
        onShare: () {},
        onDownload: () {},
        autoClip: true,
        onWatchPortrait: () {},
        onComments: () {},
      ),
    ),
  ),
  'the recaps shelf': () => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: ProfileRecapsShelf(load: () async => [_recap(), _recap()]),
    ),
  ),
  'a recap playing': () => RecapScreen(
    recap: _recap(),
    playerFactory: (clip, {required portrait}) => FakeVodController(),
  ),
  'a recap no longer available': () => RecapScreen(
    recap: _recap(),
    refresh: (_) async => throw const RecapUnavailableException(),
    playerFactory: (clip, {required portrait}) => FakeVodController(),
  ),
  'a portrait clip': () => ClipStoryScreen(
    clips: [clipFixture('Slug')],
    title: 'Caster',
    portrait: true,
    playerFactory: (clip, {required portrait}) => FakeVodController(),
  ),
  'the edit profile page': _editProfilePage,
};

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final locale in sweepLocales) {
    for (final (name, size) in frenchScreenSizes) {
      for (final scale in frenchTextScales) {
        final at = '$name, text ×$scale${sweepName(locale)}';
        for (final MapEntry(key: screen, value: build)
            in lot8dScreens().entries) {
          testWidgets('$screen, $at', (tester) async {
            await pumpLocalized(
              tester,
              build(),
              locale: locale,
              size: size,
              textScale: scale,
            );
            await _settle(tester);
            await expectFrenchThroughout(
              tester,
              '$screen, $at',
              content: _content,
            );
          });
        }

        for (final (dialog, key) in [
          ('display name', EditProfile.displayNameKey),
          ('username', EditProfile.usernameKey),
          ('bio', EditProfile.bioKey),
          ('social link', EditProfile.linkKey('a')),
        ]) {
          testWidgets('the $dialog dialog, $at', (tester) async {
            await pumpLocalized(
              tester,
              _editProfilePage(),
              locale: locale,
              size: size,
              textScale: scale,
            );
            await _settle(tester);
            await tester.scrollUntilVisible(
              find.byKey(key),
              200,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.tap(find.byKey(key));
            await _settle(tester);
            await expectFrenchThroughout(
              tester,
              '$dialog dialog, $at',
              content: _content,
            );
          });
        }
      }
    }
  }
}
