import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/category.dart';
import 'package:frosty/screens/home/shell/shell_tabs.dart';
import 'package:frosty/screens/home/top/categories/category_card.dart';

void main() {
  testWidgets('a screen reader can open a tab', (tester) async {
    final handle = tester.ensureSemantics();
    final picked = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShellTabs(
            labels: const ['Top', 'Videos'],
            index: 0,
            onSelect: picked.add,
            height: 44,
            fontSize: 15,
            gap: 22,
            bottomPadding: 12,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            activeColor: Colors.white,
            idleColor: Colors.grey,
            indicatorColor: Colors.lime,
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('Videos')),
      matchesSemantics(
        label: 'Videos',
        isButton: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('Videos'));
    expect(picked, [1]);
    handle.dispose();
  });

  testWidgets('a screen reader can open a category tile', (tester) async {
    final handle = tester.ensureSemantics();
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: CategoryTile(
              category: const CategoryTwitch(
                'https://a/{width}x{height}.jpg',
                '1',
                'Chess',
              ),
              onTap: () => opened++,
            ),
          ),
        ),
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('Chess'));
    expect(opened, 1);
    handle.dispose();
  });

  test('a monogram never splits a character', () {
    expect(categoryMonogram('Rocket League'), 'RL');
    expect(categoryMonogram('Minecraft'), 'MIN');
    expect(categoryMonogram('🎮🎲🎯🎳'), '🎮🎲🎯');
    expect(categoryMonogram(''), '');
  });

  testWidgets('a count after a label: the pill, read with the label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    Widget tabs(List<int> badges, int index) => MaterialApp(
      home: Scaffold(
        body: ShellTabs(
          labels: const ['Notifications', 'Whispers'],
          badges: badges,
          index: index,
          onSelect: (_) {},
          height: 44,
          fontSize: 16,
          gap: 26,
          bottomPadding: 11,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          activeColor: Colors.white,
          idleColor: Colors.grey,
          indicatorColor: const Color(0xFFC8FF3D),
        ),
      ),
    );
    await tester.pumpWidget(tabs(const [3, 0], 0));
    expect(find.byKey(const ValueKey('tab-count')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Notifications')),
      matchesSemantics(
        label: 'Notifications, 3 unread',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    // The underline spans the label and its count.
    final line = tester.getRect(find.byKey(const ValueKey('tab-indicator')));
    final pill = tester.getRect(find.byKey(const ValueKey('tab-count')));
    expect(line.right, closeTo(pill.right, 0.01));
    // Switching tabs while a weight changes: never an overflow.
    await tester.pumpWidget(tabs(const [3, 12], 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('tab-count')), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
