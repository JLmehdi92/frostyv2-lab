import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/widgets/uptime.dart';

void main() {
  testWidgets('an unreadable start shows nothing instead of failing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Uptime(startTime: '')),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a readable start shows a time', (tester) async {
    final start = DateTime.now().subtract(const Duration(hours: 2));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Uptime(startTime: start.toIso8601String())),
      ),
    );
    expect(find.byType(Text), findsOneWidget);
  });
}
