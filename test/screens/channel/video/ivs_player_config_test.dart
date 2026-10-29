import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/ivs_player_config.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

void main() {
  group('IvsPlayerConfig', () {
    test('speed-up + standard matches the official app', () {
      final args = const IvsPlayerConfig(
        catchUp: LiveCatchUpMode.speedUp,
        buffer: BufferProfile.standard,
      ).toCreateArgs();

      expect(args, {
        'speedUpCatchUp': true,
        'rebufferToLive': false,
        'initialBufferMs': 100,
      });
    });

    test('jump-to-live reproduces the previous behaviour', () {
      final args = const IvsPlayerConfig(
        catchUp: LiveCatchUpMode.jumpToLive,
        buffer: BufferProfile.standard,
      ).toCreateArgs();

      expect(args['speedUpCatchUp'], isFalse);
      expect(args['rebufferToLive'], isTrue);
      expect(args.containsKey('llMinBufferSec'), isFalse);
    });

    test('ultra lowers the low-latency buffer targets', () {
      final args = const IvsPlayerConfig(
        catchUp: LiveCatchUpMode.speedUp,
        buffer: BufferProfile.ultra,
      ).toCreateArgs();

      expect(args['llMinBufferSec'], 0.5);
      expect(args['llMinBufferCeilingSec'], 3.0);
      expect(args['speedUpCatchUp'], isTrue);
    });

    test('standard leaves the IVS buffer defaults untouched', () {
      final args = const IvsPlayerConfig(
        catchUp: LiveCatchUpMode.jumpToLive,
        buffer: BufferProfile.standard,
      ).toCreateArgs();

      expect(args.containsKey('llMinBufferSec'), isFalse);
      expect(args.containsKey('llMinBufferCeilingSec'), isFalse);
    });

    test('fromSettings reads both settings', () {
      final settings = SettingsStore.fromJson({})
        ..liveCatchUpMode = LiveCatchUpMode.jumpToLive
        ..bufferProfile = BufferProfile.ultra;

      final config = IvsPlayerConfig.fromSettings(settings);

      expect(config.catchUp, LiveCatchUpMode.jumpToLive);
      expect(config.buffer, BufferProfile.ultra);
    });

    test('describes the active mode for the stats panel', () {
      expect(
        const IvsPlayerConfig(
          catchUp: LiveCatchUpMode.speedUp,
          buffer: BufferProfile.standard,
        ).label,
        'Speed up · Standard',
      );
      expect(
        const IvsPlayerConfig(
          catchUp: LiveCatchUpMode.jumpToLive,
          buffer: BufferProfile.ultra,
        ).label,
        'Jump to live · Ultra',
      );
    });
  });

  test('vod players are created in vod mode only', () {
    expect(IvsPlayerConfig.vodCreateArgs, {'vod': true});
    for (final catchUp in LiveCatchUpMode.values) {
      for (final buffer in BufferProfile.values) {
        expect(
          IvsPlayerConfig(catchUp: catchUp, buffer: buffer).toCreateArgs(),
          isNot(contains('vod')),
        );
      }
    }
  });
}
