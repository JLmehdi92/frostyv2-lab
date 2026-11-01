import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/home/stream_list/stream_sort_button.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

void main() {
  testWidgets('says the order and changes the remembered one', (tester) async {
    final settings = SettingsStore.fromJson({});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FollowedSortButton(settingsStore: settings)),
      ),
    );

    expect(find.text('Sorted by Viewers (high to low)'), findsOneWidget);

    await tester.tap(find.byType(FollowedSortButton));
    await tester.pumpAndSettle();
    for (final sort in FollowedSort.values) {
      expect(find.text(sort.label(L10n.english)), findsOneWidget);
    }

    await tester.tap(find.text('Recently started'));
    await tester.pumpAndSettle();

    expect(settings.followedSort, FollowedSort.recent);
    expect(find.text('Sorted by Recently started'), findsOneWidget);
  });
}
