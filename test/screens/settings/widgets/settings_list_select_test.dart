import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/widgets/settings_list_select.dart';

enum _Profile { standard, ultra }

enum _CatchUp { speedUp, jumpToLive }

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the subtitle under the options', (tester) async {
    await tester.pumpWidget(
      host(
        SettingsListSelect<_Profile>(
          title: 'Buffer profile',
          subtitle: 'Applies the next time a stream is opened.',
          value: _Profile.standard,
          values: _Profile.values,
          labelOf: (profile) => switch (profile) {
            _Profile.standard => 'Standard',
            _Profile.ultra => 'Ultra',
          },
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

  testWidgets('reports the value tapped, not its label', (tester) async {
    _CatchUp? selected;
    await tester.pumpWidget(
      host(
        SettingsListSelect<_CatchUp>(
          title: 'Live catch-up',
          value: _CatchUp.speedUp,
          values: _CatchUp.values,
          labelOf: (mode) => switch (mode) {
            _CatchUp.speedUp => 'Speed up',
            _CatchUp.jumpToLive => 'Jump to live',
          },
          onChanged: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.text('Jump to live'));

    expect(selected, _CatchUp.jumpToLive);
  });

  testWidgets('two options with the same label stay two choices', (
    tester,
  ) async {
    _CatchUp? selected;
    await tester.pumpWidget(
      host(
        SettingsListSelect<_CatchUp>(
          stacked: true,
          groupLabel: 'Same',
          value: _CatchUp.speedUp,
          values: _CatchUp.values,
          labelOf: (_) => 'Auto',
          onChanged: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.text('Auto').last);

    expect(selected, _CatchUp.jumpToLive);
  });

  testWidgets('tapping the selected option says nothing', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        SettingsListSelect<_Profile>(
          title: 'Buffer profile',
          value: _Profile.standard,
          values: _Profile.values,
          labelOf: (profile) => profile.name,
          onChanged: (_) => calls++,
        ),
      ),
    );

    await tester.tap(find.text('standard'));

    expect(calls, 0);
  });
}
