import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/legendary_collection.dart';

import '../fixtures/legendary_payloads.dart';

void main() {
  test('reads the collection, rarest tier first', () {
    final collection = LegendaryCollection.fromBody(legendarySeasonResponse())!;

    expect(collection.campaignName, 'Winter Chests');
    expect(collection.emotes, hasLength(3));
    expect(collection.ownedCount, 2);
    expect(collection.unopenedChests, 3);
    expect(collection.byTier.map((group) => group.$1), [
      'LEGENDARY',
      'RARE',
      'COMMON',
    ]);
  });

  test('no season, no card', () {
    expect(LegendaryCollection.fromBody(noLegendarySeasonResponse), isNull);
    expect(LegendaryCollection.fromBody(null), isNull);
  });
}
