import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/utils/link_router.dart';
import 'package:frosty/utils/twitch_links.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  late List<(Uri, LaunchMode)> launched;
  late List<TwitchLink> handled;

  setUp(() {
    launched = [];
    handled = [];
    LinkRouter.launcher = (url, {mode = LaunchMode.platformDefault}) async {
      launched.add((url, mode));
      return true;
    };
    LinkRouter.inAppHandler = (link) async {
      handled.add(link);
      return true;
    };
  });

  tearDown(() => LinkRouter.inAppHandler = null);

  test('a VOD link opens in-app, never in a browser', () async {
    await LinkRouter.open(
      'https://www.twitch.tv/videos/123?t=1m',
      launchExternal: true,
    );

    expect(handled, [const VodLink('123', startAt: Duration(minutes: 1))]);
    expect(launched, isEmpty);
  });

  test('a channel videos link opens in-app', () async {
    await LinkRouter.open(
      'https://twitch.tv/somechannel/videos',
      launchExternal: false,
    );

    expect(handled, [const ChannelVideosLink('somechannel')]);
    expect(launched, isEmpty);
  });

  test('clip links open in-app, never in a browser', () async {
    await LinkRouter.open(
      'https://clips.twitch.tv/SomeClipSlug',
      launchExternal: true,
    );
    await LinkRouter.open(
      'https://www.twitch.tv/xqc/clips?range=7d',
      launchExternal: true,
    );

    expect(handled, [
      const ClipLink('SomeClipSlug'),
      const ChannelClipsLink('xqc', period: ClipPeriod.lastWeek),
    ]);
    expect(launched, isEmpty);
  });

  test('a channel page is not handled in-app here', () async {
    await LinkRouter.open('https://www.twitch.tv/xqc', launchExternal: false);

    expect(handled, isEmpty);
    expect(launched, hasLength(1));
  });

  test('before the app is ready a VOD link is launched', () async {
    LinkRouter.inAppHandler = null;

    await LinkRouter.open('https://twitch.tv/videos/1', launchExternal: false);

    expect(launched.single.$1.toString(), 'https://twitch.tv/videos/1');
  });

  test('a link the app could not handle is launched', () async {
    LinkRouter.inAppHandler = (link) async => false;

    await LinkRouter.open('https://twitch.tv/videos/1', launchExternal: false);

    expect(launched, hasLength(1));
  });

  test('only web links are launched; other schemes are refused', () async {
    for (final link in [
      'javascript:alert(1)',
      'intent://scan/#Intent;scheme=zxing;end',
      'file:///sdcard/secret.txt',
      'tel:+15555550100',
      'market://details?id=x',
      'content://contacts/people/1',
      'example.com',
      '://broken',
    ]) {
      await LinkRouter.open(link, launchExternal: true);
    }
    expect(launched, isEmpty);
    expect(handled, isEmpty);

    await LinkRouter.open('http://example.com/a', launchExternal: true);
    await LinkRouter.open('HTTPS://example.com/b', launchExternal: false);
    expect(launched.map((l) => l.$1.toString()), [
      'http://example.com/a',
      'https://example.com/b',
    ]);
  });

  test('other links keep the browser preference', () async {
    await LinkRouter.open('https://example.com/a', launchExternal: true);
    await LinkRouter.open('https://example.com/b', launchExternal: false);
    await LinkRouter.open(
      'https://twitch.tv/somechannel',
      launchExternal: true,
    );

    expect(handled, isEmpty);
    expect(launched.map((l) => l.$2), [
      LaunchMode.externalApplication,
      LaunchMode.inAppBrowserView,
      LaunchMode.externalApplication,
    ]);
  });
}
