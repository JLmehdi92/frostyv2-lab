import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_tv_auth_service.dart';
import 'package:onset/main.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/screens/channel/chat/widgets/channel_points_sheet.dart';
import 'package:onset/screens/channel/chat/widgets/prediction_dialogs.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/screens/settings/stores/twitch_tv_session_store.dart';
import 'package:onset/services/hermes_client.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:provider/provider.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

const _hydrate = PointsReward(id: 'hydrate', title: 'Hydrate', cost: 100);
const _song = PointsReward(
  id: 'song',
  title: 'Request a song',
  cost: 200,
  requiresInput: true,
);
const _pricey = PointsReward(id: 'pricey', title: 'Pick a game', cost: 5000);
const _builtIn = PointsReward(
  id: 'auto',
  title: 'Highlight my message',
  cost: 50,
  automaticType: 'SEND_HIGHLIGHTED_MESSAGE',
);

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

class _MockTvAuth extends Mock implements TwitchTvAuthService {}

void main() {
  setUpAll(() => registerFallbackValue(_hydrate));

  late MockPointsService service;
  late ChannelEventsStore store;
  late CommunityPointsContext context;
  late PredictionAccess access;

  setUp(() {
    service = MockPointsService();
    access = const PredictionAccess(hasAcceptedTerms: true);
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
      () => service.fetchPredictionAccess(
        eventId: any(named: 'eventId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => access);
    when(
      () => service.acceptPredictionTerms(
        temporaryBadgeEnabled: any(named: 'temporaryBadgeEnabled'),
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
  Future<void> pump(
    WidgetTester tester,
    CommunityPointsContext points, {
    TwitchTvSessionStore? tvSession,
  }) async {
    context = points;
    await store.refreshPoints();
    tester.view
      ..physicalSize = const Size(800, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<TwitchTvSessionStore?>.value(
        value: tvSession,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: Scaffold(
            body: ChannelPointsSheet(points: points, store: store),
          ),
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

  /// What a tap on the reward [title] does (null: not tappable).
  VoidCallback? tile(WidgetTester tester, String title) {
    final row = find.ancestor(
      of: find.text(title),
      matching: find.byType(RewardRow),
    );
    return tester.widget<RewardRow>(row).onTapFor(tester.element(row));
  }

  void verifyNoRedeem() => verifyNever(
    () => service.redeemReward(
      channelId: any(named: 'channelId'),
      reward: any(named: 'reward'),
      authToken: any(named: 'authToken'),
      userInput: any(named: 'userInput'),
    ),
  );

  group('rewards', () {
    testWidgets('only an affordable custom reward can be tapped', (
      tester,
    ) async {
      await pump(
        tester,
        const CommunityPointsContext(
          balance: 1000,
          rewards: [_builtIn, _hydrate, _pricey],
        ),
      );

      expect(tile(tester, 'Hydrate'), isNotNull);
      expect(tile(tester, 'Pick a game'), isNull);
      expect(tile(tester, 'Highlight my message'), isNull);
    });

    testWidgets('signed out: nothing can be tapped, and it says why', (
      tester,
    ) async {
      await pump(tester, const CommunityPointsContext(rewards: [_hydrate]));

      expect(find.text('Log in to see your balance.'), findsOneWidget);
      expect(tile(tester, 'Hydrate'), isNull);
    });

    testWidgets('a reward that asks for text waits for it', (tester) async {
      await pump(
        tester,
        const CommunityPointsContext(balance: 1000, rewards: [_song]),
      );

      await tester.tap(find.text('Request a song'));
      await tester.pumpAndSettle();
      expect(find.text('Spend 200 points?'), findsOneWidget);
      FilledButton redeem() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Redeem'),
      );
      expect(redeem().onPressed, isNull);

      await tester.enterText(find.byType(TextField), '  Darude  ');
      await tester.pump();
      await tester.tap(find.text('Redeem'));
      await tester.pumpAndSettle();

      verify(
        () => service.redeemReward(
          channelId: '42',
          reward: _song,
          authToken: 'tok',
          userInput: 'Darude',
        ),
      ).called(1);
      expect(find.text('Done.'), findsOneWidget);
    });

    testWidgets('the message is capped at 200 characters, and counted', (
      tester,
    ) async {
      await pump(
        tester,
        const CommunityPointsContext(balance: 1000, rewards: [_song]),
      );
      await tester.tap(find.text('Request a song'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'a' * 260);
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.length, 200);
      expect(find.text('200 / 200'), findsOneWidget);
    });

    testWidgets('a reward without text is confirmed and sent bare', (
      tester,
    ) async {
      await pump(
        tester,
        const CommunityPointsContext(balance: 1000, rewards: [_hydrate]),
      );

      await tester.tap(find.text('Hydrate'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Redeem'));
      await tester.pumpAndSettle();

      verify(
        () => service.redeemReward(
          channelId: '42',
          reward: _hydrate,
          authToken: 'tok',
        ),
      ).called(1);
    });

    testWidgets('cancel spends nothing', (tester) async {
      await pump(
        tester,
        const CommunityPointsContext(balance: 1000, rewards: [_hydrate]),
      );

      await tester.tap(find.text('Hydrate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNoRedeem();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('an integrity refusal is reported as such', (tester) async {
      when(
        () => service.redeemReward(
          channelId: any(named: 'channelId'),
          reward: any(named: 'reward'),
          authToken: any(named: 'authToken'),
          userInput: any(named: 'userInput'),
        ),
      ).thenAnswer((_) async => 'failed integrity check');
      await pump(
        tester,
        const CommunityPointsContext(balance: 1000, rewards: [_hydrate]),
      );

      await tester.tap(find.text('Hydrate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Redeem'));
      await tester.pumpAndSettle();

      expect(find.textContaining('anti-bot check'), findsOneWidget);
    });

    testWidgets('an integrity refusal offers to connect a Twitch session', (
      tester,
    ) async {
      when(
        () => service.redeemReward(
          channelId: any(named: 'channelId'),
          reward: any(named: 'reward'),
          authToken: any(named: 'authToken'),
          userInput: any(named: 'userInput'),
        ),
      ).thenAnswer((_) async => 'failed integrity check');
      await pump(
        tester,
        const CommunityPointsContext(balance: 1000, rewards: [_hydrate]),
        tvSession: TwitchTvSessionStore(
          auth: _MockTvAuth(),
          viewerId: () => '77',
        ),
      );

      await tester.tap(find.text('Hydrate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Redeem'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SnackBarAction, 'Connect'), findsOneWidget);
    });

    testWidgets('a channel without rewards says so', (tester) async {
      await pump(tester, const CommunityPointsContext(balance: 10));

      expect(find.text('This channel has no rewards set up.'), findsOneWidget);
    });
  });

  group('the bonus chest', () {
    const withChest = CommunityPointsContext(
      balance: 1000,
      availableClaimId: 'chest',
    );

    // `FilledButton.icon` builds a subclass, which `byType` would miss.
    FilledButton collect(WidgetTester tester) => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Collect bonus'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );

    testWidgets('is offered only while there is one', (tester) async {
      await pump(tester, const CommunityPointsContext(balance: 1000));
      expect(find.text('Collect bonus'), findsNothing);

      await pump(tester, withChest);
      expect(collect(tester).onPressed, isNotNull);
    });

    testWidgets('is disabled while an action is in flight', (tester) async {
      final reply = Completer<String?>();
      when(
        () => service.claimBonus(
          channelId: any(named: 'channelId'),
          claimId: any(named: 'claimId'),
          authToken: any(named: 'authToken'),
        ),
      ).thenAnswer((_) => reply.future);
      await pump(tester, withChest);

      await tester.tap(find.text('Collect bonus'));
      await tester.pump();
      expect(collect(tester).onPressed, isNull);

      reply.complete(null);
      await tester.pumpAndSettle();
      expect(collect(tester).onPressed, isNotNull);
    });

    testWidgets('an integrity refusal replaces it with an explanation', (
      tester,
    ) async {
      when(
        () => service.claimBonus(
          channelId: any(named: 'channelId'),
          claimId: any(named: 'claimId'),
          authToken: any(named: 'authToken'),
        ),
      ).thenAnswer((_) async => 'failed integrity check');
      await pump(tester, withChest);

      await tester.tap(find.text('Collect bonus'));
      await tester.pumpAndSettle();

      expect(find.text('Collect bonus'), findsNothing);
      expect(
        find.textContaining('Twitch’s anti-bot check refused the bonus'),
        findsOneWidget,
      );
    });
  });

  group('predictions', () {
    testWidgets('an open one can be bet on', (tester) async {
      await pump(
        tester,
        CommunityPointsContext(balance: 1000, predictions: [_prediction()]),
      );

      expect(find.text('PREDICTION — OPEN'), findsOneWidget);
      expect(find.text('Tap an outcome to bet.'), findsOneWidget);
      expect(find.text('1.33×'), findsOneWidget);
      expect(find.text('4.00×'), findsOneWidget);
    });

    testWidgets('a locked one shows its odds but takes no bet', (tester) async {
      await pump(
        tester,
        CommunityPointsContext(
          balance: 1000,
          predictions: [_prediction(status: 'LOCKED')],
        ),
      );

      expect(find.text('PREDICTION — LOCKED'), findsOneWidget);
      expect(find.text('Tap an outcome to bet.'), findsNothing);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(find.text('BET ON'), findsNothing);
    });
  });

  group('the bet sheet', () {
    testWidgets('starts at the minimum, offers what the balance allows', (
      tester,
    ) async {
      await openBet(tester, balance: 1500);

      expect(find.text('BET ON'), findsOneWidget);
      expect(find.text('Bet 10'), findsOneWidget);
      expect(find.widgetWithText(SheetChoicePill, '10'), findsOneWidget);
      expect(find.widgetWithText(SheetChoicePill, '100'), findsOneWidget);
      expect(find.widgetWithText(SheetChoicePill, '1 000'), findsOneWidget);
      expect(find.widgetWithText(SheetChoicePill, '10 000'), findsNothing);

      await tester.tap(find.widgetWithText(SheetChoicePill, 'Max'));
      await tester.pump();
      expect(find.text('Bet 1 500'), findsOneWidget);
    });

    testWidgets('more than the balance cannot be bet', (tester) async {
      await openBet(tester, balance: 1500);

      await tester.enterText(find.byType(TextField), '2000');
      await tester.pump();

      expect(betButton(tester).onPressed, isNull);
    });

    testWidgets('a balance under the minimum cannot bet at all', (
      tester,
    ) async {
      await openBet(tester, balance: 5);

      expect(find.text('You need at least 10 points to bet.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a bet is sent with its outcome and stake', (tester) async {
      await openBet(tester);

      await tester.tap(find.widgetWithText(SheetChoicePill, '100'));
      await tester.pump();
      await tester.tap(find.text('Bet 100'));
      await tester.pumpAndSettle();

      verify(
        () => service.makePrediction(
          eventId: 'pred',
          outcomeId: 'yes',
          points: 100,
          authToken: 'tok',
        ),
      ).called(1);
      expect(find.text('Done.'), findsOneWidget);
    });

    testWidgets('the stake takes digits only', (tester) async {
      await openBet(tester);
      await tester.enterText(find.byType(TextField), '1,5e2-');
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '152');
      expect(find.text('Bet 152'), findsOneWidget);
    });

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

  group('prediction terms, spectators and moderators', () {
    void verifyBet(int points) => verify(
      () => service.makePrediction(
        eventId: 'pred',
        outcomeId: 'yes',
        points: points,
        authToken: 'tok',
      ),
    ).called(1);

    void verifyNoBet() => verifyNever(
      () => service.makePrediction(
        eventId: any(named: 'eventId'),
        outcomeId: any(named: 'outcomeId'),
        points: any(named: 'points'),
        authToken: any(named: 'authToken'),
      ),
    );

    testWidgets('a first bet asks for the terms, then accepts them', (
      tester,
    ) async {
      access = const PredictionAccess(hasAcceptedTerms: false);
      await openBet(tester);
      await tester.tap(find.text('Bet 10'));
      await tester.pumpAndSettle();

      expect(
        find.text('Predict “Yes” with 10 channel points?'),
        findsOneWidget,
      );
      expect(find.text('Prediction terms'), findsOneWidget);
      verifyNoBet();

      await tester.tap(find.byKey(PredictionTermsDialog.acceptKey));
      await tester.pumpAndSettle();

      verify(
        () => service.acceptPredictionTerms(
          temporaryBadgeEnabled: true,
          authToken: 'tok',
        ),
      ).called(1);
      verifyBet(10);
    });

    testWidgets('going back from the terms bets nothing', (tester) async {
      access = const PredictionAccess(hasAcceptedTerms: false);
      await openBet(tester);
      await tester.tap(find.text('Bet 10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();

      verifyNoBet();
      verifyNever(
        () => service.acceptPredictionTerms(
          temporaryBadgeEnabled: any(named: 'temporaryBadgeEnabled'),
          authToken: any(named: 'authToken'),
        ),
      );
    });

    testWidgets('a region-locked viewer predicts with 0 points', (
      tester,
    ) async {
      access = const PredictionAccess(
        hasAcceptedTerms: true,
        restriction: PredictionRestriction.regionLocked,
      );
      await openBet(tester);

      expect(find.text('BET ON'), findsNothing);
      expect(find.text('Predict “Yes” with 0 channel points?'), findsOneWidget);
      expect(
        find.text(
          'Viewers in your region can only predict without spending '
          'channel points.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(PredictionTermsDialog.acceptKey));
      await tester.pumpAndSettle();

      verifyBet(0);
      expect(
        find.text('You predicted “Yes” with 0 channel points.'),
        findsOneWidget,
      );
    });

    testWidgets('a moderator confirms before betting', (tester) async {
      access = const PredictionAccess(
        hasAcceptedTerms: true,
        restriction: PredictionRestriction.moderator,
      );
      await pump(
        tester,
        CommunityPointsContext(
          balance: 1000,
          predictions: [
            Prediction(
              id: 'pred',
              title: 'Will he win?',
              status: 'ACTIVE',
              creatorId: '42',
              outcomes: _prediction().outcomes,
            ),
          ],
        ),
      );
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(find.text('You’re taking part as a moderator'), findsOneWidget);
      expect(
        find.textContaining('The streamer created this prediction.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('BET ON'), findsNothing);

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PredictionModeratorDialog.acceptKey));
      await tester.pumpAndSettle();
      expect(find.text('BET ON'), findsOneWidget);
    });

    testWidgets('a terms refusal shows the terms and retries once', (
      tester,
    ) async {
      var calls = 0;
      when(
        () => service.makePrediction(
          eventId: any(named: 'eventId'),
          outcomeId: any(named: 'outcomeId'),
          points: any(named: 'points'),
          authToken: any(named: 'authToken'),
        ),
      ).thenAnswer((_) async => calls++ == 0 ? 'MUST_ACCEPT_TOS' : null);
      await openBet(tester);
      await tester.tap(find.text('Bet 10'));
      await tester.pumpAndSettle();

      expect(find.text('Prediction terms'), findsOneWidget);
      await tester.tap(find.byKey(PredictionTermsDialog.acceptKey));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.text('Done.'), findsOneWidget);
    });

    testWidgets('a named refusal is explained', (tester) async {
      when(
        () => service.makePrediction(
          eventId: any(named: 'eventId'),
          outcomeId: any(named: 'outcomeId'),
          points: any(named: 'points'),
          authToken: any(named: 'authToken'),
        ),
      ).thenAnswer((_) async => 'EVENT_MANAGER');
      await openBet(tester);
      await tester.tap(find.text('Bet 10'));
      await tester.pumpAndSettle();

      expect(
        find.text('Streamers can’t predict on their own channel.'),
        findsOneWidget,
      );
    });
  });

  test('who created a prediction, as the moderator step names it', () {
    Prediction by(String? id, [String? name]) => Prediction(
      id: 'p',
      title: 't',
      status: 'ACTIVE',
      creatorId: id,
      creatorName: name,
    );

    expect(
      predictionCreatorOf(by('42'), channelId: '42', viewerId: '7'),
      PredictionCreator.streamer,
    );
    expect(
      predictionCreatorOf(by('7'), channelId: '42', viewerId: '7'),
      PredictionCreator.self,
    );
    expect(
      predictionCreatorOf(by('9', 'Mod'), channelId: '42', viewerId: '7'),
      PredictionCreator.other,
    );
    expect(
      predictionCreatorOf(by(null), channelId: '42'),
      PredictionCreator.unknown,
    );
  });
}
