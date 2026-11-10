import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/profile_edit.dart';
import 'package:onset/screens/clips/widgets/clip_manage_sheet.dart';

import '../../helpers/l10n.dart';

const _slug = 'SmellySlipperyEggnogDBstyle-YKZwOj2rR3IVcuor';

void main() {
  late List<String> renamed;
  late List<String> deleted;
  late Completer<AccountEditOutcome>? deleteAnswer;
  ClipChange? change;

  ClipManageActions actions() => ClipManageActions(
    rename: (slug, title) async {
      renamed.add(title);
      return AccountEditResult(AccountEditOutcome.done, value: title.trim());
    },
    delete: (slug) {
      deleted.add(slug);
      return deleteAnswer?.future ?? Future.value(AccountEditOutcome.done);
    },
  );

  setUp(() {
    renamed = [];
    deleted = [];
    deleteAnswer = null;
    change = null;
  });

  Future<void> open(
    WidgetTester tester, {
    Locale locale = en,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => change = await showClipManageSheet(
                context,
                slug: _slug,
                title: 'Old title',
                actions: actions(),
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

  testWidgets('rename saves the new title and says so', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(ClipManageKeys.rename));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Clutch round');
    await tester.pump();
    await tester.tap(find.byKey(ClipManageKeys.save));
    await tester.pumpAndSettle();
    expect(renamed, ['Clutch round']);
    expect(change, ClipChange.renamed);
    expect(find.text('Clip renamed.'), findsOneWidget);
  });

  testWidgets('an empty title can’t be saved', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(ClipManageKeys.rename));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.byKey(ClipManageKeys.save), warnIfMissed: false);
    await tester.pump();
    expect(renamed, isEmpty);
  });

  testWidgets('delete asks first, then deletes once', (tester) async {
    deleteAnswer = Completer();
    await open(tester);
    await tester.tap(find.byKey(ClipManageKeys.delete));
    await tester.pumpAndSettle();
    expect(find.text('Delete this clip?'), findsOneWidget);
    expect(deleted, isEmpty);

    await tester.tap(find.byKey(ClipManageKeys.confirmDelete));
    await tester.pump();
    await tester.tap(
      find.byKey(ClipManageKeys.confirmDelete),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(deleted, [_slug]);

    deleteAnswer!.complete(AccountEditOutcome.done);
    await tester.pumpAndSettle();
    expect(change, ClipChange.deleted);
    expect(find.text('Clip deleted.'), findsOneWidget);
  });

  testWidgets('Cancel deletes nothing', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(ClipManageKeys.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    expect(change, isNull);
  });

  testWidgets('a refusal is said and changes nothing', (tester) async {
    deleteAnswer = Completer()..complete(AccountEditOutcome.integrityRefused);
    await open(tester);
    await tester.tap(find.byKey(ClipManageKeys.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ClipManageKeys.confirmDelete));
    await tester.pumpAndSettle();
    expect(change, isNull);
    expect(find.textContaining('anti-bot check'), findsOneWidget);
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
        testWidgets('${locale.languageCode} $name ×$scale: sheet and dialogs '
            'read whole', (tester) async {
          await open(tester, locale: locale, size: size, textScale: scale);
          final where = '${locale.languageCode} $name ×$scale';
          void check() {
            expect(tester.takeException(), isNull, reason: where);
            expect(clippedTexts(tester), isEmpty, reason: where);
            expect(ellipsizedTexts(tester), isEmpty, reason: where);
            if (locale == fr) {
              expect(
                englishLeaks(
                  tester,
                ).where((text) => text != 'go' && text != 'Old title'),
                isEmpty,
                reason: where,
              );
            }
          }

          check();
          await tester.tap(find.byKey(ClipManageKeys.delete));
          await tester.pumpAndSettle();
          check();
          await tester.tap(find.text(locale == fr ? 'Annuler' : 'Cancel'));
          await tester.pumpAndSettle();
        });
      }
    }
  }
}
