import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/home/home.dart';

void main() {
  const destinations = <HomeDestination>[
    (
      icon: Icon(Icons.favorite_border_rounded),
      selectedIcon: Icon(Icons.favorite_rounded),
      label: 'Following',
    ),
    (
      icon: Icon(Icons.arrow_upward_rounded),
      selectedIcon: Icon(Icons.arrow_upward_rounded),
      label: 'Top',
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required bool useRail,
    ValueChanged<int>? onSelected,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HomeRailLayout(
          useRail: useRail,
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: onSelected ?? (_) {},
          child: const SizedBox.expand(key: ValueKey('pages')),
        ),
      ),
    ),
  );

  testWidgets('phones show only the pages', (tester) async {
    await pump(tester, useRail: false);

    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.getTopLeft(find.byKey(const ValueKey('pages'))).dx, 0);
  });

  testWidgets('a large screen puts a labelled rail beside the pages', (
    tester,
  ) async {
    final taps = <int>[];
    await pump(tester, useRail: true, onSelected: taps.add);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('pages'))).dx,
      greaterThan(0),
    );

    await tester.tap(find.text('Top'));
    expect(taps, [1]);
  });

  testWidgets('the pages do not add the cutout the rail already took', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(left: 40);
    addTearDown(tester.view.reset);
    late EdgeInsets inset;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeRailLayout(
            useRail: true,
            destinations: destinations,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            child: Builder(
              builder: (context) {
                inset = MediaQuery.paddingOf(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );

    expect(inset.left, 0);
  });
}
