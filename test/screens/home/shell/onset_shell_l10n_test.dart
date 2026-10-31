import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/home/shell/onset_shell.dart';
import 'package:onset/screens/home/stores/home_store.dart';

import '../../../helpers/l10n.dart';

/// The shell in French on a narrow phone, in the real Inter font: nothing
/// it shows is cut.
void main() {
  final french = lookupAppLocalizations(fr);

  for (final size in const [Size(360, 640), Size(320, 568)]) {
    testWidgets('Browse at ${size.width.toInt()} dp: the search hint and the '
        'bar\'s labels are whole', (tester) async {
      await pumpLocalized(
        tester,
        Scaffold(
          body: OnsetShell(
            section: ShellSection.browse,
            onSection: (_) {},
            onSearch: () {},
            header: ShellHeader(
              title: french.shellSectionBrowse,
              showSearch: false,
              searchField: true,
              tabs: [for (final tab in BrowseTab.values) tab.label(french)],
            ),
            body: const SizedBox.expand(),
          ),
        ),
        size: size,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final text in [
        french.shellSearchHint,
        for (final section in ShellSection.values.take(3))
          section.label(french),
        for (final tab in BrowseTab.values) tab.label(french),
      ]) {
        final finder = find.text(text);
        expect(finder, findsWidgets, reason: text);
        for (final paragraph in tester.renderObjectList<RenderParagraph>(
          find.descendant(of: finder, matching: find.byType(RichText)),
        )) {
          expect(paragraph.didExceedMaxLines, isFalse, reason: text);
        }
      }
    });
  }
}
