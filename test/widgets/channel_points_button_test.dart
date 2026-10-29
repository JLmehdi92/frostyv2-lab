import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/widgets/channel_points_button.dart';
import 'package:provider/provider.dart';

class MockChannelEventsStore extends Mock implements ChannelEventsStore {}

void main() {
  late MockChannelEventsStore store;

  setUp(() {
    store = MockChannelEventsStore();
    when(() => store.channelId).thenReturn('watched');
    when(() => store.points).thenReturn(CommunityPointsContext.empty);
  });

  Future<void> pump(WidgetTester tester, {String? channelId}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<ChannelEventsStore?>.value(
              value: store,
              child: ChannelPointsButton(channelId: channelId),
            ),
          ),
        ),
      );

  test('compact shortens a balance the way Twitch does', () {
    const table = {
      0: '0',
      999: '999',
      1000: '1K',
      1500: '1.5K',
      9999: '10K',
      12345: '12K',
      999499: '999K',
      999500: '1M',
      1000000: '1M',
      1250000: '1.3M',
      9999999: '10M',
      25000000: '25M',
    };
    for (final MapEntry(:key, :value) in table.entries) {
      expect(ChannelPointsButton.compact(key), value, reason: '$key');
    }
  });

  testWidgets("another channel's chat tab never reads the store", (
    tester,
  ) async {
    await pump(tester, channelId: 'other');

    verifyNever(() => store.points);
  });

  testWidgets("the watched channel's chat reads it", (tester) async {
    await pump(tester, channelId: 'watched');

    verify(() => store.points).called(greaterThan(0));
  });

  group('what the button shows', () {
    Future<void> show(WidgetTester tester, CommunityPointsContext points) {
      when(() => store.points).thenReturn(points);
      return pump(tester, channelId: 'watched');
    }

    testWidgets('nothing at all without a points context', (tester) async {
      await show(tester, CommunityPointsContext.empty);

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('a dash while signed out, the compact balance otherwise', (
      tester,
    ) async {
      await show(
        tester,
        const CommunityPointsContext(
          rewards: [PointsReward(id: 'r', title: 'R', cost: 1)],
        ),
      );
      expect(find.text('—'), findsOneWidget);

      await show(tester, const CommunityPointsContext(balance: 1250000));
      expect(find.text('1.3M'), findsOneWidget);
    });

    testWidgets('a chest outranks a prediction, which outranks the artwork', (
      tester,
    ) async {
      const open = Prediction(id: 'p', title: 'P', status: 'ACTIVE');
      const art = 'https://cdn.example/points/icon-1.png';

      await show(
        tester,
        const CommunityPointsContext(
          balance: 10,
          availableClaimId: 'chest',
          predictions: [open],
          pointsImageUrl: art,
        ),
      );
      expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
      expect(find.byIcon(Icons.leaderboard_rounded), findsNothing);

      await show(
        tester,
        const CommunityPointsContext(
          balance: 10,
          predictions: [open],
          pointsImageUrl: art,
        ),
      );
      expect(find.byIcon(Icons.card_giftcard_rounded), findsNothing);
      expect(find.byIcon(Icons.leaderboard_rounded), findsOneWidget);

      await show(
        tester,
        const CommunityPointsContext(balance: 10, pointsImageUrl: art),
      );
      expect(find.byIcon(Icons.leaderboard_rounded), findsNothing);
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as NetworkImage).url,
        'https://cdn.example/points/icon-2.png',
      );
    });

    testWidgets('a locked prediction does not take the icon', (tester) async {
      await show(
        tester,
        const CommunityPointsContext(
          balance: 10,
          predictions: [Prediction(id: 'p', title: 'P', status: 'LOCKED')],
        ),
      );

      expect(find.byIcon(Icons.leaderboard_rounded), findsNothing);
      expect(find.byKey(ChannelPointsButton.genericIconKey), findsOneWidget);
    });
  });

  testWidgets('outside a channel there is no store and no button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Provider<ChannelEventsStore?>.value(
            value: null,
            child: const ChannelPointsButton(),
          ),
        ),
      ),
    );

    expect(find.byType(InkWell), findsNothing);
  });
}
