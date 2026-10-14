import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/overlay_common.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool controlsVisible,
    Map<String, VoidCallback> actions = const {},
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    MaterialApp(
      home: VideoSurfaceSemantics(
        controlsVisible: controlsVisible,
        actions: actions,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );

  testWidgets('the player says what a tap does', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, controlsVisible: false);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Video player')),
      matchesSemantics(
        label: 'Video player',
        hasTapAction: true,
        onTapHint: 'show controls',
      ),
    );

    await pump(tester, controlsVisible: true);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Video player')),
      matchesSemantics(
        label: 'Video player',
        hasTapAction: true,
        onTapHint: 'hide controls',
      ),
    );
    semantics.dispose();
  });

  testWidgets('double-tap gestures are offered as actions', (tester) async {
    final semantics = tester.ensureSemantics();
    var skipped = 0;
    await pump(
      tester,
      controlsVisible: false,
      actions: {'Forward 10 seconds': () => skipped++},
    );

    const action = CustomSemanticsAction(label: 'Forward 10 seconds');
    final node = tester.getSemantics(find.bySemanticsLabel('Video player'));
    expect(
      node,
      matchesSemantics(
        label: 'Video player',
        hasTapAction: true,
        onTapHint: 'show controls',
        customActions: [action],
      ),
    );
    final wrapper = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(VideoSurfaceSemantics),
            matching: find.byType(Semantics),
          )
          .first,
    );
    wrapper.properties.customSemanticsActions![action]!();
    expect(skipped, 1);
    semantics.dispose();
  });
}
