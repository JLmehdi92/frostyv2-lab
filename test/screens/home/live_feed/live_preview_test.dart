import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/hls_variant.dart';
import 'package:frosty/screens/home/live_feed/live_preview.dart';

/// Counts the decoders alive at once.
class FakePreviewBackend implements LivePreviewBackend {
  FakePreviewBackend(this.log, {this.disposeDelay = Duration.zero});

  final List<String> log;
  final Duration disposeDelay;
  static var alive = 0;
  static var mostAlive = 0;
  String? url;
  double volume = 0;
  var disposed = false;

  @override
  final showing = ValueNotifier(false);

  @override
  Future<void> open(String url) async {
    alive++;
    if (alive > mostAlive) mostAlive = alive;
    this.url = url;
    log.add('open $url');
  }

  @override
  Future<void> setVolume(double volume) async => this.volume = volume;

  @override
  Widget buildVideo() => const SizedBox();

  @override
  Future<void> dispose() async {
    await Future<void>.delayed(disposeDelay);
    if (url != null) alive--;
    disposed = true;
    log.add('dispose $url');
  }
}

void main() {
  late List<String> log;
  late List<FakePreviewBackend> made;

  setUp(() {
    log = [];
    made = [];
    FakePreviewBackend.alive = 0;
    FakePreviewBackend.mostAlive = 0;
  });

  LivePreviewController controller({
    Duration disposeDelay = Duration.zero,
    Future<String> Function(String login)? resolve,
  }) => LivePreviewController(
    resolveUrl: resolve ?? (login) async => 'https://usher/$login.m3u8',
    createBackend: () {
      final backend = FakePreviewBackend(log, disposeDelay: disposeDelay);
      made.add(backend);
      return backend;
    },
  );

  test('a preview starts once the feed settles on a channel', () {
    fakeAsync((async) {
      final c = controller()..setActive(true);
      c.show('one');
      async.elapse(const Duration(milliseconds: 200));
      expect(made, isEmpty);
      async.elapse(const Duration(milliseconds: 200));
      expect(log, ['open https://usher/one.m3u8']);
      expect(c.playingLogin, 'one');
      expect(c.muted, isTrue);
      c.dispose();
      async.flushMicrotasks();
    });
  });

  test('a fast swipe starts no decoder for the channels passed', () {
    fakeAsync((async) {
      final c = controller()..setActive(true);
      for (final login in ['a', 'b', 'c', 'd']) {
        c.show(login);
        async.elapse(const Duration(milliseconds: 100));
      }
      async.elapse(const Duration(seconds: 1));
      expect(log, ['open https://usher/d.m3u8']);
      c.dispose();
      async.flushMicrotasks();
    });
  });

  test('never two decoders: the next waits for the last to be gone', () {
    fakeAsync((async) {
      final c = controller(disposeDelay: const Duration(seconds: 2))
        ..setActive(true)
        ..show('one');
      async.elapse(const Duration(seconds: 1));
      c.show('two');
      async.elapse(const Duration(seconds: 1));
      // "one" is still being let go: "two" has not started.
      expect(log, ['open https://usher/one.m3u8']);
      async.elapse(const Duration(seconds: 2));
      expect(log, [
        'open https://usher/one.m3u8',
        'dispose https://usher/one.m3u8',
        'open https://usher/two.m3u8',
      ]);
      expect(FakePreviewBackend.mostAlive, 1);
      c.dispose();
      async.elapse(const Duration(seconds: 3));
      expect(FakePreviewBackend.alive, 0);
    });
  });

  test('inactive (covered, background, mini player): stopped at once, '
      'back when active again', () {
    fakeAsync((async) {
      final c = controller()
        ..setActive(true)
        ..show('one');
      async.elapse(const Duration(seconds: 1));
      c.setActive(false);
      async.elapse(const Duration(milliseconds: 1));
      expect(c.backend, isNull);
      expect(made.single.disposed, isTrue);
      c.setActive(true);
      async.elapse(const Duration(seconds: 1));
      expect(made, hasLength(2));
      c.stop();
      async.elapse(const Duration(milliseconds: 1));
      expect(made.last.disposed, isTrue);
      c.dispose();
    });
  });

  test('never starts while inactive', () {
    fakeAsync((async) {
      final c = controller()..show('one');
      async.elapse(const Duration(seconds: 2));
      expect(made, isEmpty);
      c.dispose();
    });
  });

  test('unmuting is for the current preview only', () {
    fakeAsync((async) {
      final c = controller()
        ..setActive(true)
        ..show('one');
      async.elapse(const Duration(seconds: 1));
      unawaited(c.toggleMute());
      async.flushMicrotasks();
      expect(c.muted, isFalse);
      expect(made.single.volume, 1);
      c.show('two');
      expect(c.muted, isTrue);
      async.elapse(const Duration(seconds: 1));
      expect(made.last.volume, 0);
      c.dispose();
      async.flushMicrotasks();
    });
  });

  test('a channel that cannot play says so and keeps its picture', () {
    fakeAsync((async) {
      final c = controller(resolve: (login) async => throw Exception('offline'))
        ..setActive(true);
      var notified = 0;
      c
        ..addListener(() => notified++)
        ..show('one');
      async.elapse(const Duration(seconds: 1));
      expect(c.failed, isTrue);
      expect(made, isEmpty);
      expect(notified, greaterThan(0));
      c.dispose();
    });
  });

  test('disposed while resolving: nothing starts', () {
    fakeAsync((async) {
      final completer = Completer<String>();
      final c = controller(resolve: (_) => completer.future)
        ..setActive(true)
        ..show('one');
      async.elapse(const Duration(seconds: 1));
      c.dispose();
      completer.complete('https://usher/one.m3u8');
      async.flushMicrotasks();
      expect(made, isEmpty);
    });
  });

  group('pickPreviewVariant', () {
    const variants = [
      HlsVariant(name: '1080p60 (source)', url: 's'),
      HlsVariant(name: '720p60', url: '720'),
      HlsVariant(name: '480p30', url: '480'),
      HlsVariant(name: '360p30', url: '360'),
      HlsVariant(name: '160p30', url: '160'),
      HlsVariant(name: 'audio_only', url: 'a'),
    ];

    test('the smallest at least as tall as asked', () {
      expect(pickPreviewVariant(variants)!.url, '480');
      expect(pickPreviewVariant(variants, targetHeight: 720)!.url, '720');
      expect(pickPreviewVariant(variants, targetHeight: 500)!.url, '720');
    });

    test('else the tallest below; never audio only', () {
      expect(
        pickPreviewVariant(variants.skip(2).toList(), targetHeight: 720)!.url,
        '480',
      );
      expect(
        pickPreviewVariant(const [HlsVariant(name: 'audio_only', url: 'a')]),
        isNull,
      );
    });
  });
}
