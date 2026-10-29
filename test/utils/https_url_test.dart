import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/utils/https_url.dart';

void main() {
  test("raid pictures come from Twitch's image host over https only", () {
    const ok = 'https://static-cdn.jtvnw.net/jtv_user_pictures/a-70x70.png';
    expect(twitchImageOrNull(ok), ok);
    expect(twitchImageOrNull(null), isNull);
    expect(twitchImageOrNull('http://static-cdn.jtvnw.net/a.png'), isNull);
    expect(twitchImageOrNull('https://evil.example.com/a.png'), isNull);
    expect(
      twitchImageOrNull('https://static-cdn.jtvnw.net.evil.com/a'),
      isNull,
    );
    expect(twitchImageOrNull('https://user@static-cdn.jtvnw.net/a'), isNull);
    expect(twitchImageOrNull('not a url'), isNull);
  });
}
