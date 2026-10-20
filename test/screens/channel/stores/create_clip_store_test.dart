import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/channel/stores/create_clip_store.dart';
import 'package:mocktail/mocktail.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

void main() {
  late MockTwitchApi api;
  late bool loggedIn;

  const creation = ClipCreation(id: 'Slug-abc');

  setUp(() {
    api = MockTwitchApi();
    loggedIn = true;
    when(
      () => api.getTokenScopes(),
    ).thenAnswer((_) async => {'chat:read', 'clips:edit'});
    when(
      () => api.createClip(broadcasterId: '42'),
    ).thenAnswer((_) async => creation);
  });

  CreateClipStore make() => CreateClipStore(
    twitchApi: api,
    broadcasterId: '42',
    isLoggedIn: () => loggedIn,
  );

  test('creates the clip, then waits until Twitch has made it', () {
    fakeAsync((async) {
      var polls = 0;
      when(() => api.getCreatedClip('Slug-abc')).thenAnswer((_) async {
        polls++;
        return polls < 3
            ? null
            : const CreatedClip(
                id: 'Slug-abc',
                thumbnailUrl: 'https://t/x.jpg',
              );
      });
      final store = make();

      store.start();
      async.flushMicrotasks();
      expect(store.status, CreateClipStatus.rendering);
      expect(store.creation?.link, 'https://clips.twitch.tv/Slug-abc');

      async.elapse(const Duration(seconds: 15));
      expect(store.status, CreateClipStatus.ready);
      expect(store.thumbnailUrl, 'https://t/x.jpg');
      expect(polls, 3);

      async.elapse(const Duration(minutes: 2));
      expect(polls, 3, reason: 'no polling once made');
      store.dispose();
    });
  });

  test('gives up after a minute, as Twitch advises', () {
    fakeAsync((async) {
      var polls = 0;
      when(() => api.getCreatedClip('Slug-abc')).thenAnswer((_) async {
        polls++;
        return null;
      });
      final store = make();

      store.start();
      async.elapse(const Duration(seconds: 61));

      expect(store.status, CreateClipStatus.failed);
      expect(store.failure, ClipCreateFailure.unknown);
      expect(polls, lessThanOrEqualTo(13), reason: 'bounded polling');
      async.elapse(const Duration(minutes: 5));
      expect(polls, lessThanOrEqualTo(13));
      store.dispose();
    });
  });

  test('a failed poll is tried again on the next tick', () {
    fakeAsync((async) {
      var polls = 0;
      when(() => api.getCreatedClip('Slug-abc')).thenAnswer((_) async {
        polls++;
        if (polls == 1) throw const NetworkException('offline');
        return const CreatedClip(id: 'Slug-abc');
      });
      final store = make();

      store.start();
      async.elapse(const Duration(seconds: 11));

      expect(store.status, CreateClipStatus.ready);
      store.dispose();
    });
  });

  test('logged out: asks to log in, without a request', () {
    fakeAsync((async) {
      loggedIn = false;
      final store = make();

      store.start();
      async.flushMicrotasks();

      expect(store.status, CreateClipStatus.needsLogin);
      verifyNever(() => api.getTokenScopes());
      verifyNever(
        () => api.createClip(broadcasterId: any(named: 'broadcasterId')),
      );
    });
  });

  test('a token from before clips: asks to reconnect, without clipping', () {
    fakeAsync((async) {
      when(() => api.getTokenScopes()).thenAnswer((_) async => {'chat:read'});
      final store = make();

      store.start();
      async.flushMicrotasks();

      expect(store.status, CreateClipStatus.missingScope);
      verifyNever(
        () => api.createClip(broadcasterId: any(named: 'broadcasterId')),
      );
    });
  });

  test('scopes unknown (offline check): tries, and Twitch decides', () {
    fakeAsync((async) {
      when(
        () => api.getTokenScopes(),
      ).thenThrow(const NetworkException('offline'));
      when(
        () => api.createClip(broadcasterId: '42'),
      ).thenThrow(const ClipCreateException(ClipCreateFailure.missingScope));
      final store = make();

      store.start();
      async.flushMicrotasks();

      expect(store.status, CreateClipStatus.missingScope);
    });
  });

  test('a refusal is kept with its reason', () {
    fakeAsync((async) {
      when(
        () => api.createClip(broadcasterId: '42'),
      ).thenThrow(const ClipCreateException(ClipCreateFailure.restricted));
      final store = make();

      store.start();
      async.flushMicrotasks();

      expect(store.status, CreateClipStatus.failed);
      expect(store.failure, ClipCreateFailure.restricted);
    });
  });

  test('another tap while busy makes no second clip', () {
    fakeAsync((async) {
      when(() => api.getCreatedClip('Slug-abc')).thenAnswer((_) async => null);
      final store = make();

      store.start();
      store.start();
      async.flushMicrotasks();
      store.start();
      async.flushMicrotasks();

      verify(() => api.createClip(broadcasterId: '42')).called(1);
      store.dispose();
    });
  });

  test('retry after a failure clips again', () {
    fakeAsync((async) {
      var calls = 0;
      when(() => api.createClip(broadcasterId: '42')).thenAnswer((_) async {
        if (calls++ == 0) {
          throw const ClipCreateException(ClipCreateFailure.unknown);
        }
        return creation;
      });
      when(
        () => api.getCreatedClip('Slug-abc'),
      ).thenAnswer((_) async => const CreatedClip(id: 'Slug-abc'));
      final store = make();

      store.start();
      async.flushMicrotasks();
      expect(store.status, CreateClipStatus.failed);

      store.start();
      async.elapse(const Duration(seconds: 6));
      expect(store.status, CreateClipStatus.ready);
      store.dispose();
    });
  });

  test('closed while rendering: polling stops', () {
    fakeAsync((async) {
      var polls = 0;
      when(() => api.getCreatedClip('Slug-abc')).thenAnswer((_) async {
        polls++;
        return null;
      });
      final store = make();

      store.start();
      async.flushMicrotasks();
      store.dispose();
      async.elapse(const Duration(minutes: 2));

      expect(polls, 0);
    });
  });
}
