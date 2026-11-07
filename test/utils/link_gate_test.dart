import 'package:flutter_test/flutter_test.dart';
import 'package:onset/utils/link_router.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  late List<Uri> launched;
  late List<Uri> asked;
  late bool answer;

  setUp(() {
    launched = [];
    asked = [];
    answer = true;
    LinkRouter.launcher = (url, {mode = LaunchMode.platformDefault}) async {
      launched.add(url);
      return true;
    };
    LinkRouter.externalLinkGate = (url) async {
      asked.add(url);
      return answer;
    };
  });

  tearDown(() => LinkRouter.externalLinkGate = null);

  test('a link that asks is opened only once allowed', () async {
    answer = false;
    await LinkRouter.open(
      'https://example.com/a',
      launchExternal: false,
      confirm: true,
    );
    expect(asked, [Uri.parse('https://example.com/a')]);
    expect(launched, isEmpty);

    answer = true;
    await LinkRouter.open(
      'example.com/b',
      launchExternal: false,
      confirm: true,
    );
    expect(launched, [Uri.parse('https://example.com/b')]);
  });

  test('a link of the app itself never asks', () async {
    await LinkRouter.open('https://example.com/a', launchExternal: false);
    expect(asked, isEmpty);
    expect(launched, hasLength(1));
  });

  test('a twitch.tv page never asks', () async {
    await LinkRouter.open(
      'https://www.twitch.tv/settings/security',
      launchExternal: false,
      confirm: true,
    );
    await LinkRouter.open(
      'https://twitch.tv/somebody/about',
      launchExternal: false,
      confirm: true,
    );
    expect(asked, isEmpty);
    expect(launched, hasLength(2));
  });

  test('a look-alike host still asks', () async {
    await LinkRouter.open(
      'https://twitch.tv.example.com/x',
      launchExternal: false,
      confirm: true,
    );
    await LinkRouter.open(
      'https://eviltwitch.tv/x',
      launchExternal: false,
      confirm: true,
    );
    expect(asked, hasLength(2));
  });

  test('a refused scheme is refused before asking', () async {
    await LinkRouter.open(
      'javascript:alert(1)',
      launchExternal: false,
      confirm: true,
    );
    expect(asked, isEmpty);
    expect(launched, isEmpty);
  });

  test('without a gate the link opens as before', () async {
    LinkRouter.externalLinkGate = null;
    await LinkRouter.open(
      'https://example.com/a',
      launchExternal: false,
      confirm: true,
    );
    expect(launched, hasLength(1));
  });
}
