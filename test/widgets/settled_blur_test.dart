import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/widgets/settled_blur.dart';

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> pumpPage(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: Scaffold(
        body: SettledBlur(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    ),
  );

  bool blurEnabled(WidgetTester tester) => tester
      .widget<BackdropFilter>(find.byType(BackdropFilter, skipOffstage: false))
      .enabled;

  testWidgets('blur pauses while a bottom sheet slides over the page', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(blurEnabled(tester), isTrue);

    showModalBottomSheet<void>(
      context: navigatorKey.currentContext!,
      builder: (_) => const SizedBox(height: 200, child: Text('sheet')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(blurEnabled(tester), isFalse);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(blurEnabled(tester), isTrue);
  });

  testWidgets('blur pauses while its own page is pushed', (tester) async {
    await pumpPage(tester);
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: SettledBlur(
            filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final filters = tester.widgetList<BackdropFilter>(
      find.byType(BackdropFilter, skipOffstage: false),
    );
    expect(filters.every((f) => !f.enabled), isTrue);

    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<BackdropFilter>(
            find.byType(BackdropFilter, skipOffstage: false),
          )
          .last
          .enabled,
      isTrue,
    );
  });
}
