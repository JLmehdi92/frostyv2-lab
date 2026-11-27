import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

import '../../helpers/l10n.dart';

class _Screen extends StatefulWidget {
  const _Screen({required this.probe});

  final bool probe;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  static var builds = 0;
  ModalRoute<dynamic>? route;

  bool get current => widget.probe
      ? route?.isCurrent == true
      : ModalRoute.of(context)?.isCurrent == true;

  @override
  Widget build(BuildContext context) {
    builds++;
    final content = Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showOnsetSheet<void>(
              context: context,
              builder: (_) => const SizedBox(height: 200),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    if (!widget.probe) return content;
    return Builder(
      builder: (context) {
        route = ModalRoute.of(context);
        return content;
      },
    );
  }
}

Future<int> _buildsWhileOpening(
  WidgetTester tester, {
  required bool probe,
}) async {
  await pumpLocalized(tester, _Screen(probe: probe));
  final state = tester.state<_ScreenState>(find.byType(_Screen));
  expect(state.current, isTrue);
  _ScreenState.builds = 0;
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pumpAndSettle();
  expect(state.current, isFalse);
  return _ScreenState.builds;
}

void main() {
  testWidgets('reading the route from the screen rebuilds it under a sheet', (
    tester,
  ) async {
    expect(await _buildsWhileOpening(tester, probe: false), greaterThan(0));
  });

  testWidgets('the route read below the screen leaves it alone', (
    tester,
  ) async {
    expect(await _buildsWhileOpening(tester, probe: true), 0);
  });
}
