import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/community_points.dart';

void main() {
  group('PointsActionResult', () {
    test('a busy refusal says an action is already running', () {
      const busy = PointsActionResult(PointsActionStatus.unknown, 'busy');

      expect(busy.message, 'Already in progress.');
      expect(PointsActionResult.fromError('busy').message, busy.message);
    });
  });

  test('fromError classifies what Twitch says', () {
    const table = {
      'failed integrity check': PointsActionStatus.integrityRefused,
      'Integrity': PointsActionStatus.integrityRefused,
      'UNAUTHENTICATED': PointsActionStatus.notAuthenticated,
      'unauthorized': PointsActionStatus.notAuthenticated,
      'please login': PointsActionStatus.notAuthenticated,
      'request_failed': PointsActionStatus.network,
      'NOT_ENOUGH_POINTS': PointsActionStatus.unknown,
      'unknown_error': PointsActionStatus.unknown,
    };
    for (final MapEntry(:key, :value) in table.entries) {
      final result = PointsActionResult.fromError(key);
      expect(result.status, value, reason: key);
      expect(result.rawCode, key);
      expect(result.isSuccess, isFalse);
    }

    expect(PointsActionResult.fromError(null), PointsActionResult.ok);
    expect(PointsActionResult.ok.isSuccess, isTrue);
  });

  test('each outcome has its own wording', () {
    expect(PointsActionResult.ok.message, 'Done.');
    expect(
      PointsActionResult.fromError('failed integrity check').message,
      contains('anti-bot'),
    );
    expect(
      PointsActionResult.fromError('unauthorized').message,
      contains('Sign in again'),
    );
    expect(
      PointsActionResult.fromError('request_failed').message,
      'Could not reach Twitch. Try again.',
    );
    expect(
      PointsActionResult.fromError('NOT_ENOUGH_POINTS').message,
      'Twitch refused: NOT_ENOUGH_POINTS',
    );
    expect(
      const PointsActionResult(PointsActionStatus.unknown).message,
      'Twitch refused: no reason',
    );
  });

  group('PointsReward.tryParse', () {
    test('needs an id and a title', () {
      expect(PointsReward.tryParse({'title': 'x', 'cost': 1}), isNull);
      expect(PointsReward.tryParse({'id': 'x', 'cost': 1}), isNull);
      expect(PointsReward.tryParse({'id': 1, 'title': 'x'}), isNull);
    });

    test('reads a custom reward, defaulting what is missing', () {
      final reward = PointsReward.tryParse({'id': 'r', 'title': 'Hydrate'})!;

      expect(reward.cost, 0);
      expect(reward.isEnabled, isTrue);
      expect(reward.requiresInput, isFalse);
      expect(reward.backgroundColor, isNull);
      expect(reward.imageUrl, isNull);
      expect(reward.isAutomatic, isFalse);
      expect(reward.isRedeemable, isTrue);
    });

    test('reads the colour and the image', () {
      final reward = PointsReward.tryParse({
        'id': 'r',
        'title': 'T',
        'cost': 250.0,
        'isEnabled': false,
        'isUserInputRequired': true,
        'backgroundColor': '#00FF7F',
        'image': {'url': 'https://x/img.png'},
      })!;

      expect(reward.cost, 250);
      expect(reward.isEnabled, isFalse);
      expect(reward.requiresInput, isTrue);
      expect(reward.backgroundColor, const Color(0xFF00FF7F));
      expect(reward.imageUrl, 'https://x/img.png');
    });

    test('a malformed colour is no colour', () {
      for (final hex in ['#FFF', 'not-hex', '#GGGGGG', '#1234567']) {
        expect(
          PointsReward.tryParse({
            'id': 'r',
            'title': 'T',
            'backgroundColor': hex,
          })!.backgroundColor,
          isNull,
          reason: hex,
        );
      }
    });
  });

  group('PointsReward.tryParseAutomatic', () {
    test('needs an id and a type', () {
      expect(PointsReward.tryParseAutomatic({'type': 'X', 'cost': 1}), isNull);
      expect(PointsReward.tryParseAutomatic({'id': 'a', 'cost': 1}), isNull);
    });

    test('a null cost is a bits power-up and is dropped', () {
      expect(
        PointsReward.tryParseAutomatic({
          'id': 'a',
          'type': 'GIGANTIFY_AN_EMOTE',
          'cost': null,
        }),
        isNull,
      );
    });

    test('takes its title from the type and its default image', () {
      final reward = PointsReward.tryParseAutomatic({
        'id': 'a',
        'type': 'SEND_HIGHLIGHTED_MESSAGE',
        'cost': 300,
        'defaultImage': {'url': 'https://x/default.png'},
        'image': {'url': 'https://x/custom.png'},
      })!;

      expect(reward.title, 'Highlight my message');
      expect(reward.cost, 300);
      expect(reward.imageUrl, 'https://x/default.png');
      expect(reward.automaticType, 'SEND_HIGHLIGHTED_MESSAGE');
      expect(reward.isAutomatic, isTrue);
      expect(reward.isRedeemable, isFalse);
    });

    test('falls back to the image without a default one', () {
      final reward = PointsReward.tryParseAutomatic({
        'id': 'a',
        'type': 'X',
        'cost': 1,
        'image': {'url': 'https://x/custom.png'},
      })!;

      expect(reward.imageUrl, 'https://x/custom.png');
    });
  });

  test('automaticRewardTitle names the known types, reads the others', () {
    expect(
      PointsReward.automaticRewardTitle('RANDOM_SUB_EMOTE_UNLOCK'),
      'Unlock a random sub emote',
    );
    expect(
      PointsReward.automaticRewardTitle('CHOSEN_SUB_EMOTE_UNLOCK'),
      'Choose an emote to unlock',
    );
    expect(
      PointsReward.automaticRewardTitle('CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK'),
      'Modify a single emote',
    );
    expect(
      PointsReward.automaticRewardTitle('SINGLE_MESSAGE_BYPASS_SUB_MODE'),
      'Send a message in sub-only mode',
    );
    expect(
      PointsReward.automaticRewardTitle('SOME_NEW_THING'),
      'some new thing',
    );
  });

  test('affordableWith needs a balance at least the cost', () {
    const reward = PointsReward(id: 'r', title: 'T', cost: 100);

    expect(reward.affordableWith(null), isFalse);
    expect(reward.affordableWith(99), isFalse);
    expect(reward.affordableWith(100), isTrue);
    expect(reward.affordableWith(5000), isTrue);
  });

  test('odds are the pot over the outcome, none without stakes', () {
    const outcome = PredictionOutcome(
      id: 'o',
      title: 'Yes',
      color: 'BLUE',
      totalPoints: 1000,
    );
    const empty = PredictionOutcome(id: 'e', title: 'No', color: 'PINK');

    expect(outcome.odds(4000), 4.0);
    expect(outcome.odds(0), isNull);
    expect(empty.odds(4000), isNull);
  });

  test('activePrediction prefers the open one, then the locked one', () {
    const resolved = Prediction(id: 'r', title: 'R', status: 'RESOLVED');
    const locked = Prediction(id: 'l', title: 'L', status: 'LOCKED');
    const open = Prediction(id: 'o', title: 'O', status: 'ACTIVE');

    expect(
      const CommunityPointsContext(
        predictions: [resolved, locked, open],
      ).activePrediction,
      open,
    );
    expect(
      const CommunityPointsContext(
        predictions: [resolved, locked],
      ).activePrediction,
      locked,
    );
    expect(
      const CommunityPointsContext(predictions: [resolved]).activePrediction,
      isNull,
    );
  });

  test('pointsImageUrlAt swaps in the denser icons Twitch publishes', () {
    const context = CommunityPointsContext(
      pointsImageUrl: 'https://cdn.example/points/icon-1.png',
    );

    expect(
      context.pointsImageUrlAt(1),
      'https://cdn.example/points/icon-1.png',
    );
    expect(
      context.pointsImageUrlAt(2),
      'https://cdn.example/points/icon-2.png',
    );
    expect(
      context.pointsImageUrlAt(4),
      'https://cdn.example/points/icon-4.png',
    );
    // icon-3 does not exist on Twitch's CDN.
    expect(
      context.pointsImageUrlAt(3),
      'https://cdn.example/points/icon-2.png',
    );

    const other = CommunityPointsContext(
      pointsImageUrl: 'https://cdn.example/points/custom.png',
    );
    expect(other.pointsImageUrlAt(4), 'https://cdn.example/points/custom.png');
    expect(CommunityPointsContext.empty.pointsImageUrlAt(2), isNull);
  });
}
