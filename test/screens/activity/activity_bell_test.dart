import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/activity/activity_bell.dart';
import 'package:frosty/screens/activity/activity_screen.dart';
import 'package:frosty/screens/activity/stores/activity_store.dart';
import 'package:frosty/services/notifications/activity_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ActivityStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = ActivityStore(log: await ActivityLog.load());
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [ActivityBell(store: store, onOpenChannel: (_) {})],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('counts what came since the list was opened', (tester) async {
    await pump(tester);
    expect(find.byTooltip('Activity'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await store.addAll([
      ActivityEntry(
        id: 'a',
        kind: ActivityKind.live,
        title: 'Streamer is live',
        body: '',
        at: DateTime.now(),
      ),
    ]);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.byTooltip('Activity (1 new)'), findsOneWidget);

    await tester.tap(find.byType(ActivityBell));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityScreen), findsOneWidget);
    expect(store.newCount, 0);
  });
}
