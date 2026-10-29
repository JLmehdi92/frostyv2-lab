import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:onset/screens/channel/video/live_progress.dart';
import 'package:onset/screens/channel/video/stores/ivs_video_store.dart';
import 'package:onset/stores/mini_player_store.dart';

class _MockPlayer extends Mock implements IvsVideoStore {}

class _MockChat extends Mock implements ChatTabsStore {}

class _MockTracker extends Mock implements LiveProgressTracker {}

void main() {
  late MiniPlayerStore store;
  late List<String> calls;

  _MockPlayer player(String name) {
    final p = _MockPlayer();
    when(p.dispose).thenAnswer((_) => calls.add('$name.dispose'));
    return p;
  }

  _MockChat chat() {
    final c = _MockChat();
    when(c.dispose).thenReturn(null);
    return c;
  }

  _MockTracker tracker(String name) {
    final t = _MockTracker();
    when(t.close).thenAnswer((_) async => calls.add('$name.close'));
    return t;
  }

  void adopt(
    IvsVideoStore p,
    LiveProgressTracker? t, {
    String login = 'streamer',
  }) => store.adopt(
    player: p,
    chatTabsStore: chat(),
    userLogin: login,
    userId: '42',
    displayName: 'Streamer',
    liveProgress: t,
  );

  setUp(() {
    store = MiniPlayerStore();
    calls = [];
  });

  test('the live progress follows the player into the mini window', () {
    final p = player('p');
    final t = tracker('t');
    adopt(p, t);

    final released = store.release();

    expect(released.player, same(p));
    expect(released.liveProgress, same(t));
    expect(calls, isEmpty, reason: 'still playing, still followed');
  });

  test('closing saves the position before the player goes', () {
    adopt(player('p'), tracker('t'));

    store.close();

    expect(calls, ['t.close', 'p.dispose']);
    expect(store.release().liveProgress, isNull);
  });

  test('another channel minimized replaces and closes the first', () {
    adopt(player('a'), tracker('ta'));
    adopt(player('b'), tracker('tb'), login: 'other');

    expect(calls, ['ta.close', 'a.dispose']);
  });

  test('a player without a tracker is fine', () {
    adopt(player('p'), null);

    store.close();

    expect(calls, ['p.dispose']);
  });
}
