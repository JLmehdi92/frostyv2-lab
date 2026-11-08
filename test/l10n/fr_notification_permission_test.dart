import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/widgets/notification_permission_prompt.dart';

import '../helpers/l10n.dart';

void main() {
  final french = lookupAppLocalizations(fr);

  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';

      testWidgets('the notification permission explanation, $at', (
        tester,
      ) async {
        await pumpLocalized(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  key: const ValueKey('open'),
                  onPressed: () => explainNotificationPermission(context),
                  child: const SizedBox(width: 40, height: 40),
                ),
              ),
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.tap(find.byKey(const ValueKey('open')));
        await tester.pumpAndSettle();
        expect(find.text(french.notificationPermissionTitle), findsOneWidget);
        expect(
          find.text(french.notificationPermissionContinue),
          findsOneWidget,
        );
        await expectFrenchThroughout(tester, 'notification permission, $at');
      });
    }
  }
}
