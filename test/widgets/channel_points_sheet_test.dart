import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_points_service.dart';
import 'package:frosty/models/community_points.dart';
import 'package:frosty/screens/channel/stores/channel_events_store.dart';
import 'package:frosty/services/hermes_client.dart';
import 'package:frosty/widgets/channel_points_sheet.dart';
import 'package:mocktail/mocktail.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

const _hydrate = PointsReward(id: 'hydrate', title: 'Hydrate', cost: 100);
Prediction _prediction({String status = 'ACTIVE'}) => Prediction(
  id: 'pred',
  title: 'Will he win?',
  status: status,
  outcomes: const [
    PredictionOutcome(
      id: 'yes',
      title: 'Yes',
      color: 'BLUE',
      totalPoints: 3000,
      totalUsers: 3,
    ),
    PredictionOutcome(
      id: 'no',
      title: 'No',
      color: 'PINK',
      totalPoints: 1000,
      totalUsers: 1,
    ),
  ],
);

void main() {
  setUpAll(() => registerFallbackValue(_hydrate));

  late MockPointsService service;
  late ChannelEventsStore store;
  late CommunityPointsContext context;

  setUp(() {
    service = MockPointsService();
    context = const CommunityPointsContext();
    when(
      () => service.fetchContext(
        userLogin: any(named: 'userLogin'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => context);
    when(
      () => service.redeemReward(
        channelId: any(named: 'channelId'),
        reward: any(named: 'reward'),
        authToken: any(named: 'authToken'),
        userInput: any(named: 'userInput'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => service.makePrediction(
        eventId: any(named: 'eventId'),
        outcomeId: any(named: 'outcomeId'),
        points: any(named: 'points'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => service.claimBonus(
        channelId: any(named: 'channelId'),
        claimId: any(named: 'claimId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => null);
    store = ChannelEventsStore(
      channelId: '42',
      channelLogin: 'streamer',
      client: MockHermesClient(),
      pointsService: service,
      tokenProvider: () async => 'tok',
    );
  });

  /// Shows the sheet for [points], loaded into the store as Twitch would.
  Future<void> pump(WidgetTester tester, CommunityPointsContext points) async {
    context = points;
    await store.refreshPoints();
    tester.view
      ..physicalSize = const Size(800, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChannelPointsSheet(points: points, store: store),
        ),
      ),
    );
  }

  Future<void> openBet(WidgetTester tester, {int balance = 1000}) async {
    await pump(
      tester,
      CommunityPointsContext(balance: balance, predictions: [_prediction()]),
    );
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
  }

  FilledButton betButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(
      of: find.textContaining(RegExp(r'^Bet')),
      matching: find.byType(FilledButton),
    ),
  );

  group('the bet sheet', () {
    testWidgets('clearing the field does not keep the last stake', (
      tester,
    ) async {
      await openBet(tester);

      await tester.enterText(find.byType(TextField), '500');
      await tester.pump();
      expect(find.text('Bet 500'), findsOneWidget);
      expect(betButton(tester).onPressed, isNotNull);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(find.text('Bet 500'), findsNothing);
      expect(find.text('Bet'), findsOneWidget);
      expect(betButton(tester).onPressed, isNull);
    });
  });
}
