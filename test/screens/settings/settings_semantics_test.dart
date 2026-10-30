import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show runInAction;
import 'package:onset/models/user.dart';
import 'package:onset/screens/settings/chat_settings.dart';
import 'package:onset/screens/settings/profile_tab.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import 'settings_harness.dart';

/// A screen reader activates a control through its semantics node: a button
/// node without a tap action reads as a button and does nothing.
void main() {
  late SettingsStore settings;

  setUp(() {
    mockSettingsPlatform();
    settings = SettingsStore.fromJson({});
  });

  Future<void> pumpTablet(WidgetTester tester, FakeAuthStore auth) =>
      pumpSettings(
        tester,
        ProfileTab(settingsStore: settings, authStore: auth),
        settings: settings,
        auth: auth,
        size: const Size(1280, 854),
      );

  /// Every button node on screen that has no tap action, by label.
  List<String> buttonsWithoutTap(WidgetTester tester) {
    final missing = <String>[];
    void visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (data.flagsCollection.isButton &&
          !data.hasAction(SemanticsAction.tap)) {
        missing.add(data.label);
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
    return missing;
  }

  testWidgets('a tablet section opens from its semantics node', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpTablet(tester, FakeAuthStore(loggedIn: true));
    expect(find.byType(ChatSettings), findsNothing);
    tester.semantics.tap(find.semantics.byLabel('Chat'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatSettings), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Log out answers a screen reader too', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpTablet(tester, FakeAuthStore(loggedIn: true));
    tester.semantics.tap(find.semantics.byLabel('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the muted keywords button answers a screen reader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    settings.mutedWords = ['spoiler'];
    await pumpTablet(tester, FakeAuthStore(loggedIn: true));
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Muted keywords'));
    await tester.pumpAndSettle();
    expect(buttonsWithoutTap(tester), isEmpty);
    await tester.enterText(find.byType(TextField), 'late');
    await tester.pump();
    tester.semantics.tap(find.semantics.byLabel('Add keyword'));
    await tester.pumpAndSettle();
    expect(settings.mutedWords, contains('late'));
    semantics.dispose();
  });

  testWidgets('every settings button has a tap action, page by page', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final auth = FakeAuthStore(loggedIn: true);
    runInAction(
      () => auth.blocked.add(const UserBlockedTwitch('9', 'spam', 'Spam')),
    );
    await pumpTablet(tester, auth);
    for (final page in [
      'General',
      'Video',
      'Chat',
      'Notifications',
      'Other',
      'Blocked users',
    ]) {
      await tester.tap(find.text(page).first);
      await tester.pumpAndSettle();
      expect(buttonsWithoutTap(tester), isEmpty, reason: page);
    }
    semantics.dispose();
  });
}
