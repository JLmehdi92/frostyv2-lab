import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/recap.dart';
import 'package:onset/screens/channel_profile/widgets/profile_recaps_shelf.dart';
import 'package:onset/screens/clips/recap_screen.dart';
import 'package:onset/widgets/report/report_sheet.dart';
import 'package:onset/widgets/twitch_web_page.dart';

import '../../fixtures/clip_extras_payloads.dart';
import '../../helpers/fake_vod_controller.dart';
import '../../helpers/l10n.dart';

Recap recapFixture() => Recap.tryParse(recapNode())!;

void main() {
  tearDown(() => TwitchWebPage.debugBody = null);

  group('ProfileRecapsShelf', () {
    testWidgets('shows the recaps', (tester) async {
      await pumpLocalized(
        tester,
        Scaffold(body: ProfileRecapsShelf(load: () async => [recapFixture()])),
        locale: en,
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Stream recaps'), findsOneWidget);
      expect(find.text('Warzone night'), findsOneWidget);
      expect(find.text('2 clips'), findsOneWidget);
    });

    testWidgets('nothing when empty or failing', (tester) async {
      await pumpLocalized(
        tester,
        Scaffold(
          body: Column(
            children: [
              ProfileRecapsShelf(load: () async => const []),
              ProfileRecapsShelf(load: () async => throw Exception('down')),
            ],
          ),
        ),
        locale: en,
      );
      await tester.pumpAndSettle();
      expect(find.text('Stream recaps'), findsNothing);
    });
  });

  group('RecapScreen', () {
    testWidgets('plays the fresh recap and reports on a tap', (tester) async {
      TwitchWebPage.debugBody = () => const SizedBox(key: ValueKey('web'));
      final players = <String>[];
      await pumpLocalized(
        tester,
        RecapScreen(
          recap: recapFixture(),
          refresh: (_) async => recapFixture(),
          playerFactory: (clip, {required portrait}) {
            players.add(clip.slug);
            return FakeVodController();
          },
        ),
        locale: en,
      );
      await tester.pumpAndSettle();
      expect(players, ['AmusedPlainTaro-yCRO7oUZG8QUP-yO']);
      expect(find.text('Caster'), findsOneWidget);
      expect(find.text('Warzone night'), findsOneWidget);
      await tester.tap(find.byKey(RecapScreen.reportKey));
      await tester.pumpAndSettle();
      expect(find.text('Report on twitch.tv?'), findsOneWidget);
      await tester.tap(find.byKey(ReportSheet.webFallbackKey));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web')), findsOneWidget);
    });

    testWidgets('a removed recap says it is no longer available', (
      tester,
    ) async {
      final players = <String>[];
      await pumpLocalized(
        tester,
        RecapScreen(
          recap: recapFixture(),
          refresh: (_) async => throw const RecapUnavailableException(),
          playerFactory: (clip, {required portrait}) {
            players.add(clip.slug);
            return FakeVodController();
          },
        ),
        locale: en,
      );
      await tester.pumpAndSettle();
      expect(find.text('This recap is no longer available.'), findsOneWidget);
      expect(players, isEmpty);
    });

    testWidgets('a failed check still plays what the shelf had', (
      tester,
    ) async {
      final players = <String>[];
      await pumpLocalized(
        tester,
        RecapScreen(
          recap: recapFixture(),
          refresh: (_) async => throw Exception('offline'),
          playerFactory: (clip, {required portrait}) {
            players.add(clip.slug);
            return FakeVodController();
          },
        ),
        locale: en,
      );
      await tester.pumpAndSettle();
      expect(players, hasLength(1));
    });
  });
}
