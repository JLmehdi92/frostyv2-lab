import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/utils/twitch_links.dart';

void main() {
  test("a channel's subscription page on twitch.tv", () {
    expect(
      twitchSubscribeUrl('Streamer_1'),
      Uri.https('www.twitch.tv', '/subs/streamer_1'),
    );
  });

  test('anything but a login gives nothing', () {
    expect(twitchSubscribeUrl(''), isNull);
    expect(twitchSubscribeUrl('../evil'), isNull);
    expect(twitchSubscribeUrl('a/b'), isNull);
    expect(twitchSubscribeUrl('x' * 26), isNull);
  });
}
