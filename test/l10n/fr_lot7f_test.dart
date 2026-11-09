import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/live_together.dart';
import 'package:onset/screens/channel/chat/widgets/live_together.dart';

import '../fixtures/live_together_payloads.dart';
import '../helpers/l10n.dart';

void main() {
  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';

      testWidgets('the co-stream line, $at', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            body: LiveTogetherStrip(
              roster: LiveTogether.fromCostream(costreamResponse()),
              channelId: '1000',
              onOpen: (_) {},
            ),
          ),
          size: size,
          textScale: scale,
        );
        await expectFrenchThroughout(
          tester,
          'co-stream line, $at',
          content: const ['HostChannel', 'ThirdOne'],
        );
      });

      testWidgets('the guest list, $at', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            body: LiveTogetherSheet(
              roster: LiveTogether.fromGuestStar(guestStarResponse())!,
              channelId: '1000',
              onOpen: (_) {},
            ),
          ),
          size: size,
          textScale: scale,
        );
        await expectFrenchThroughout(
          tester,
          'guest list, $at',
          content: const ['GuestOne', 'GuestTwo'],
        );
      });
    }
  }
}
