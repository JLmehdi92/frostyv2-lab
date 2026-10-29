import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/player_engine_resolver.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

void main() {
  group('resolvePlayerEngine', () {
    test('keeps the chosen engine on Android', () {
      for (final engine in PlayerEngine.values) {
        expect(
          resolvePlayerEngine(
            setting: engine,
            isAndroid: true,
            forceWeb: false,
          ),
          engine,
        );
      }
    });

    test('never uses IVS off Android (it has no native player there)', () {
      expect(
        resolvePlayerEngine(
          setting: PlayerEngine.ivs,
          isAndroid: false,
          forceWeb: false,
        ),
        PlayerEngine.twitchWeb,
      );
    });

    test('keeps mpv and web off Android', () {
      expect(
        resolvePlayerEngine(
          setting: PlayerEngine.nativeLowLatency,
          isAndroid: false,
          forceWeb: false,
        ),
        PlayerEngine.nativeLowLatency,
      );
      expect(
        resolvePlayerEngine(
          setting: PlayerEngine.twitchWeb,
          isAndroid: false,
          forceWeb: false,
        ),
        PlayerEngine.twitchWeb,
      );
    });

    test('forceWeb always wins', () {
      for (final engine in PlayerEngine.values) {
        for (final android in [true, false]) {
          expect(
            resolvePlayerEngine(
              setting: engine,
              isAndroid: android,
              forceWeb: true,
            ),
            PlayerEngine.twitchWeb,
          );
        }
      }
    });
  });
}
