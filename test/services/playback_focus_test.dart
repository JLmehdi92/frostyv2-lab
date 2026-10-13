import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/services/playback_focus.dart';

void main() {
  late PlaybackFocus focus;
  late List<String> log;

  setUp(() {
    focus = PlaybackFocus();
    log = [];
  });

  void register(String name) => focus.register(
    name,
    onLost: () => log.add('$name lost'),
    onRegained: () => log.add('$name regained'),
  );

  test('claiming pauses the previous owner', () {
    register('live');
    register('vod');
    focus.claim('live');

    focus.claim('vod');

    expect(log, ['live lost']);
    expect(focus.top, 'vod');
  });

  test('releasing the top resumes the one below', () {
    register('live');
    register('vod');
    focus
      ..claim('live')
      ..claim('vod');

    focus.release('vod');

    expect(log, ['live lost', 'live regained']);
    expect(focus.top, 'live');
  });

  test('releasing an owner below the top calls nobody', () {
    register('live');
    register('vod');
    focus
      ..claim('live')
      ..claim('vod');
    log.clear();

    focus.release('live');

    expect(log, isEmpty);
    expect(focus.top, 'vod');
    focus.release('vod');
    expect(log, isEmpty, reason: 'live is gone, nothing to resume');
  });

  test('claiming twice is a no-op', () {
    register('live');
    register('vod');
    focus
      ..claim('live')
      ..claim('vod');
    log.clear();

    focus.claim('vod');

    expect(log, isEmpty);
  });

  test('an owner that claims again moves back on top', () {
    register('live');
    register('vod');
    focus
      ..claim('live')
      ..claim('vod')
      ..claim('live');

    expect(log, ['live lost', 'vod lost']);
    expect(focus.top, 'live');

    focus.release('live');
    expect(log.last, 'vod regained');
  });

  test('unknown owners are ignored', () {
    register('live');
    focus.claim('live');

    focus
      ..claim('stranger')
      ..release('stranger');

    expect(log, isEmpty);
    expect(focus.top, 'live');
  });

  test('a released owner must register again', () {
    register('live');
    focus
      ..claim('live')
      ..release('live')
      ..claim('live');

    expect(focus.top, isNull);
  });
}
