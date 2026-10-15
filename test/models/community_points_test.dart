import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/community_points.dart';

void main() {
  group('PointsActionResult', () {
    test('a busy refusal says an action is already running', () {
      const busy = PointsActionResult(PointsActionStatus.unknown, 'busy');

      expect(busy.message, 'Already in progress.');
      expect(PointsActionResult.fromError('busy').message, busy.message);
    });
  });
}
