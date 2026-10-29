import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/widgets/settings_list_select.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the subtitle under the options', (tester) async {
    await tester.pumpWidget(
      host(
        SettingsListSelect(
          title: 'Buffer profile',
          subtitle: 'Applies the next time a stream is opened.',
          selectedOption: 'Standard',
          options: const ['Standard', 'Ultra'],
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Buffer profile'), findsOneWidget);
    expect(
      find.text('Applies the next time a stream is opened.'),
      findsOneWidget,
    );
    expect(find.text('Ultra'), findsOneWidget);
  });

  testWidgets('reports the selected option', (tester) async {
    String? selected;
    await tester.pumpWidget(
      host(
        SettingsListSelect(
          title: 'Live catch-up',
          selectedOption: 'Speed up',
          options: const ['Speed up', 'Jump to live'],
          onChanged: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.text('Jump to live'));

    expect(selected, 'Jump to live');
  });
}
