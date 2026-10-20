import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/services/go_live/go_live_worker.dart';

void main() {
  test('a notice opens only a well-formed login', () {
    expect(GoLiveNotifications.loginOf('some_streamer'), 'some_streamer');
    expect(GoLiveNotifications.loginOf(null), isNull);
    expect(GoLiveNotifications.loginOf(''), isNull);
    expect(GoLiveNotifications.loginOf('../evil'), isNull);
    expect(GoLiveNotifications.loginOf('a' * 26), isNull);
    // A mention notice only brings the app back to the front.
    expect(GoLiveNotifications.loginOf('mention:some_streamer'), isNull);
  });
}
