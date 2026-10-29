import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/chat_settings.dart';
import 'package:onset/screens/settings/profile_tab.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/video_settings.dart';

import 'settings_harness.dart';

void main() {
  late SettingsStore settings;
  late FakeAuthStore auth;

  setUp(() {
    mockSettingsPlatform();
    settings = SettingsStore.fromJson({});
    auth = FakeAuthStore(loggedIn: true);
  });

  /// The keyboard over the bottom [height] dp.
  void keyboard(WidgetTester tester, double height) =>
      tester.view.viewInsets = FakeViewPadding(bottom: height);

  /// [field] is fully on screen, above the keyboard.
  void expectAboveKeyboard(
    WidgetTester tester,
    Finder field,
    Size size,
    double keyboardHeight,
  ) {
    final rect = tester.getRect(field);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(size.height - keyboardHeight));
  }

  for (final (size, inset) in const [
    (Size(844, 390), 200.0),
    (Size(390, 844), 300.0),
  ]) {
    final name = '${size.width.toInt()}×${size.height.toInt()}';

    testWidgets('$name: muted keywords stay above the keyboard', (
      tester,
    ) async {
      settings.mutedWords = [for (var i = 0; i < 12; i++) 'word $i'];
      await pumpSettings(
        tester,
        ChatSettings(settingsStore: settings),
        settings: settings,
        auth: auth,
        size: size,
      );
      await tapVisible(tester, find.text('Muted keywords'));
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      keyboard(tester, inset);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expectAboveKeyboard(tester, find.byType(TextField), size, inset);
      // The words still scroll under the field.
      await tester.enterText(find.byType(TextField), 'late');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(settings.mutedWords.last, 'late');
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: the web token field stays above the keyboard', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        VideoSettings(settingsStore: settings, isAndroid: true, isIOS: false),
        settings: settings,
        auth: auth,
        size: size,
      );
      await tapVisible(tester, find.text('Twitch web token (2K)'));
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      keyboard(tester, inset);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expectAboveKeyboard(tester, find.byType(TextField), size, inset);
    });
  }

  testWidgets('the muted keywords dialog outlives its page (a fold)', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      ProfileTab(settingsStore: settings, authStore: auth),
      settings: settings,
      auth: auth,
      size: const Size(1280, 854),
    );
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Muted keywords'));

    // Folded to a phone: the tablet pane (and its Chat page) goes.
    useWindow(tester, const Size(390, 844));
    await tester.pumpAndSettle();
    expect(find.byType(ChatSettings), findsNothing);

    await tester.enterText(find.byType(TextField), 'kept');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(settings.mutedWords, ['kept']);
    expect(tester.takeException(), isNull);
  });
}
