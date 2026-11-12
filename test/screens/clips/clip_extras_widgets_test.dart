import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/clip_comment.dart';
import 'package:onset/models/profile_edit.dart';
import 'package:onset/screens/clips/clip_story_screen.dart';
import 'package:onset/screens/clips/widgets/clip_comments_sheet.dart';
import 'package:onset/screens/clips/widgets/clip_info_panel.dart';
import 'package:onset/screens/vod/vod_player_controller.dart';
import 'package:onset/services/playback_focus.dart';

import '../../helpers/fake_vod_controller.dart';
import '../../helpers/l10n.dart';

Clip clipFixture(String slug, {String title = 'A clip'}) => Clip(
  id: slug,
  slug: slug,
  title: title,
  viewCount: 1200,
  createdAt: DateTime.utc(2026, 11, 8),
  durationSeconds: 30,
  broadcasterId: '1000',
  broadcasterLogin: 'caster',
  broadcasterDisplayName: 'Caster',
  curatorDisplayName: 'Clipper',
);

ClipComment commentFixture(
  String id, {
  bool collapsed = false,
  bool liked = false,
  int likes = 2,
  String body = 'Superbe action',
}) => ClipComment(
  id: id,
  body: body,
  createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  authorLogin: 'viewer_$id',
  authorDisplayName: 'Viewer$id',
  likeCount: likes,
  replyCount: 1,
  collapsed: collapsed,
  likedByViewer: liked,
);

ClipCommentActions commentActions({
  ClipCommentEligibility? eligibility = const ClipCommentEligibility(
    allowed: true,
  ),
  AccountEditResult<ClipComment>? post,
  AccountEditOutcome like = AccountEditOutcome.done,
  List<String>? posted,
  List<(String, bool)>? likes,
}) => ClipCommentActions(
  eligibility: () async => eligibility,
  post: (body) async {
    posted?.add(body);
    return post ??
        AccountEditResult(
          AccountEditOutcome.done,
          value: commentFixture('new', body: body),
        );
  },
  setLiked: (id, liked) async {
    likes?.add((id, liked));
    return like;
  },
);

Widget sheetHost(Widget sheet) => Scaffold(
  body: Align(alignment: Alignment.bottomCenter, child: sheet),
);

