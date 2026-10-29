import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/models/raid_arrival.dart';
import 'package:onset/screens/channel/community_highlights/raid_departure.dart';

const _raid = OutgoingRaid(
  id: 'r',
  sourceId: '1',
  targetId: '2',
  targetLogin: 'friend',
  targetDisplayName: 'Friend',
  viewerCount: 1204,
  targetProfileImage: 'https://static-cdn.jtvnw.net/friend.png',
);

final _now = DateTime.utc(2026, 10, 28, 20);

void main() {
  late bool canLeave;
  late List<(OutgoingRaid, RaidArrival)> switched;
  late int changes;
  late RaidDeparture departure;

  setUp(() {
    canLeave = true;
    switched = [];
    changes = 0;
    departure = RaidDeparture(
      canLeave: () => canLeave,
      onSwitch: (raid, arrival) => switched.add((raid, arrival)),
      onChanged: () => changes++,
    );
  });

  bool start() => departure.start(
    _raid,
    fromName: 'Nisqyy',
    fromLogin: 'nisqyy',
    delay: const Duration(milliseconds: 1350),
    now: _now,
  );

  test('the switch comes after the overlay, once', () {
    fakeAsync((async) {
      expect(start(), isTrue);
      expect(changes, 1);
      final arrival = departure.current!;
      expect(arrival.fromName, 'Nisqyy');
      expect(arrival.fromLogin, 'nisqyy');
      expect(arrival.targetName, 'Friend');
      expect(arrival.viewers, 1204);
      expect(arrival.at, _now);
      expect(arrival.targetAvatarUrl, _raid.targetProfileImage);

      // The raid leaving after "Go now" starts nothing more.
      expect(start(), isFalse);
      async.elapse(const Duration(milliseconds: 1300));
      expect(switched, isEmpty);
      async.elapse(const Duration(milliseconds: 100));
      expect(switched.single.$1, same(_raid));
      expect(switched.single.$2, same(arrival));
    });
  });

  test('PiP or a page opened meanwhile keeps the viewer here', () {
    fakeAsync((async) {
      start();
      canLeave = false;
      async.elapse(const Duration(seconds: 2));
      expect(switched, isEmpty);
      expect(departure.current, isNull);
      expect(changes, 2);
      // And they can go again later.
      canLeave = true;
      expect(start(), isTrue);
      async.elapse(const Duration(seconds: 2));
      expect(switched, hasLength(1));
    });
  });

  test('a screen gone before the switch switches nothing', () {
    fakeAsync((async) {
      start();
      departure.dispose();
      async.elapse(const Duration(seconds: 2));
      expect(switched, isEmpty);
      expect(start(), isFalse);
    });
  });

  test('a picture that is not https is not carried over', () {
    final arrival = RaidArrival.leaving(
      const OutgoingRaid(
        id: 'r',
        sourceId: '1',
        targetId: '2',
        targetLogin: 'friend',
        targetDisplayName: 'Friend',
        viewerCount: 3,
        targetProfileImage: 'http://example.com/a.png',
      ),
      fromName: 'Nisqyy',
      at: _now,
    );
    expect(arrival.targetAvatarUrl, isNull);
  });

  test('called off (the raid was cancelled): no switch, at once', () {
    fakeAsync((async) {
      start();
      async.elapse(const Duration(milliseconds: 400));
      departure.callOff();
      expect(departure.current, isNull);
      expect(changes, 2);
      async.elapse(const Duration(seconds: 2));
      expect(switched, isEmpty);
      // Nothing under way: nothing to call off.
      departure.callOff();
      expect(changes, 2);
    });
  });

  test('Go now, then the raid leaving: one switch', () {
    fakeAsync((async) {
      // "Go now".
      expect(start(), isTrue);
      async.elapse(const Duration(milliseconds: 500));
      // The automatic go-along when the raid leaves meanwhile.
      expect(start(), isFalse);
      async.elapse(const Duration(seconds: 3));
      expect(switched, hasLength(1));
    });
  });

  test('the screen wiring: a raid cancelled meanwhile never switches', () {
    fakeAsync((async) {
      var cancelled = false;
      final wired = RaidDeparture(
        // As channel.dart: a cancelled raid takes no one anywhere.
        canLeave: () => !cancelled && canLeave,
        onSwitch: (raid, arrival) => switched.add((raid, arrival)),
        onChanged: () => changes++,
      );
      wired.start(
        _raid,
        fromName: 'Nisqyy',
        delay: const Duration(milliseconds: 1350),
        now: _now,
      );
      cancelled = true;
      async.elapse(const Duration(seconds: 2));
      expect(switched, isEmpty);
      expect(wired.current, isNull);
    });
  });
}
