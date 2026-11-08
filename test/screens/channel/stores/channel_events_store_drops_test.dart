import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_community_service.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/drop_campaign.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/services/hermes_client.dart';

import '../../../fixtures/drops_gql_payloads.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

class MockViewerActions extends Mock implements TwitchViewerActionsService {}

class MockCommunity extends Mock implements TwitchCommunityService {}

void main() {
  late MockPointsService points;
  late MockHermesClient hermes;
  late MockViewerActions actions;
  late MockCommunity community;
  late List<DropCampaign> campaigns;

  setUp(() {
    points = MockPointsService();
    hermes = MockHermesClient();
    actions = MockViewerActions();
    community = MockCommunity();
    campaigns = DropCampaign.listFrom(signedInDropCampaignsResponse())!;
    when(() => hermes.dispose()).thenReturn(null);
    when(
      () => points.fetchContext(
        userLogin: any(named: 'userLogin'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => CommunityPointsContext.empty);
    when(
      () => community.getDropCampaigns(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => campaigns);
  });

  ChannelEventsStore build({String? token = 'webtok', bool live = true}) =>
      ChannelEventsStore(
        channelId: '42',
        channelLogin: 'streamer',
        isChannelLive: () => live,
        client: hermes,
        pointsService: points,
        viewerActionsService: actions,
        communityService: community,
        tokenProvider: () async => token,
      );

  test('reads the campaigns and announces each one once', () async {
    final store = build();
    final announced = <String>[];
    store.communityDrops.listen((c) => announced.add(c.id));

    await store.refreshDrops();
    await store.refreshDrops(force: true);
    await Future<void>.delayed(Duration.zero);

    expect(store.dropCampaigns.single.id, 'campaign-2');
    expect(announced, ['campaign-2']);
    verify(
      () => community.getDropCampaigns(channelId: '42', authToken: 'webtok'),
    ).called(2);
    store.dispose();
  });

  test('asks at most once a minute unless forced', () async {
    final store = build();

    await store.refreshDrops();
    await store.refreshDrops();

    verify(
      () => community.getDropCampaigns(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).called(1);
    store.dispose();
  });

  test('says nothing in chat while the channel is offline', () async {
    final store = build(live: false);
    final announced = <DropCampaign>[];
    store.communityDrops.listen(announced.add);

    await store.refreshDrops();
    await Future<void>.delayed(Duration.zero);

    expect(store.dropCampaigns, isNotEmpty);
    expect(announced, isEmpty);
    store.dispose();
  });

  test('a failed read keeps the last campaigns and asks again', () async {
    final store = build();
    await store.refreshDrops();
    when(
      () => community.getDropCampaigns(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => null);

    await store.refreshDrops(force: true);
    await store.refreshDrops();

    expect(store.dropCampaigns.single.id, 'campaign-2');
    verify(
      () => community.getDropCampaigns(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).called(3);
    store.dispose();
  });

  test('claims a ready drop, then reads the campaigns again', () async {
    final store = build();
    await store.refreshDrops();
    when(
      () => actions.claimDrop(
        dropInstanceId: any(named: 'dropInstanceId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => DropClaimResult.claimed);
    final ready = store.dropCampaigns.single.drops.first;

    final result = await store.claimDrop(ready);

    expect(result, DropClaimResult.claimed);
    expect(store.claimingDropId, isNull);
    verify(
      () =>
          actions.claimDrop(dropInstanceId: 'instance-a', authToken: 'webtok'),
    ).called(1);
    verify(
      () => community.getDropCampaigns(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).called(2);
    store.dispose();
  });

  test(
    'a refused claim does not reread, and an unready drop sends nothing',
    () async {
      final store = build();
      await store.refreshDrops();
      when(
        () => actions.claimDrop(
          dropInstanceId: any(named: 'dropInstanceId'),
          authToken: any(named: 'authToken'),
        ),
      ).thenAnswer((_) async => DropClaimResult.needsAccountLink);
      final [ready, going, _] = store.dropCampaigns.single.drops;

      expect(await store.claimDrop(going), isNull);
      expect(await store.claimDrop(ready), DropClaimResult.needsAccountLink);
      verify(
        () => community.getDropCampaigns(
          channelId: any(named: 'channelId'),
          authToken: any(named: 'authToken'),
        ),
      ).called(1);
      store.dispose();
    },
  );

  test('a claim without a token is signed out', () async {
    final store = build(token: null);
    await store.refreshDrops();

    expect(
      await store.claimDrop(store.dropCampaigns.single.drops.first),
      DropClaimResult.signedOut,
    );
    verifyNever(
      () => actions.claimDrop(
        dropInstanceId: any(named: 'dropInstanceId'),
        authToken: any(named: 'authToken'),
      ),
    );
    store.dispose();
  });
}
