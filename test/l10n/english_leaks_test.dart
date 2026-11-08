import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/home/stream_list/large_stream_card.dart';

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

  testWidgets('catches RollingViewers drawing "2,445 watching" in English on '
      'a French screen (the number and its word drawn apart)', (tester) async {
    Widget viewers({required bool english}) => Builder(
      builder: (context) => english
          ? Localizations.override(
              context: context,
              locale: en,
              child: const RollingViewers(viewers: 2445, spelled: true),
            )
          : const RollingViewers(viewers: 2445, spelled: true),
    );
    // In English the screen shows the number beside " watching".
    final leaks = await leaksOf(tester, [viewers(english: true)]);
    expect(leaks, hasLength(1));
    expect(leaks.single, endsWith(' watching'));
    expect(await leaksOf(tester, [viewers(english: false)]), isEmpty);
  });

  testWidgets('catches a number and its word in two Text widgets of a row', (
    tester,
  ) async {
    final words = english.streamWatching(count: 2445).split('2,445');
    expect(words, ['', ' watching']);
    Widget row(String number, String word) => Row(
      mainAxisSize: MainAxisSize.min,
      // As RollingNumber draws it: one Text per character, in its own row.
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final c in number.split('')) Text(c)],
        ),
        Text(word),
      ],
    );
    expect(await leaksOf(tester, [row('2 445', words.last)]), [
      '2 445 watching',
    ]);
    final french = lookupAppLocalizations(fr).streamWatching(count: 2445);
    expect(
      await leaksOf(tester, [
        row('2\u202f445', french.split('2\u202f445').last),
      ]),
      isEmpty,
    );
  });

  testWidgets('catches an English message with punctuation added', (
    tester,
  ) async {
    expect(english.clipsListFailed, 'Couldn’t load clips.');
    expect(
      await leaksOf(tester, [
        Text('${english.clipsListFailed}.'),
        Text('${english.commonTryAgain}!'),
        Text('${english.settingsTitle}\u00a0:'),
      ]),
      [
        '${english.clipsListFailed}.',
        '${english.commonTryAgain}!',
        '${english.settingsTitle}\u00a0:',
      ],
    );
    expect(
      await leaksOf(tester, [
        Text('${french.clipsListFailed}.'),
        Text('${french.settingsTitle}\u00a0:'),
      ]),
      isEmpty,
    );
  });

  testWidgets('catches an attributed Semantics label, value and hint', (
    tester,
  ) async {
    const box = SizedBox(width: 10, height: 10);
    expect(
      await leaksOf(tester, [
        Semantics(
          attributedLabel: AttributedString(english.settingsTitle),
          child: box,
        ),
        Semantics(
          attributedValue: AttributedString(english.commonNext),
          child: box,
        ),
        Semantics(
          attributedHint: AttributedString(english.commonClose),
          child: box,
        ),
      ]),
      unorderedEquals([
        english.settingsTitle,
        english.commonNext,
        english.commonClose,
      ]),
    );
    expect(
      await leaksOf(tester, [
        Semantics(
          attributedLabel: AttributedString(french.settingsTitle),
          child: box,
        ),
      ]),
      isEmpty,
    );
  });

  testWidgets('catches SelectableText, plain or rich', (tester) async {
    expect(
      await leaksOf(tester, [
        SelectableText(english.settingsTitle),
        SelectableText.rich(TextSpan(text: english.commonClose)),
      ]),
      unorderedEquals([english.settingsTitle, english.commonClose]),
    );
    expect(
      await leaksOf(tester, [SelectableText(french.settingsTitle)]),
      isEmpty,
    );
  });

  testWidgets('catches English inside composed texts and in every screen-'
      'reader field (the phase 4 review\'s plants)', (tester) async {
    const box = SizedBox(width: 10, height: 10);
    final watching = english.streamWatching(count: 2445).split('2,445').last;
    final planted = <String, Widget>{
      'a custom action': Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: english.htCollapse): () {},
        },
        child: box,
      ),
      'a tap hint': Semantics(
        onTapHint: english.htExpand,
        onTap: () {},
        child: box,
      ),
      'a long-press hint': Semantics(
        onLongPressHint: english.playerChangeChatLayout,
        onLongPress: () {},
        child: box,
      ),
      'an increased value': Semantics(
        increasedValue: english.livePlayerUnmute,
        value: '1',
        onIncrease: () {},
        child: box,
      ),
      'a decreased value': Semantics(
        decreasedValue: english.htCollapse,
        value: '1',
        onDecrease: () {},
        child: box,
      ),
      'after a leading separator': Text(' · ${english.streamOffline}'),
      'in a joined line': Text(
        [french.streamWatching(count: 2445), english.streamOffline].join(' · '),
      ),
      'inside a French sentence': Text(
        '${french.channelWebFallback(notice: '')} ${english.liveRefused}'
            .trim(),
      ),
      'a number and its word in a Wrap': Wrap(
        children: [const Text('2 445'), Text(watching)],
      ),
      'a row with a third item': Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('2 445'),
          Text(watching),
          const Text(' · 3 h 12'),
        ],
      ),
      'a joined screen-reader summary': Semantics(
        label: [
          english.highlightKind(kind: 'prediction'),
          'Qui gagne ?',
          french.highlightPredictionsOpen,
        ].join(', '),
        child: box,
      ),
      'after a bullet': Text('• ${english.clipsListFailed}'),
      'in quotes': Text('«\u00a0${english.streamOffline}\u00a0»'),
      'a stats row\'s label': Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${english.latencyStatsBuffer}  '),
            const TextSpan(text: '1,7\u00a0s'),
          ],
        ),
      ),
      'a stats row\'s value': Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${french.latencyStatsAutoLatency}  '),
            TextSpan(
              text: english.latencyAutoHeld(
                reason: english.latencyReasonPaused,
              ),
            ),
          ],
        ),
      ),
    };
    for (final MapEntry(key: where, value: widget) in planted.entries) {
      expect(await leaksOf(tester, [widget]), isNotEmpty, reason: where);
    }
    // The same shapes in French pass.
    expect(
      await leaksOf(tester, [
        Semantics(
          customSemanticsActions: {
            CustomSemanticsAction(label: french.htCollapse): () {},
          },
          onTapHint: french.htExpand,
          onTap: () {},
          child: box,
        ),
        Text(' · ${french.streamOffline}'),
        Text(
          [
            french.streamWatching(count: 2445),
            french.streamOffline,
          ].join(' · '),
        ),
        Text(french.channelWebFallback(notice: french.liveRefused)),
        Text('• ${french.clipsListFailed}'),
        Text('«\u00a0${french.streamOffline}\u00a0»'),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${french.latencyStatsBuffer}  '),
              const TextSpan(text: '1,7\u00a0s'),
            ],
          ),
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${french.latencyStatsAutoLatency}  '),
              TextSpan(
                text: french.latencyAutoHeld(
                  reason: french.latencyReasonPaused,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          label: [
            french.highlightKind(kind: 'prediction'),
            'Qui gagne ?',
            french.highlightPredictionsOpen,
          ].join(', '),
          child: box,
        ),
      ]),
      isEmpty,
    );
  });

  test('a piece is only checked against messages French cannot share', () {
    expect(textPieces(' · Offline'), ['Offline']);
    expect(textPieces('Latence : 2,3 s'), ['Latence']);
    expect(textPieces('Passage au lecteur web. Twitch refused this stream.'), [
      'Passage au lecteur web',
      'Twitch refused this stream.',
    ]);
    expect(textPieces('Buffer  1,7 s'), ['Buffer']);
  });

  testWidgets('clippedTexts finds a text cut off without an ellipsis, and '
      'only that', (tester) async {
    const long =
        'Atteignez le niveau 3 de ce train pour débloquer une réduction';
    Future<List<String>> clipsOf(Widget shown) async {
      await pumpLocalized(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 160, child: shown),
          ),
        ),
      );
      return clippedTexts(tester);
    }

    // Two lines in a box one line high (a banner of fixed height).
    expect(
      await clipsOf(
        const SizedBox(
          height: 20,
          child: Text(long, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
      [contains('px of lines in a 20.0 px box')],
    );
    // One line allowed, cut with nothing to show it (the default clip).
    expect(await clipsOf(const Text(long, maxLines: 1)), [
      contains('cut off with no ellipsis'),
    ]);
    // A line that does not wrap, cut at the box's edge.
    expect(await clipsOf(const Text(long, softWrap: false)), [
      contains('px wide in a 160.0 px box'),
    ]);
    // What a viewer can see is cut passes: an ellipsis, a fade.
    expect(
      await clipsOf(
        const Text(long, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      isEmpty,
    );
    expect(
      await clipsOf(const Text(long, maxLines: 1, overflow: TextOverflow.fade)),
      isEmpty,
    );
    // Room for every line passes.
    expect(await clipsOf(const Text(long)), isEmpty);
  });

  testWidgets('catches English inside French with no separator, and '
      'English command words in a French help line (the phase 5 review\'s '
      'plants)', (tester) async {
    expect(
      await leaksOf(tester, const [Text('Vous devez Log in to whisper')]),
      ['Vous devez Log in to whisper'],
    );
    expect(
      await leaksOf(tester, const [
        Text('Commandes : /me <message>, /color <color>, /block <user>'),
      ]),
      isNotEmpty,
    );
    expect(
      await leaksOf(tester, const [Text('/ban <utilisateur> [reason]')]),
      isNotEmpty,
    );
    // The French help line passes: « message » is the same word.
    expect(
      await leaksOf(tester, [
        Text(
          french.chatHelpCommands(
            commands:
                '/me <${french.chatCommandArgMessage}>, /color '
                '<${french.chatCommandArgColor}>, /ban '
                '<${french.chatCommandArgUser}> '
                '[${french.chatCommandArgReason}]',
          ),
        ),
      ]),
      isEmpty,
    );
  });

  testWidgets('passes chat content marked as such: a viewer\'s English '
      'message, an IRC NOTICE as Twitch sends it', (tester) async {
    const notice =
        'This room is now in slow mode. You may send messages every 30 '
        'seconds.';
    const shown = [
      Text(notice),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'bob'),
            TextSpan(text: ': '),
            TextSpan(text: 'brb, Reconnect'),
          ],
        ),
      ),
    ];
    // Unmarked, they read as English.
    expect(await leaksOf(tester, shown), isNotEmpty);
    expect(
      englishLeaks(tester, content: const [notice, 'brb, Reconnect']),
      isEmpty,
    );
    // The app's own English is never content: passing it fails the test,
    // as it would hide the leak. Twitch's own sentence holding an app's
    // words (« slow mode », « 30 seconds ») still passes, above.
    for (final app in [
      english.chatReconnect,
      english.chatReconnectingNotice,
      english.whisperLogInAgain,
    ]) {
      expect(
        () => englishLeaks(tester, content: [app]),
        throwsA(isA<TestFailure>()),
        reason: app,
      );
    }
    // What the app wrote around the content is still read.
    await leaksOf(tester, [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(text: english.chatReconnect),
            const TextSpan(text: ' · '),
            const TextSpan(text: 'Kappa 14 months!'),
          ],
        ),
      ),
    ]);
    expect(
      englishLeaks(tester, content: const ['Kappa 14 months!']),
      isNotEmpty,
    );
  });

  testWidgets('clippedTexts finds a text an ancestor cuts off, and a box '
      'squeezed under a pixel (the phase 5 review\'s plants)', (tester) async {
    const long = 'Une phrase assez longue pour deux lignes';
    final planted = <String, Widget>{
      'a ClipRect around an OverflowBox': const SizedBox(
        width: 120,
        height: 16,
        child: ClipRect(
          child: OverflowBox(
            maxHeight: double.infinity,
            alignment: Alignment.topLeft,
            child: Text(long),
          ),
        ),
      ),
      'a scroll view of fixed height the viewer cannot scroll': const SizedBox(
        width: 120,
        height: 16,
        child: SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: Text(long),
        ),
      ),
      'a ClipRect around an Align with a heightFactor': const SizedBox(
        width: 120,
        child: ClipRect(
          child: Align(
            alignment: Alignment.topLeft,
            heightFactor: 0.5,
            child: Text(long),
          ),
        ),
      ),
      'a SizeTransition half open': SizeTransition(
        sizeFactor: const AlwaysStoppedAnimation(0.5),
        axisAlignment: -1,
        child: const SizedBox(width: 120, child: Text(long)),
      ),
      'a box squeezed to half a pixel': const SizedBox(
        width: 120,
        height: 0.5,
        child: Text('Abonnements'),
      ),
    };
    for (final MapEntry(key: where, value: widget) in planted.entries) {
      await pumpLocalized(
        tester,
        Scaffold(
          body: Align(alignment: Alignment.topLeft, child: widget),
        ),
      );
      tester.takeException();
      expect(clippedTexts(tester), isNotEmpty, reason: where);
    }
    // What a viewer can scroll to, or what is hidden whole, is not cut.
    final fine = <String, Widget>{
      'a scroll view the viewer can scroll': const SizedBox(
        width: 120,
        height: 16,
        child: SingleChildScrollView(child: Text(long)),
      ),
      'a collapsed SizeTransition': SizeTransition(
        sizeFactor: const AlwaysStoppedAnimation(0),
        child: const SizedBox(width: 120, child: Text(long)),
      ),
      'a ClipRect with room': const SizedBox(
        width: 120,
        child: ClipRect(child: Text(long)),
      ),
    };
    for (final MapEntry(key: where, value: widget) in fine.entries) {
      await pumpLocalized(
        tester,
        Scaffold(
          body: Align(alignment: Alignment.topLeft, child: widget),
        ),
      );
      expect(clippedTexts(tester), isEmpty, reason: where);
    }
  });

  testWidgets('ellipsizedTexts finds words lost to an ellipsis, and only '
      'those', (tester) async {
    const long = 'Atteignez le niveau 5 et le chat recevra aussi des emotes !';
    await pumpLocalized(
      tester,
      const Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 120,
            child: Column(
              children: [
                Text(long, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(long, softWrap: false, overflow: TextOverflow.ellipsis),
                Text('Court', maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(long),
              ],
            ),
          ),
        ),
      ),
    );
    expect(ellipsizedTexts(tester), hasLength(2));
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

  test('no French text is an English text French words otherwise, so the '
      'check is never blinded', () {
    final english =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, Object?>;
    final french =
        jsonDecode(File('lib/l10n/app_fr.arb').readAsStringSync())
            as Map<String, Object?>;
    final frenchValues = {
      for (final MapEntry(:key, :value) in french.entries)
        if (value is String) value: key,
    };
    final clashes = [
      for (final MapEntry(:key, :value) in english.entries)
        if (!key.startsWith('@') &&
            value is String &&
            french[key] != value &&
            frenchValues.containsKey(value))
          '$key "$value" is the French of ${frenchValues[value]}',
    ];
    // "English" names the language in a sentence (« anglais »); the pill
    // shows it as an endonym, the same in French.
    // "Clip" and "Chat" are an English verb and placeholder whose French
    // says more (« Créer un clip », « Envoyer un message »); the French
    // nouns « Clip » and « Chat » are what other messages show.
    expect(clashes, [
      'languageInTextEnglish "English" is the French of languageNameEnglish',
      'clipCreateButton "Clip" is the French of chatLinkClip',
      'chatInputPlaceholder "Chat" is the French of channelPrefsChat',
    ]);
  });
}
