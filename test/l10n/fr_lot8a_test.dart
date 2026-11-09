import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/channel/channel_info.dart';
import 'package:onset/screens/channel/stores/channel_info_store.dart';
import 'package:onset/widgets/follow/follow_actions.dart';
import 'package:onset/widgets/follow/follow_flow.dart';
import 'package:provider/provider.dart';

import '../helpers/l10n.dart';

class _MockActions extends Mock implements FollowActions {}

class _MockApi extends Mock implements TwitchApi {}

StreamTwitch _stream(String id, String name) => StreamTwitch(
  id,
  name.toLowerCase(),
  name,
  '509658',
  'Just Chatting',
  '',
  12345,
  '',
  '',
);

void main() {
  late _MockActions actions;

  setUp(() {
    actions = _MockActions();
    when(() => actions.canFollowInApp).thenReturn(true);
    when(
      () => actions.followChannel(any()),
    ).thenAnswer((_) async => FollowResult.done);
  });

  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';

      testWidgets('the follow suggestions, $at', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            body: FollowSuggestionsSheet(
              name: 'Streamer',
              suggestions: [
                _stream('1', 'Alpha'),
                _stream('2', 'BetaChannelLongName'),
              ],
              actions: actions,
            ),
          ),
          size: size,
          textScale: scale,
        );
        await expectFrenchThroughout(
          tester,
          'follow suggestions, $at',
          content: const ['Streamer', 'Alpha', 'BetaChannelLongName'],
        );
        await tester.tap(find.byKey(FollowSuggestionsSheet.followAllKey));
        await tester.pumpAndSettle();
        await expectFrenchThroughout(tester, 'follow all confirm, $at');
      });

      testWidgets('the unfollow confirmation, $at', (tester) async {
        final info = ChannelInfoStore(
          channelId: '1000',
          api: _MockApi(),
          viewerId: () => '77',
        )..following.value = true;
        addTearDown(info.dispose);
        await pumpLocalized(
          tester,
          Scaffold(
            body: Center(
              child: FollowButton(
                info: info,
                login: 'streamer',
                name: 'Streamer',
                height: 40,
              ),
            ),
          ),
          size: size,
          textScale: scale,
          wrap: (app) =>
              Provider<FollowActions?>.value(value: actions, child: app),
        );
        await tester.tap(find.byType(FollowButton));
        await tester.pumpAndSettle();
        await expectFrenchThroughout(
          tester,
          'unfollow confirm, $at',
          content: const ['Streamer'],
        );
      });
    }
  }
}
