import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/up_next.dart';
import 'package:onset/screens/vod/vod_resume.dart';

Vod _vod(
  String id, {
  int length = 3600,
  bool restricted = false,
  String owner = '42',
}) => Vod(
  id: id,
  title: 'Video $id',
  lengthSeconds: length,
  createdAt: DateTime.utc(2026, 10, 2),
  viewCount: 1,
  ownerId: owner,
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
  isRestricted: restricted,
);

VodResumeEntry _at(int position, {int length = 3600, bool finished = false}) =>
    VodResumeEntry(
      positionSec: position,
      lengthSec: length,
      finished: finished,
    );

void main() {
  group('isVodWatched (Twitch heuristic)', () {
    test('never opened is not watched', () {
      expect(isVodWatched(_vod('1'), null), isFalse);
    });

    test('watched to the end is watched', () {
      expect(isVodWatched(_vod('1'), _at(0, finished: true)), isTrue);
    });

    test('under 5 minutes: watched only at the end', () {
      final short = _vod('1', length: 200);
      expect(isVodWatched(short, _at(150, length: 200)), isFalse);
      expect(isVodWatched(short, _at(200, length: 200)), isTrue);
    });

    test('up to 50 minutes: watched after 5 minutes', () {
      final medium = _vod('1', length: 3000);
      expect(isVodWatched(medium, _at(299, length: 3000)), isFalse);
      expect(isVodWatched(medium, _at(300, length: 3000)), isTrue);
    });

    test('longer: watched after a tenth of it', () {
      final long = _vod('1', length: 20000);
      expect(isVodWatched(long, _at(1999, length: 20000)), isFalse);
      expect(isVodWatched(long, _at(2000, length: 20000)), isTrue);
    });
  });

  group('pickUpNext', () {
    test('the first other video of the list', () {
      final current = _vod('1');
      final next = pickUpNext(
        current: current,
        candidates: [current, _vod('2'), _vod('3')],
        saved: const {},
      );
      expect(next?.id, '2');
    });

    test('skips watched and subscriber-only videos', () {
      final current = _vod('1');
      final next = pickUpNext(
        current: current,
        candidates: [
          _vod('2', restricted: true),
          _vod('3'),
          current,
          _vod('4'),
        ],
        saved: {'3': _at(0, finished: true)},
      );
      expect(next?.id, '4');
    });

    test('nothing left is null', () {
      final current = _vod('1');
      expect(
        pickUpNext(current: current, candidates: [current], saved: const {}),
        isNull,
      );
    });
  });

  group('autoplayAllowed', () {
    test('mobile data and Wi-Fi plays on any network', () {
      expect(autoplayAllowed(VodAutoplay.always, metered: true), isTrue);
      expect(autoplayAllowed(VodAutoplay.always, metered: null), isTrue);
    });

    test('Wi-Fi only plays on an unmetered network only', () {
      expect(autoplayAllowed(VodAutoplay.wifiOnly, metered: false), isTrue);
      expect(autoplayAllowed(VodAutoplay.wifiOnly, metered: true), isFalse);
      expect(
        autoplayAllowed(VodAutoplay.wifiOnly, metered: null),
        isFalse,
        reason: 'an unknown network may be mobile data',
      );
    });

    test('never never plays', () {
      expect(autoplayAllowed(VodAutoplay.never, metered: false), isFalse);
    });
  });

  test('the setting defaults to Twitch\'s: mobile data and Wi-Fi', () {
    expect(SettingsStore().vodAutoplay, VodAutoplay.always);
    expect(SettingsStore.fromJson({}).vodAutoplay, VodAutoplay.always);
    expect(
      SettingsStore.fromJson({'vodAutoplay': 'bogus'}).vodAutoplay,
      VodAutoplay.always,
    );
    final store = SettingsStore()..vodAutoplay = VodAutoplay.never;
    expect(
      SettingsStore.fromJson(store.toJson()).vodAutoplay,
      VodAutoplay.never,
    );
    store.resetVideoSettings();
    expect(store.vodAutoplay, VodAutoplay.always);
  });
}
