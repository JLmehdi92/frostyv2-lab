import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/chat/announcement_color.dart';

void main() {
  test('Twitch announcement colours; primary keeps the default', () {
    expect(announcementColor('BLUE'), const Color(0xFF00D6D6));
    expect(announcementColor('green'), const Color(0xFF00DB84));
    expect(announcementColor('ORANGE'), const Color(0xFFFFB31A));
    expect(announcementColor('PURPLE'), const Color(0xFF9146FF));
    expect(announcementColor('PRIMARY'), isNull);
    expect(announcementColor(null), isNull);
    expect(announcementColor('<script>'), isNull);
  });
}
