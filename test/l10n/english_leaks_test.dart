import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';

import '../helpers/l10n.dart';

/// The leak check of the French screen tests (englishLeaks): what it must
/// catch, and what is French and must pass. Each "catches" case was missed
/// by the check before it read semantics, tooltips and choices inside text,
/// and before it stopped excusing "Live" for looking like "LIVE".
void main() {
  final english = L10n.english;
  final french = lookupAppLocalizations(fr);

  Future<List<String>> leaksOf(WidgetTester tester, List<Widget> shown) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: SingleChildScrollView(child: Column(children: shown)),
      ),
    );
    return englishLeaks(tester);
  }

  testWidgets('catches "Live": the French "LIVE" badge excuses only itself', (
    tester,
  ) async {
    expect(english.shellFeedLive, 'Live');
    expect(french.commonLiveBadge, 'LIVE');
    expect(await leaksOf(tester, [Text(english.shellFeedLive)]), ['Live']);
    expect(await leaksOf(tester, [Text(french.commonLiveBadge)]), isEmpty);
    expect(await leaksOf(tester, [Text(french.shellFeedLive)]), isEmpty);
  });

  testWidgets('catches the English shown in capitals (a group label)', (
    tester,
  ) async {
    expect(await leaksOf(tester, [Text(english.settingsTitle.toUpperCase())]), [
      english.settingsTitle.toUpperCase(),
    ]);
    expect(
      await leaksOf(tester, [Text(french.settingsTitle.toUpperCase())]),
      isEmpty,
    );
  });

  testWidgets('catches a choice inside a longer text, every combination', (
    tester,
  ) async {
    final shown = [
      for (final goLive in OnOff.values)
        for (final mentions in OnOff.values)
          english.settingsSummaryGoLiveMentions(
            goLive: goLive.name,
            mentions: mentions.name,
          ),
    ];
    expect(await leaksOf(tester, [for (final t in shown) Text(t)]), shown);
    expect(
      await leaksOf(tester, [
        for (final goLive in OnOff.values)
          Text(
            french.settingsSummaryGoLiveMentions(
              goLive: goLive.name,
              mentions: OnOff.off.name,
            ),
          ),
      ]),
      isEmpty,
    );
  });

  testWidgets('catches a plural branch, with its number', (tester) async {
    expect(
      await leaksOf(tester, [
        Text(english.mutedKeywordsCount(count: 1)),
        Text(english.mutedKeywordsCount(count: 12)),
      ]),
      [
        english.mutedKeywordsCount(count: 1),
        english.mutedKeywordsCount(count: 12),
      ],
    );
    expect(
      await leaksOf(tester, [
        Text(french.mutedKeywordsCount(count: 0)),
        Text(french.mutedKeywordsCount(count: 12)),
      ]),
      isEmpty,
    );
  });

  testWidgets('catches what only a screen reader says: Semantics, Tooltip', (
    tester,
  ) async {
    const box = SizedBox(width: 10, height: 10);
    expect(
      await leaksOf(tester, [
        Semantics(label: english.settingsTitle, child: box),
        Semantics(value: english.commonNext, child: box),
        Tooltip(message: english.commonClose, child: box),
        IconButton(
          tooltip: english.commonBack,
          onPressed: () {},
          icon: const Icon(Icons.arrow_back),
        ),
        Text.rich(TextSpan(text: 'x', semanticsLabel: english.commonDone)),
      ]),
      unorderedEquals([
        english.settingsTitle,
        english.commonNext,
        english.commonClose,
        english.commonBack,
        // A span's label stands in for its text.
        english.commonDone,
      ]),
    );
    expect(
      await leaksOf(tester, [
        Semantics(label: french.settingsTitle, child: box),
        Tooltip(message: french.commonClose, child: box),
        IconButton(
          tooltip: french.commonBack,
          onPressed: () {},
          icon: const Icon(Icons.arrow_back),
        ),
      ]),
      isEmpty,
    );
  });

  testWidgets('passes what French writes as English does: an endonym, data', (
    tester,
  ) async {
    expect(
      await leaksOf(tester, const [
        Text('English'),
        Text('Français'),
        Text('jltomy'),
        Text('Just Chatting'),
      ]),
      isEmpty,
    );
  });
}
