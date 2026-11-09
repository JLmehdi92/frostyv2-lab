import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/recommended_channel.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/widgets/recommendations/recommended_channels.dart';
import 'package:provider/provider.dart';

import '../../fixtures/social_payloads.dart';
import '../../helpers/l10n.dart';

List<RecommendedChannel> _channels() => [
  for (final item
      in (personalSectionsResponse()['data']!
              as Map)['personalSections'][0]['items']
          as List)
    RecommendedChannel.fromItem(item)!,
];

void main() {
  late SettingsStore settings;

  setUp(() => settings = SettingsStore());

  Future<void> pump(WidgetTester tester, Widget child) => pumpLocalized(
    tester,
    Provider<SettingsStore>.value(
      value: settings,
      child: Scaffold(body: child),
    ),
    locale: en,
  );

  testWidgets('the shelf shows channels and leaves out hidden ones', (
    tester,
  ) async {
    settings.markNotInterested('1001', 'Alpha_Live');
    await pump(
      tester,
      ListView(children: [RecommendationsShelf(load: () async => _channels())]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Channels for you'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('Alpha_Live'), findsNothing);

    settings.markNotInterested('1002', 'beta');
    await tester.pumpAndSettle();
    expect(find.byKey(RecommendationsShelf.shelfKey), findsNothing);
  });

  testWidgets('a failed load hides the shelf', (tester) async {
    await pump(tester, RecommendationsShelf(load: () async => null));
    await tester.pumpAndSettle();
    expect(find.byKey(RecommendationsShelf.shelfKey), findsNothing);
  });

  testWidgets('not interested asks a reason, hides, and can be undone', (
    tester,
  ) async {
    final told = <NotInterestedReason>[];
    final channel = _channels().last;
    await pump(
      tester,
      SimilarChannelsSheet(
        name: 'Alpha_Live',
        load: () async => _channels(),
        onOpen: (_) {},
        onNotInterested: (channel) {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Channels like Alpha_Live'), findsOneWidget);
    expect(find.text('Chess · 1,200 viewers'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => markNotInterested(
            context,
            channel,
            tellTwitch: (c, reason) async {
              told.add(reason);
              return ViewerActionOutcome.done;
            },
            signedIn: true,
          ),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Not interested in beta?'), findsOneWidget);
    expect(find.text('Twitch receives your reason.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('not-interested-offensive')));
    await tester.pumpAndSettle();
    expect(told, [NotInterestedReason.offensive]);
    expect(settings.notInterestedChannels, {'1002': 'beta'});
    expect(
      find.text(
        'You won’t see beta in suggestions. Undo restores it in ONSET only.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Undo'));
    expect(settings.notInterestedChannels, isEmpty);
  });

  testWidgets('a refused reason still hides, and says Twitch has none', (
    tester,
  ) async {
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => markNotInterested(
            context,
            _channels().last,
            tellTwitch: (c, reason) async => ViewerActionOutcome.failed,
            signedIn: true,
          ),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('not-interested-other')));
    await tester.pumpAndSettle();
    expect(settings.notInterestedChannels.keys, ['1002']);
    expect(find.textContaining('hidden in ONSET only'), findsOneWidget);
  });

  testWidgets('signed out, nothing is sent and the sheet says nothing of Twitch', (
    tester,
  ) async {
    var sent = 0;
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => markNotInterested(
            context,
            _channels().last,
            tellTwitch: (c, reason) async {
              sent++;
              return ViewerActionOutcome.done;
            },
            signedIn: false,
          ),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Twitch receives your reason.'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('not-interested-other')));
    await tester.pumpAndSettle();
    expect(sent, 0);
    expect(settings.notInterestedChannels.keys, ['1002']);
    expect(
      find.text('You won’t see beta in suggestions in ONSET.'),
      findsOneWidget,
    );
  });
}
