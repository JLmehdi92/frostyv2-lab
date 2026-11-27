import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/clips/widgets/clip_info_panel.dart';
import 'package:onset/screens/home/stream_list/streams_list.dart';
import 'package:onset/screens/settings/widgets/release_notes_parts.dart';

import '../helpers/l10n.dart';

void main() {
  final pills = <(String, Widget, String, double)>[
    ('new videos badge', const NewVideosBadge(count: 4), '4', 22),
    (
      'clip origin pill',
      const ClipOriginPill(label: 'Auto clip'),
      'Auto clip',
      26,
    ),
    (
      'release version pill',
      const ReleaseVersionPill('v1.1.0', latest: true),
      'v1.1.0',
      24,
    ),
  ];

  for (final (name, pill, text, height) in pills) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('the $name holds its text at text ×$scale', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            body: Column(
              children: [
                Wrap(children: [pill]),
                Row(children: [pill]),
              ],
            ),
          ),
          locale: en,
          textScale: scale,
        );
        for (final element in find.byWidget(pill).evaluate()) {
          final size = (element.renderObject! as RenderBox).size;
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byElementPredicate((e) => e == element),
              matching: find.text(text),
            ),
          );
          final needed = paragraph.getMaxIntrinsicHeight(paragraph.size.width);
          expect(paragraph.size.height, needed, reason: '$name ×$scale');
          expect(size.width, lessThan(200), reason: 'a pill, not a bar');
          if (scale == 1) {
            expect(size.height, height, reason: name);
          } else {
            expect(size.height, greaterThanOrEqualTo(needed), reason: name);
          }
        }
      });
    }
  }
}