void main() {
  group('ClipCommentsSheet', () {
    testWidgets('lists comments, reveals a hidden one and pages', (
      tester,
    ) async {
      final cursors = <String?>[];
      await pumpLocalized(
        tester,
        sheetHost(
          ClipCommentsSheet(
            load: (cursor) async {
              cursors.add(cursor);
              return cursor == null
                  ? ClipCommentPage(
                      items: [
                        commentFixture('1'),
                        commentFixture('2', collapsed: true, body: 'secret'),
                      ],
                      cursor: 'next',
                    )
                  : ClipCommentPage(items: [commentFixture('3')]);
            },
          ),
        ),
        locale: en,
      );
      await tester.pumpAndSettle();
      expect(find.text('Superbe action'), findsOneWidget);
      expect(find.text('secret'), findsNothing);
      expect(find.text('Hidden by the community'), findsOneWidget);
      await tester.tap(find.byKey(ClipCommentsSheet.showKey('2')));
      await tester.pump();
      expect(find.text('secret'), findsOneWidget);
      expect(find.text('Log in to post comments.'), findsOneWidget);
      await tester.tap(find.byKey(ClipCommentsSheet.moreKey));
      await tester.pumpAndSettle();
      expect(cursors, [null, 'next']);
      expect(find.byKey(ClipCommentsSheet.moreKey), findsNothing);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      var calls = 0;
      await pumpLocalized(
        tester,
        sheetHost(
          ClipCommentsSheet(
            load: (_) async {
              if (calls++ == 0) throw Exception('down');
              return const ClipCommentPage(items: []);
            },
          ),
        ),
        locale: en,
      );
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t load the comments.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No comments yet.'), findsOneWidget);
    });

    testWidgets('posts a comment on a tap and shows it first', (tester) async {
      final posted = <String>[];
      await pumpLocalized(
        tester,
        sheetHost(
          ClipCommentsSheet(
            load: (_) async => ClipCommentPage(items: [commentFixture('1')]),
            actions: commentActions(posted: posted),
          ),
        ),
        locale: en,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(ClipCommentsSheet.composerKey),
          matching: find.byType(TextField),
        ),
        'Hello there',
      );
      expect(posted, isEmpty);
      await tester.tap(find.byKey(ClipCommentsSheet.sendKey));
      await tester.pumpAndSettle();
      expect(posted, ['Hello there']);
      expect(find.text('Hello there'), findsOneWidget);
    });

    testWidgets('a refused comment says why and stays in the field', (
      tester,
    ) async {
      await pumpLocalized(
        tester,
        sheetHost(
          ClipCommentsSheet(
            load: (_) async => const ClipCommentPage(items: []),
            actions: commentActions(
              post: const AccountEditResult(
                AccountEditOutcome.refused,
                code: 'CONTAINS_LINK',
              ),
            ),
          ),
        ),
        locale: en,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'x.com');
      await tester.tap(find.byKey(ClipCommentsSheet.sendKey));
      await tester.pumpAndSettle();
      expect(find.text('Comments can’t contain links.'), findsOneWidget);
      expect(find.text('x.com'), findsOneWidget);
    });

    testWidgets('likes and unlikes, counting', (tester) async {
      final likes = <(String, bool)>[];
      await pumpLocalized(
        tester,
        sheetHost(
          ClipCommentsSheet(
            load: (_) async => ClipCommentPage(items: [commentFixture('1')]),
            actions: commentActions(likes: likes),
          ),
        ),
        locale: en,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ClipCommentsSheet.likeKey('1')));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byKey(ClipCommentsSheet.likeKey('1')));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(likes, [('1', true), ('1', false)]);
    });

    testWidgets('a refused like keeps the count and says so', (tester) async {
      await pumpLocalized(
        tester,
        sheetHost(
          ClipCommentsSheet(
            load: (_) async => ClipCommentPage(items: [commentFixture('1')]),
            actions: commentActions(like: AccountEditOutcome.failed),
          ),
        ),
        locale: en,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ClipCommentsSheet.likeKey('1')));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Couldn’t update your like.'), findsOneWidget);
    });

    testWidgets('no composer where Twitch says the viewer may not comment', (
      tester,
    ) async {
      await pumpLocalized(
        tester,
        sheetHost(
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
        locale: en,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ClipCommentsSheet.composerKey), findsNothing);
      expect(
        find.text(
          'You need to follow this channel for at least 10 minutes to comment on its clips.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an unknown eligibility hides the composer', (tester) async {
      await pumpLocalized(
        tester,
        sheetHost(
          ClipCommentsSheet(
            load: (_) async => const ClipCommentPage(items: []),
            actions: commentActions(eligibility: null),
          ),
        ),
        locale: en,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ClipCommentsSheet.composerKey), findsNothing);
      expect(
        find.text('Couldn’t check whether you can comment on this clip.'),
        findsOneWidget,
      );
    });
  });

  group('ClipInfoPanel', () {
    testWidgets('auto clip, comments and portrait only when given', (
      tester,
    ) async {
      var portrait = 0;
      var comments = 0;
      await pumpLocalized(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: ClipInfoPanel(
              clip: clipFixture('Slug'),
              onCopyLink: () {},
              onShare: () {},
              autoClip: true,
              onWatchPortrait: () => portrait++,
              onComments: () => comments++,
            ),
          ),
        ),
        locale: en,
      );
      expect(find.text('Auto clip'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('clip-portrait')));
      await tester.tap(find.byKey(const ValueKey('clip-comments')));
      expect((portrait, comments), (1, 1));
    });

    testWidgets('none of them by default', (tester) async {
      await pumpLocalized(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: ClipInfoPanel(
              clip: clipFixture('Slug'),
              onCopyLink: () {},
              onShare: () {},
            ),
          ),
        ),
        locale: en,
      );
      expect(find.byKey(const ValueKey('clip-auto')), findsNothing);
      expect(find.byKey(const ValueKey('clip-portrait')), findsNothing);
      expect(find.byKey(const ValueKey('clip-comments')), findsNothing);
    });
  });

  group('ClipStoryScreen', () {
    testWidgets('plays the clips one after another, portrait when asked', (
      tester,
    ) async {
      final players = <String, FakeVodController>{};
      final portraits = <bool>[];
      await pumpLocalized(
        tester,
        ClipStoryScreen(
          clips: [
            clipFixture('One', title: 'First'),
            clipFixture('Two'),
          ],
          title: 'Caster',
          portrait: true,
          playerFactory: (clip, {required portrait}) {
            portraits.add(portrait);
            return players[clip.slug] = FakeVodController();
          },
        ),
        locale: en,
      );
      await tester.pump();
      expect(find.text('First'), findsOneWidget);
      players['One']!.status = VodPlaybackStatus.ended;
      await tester.pump();
      expect(players.keys, ['One', 'Two']);
      expect(players['One']!.calls, contains('dispose'));
      await tester.tap(find.byKey(ClipStoryScreen.previousKey));
      await tester.pump();
      expect(find.text('First'), findsOneWidget);
      expect(portraits, everyElement(isTrue));
    });

    testWidgets('a story under another player stays silent', (tester) async {
      final created = <FakeVodController>[];
      await pumpLocalized(
        tester,
        ClipStoryScreen(
          clips: [clipFixture('One'), clipFixture('Two')],
          title: 'Caster',
          playerFactory: (clip, {required portrait}) {
            final player = FakeVodController();
            created.add(player);
            return player;
          },
        ),
        locale: en,
      );
      final other = Object();
      PlaybackFocus.shared
        ..register(other, onLost: () {}, onRegained: () {})
        ..claim(other);
      expect(created.first.calls, containsAll(['focused false', 'pause']));

      created.first.status = VodPlaybackStatus.ended;
      await tester.pump();
      expect(created.last.calls, contains('focused false'));

      PlaybackFocus.shared.release(other);
      expect(created.last.calls.last, 'focused true');
    });

    testWidgets('a clip that cannot play offers a retry', (tester) async {
      final created = <FakeVodController>[];
      await pumpLocalized(
        tester,
        ClipStoryScreen(
          clips: [clipFixture('One')],
          title: 'Caster',
          playerFactory: (clip, {required portrait}) {
            final player = FakeVodController();
            created.add(player);
            return player;
          },
        ),
        locale: en,
      );
      created.single.status = VodPlaybackStatus.failed;
      await tester.pump();
      await tester.tap(find.byWidgetPredicate((w) => w is TextButton));
      await tester.pump();
      expect(created, hasLength(2));
    });
  });
}
