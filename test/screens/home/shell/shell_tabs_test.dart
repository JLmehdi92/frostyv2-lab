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
}
