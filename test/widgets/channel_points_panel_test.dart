import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_points_service.dart';
import 'package:frosty/models/community_points.dart';
import 'package:frosty/screens/channel/stores/channel_events_store.dart';
import 'package:frosty/services/hermes_client.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/channel_points_button.dart';
import 'package:frosty/widgets/channel_points_sheet.dart';
import 'package:frosty/widgets/sheet/onset_panel.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

final _points = CommunityPointsContext(
  balance: 12840,
  rewards: const [PointsReward(id: 'hydrate', title: 'Hydrate', cost: 500)],
  predictions: [
    Prediction(
      id: 'pred',
      title: 'Will he win?',
      status: 'ACTIVE',
      outcomes: const [
        PredictionOutcome(
          id: 'yes',
          title: 'Yes',
          color: 'BLUE',
          totalPoints: 41280,
          totalUsers: 312,
        ),
        PredictionOutcome(
          id: 'no',
          title: 'No',
          color: 'PINK',
          totalPoints: 25560,
          totalUsers: 188,
        ),
      ],
    ),
  ],
);

void main() {
  late MockPointsService service;
  late ChannelEventsStore store;

  setUpAll(
    () =>
        registerFallbackValue(const PointsReward(id: 'x', title: 'x', cost: 1)),
  );

  setUp(() {
    service = MockPointsService();
    when(
      () => service.fetchContext(
        userLogin: any(named: 'userLogin'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => _points);
    when(
      () => service.makePrediction(
        eventId: any(named: 'eventId'),
        outcomeId: any(named: 'outcomeId'),
        points: any(named: 'points'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => service.redeemReward(
        channelId: any(named: 'channelId'),
        reward: any(named: 'reward'),
        authToken: any(named: 'authToken'),
        userInput: any(named: 'userInput'),
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

  Future<void> pump(
    WidgetTester tester,
    Size size, {
    Brightness brightness = Brightness.dark,
  }) async {
    await store.refreshPoints();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
    final chatWidth = size.width > size.height ? 400.0 : size.width;
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? themes.dark : themes.light,
        home: Scaffold(
          body: Provider<ChannelEventsStore?>.value(
            value: store,
            child: Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(
                width: chatWidth,
                height: size.height,
                child: const PanelRegion(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0, 0, 14, 16),
                      child: ChannelPointsButton(channelId: '42'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final brightness in Brightness.values) {
    testWidgets('phone: the sheet, then the bet as a sheet over it '
        '($brightness)', (tester) async {
      await pump(tester, const Size(390, 844), brightness: brightness);
      await tester.tap(find.byType(ChannelPointsButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('12 840'), findsOneWidget);
      expect(find.text('PREDICTION — OPEN'), findsOneWidget);
      expect(find.text('REWARDS'), findsOneWidget);

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNWidgets(2));
      final colors = brightness == Brightness.dark
          ? SheetColors.dark
          : SheetColors.light;
      expect(
        tester
            .widgetList<BottomSheet>(find.byType(BottomSheet))
            .last
            .backgroundColor,
        colors.panel,
      );
      expect(find.text('BET ON'), findsOneWidget);
    });
  }

  testWidgets('tablet: a panel above the pill, the bet inside it', (
    tester,
  ) async {
    await pump(tester, const Size(1280, 854));
    await tester.tap(find.byType(ChannelPointsButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsNothing);
    final panel = tester.getRect(find.byType(OnsetPanelSurface));
    final pill = tester.getRect(find.byType(ChannelPointsButton));
    expect(panel.size, ChannelPointsSheet.panelSize);
    expect(panel.bottom, lessThan(pill.top));
    expect(panel.right, lessThanOrEqualTo(1280 - 12));

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    // Same panel, no sheet.
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('BET ON'), findsOneWidget);
    expect(tester.getRect(find.byType(OnsetPanelSurface)), panel);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('BET ON'), findsNothing);
    expect(find.text('REWARDS'), findsOneWidget);

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SheetChoicePill, '100'));
    await tester.pump();
    await tester.tap(find.text('Bet 100'));
    await tester.pumpAndSettle();
    expect(find.byType(OnsetPanelSurface), findsNothing);
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

  testWidgets('tablet portrait: the panel still fits above the pill', (
    tester,
  ) async {
    await pump(tester, const Size(854, 1280));
    await tester.tap(find.byType(ChannelPointsButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(OnsetPanelSurface), findsOneWidget);
  });
  testWidgets('tablet: a bet left open never carries to a new prediction', (
    tester,
  ) async {
    await pump(tester, const Size(1280, 854));
    await tester.tap(find.byType(ChannelPointsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('BET ON'), findsOneWidget);

    // The prediction ends and another opens, its outcome named alike.
    when(
      () => service.fetchContext(
        userLogin: any(named: 'userLogin'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer(
      (_) async => CommunityPointsContext(
        balance: 12840,
        predictions: [
          Prediction(
            id: 'next',
            title: 'Next round?',
            status: 'ACTIVE',
            outcomes: const [
              PredictionOutcome(
                id: 'yes-2',
                title: 'Yes',
                color: 'BLUE',
                totalPoints: 10,
                totalUsers: 1,
              ),
              PredictionOutcome(
                id: 'no-2',
                title: 'No',
                color: 'PINK',
                totalPoints: 10,
                totalUsers: 1,
              ),
            ],
          ),
        ],
      ),
    );
    await store.refreshPoints();
    await tester.pumpAndSettle();
    // Back on the list: the old outcome is not offered against the new one.
    expect(find.text('BET ON'), findsNothing);
    expect(find.text('Next round?'), findsOneWidget);
  });

  testWidgets('a redeem confirmed after a rotation closed the panel '
      'still reports', (tester) async {
    await pump(tester, const Size(1280, 854));
    await tester.tap(find.byType(ChannelPointsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hydrate'));
    await tester.pumpAndSettle();
    expect(find.text('Redeem'), findsOneWidget);
    // The rotation strands the panel under the dialog: it is removed.
    tester.view.physicalSize = const Size(854, 1280);
    await tester.pumpAndSettle();
    expect(find.byType(OnsetPanelSurface), findsNothing);
    await tester.tap(find.text('Redeem'));
    await tester.pumpAndSettle();
    verify(
      () => service.redeemReward(
        channelId: '42',
        reward: any(named: 'reward'),
        authToken: 'tok',
        userInput: any(named: 'userInput'),
      ),
    ).called(1);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
