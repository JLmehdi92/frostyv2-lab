import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_clip_service.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/screens/clips/stores/clip_player_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_clip_backend.dart';

class MockClipService extends Mock implements TwitchClipService {}

const _slug = 'SomeClipSlug';

ClipPlayback _playback({String token = 't1'}) => ClipPlayback(
  renditions: const [
    ClipRendition(
      height: 1080,
      frameRate: 60,
      url: 'https://c.cloudfront.net/1080.mp4',
    ),
    ClipRendition(
      height: 720,
      frameRate: 60,
      url: 'https://c.cloudfront.net/720.mp4',
    ),
    ClipRendition(
      height: 360,
      frameRate: 30,
      url: 'https://c.cloudfront.net/360.mp4',
    ),
  ],
  signature: 'sig',
  token: token,
);

void main() {
  late MockClipService service;
  late SettingsStore settings;
  late FakeClipBackend backend;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = MockClipService();
    settings = SettingsStore.fromJson({});
    backend = FakeClipBackend();
    when(
      () => service.getClipPlayback(any()),
    ).thenAnswer((_) async => _playback());
  });

  ClipPlayerStore create({Duration? knownLength}) => ClipPlayerStore(
    slug: _slug,
    clipService: service,
    settingsStore: settings,
    knownLength: knownLength,
    backend: backend,
  );

  String openedPath([int i = -1]) =>
      Uri.parse(i < 0 ? backend.opened.last.url : backend.opened[i].url).path;

  test('opens the best rendition, signed, and plays', () {
    fakeAsync((async) {
      final store = create(knownLength: const Duration(seconds: 30));
      async.flushMicrotasks();

      expect(store.qualities, ['1080p60', '720p60', '360p']);
      expect(store.quality, '1080p60');
      expect(openedPath(), '/1080.mp4');
      final query = Uri.parse(backend.opened.last.url).queryParameters;
      expect(query['sig'], 'sig');
      expect(query['token'], 't1');
      expect(backend.opened.last.play, isTrue);

      backend.playingController.add(true);
      expect(store.status, VodPlaybackStatus.playing);
      expect(store.duration, const Duration(seconds: 30));
      store.dispose();
    });
  });

  test('restores the saved quality', () {
    SharedPreferences.setMockInitialValues({'last_stream_quality': '720p60'});
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      expect(store.quality, '720p60');
      expect(openedPath(), '/720.mp4');
      store.dispose();
    });
  });

  test('a quality change reopens at the same position', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      backend.positionController.add(const Duration(seconds: 12));

      store.setQuality('360p');
      async.flushMicrotasks();

      expect(store.quality, '360p');
      expect(openedPath(), '/360.mp4');
      expect(backend.opened.last.start, const Duration(seconds: 12));
      store.dispose();
    });
  });

  test('seeks are clamped to the clip', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      backend.durationController.add(const Duration(seconds: 30));

      store.seekTo(const Duration(seconds: -5));
      store.seekTo(const Duration(seconds: 90));
      expect(backend.calls, containsAllInOrder(['seek 0', 'seek 30000']));
      store.dispose();
    });
  });

  test('only the offered playback rates are applied', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      store.setPlaybackRate(1.5);
      store.setPlaybackRate(3);
      expect(store.playbackRate, 1.5);
      expect(backend.calls.where((c) => c.startsWith('rate')), ['rate 1.5']);
      store.dispose();
    });
  });

  test('loop is off by default, toggles, and is remembered', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      expect(store.looping, isFalse);

      store.toggleLoop();
      async.flushMicrotasks();
      expect(store.looping, isTrue);
      expect(backend.calls, contains('loop true'));
      store.dispose();

      final again = create();
      async.flushMicrotasks();
      expect(again.looping, isTrue);
      expect(backend.calls.last, isNot('loop false'));
      again.dispose();
    });
  });

  test('the end without loop: ended, and play starts over', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      backend.playingController.add(true);

      backend.playingController.add(false);
      backend.completedController.add(true);
      expect(store.status, VodPlaybackStatus.ended);
      expect(store.ended, isTrue);

      store.play();
      expect(backend.calls, containsAllInOrder(['seek 0', 'play']));
      store.dispose();
    });
  });

  test('a playback error refreshes the token once, then gives up', () {
    fakeAsync((async) {
      var fatal = 0;
      final store = create()..onFatalError = () => fatal++;
      async.flushMicrotasks();
      backend.positionController.add(const Duration(seconds: 7));
      when(
        () => service.getClipPlayback(any()),
      ).thenAnswer((_) async => _playback(token: 't2'));

      backend.errorController.add('HTTP 401');
      async.flushMicrotasks();
      expect(backend.opened, hasLength(2));
      expect(Uri.parse(backend.opened.last.url).queryParameters['token'], 't2');
      expect(backend.opened.last.start, const Duration(seconds: 7));
      expect(fatal, 0);

      // The reopened file plays, then fails again: that is the end.
      backend.playingController.add(true);
      backend.errorController.add('HTTP 401');
      backend.errorController.add('HTTP 401');
      async.flushMicrotasks();
      expect(fatal, 1);
      expect(store.status, VodPlaybackStatus.failed);
      store.dispose();
    });
  });

  test('one failure logged as a burst of mpv errors is one recovery', () {
    fakeAsync((async) {
      var fatal = 0;
      final store = create()..onFatalError = () => fatal++;
      async.flushMicrotasks();
      final refresh = Completer<ClipPlayback>();
      when(
        () => service.getClipPlayback(any()),
      ).thenAnswer((_) => refresh.future);

      backend.errorController.add('ffmpeg tcp: 403');
      backend.errorController.add('stream: failed to open');
      backend.errorController.add('cplayer: failed');
      async.flushMicrotasks();
      expect(fatal, 0);
      verify(() => service.getClipPlayback(any())).called(2);

      refresh.complete(_playback(token: 't2'));
      async.flushMicrotasks();
      // Late lines from the old file, right after the reopen.
      backend.errorController.add('stream: late');
      async.flushMicrotasks();
      expect(fatal, 0);
      expect(backend.opened, hasLength(2));

      // Past the grace period, a new error is fatal.
      async.elapse(const Duration(seconds: 3));
      backend.errorController.add('HTTP 401');
      async.flushMicrotasks();
      expect(fatal, 1);
      store.dispose();
    });
  });

  test('a failure during the refresh never reopens after giving up', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      when(
        () => service.getClipPlayback(any()),
      ).thenThrow(const ClipApiException('down'));

      backend.errorController.add('HTTP 401');
      async.flushMicrotasks();

      expect(store.status, VodPlaybackStatus.failed);
      expect(backend.opened, hasLength(1));
      store.dispose();
    });
  });

  test('a player that lost focus while loading pauses when it starts', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      store.setFocused(false);

      backend.playingController.add(true);

      expect(backend.calls, contains('pause'));
      store.dispose();
    });
  });

  test('a quality change while paused stays paused', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      backend.playingController.add(true);
      backend.playingController.add(false);

      store.setQuality('360p');
      async.flushMicrotasks();

      expect(backend.opened.last.play, isFalse);
      store.dispose();
    });
  });

  test('a refused clip is a problem, not a failure', () {
    when(
      () => service.getClipPlayback(any()),
    ).thenThrow(const ClipForbiddenException('geoblocked'));
    fakeAsync((async) {
      var fatal = 0;
      final store = create()..onFatalError = () => fatal++;
      var ready = false;
      store.ready.then((_) => ready = true);
      async.flushMicrotasks();

      expect(ready, isTrue);
      expect(store.status, VodPlaybackStatus.problem);
      expect(store.problem, VodPlaybackProblem.geoBlocked);
      expect(backend.opened, isEmpty);
      expect(fatal, 0);
      store.dispose();
    });
  });

  test('a deleted clip is a not-found problem', () {
    when(
      () => service.getClipPlayback(any()),
    ).thenThrow(const NotFoundException('Clip not found'));
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      expect(store.problem, VodPlaybackProblem.notFound);
      store.dispose();
    });
  });

  test('no playback at all: ready throws for the web fallback', () {
    when(() => service.getClipPlayback(any())).thenThrow(
      const ClipApiException('failed integrity check', isIntegrity: true),
    );
    fakeAsync((async) {
      final store = create();
      Object? error;
      store.ready.catchError((Object e) => error = e);
      async.flushMicrotasks();
      expect(error, isA<ClipApiException>());
      expect(store.status, VodPlaybackStatus.failed);
      store.dispose();
    });
  });

  test('without focus it loads paused', () {
    fakeAsync((async) {
      final store = create()..setFocused(false);
      async.flushMicrotasks();
      expect(backend.opened.last.play, isFalse);
      store.dispose();
    });
  });

  test('built without focus (a preloaded feed clip) it loads paused', () {
    fakeAsync((async) {
      final store = ClipPlayerStore(
        slug: _slug,
        clipService: service,
        settingsStore: settings,
        backend: backend,
        focused: false,
      );
      async.flushMicrotasks();
      expect(backend.opened.last.play, isFalse);

      store.setFocused(true);
      store.play();
      expect(backend.calls, contains('play'));
      store.dispose();
    });
  });

  test('the overlay hides after 5 s of playback, not while paused', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      backend.playingController.add(true);
      store.showOverlay();
      async.elapse(const Duration(seconds: 6));
      expect(store.overlayVisible, isFalse);

      backend.playingController.add(false);
      store.showOverlay();
      async.elapse(const Duration(seconds: 6));
      expect(store.overlayVisible, isTrue);
      store.dispose();
    });
  });

  test('dispose before the token arrives never opens', () {
    fakeAsync((async) {
      final store = create();
      store.dispose();
      async.flushMicrotasks();
      expect(backend.opened, isEmpty);
      expect(backend.disposed, isTrue);
    });
  });

  test('a loop toggled while loading is the one applied', () {
    fakeAsync((async) {
      final token = Completer<ClipPlayback>();
      when(
        () => service.getClipPlayback(any()),
      ).thenAnswer((_) => token.future);
      final store = create();
      async.flushMicrotasks();

      store.toggleLoop();
      token.complete(_playback());
      async.flushMicrotasks();

      expect(store.looping, isTrue);
      expect(
        backend.calls.where((c) => c.startsWith('loop')).last,
        'loop true',
      );
      store.dispose();
    });
  });

  test('a token refresh shows loading; quality waits for it', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      backend.playingController.add(true);
      final refresh = Completer<ClipPlayback>();
      when(
        () => service.getClipPlayback(any()),
      ).thenAnswer((_) => refresh.future);

      backend.errorController.add('HTTP 401');
      async.flushMicrotasks();
      expect(store.status, VodPlaybackStatus.loading);

      store.setQuality('360p');
      async.flushMicrotasks();
      expect(backend.opened, hasLength(1), reason: 'no open on the old token');

      refresh.complete(_playback(token: 't2'));
      async.flushMicrotasks();
      expect(backend.opened, hasLength(2));
      expect(Uri.parse(backend.opened.last.url).queryParameters['token'], 't2');
      store.dispose();
    });
  });

  test('a seek after the end without a known length leaves ended', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      backend.playingController.add(true);
      backend.playingController.add(false);
      backend.completedController.add(true);
      expect(store.ended, isTrue);

      store.seekTo(const Duration(seconds: 2));
      expect(store.ended, isFalse);
      store.dispose();
    });
  });
}
