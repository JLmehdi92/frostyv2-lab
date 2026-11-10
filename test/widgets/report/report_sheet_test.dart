import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/report.dart';
import 'package:onset/widgets/report/report_sheet.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/twitch_web_page.dart';

import '../../helpers/l10n.dart';

const _user = ReportTarget.user(userId: '42', name: 'Someone');

void main() {
  Future<void> pumpSheet(
    WidgetTester tester,
    ReportSender send, {
    Locale locale = en,
    Size size = const Size(390, 844),
    double textScale = 1,
    ReportTarget target = _user,
  }) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showOnsetSheet<ViewerActionOutcome>(
                context: context,
                builder: (_) => ReportSheet(target: target, send: send),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
      locale: locale,
      size: size,
      textScale: textScale,
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('a reason, then a confirmation, then the report', (tester) async {
    ReportReason? sentReason;
    String? sentText;
    await pumpSheet(tester, (reason, text) async {
      sentReason = reason;
      sentText = text;
      return ViewerActionOutcome.done;
    });
    expect(find.text('Report Someone'), findsOneWidget);
    expect(
      find.text('Why are you reporting this?'.toUpperCase()),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ReportSheet.reasonKey(ReportReason.spam)));
    await tester.pumpAndSettle();
    expect(find.text('Confirm your report'), findsOneWidget);
    expect(find.text('Spam, scams, or bots'), findsOneWidget);
    expect(sentReason, isNull);

    await tester.enterText(find.byType(TextField), 'link spam');
    await tester.tap(find.byKey(ReportSheet.sendKey));
    await tester.pumpAndSettle();
    expect(sentReason, ReportReason.spam);
    expect(sentText, 'link spam');
    expect(find.byType(ReportSheet), findsNothing);
  });

  testWidgets('Back returns to the reasons and sends nothing', (tester) async {
    var sends = 0;
    await pumpSheet(tester, (_, _) async {
      sends++;
      return ViewerActionOutcome.done;
    });
    await tester.tap(
      find.byKey(ReportSheet.reasonKey(ReportReason.harassment)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ReportSheet.reasonKey(ReportReason.spam)),
      findsOneWidget,
    );
    expect(sends, 0);
  });

  testWidgets('a report on its way can’t be sent twice', (tester) async {
    final answer = Completer<ViewerActionOutcome>();
    var sends = 0;
    await pumpSheet(tester, (_, _) {
      sends++;
      return answer.future;
    });
    await tester.tap(find.byKey(ReportSheet.reasonKey(ReportReason.spam)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ReportSheet.sendKey));
    await tester.pump();
    await tester.tap(find.byKey(ReportSheet.sendKey), warnIfMissed: false);
    await tester.pump();
    expect(sends, 1);
    answer.complete(ViewerActionOutcome.done);
    await tester.pumpAndSettle();
  });

  testWidgets('without a Twitch session it asks before opening twitch.tv', (
    tester,
  ) async {
    TwitchWebPage.debugBody = () => const SizedBox(key: ValueKey('web'));
    addTearDown(() => TwitchWebPage.debugBody = null);
    await pumpLocalized(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => reportFromOnset(
                context,
                target: _user,
                title: 'Report',
                fallbackUrl: Uri.https('www.twitch.tv', '/someone/report'),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
      locale: en,
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Report on twitch.tv?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(ReportSheet.webFallbackKey),
        matching: find.text('Open twitch.tv'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('web')), findsNothing);
    await tester.tap(find.byKey(ReportSheet.webFallbackKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('web')), findsOneWidget);
  });

  for (final locale in [fr, en]) {
    for (final (name, size) in const [
      ('320x640', Size(320, 640)),
      ('360x640', Size(360, 640)),
      ('390x844', Size(390, 844)),
      ('844x390', Size(844, 390)),
      ('1024x1366', Size(1024, 1366)),
    ]) {
      for (final scale in frenchTextScales) {
        testWidgets('${locale.languageCode} $name ×$scale: both steps read '
            'whole', (tester) async {
          await pumpSheet(
            tester,
            (_, _) async => ViewerActionOutcome.done,
            locale: locale,
            size: size,
            textScale: scale,
            target: const ReportTarget.message(
              messageId: 'm1',
              senderId: '42',
              channelId: '7',
              name: 'Someone',
            ),
          );
          final where = '${locale.languageCode} $name ×$scale';
          expect(tester.takeException(), isNull, reason: where);
          expect(clippedTexts(tester), isEmpty, reason: where);
          expect(ellipsizedTexts(tester), isEmpty, reason: where);
          if (locale == fr) {
            expect(
              englishLeaks(tester).where((text) => text != 'go'),
              isEmpty,
              reason: where,
            );
          }
          await tester.tap(
            find.byKey(ReportSheet.reasonKey(ReportReason.chatBanEvasion)),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: where);
          expect(clippedTexts(tester), isEmpty, reason: where);
          expect(ellipsizedTexts(tester), isEmpty, reason: where);
          if (locale == fr) {
            expect(
              englishLeaks(tester).where((text) => text != 'go'),
              isEmpty,
              reason: where,
            );
          }
        });
      }
    }
  }
}
