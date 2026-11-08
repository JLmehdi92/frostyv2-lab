import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/followed_channel.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/channel/chat/overlay_chat_frame.dart';
import 'package:onset/screens/channel/chat/overlay_chat_placement.dart';
import 'package:onset/screens/channel/video/audience_labels.dart';

import '../helpers/l10n.dart';
import '../screens/channel/followed_channels_drawer_test.dart'
    show drawerHost, fakeFollowedStore;

void main() {
  final french = lookupAppLocalizations(fr);

  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';

      testWidgets('the audience labels over a player, $at', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            backgroundColor: Colors.black,
            body: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AudienceLabels(
                  labelIds: const ['Gambling', 'ProfanityVulgarity'],
                  paidPromotion: true,
                  onDismiss: () {},
                ),
              ),
            ),
          ),
          size: size,
          textScale: scale,
        );
        expect(find.text(french.audienceLabelPaidPromotion), findsOneWidget);
        await expectFrenchThroughout(tester, 'audience labels, $at');
      });

      testWidgets('the overlay chat handles, $at', (tester) async {
        await pumpLocalized(
          tester,
          Row(
            children: [
              const Expanded(child: SizedBox()),
              OverlayChatFrame(
                width: 200,
                placement: const OverlayChatPlacement(top: 0.1, height: 0.6),
                showHandles: true,
                leftSide: false,
                onPlacementChanged: (_) {},
                onLeftSideChanged: (_) {},
                child: const ColoredBox(color: Colors.black),
              ),
            ],
          ),
          size: size,
          textScale: scale,
        );
        expect(find.byTooltip(french.overlayChatMove), findsOneWidget);
        await expectFrenchThroughout(tester, 'overlay chat, $at');
      });

      testWidgets('the followed channels drawer, $at', (tester) async {
        final store = fakeFollowedStore(
          live: [
            const StreamTwitch(
              '1',
              'joueuse',
              'Joueuse',
              '1',
              'Discussion',
              'Titre',
              1234,
              '',
              '',
            ),
          ],
          offline: [
            FollowedChannel(
              broadcasterId: '2',
              broadcasterLogin: 'endormi',
              broadcasterName: 'Endormi',
              followedAt: DateTime.utc(2025),
            ),
          ],
        );
        await pumpLocalized(
          tester,
          drawerHost(store),
          size: size,
          textScale: scale,
        );
        await tester.tap(find.byKey(const ValueKey('open-drawer')));
        await tester.pumpAndSettle();
        expect(find.text(french.followedDrawerTitle), findsOneWidget);
        expect(find.text(french.followedDrawerLive), findsOneWidget);
        await expectFrenchThroughout(tester, 'followed drawer, $at');
      });
    }
  }
}
