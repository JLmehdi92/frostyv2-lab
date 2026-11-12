import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/drop_campaign.dart';

import '../fixtures/drops_gql_payloads.dart';

Map<String, Object?> _campaignWith(List<Map<String, Object?>> drops) {
  final body = signedInDropCampaignsResponse(drops: drops);
  return body;
}

void main() {
  group('DropCampaign.listFrom', () {
    test('reads an anonymous campaign without progress', () {
      final campaigns = DropCampaign.listFrom(anonymousDropCampaignsResponse)!;

      expect(campaigns, hasLength(1));
      final campaign = campaigns.single;
      expect(campaign.id, 'campaign-1');
      expect(campaign.name, 'Finals Chat Badge');
      expect(campaign.gameName, 'Some Game');
      expect(campaign.isAccountConnected, isNull);
      expect(campaign.endAt, DateTime.utc(2026, 11, 15, 18, 59, 59, 999));
      final drop = campaign.drops.single;
      expect(drop.rewardName, 'Finals Supporter');
      expect(drop.requiredSubs, 1);
      expect(drop.progress, isNull);
      expect(drop.state, DropState.unknown);
      expect(campaign.offer, const CommunityDropsOffer.subs(1));
    });

    test('reads the viewer progress and the claim states', () {
      final campaign = DropCampaign.listFrom(
        signedInDropCampaignsResponse(),
      )!.single;

      expect(campaign.isAccountConnected, isTrue);
      expect(campaign.accountLinkUrl, Uri.parse('https://example.com/link'));
      final [ready, going, claimed] = campaign.drops;
      expect(ready.state, DropState.claimable);
      expect(ready.progress!.dropInstanceId, 'instance-a');
      expect(ready.fraction, 1);
      expect(going.state, DropState.inProgress);
      expect(going.fraction, 0.25);
      expect(going.minutesLeft, 90);
      expect(claimed.state, DropState.claimed);
      expect(campaign.offer, const CommunityDropsOffer.several());
    });

    test('a drop waiting on an earlier one is locked', () {
      final campaign = DropCampaign.listFrom(
        _campaignWith([
          {
            ...timedDropFixture(id: 'later', minutes: 60),
            'self': {
              'currentMinutesWatched': 0,
              'currentSubs': 0,
              'hasPreconditionsMet': false,
              'isClaimed': false,
              'dropInstanceID': null,
            },
          },
        ]),
      )!.single;

      expect(campaign.drops.single.state, DropState.locked);
    });

    test('says which community line fits a single drop', () {
      DropCampaign one(Map<String, Object?> drop) =>
          DropCampaign.listFrom(_campaignWith([drop]))!.single;

      expect(
        one(timedDropFixture(id: 'w', minutes: 45)).offer,
        const CommunityDropsOffer.watch(45),
      );
      expect(
        one(timedDropFixture(id: 's', subs: 3)).offer,
        const CommunityDropsOffer.subs(3),
      );
      expect(
        one(timedDropFixture(id: 't', turbo: 1)).offer,
        const CommunityDropsOffer.turbo(),
      );
      expect(
        one(timedDropFixture(id: 'b', minutes: 10, subs: 1)).offer,
        const CommunityDropsOffer.several(),
      );
    });

    test('no campaign is an empty list, a failed read is null', () {
      expect(DropCampaign.listFrom(noDropCampaignsResponse), isEmpty);
      expect(DropCampaign.listFrom(anonymousDropCampaignsSelfError), isNull);
      expect(DropCampaign.listFrom({'data': null}), isNull);
      expect(DropCampaign.listFrom('nope'), isNull);
    });

    test('skips a campaign without an id or drops it cannot read', () {
      final campaigns = DropCampaign.listFrom({
        'data': {
          'user': {
            'channel': {
              'viewerDropCampaigns': [
                {'name': 'No id'},
                {
                  'id': 'c',
                  'name': 'Odd',
                  'timeBasedDrops': [
                    {'id': 'x'},
                    'junk',
                  ],
                },
              ],
            },
          },
        },
      })!;

      expect(campaigns.single.id, 'c');
      expect(campaigns.single.drops.single.id, 'x');
      expect(campaigns.single.drops.single.rewardName, '');
    });
  });

  group('DropClaimResult.fromBody', () {
    test('maps every claim status', () {
      expect(
        DropClaimResult.fromBody(claimDropResponse()),
        DropClaimResult.claimed,
      );
      expect(
        DropClaimResult.fromBody(
          claimDropResponse(status: 'DROP_INSTANCE_ALREADY_CLAIMED'),
        ),
        DropClaimResult.alreadyClaimed,
      );
      expect(
        DropClaimResult.fromBody(claimDropResponse(connected: false)),
        DropClaimResult.needsAccountLink,
      );
      expect(
        DropClaimResult.fromBody(claimDropResponse(status: 'EXPIRED')),
        DropClaimResult.expired,
      );
      expect(
        DropClaimResult.fromBody(
          claimDropResponse(status: 'ENTITLEMENT_LIMIT_REACHED'),
        ),
        DropClaimResult.limitReached,
      );
      expect(
        DropClaimResult.fromBody(claimDropResponse(status: 'LIMITED')),
        DropClaimResult.refused,
      );
    });

    test('an integrity error or an odd body is not a claim', () {
      expect(
        DropClaimResult.fromBody({
          'errors': [
            {'message': 'failed integrity check'},
          ],
        }),
        DropClaimResult.integrityRefused,
      );
      expect(
        DropClaimResult.fromBody({
          'errors': [
            {'message': 'boom'},
          ],
        }),
        DropClaimResult.failed,
      );
      expect(
        DropClaimResult.fromBody({
          'data': {'claimDropRewards': null},
        }),
        DropClaimResult.failed,
      );
      expect(DropClaimResult.fromBody(null), DropClaimResult.failed);
    });
  });
}
