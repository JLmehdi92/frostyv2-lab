import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/celebration.dart';

void main() {
  group('Celebration.tryParse', () {
    test('wrongly typed fields return null or are ignored, never throw', () {
      expect(Celebration.tryParse({'type': 5}), isNull);

      final celebration = Celebration.tryParse({
        'type': 'FIREWORKS',
        'area': 3,
        'intensity': true,
        'alert_event_id': 12,
        'celebration_source': ['x'],
        'primary_color_hex': 0xFF0000,
      });

      expect(celebration, isNotNull);
      expect(celebration!.area, CelebrationArea.everywhere);
      expect(celebration.intensity, CelebrationIntensity.cool);
      expect(celebration.eventId, isNull);
      expect(celebration.source, isNull);
      expect(celebration.primaryColor, isNull);
    });
  });
}
