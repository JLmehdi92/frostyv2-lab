import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/web_page_init.dart';

void main() {
  const player = 'https://player.twitch.tv/?channel=x';

  late int checks;
  late int reloads;
  late int inits;
  late bool savedOff;
  late WebPageInit pageInit;

  setUp(() {
    checks = 0;
    reloads = 0;
    inits = 0;
    savedOff = true;
    pageInit = WebPageInit(
      isPlayerPage: (url) => url == player,
      ensureLowLatency: () async {
        checks++;
        if (!savedOff) return false;
        // The page turns it on and reloads itself.
        savedOff = false;
        reloads++;
        return true;
      },
      init: () async => inits++,
    );
  });

  test(
    'turns low latency on with one reload, then sets the player up once',
    () async {
      await pageInit.onPageFinished(player);
      expect((reloads, inits), (1, 0));

      // The reloaded page finishes loading.
      await pageInit.onPageFinished(player);
      // Any later finish of the same page changes nothing.
      await pageInit.onPageFinished(player);

      expect(checks, 1);
      expect(reloads, 1);
      expect(inits, 1);
    },
  );

  test('a page already in low latency is set up at once', () async {
    savedOff = false;

    await pageInit.onPageFinished(player);

    expect((checks, reloads, inits), (1, 0, 1));
  });

  test('a second finish while the check runs does not set up twice', () async {
    savedOff = false;
    final gate = Completer<void>();
    pageInit = WebPageInit(
      isPlayerPage: (url) => url == player,
      ensureLowLatency: () async {
        checks++;
        await gate.future;
        return false;
      },
      init: () async => inits++,
    );

    final first = pageInit.onPageFinished(player);
    final second = pageInit.onPageFinished(player);
    gate.complete();
    await Future.wait([first, second]);

    expect((checks, inits), (1, 1));
  });

  test('a refresh sets the page up again without checking again', () async {
    savedOff = false;
    await pageInit.onPageFinished(player);

    pageInit.needsInit = true;
    await pageInit.onPageFinished(player);

    expect((checks, inits), (1, 2));
  });

  test('other pages are ignored', () async {
    await pageInit.onPageFinished('about:blank');

    expect((checks, inits), (0, 0));
  });

  test('every page start and finish runs the per-page hook first', () async {
    final events = <String>[];
    pageInit = WebPageInit(
      isPlayerPage: (url) => url == player,
      ensureLowLatency: () async {
        events.add('check');
        // Saved off: the page reloads itself.
        return events.where((e) => e == 'check').length == 1;
      },
      init: () async => events.add('init'),
      everyPage: () => events.add('page'),
    );

    pageInit.onPageStarted(player);
    await pageInit.onPageFinished(player);
    // The low-latency reload: not marked as needing a setup by anyone.
    pageInit.onPageStarted(player);
    await pageInit.onPageFinished(player);
    // A reload the page does on its own, after the setup.
    pageInit.onPageStarted(player);
    await pageInit.onPageFinished(player);
    pageInit.onPageStarted('about:blank');

    expect(events, [
      'page',
      'page',
      'check',
      'page',
      'page',
      'init',
      'page',
      'page',
      'page',
    ]);
  });
}
