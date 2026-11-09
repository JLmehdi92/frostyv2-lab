import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/services/hermes_client.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

void main() {
  late MockPointsService service;
  late String? token;

  ChannelEventsStore store() => ChannelEventsStore(
    channelId: '42',
    client: MockHermesClient(),
    pointsService: service,
    tokenProvider: () async => token,
  );

  setUp(() {
    service = MockPointsService();
    token = 'tok';
    when(
      () => service.fetchPredictionAccess(
        eventId: any(named: 'eventId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer(
      (_) async => const PredictionAccess(
        hasAcceptedTerms: false,
        restriction: PredictionRestriction.moderator,
      ),
    );
    when(
      () => service.acceptPredictionTerms(
        temporaryBadgeEnabled: any(named: 'temporaryBadgeEnabled'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => null);
  });

  test('reads an event access once and keeps it', () async {
    final events = store();

    final first = await events.predictionAccess('e1');
    await events.predictionAccess('e1');

    expect(first.restriction, PredictionRestriction.moderator);
    verify(
      () => service.fetchPredictionAccess(eventId: 'e1', authToken: 'tok'),
    ).called(1);
  });

  test('signed out or failing, nothing is restricted', () async {
    token = null;
    expect(
      (await store().predictionAccess('e1')).restriction,
      PredictionRestriction.none,
    );

    token = 'tok';
    when(
      () => service.fetchPredictionAccess(
        eventId: any(named: 'eventId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenThrow(StateError('boom'));
    expect((await store().predictionAccess('e2')).needsTerms, isFalse);
  });

  test('accepting the terms clears them from what is kept', () async {
    final events = store();
    expect((await events.predictionAccess('e1')).needsTerms, isTrue);

    final result = await events.acceptPredictionTerms(
      temporaryBadgeEnabled: false,
    );

    expect(result.isSuccess, isTrue);
    expect((await events.predictionAccess('e1')).needsTerms, isFalse);
    verify(
      () => service.acceptPredictionTerms(
        temporaryBadgeEnabled: false,
        authToken: 'tok',
      ),
    ).called(1);
  });

  test('a refusal teaches the event its restriction', () async {
    final events = store();
    events.rememberPredictionRestriction(
      'e3',
      PredictionRestriction.categoryLocked,
    );

    expect((await events.predictionAccess('e3')).isSpectator, isTrue);
    verifyNever(
      () => service.fetchPredictionAccess(
        eventId: 'e3',
        authToken: any(named: 'authToken'),
      ),
    );
  });

  test('accepting signed out sends nothing', () async {
    token = '';
    final result = await store().acceptPredictionTerms();

    expect(result.status, PointsActionStatus.notAuthenticated);
    verifyNever(
      () => service.acceptPredictionTerms(
        temporaryBadgeEnabled: any(named: 'temporaryBadgeEnabled'),
        authToken: any(named: 'authToken'),
      ),
    );
  });
}
