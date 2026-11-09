import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/widgets/coach_mark.dart';
import 'package:onset/widgets/new_feature_pill.dart';

import '../helpers/l10n.dart';

Widget _screen(SettingsStore settings) => Scaffold(
  body: Align(
    alignment: Alignment.topRight,
    child: CoachMark(
      feature: NewFeature.cast,
      message: 'Watch on your TV: cast to a Google Cast device.',
      settings: settings,
      child: const SizedBox.square(dimension: 44),
    ),
  ),
);

void main() {
  testWidgets('shows once, then never after it is dismissed', (tester) async {
    final settings = SettingsStore.fromJson({});
    await pumpLocalized(tester, _screen(settings), locale: en);
    expect(find.byKey(const ValueKey('coach-mark')), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Watch on your TV: cast to a Google Cast device.'),
      findsOne,
    );

    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(find.byKey(const ValueKey('coach-mark')), findsNothing);
    expect(settings.isNewFeature(NewFeature.cast.name), isFalse);

    await tester.pumpWidget(const SizedBox());
    await pumpLocalized(tester, _screen(settings), locale: en);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('coach-mark')), findsNothing);
  });

  testWidgets('leaving before it shows leaves it for next time', (
    tester,
  ) async {
    final settings = SettingsStore.fromJson({});
    await pumpLocalized(tester, _screen(settings), locale: en);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(settings.isNewFeature(NewFeature.cast.name), isTrue);
  });

  testWidgets('waits for the tip it follows to be seen', (tester) async {
    final settings = SettingsStore.fromJson({});
    Widget screen() => Scaffold(
      body: CoachMark(
        feature: NewFeature.floatingPlayer,
        after: NewFeature.cast,
        message: 'Second tip',
        settings: settings,
        child: const SizedBox.square(dimension: 44),
      ),
    );
    await pumpLocalized(tester, screen(), locale: en);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Second tip'), findsNothing);

    settings.markFeatureSeen(NewFeature.cast.name);
    await tester.pumpWidget(const SizedBox());
    await pumpLocalized(tester, screen(), locale: en);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Second tip'), findsOne);
  });

  testWidgets('hides while its control is hidden, unseen', (tester) async {
    final settings = SettingsStore.fromJson({});
    final ignoring = ValueNotifier(false);
    await pumpLocalized(
      tester,
      Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: ignoring,
          builder: (_, value, child) =>
              IgnorePointer(ignoring: value, child: child),
          child: CoachMark(
            feature: NewFeature.cast,
            message: 'Tip',
            settings: settings,
            child: const SizedBox.square(dimension: 44),
          ),
        ),
      ),
      locale: en,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tip'), findsOne);

    ignoring.value = true;
    await tester.pump();
    await tester.pump();
    expect(find.text('Tip'), findsNothing);
    expect(settings.isNewFeature(NewFeature.cast.name), isTrue);

    ignoring.value = false;
    await tester.pump();
    await tester.pump();
    expect(find.text('Tip'), findsOne);
  });

  testWidgets('nothing without the settings', (tester) async {
    await pumpLocalized(
      tester,
      const CoachMark(
        feature: NewFeature.cast,
        message: 'Tip',
        child: SizedBox.square(dimension: 44),
      ),
      locale: en,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('coach-mark')), findsNothing);
  });
}
