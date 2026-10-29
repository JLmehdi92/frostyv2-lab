import 'package:flutter_test/flutter_test.dart';
import 'package:onset/constants.dart';
import 'package:onset/services/go_live/go_live_worker.dart';

void main() {
  test('a notice opens only a well-formed login', () {
    expect(GoLiveNotifications.loginOf('some_streamer'), 'some_streamer');
    expect(GoLiveNotifications.loginOf(null), isNull);
    expect(GoLiveNotifications.loginOf(''), isNull);
    expect(GoLiveNotifications.loginOf('../evil'), isNull);
    expect(GoLiveNotifications.loginOf('a' * 26), isNull);
    // A mention notice is not a go-live one.
    expect(GoLiveNotifications.loginOf('mention:some_streamer'), isNull);
  });

  test("a mention notice opens its channel's login, well-formed only", () {
    expect(
      GoLiveNotifications.mentionLoginOf('mention:some_streamer'),
      'some_streamer',
    );
    expect(GoLiveNotifications.mentionLoginOf('some_streamer'), isNull);
    expect(GoLiveNotifications.mentionLoginOf('mention:'), isNull);
    expect(GoLiveNotifications.mentionLoginOf('mention:../evil'), isNull);
    expect(GoLiveNotifications.mentionLoginOf('mention:${'a' * 26}'), isNull);
    expect(GoLiveNotifications.mentionLoginOf(null), isNull);
  });

  test("the background check sends the token with its own app's client id", () {
    expect(goLiveHeaders('tok', tokenClientId: 'other_app'), {
      'Client-Id': 'other_app',
      'Authorization': 'Bearer tok',
    });
    // This app's token (nothing stored): this app's client id.
    expect(goLiveHeaders('tok')['Client-Id'], clientId);
  });
}
