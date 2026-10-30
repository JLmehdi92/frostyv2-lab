import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every node on screen flagged as a button that a screen reader cannot
/// press (no tap action), by label.
///
/// `Semantics(button: true, excludeSemantics: true)` drops the tap of the
/// gesture detector it wraps along with the subtree: TalkBack then reads a
/// button that does nothing. Only nodes actually on screen are visited.
List<String> silentButtons(WidgetTester tester) {
  final silent = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.flagsCollection.isButton &&
        !data.hasAction(SemanticsAction.tap) &&
        !node.isInvisible) {
      silent.add(data.label.isEmpty ? '(unlabelled)' : data.label);
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return silent;
}

/// How many button nodes are on screen (so an audit proves it saw some).
int buttonCount(WidgetTester tester) {
  var count = 0;
  void visit(SemanticsNode node) {
    if (node.getSemanticsData().flagsCollection.isButton) count++;
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return count;
}

/// Fails when a button on screen cannot be pressed with a screen reader,
/// or when there is no button at all to check.
void expectNoSilentButtons(WidgetTester tester, {String? reason}) {
  expect(buttonCount(tester), greaterThan(0), reason: '$reason: no buttons');
  expect(silentButtons(tester), isEmpty, reason: reason);
}
