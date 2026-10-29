import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/home/shell/onset_shell.dart';

void main() {
  late ShellCoverObserver observer;
  late GlobalKey<NavigatorState> navigator;
  late Route<dynamic> shell;

  setUp(() {
    observer = ShellCoverObserver();
    navigator = GlobalKey<NavigatorState>();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) {
            shell = ModalRoute.of(context)!;
            return const Text('shell');
          },
        ),
      ),
    );
  }

  MaterialPageRoute<void> page(String name) => MaterialPageRoute<void>(
    settings: RouteSettings(name: name),
    builder: (_) => Text(name),
  );

  testWidgets('a page above covers; popping it uncovers', (tester) async {
    await pump(tester);
    var changes = 0;
    observer.addListener(() => changes++);
    expect(observer.covers(shell), isFalse);

    navigator.currentState!.push(page('a'));
    await tester.pumpAndSettle();
    expect(observer.covers(shell), isTrue);
    expect(changes, greaterThan(0));

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(observer.covers(shell), isFalse);
  });

  testWidgets('a sheet or a dialog alone does not cover', (tester) async {
    await pump(tester);
    showDialog<void>(
      context: navigator.currentContext!,
      builder: (_) => const Text('dialog'),
    );
    await tester.pumpAndSettle();
    expect(observer.covers(shell), isFalse);

    // A page from the dialog does.
    navigator.currentState!.push(page('report'));
    await tester.pumpAndSettle();
    expect(observer.covers(shell), isTrue);
  });

  testWidgets('a replaced page still covers; a removed one no longer', (
    tester,
  ) async {
    await pump(tester);
    navigator.currentState!.push(page('a'));
    await tester.pumpAndSettle();
    final b = page('b');
    navigator.currentState!.pushReplacement(b);
    await tester.pumpAndSettle();
    expect(find.text('b'), findsOneWidget);
    expect(observer.covers(shell), isTrue);

    navigator.currentState!.removeRoute(b);
    await tester.pumpAndSettle();
    expect(observer.covers(shell), isFalse);
  });

  testWidgets('popUntil the shell through pages and sheets uncovers', (
    tester,
  ) async {
    await pump(tester);
    navigator.currentState!.push(page('a'));
    await tester.pumpAndSettle();
    showModalBottomSheet<void>(
      context: navigator.currentContext!,
      builder: (_) => const SizedBox(height: 80),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.push(page('c'));
    await tester.pumpAndSettle();
    expect(observer.covers(shell), isTrue);

    navigator.currentState!.popUntil((route) => route == shell);
    await tester.pumpAndSettle();
    expect(find.text('shell'), findsOneWidget);
    expect(observer.covers(shell), isFalse);
  });

  testWidgets('the shell itself replaced: nothing covers a gone route', (
    tester,
  ) async {
    await pump(tester);
    final before = shell;
    navigator.currentState!.pushReplacement(page('new home'));
    await tester.pumpAndSettle();
    expect(observer.covers(before), isFalse);
  });

  testWidgets('the routes above a route, in order', (tester) async {
    await pump(tester);
    final first = page('first');
    final second = page('second');
    unawaited(navigator.currentState!.push(first));
    unawaited(navigator.currentState!.push(second));
    await tester.pumpAndSettle();

    expect(observer.above(shell), [first, second]);
    expect(observer.above(first), [second]);
    expect(observer.above(second), isEmpty);
    expect(observer.above(page('unknown')), isEmpty);
  });
}
