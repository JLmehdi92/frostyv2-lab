import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/video/buffer_fallback.dart';
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
        ..bufferProfile = BufferProfile.ultra
        ..autoLatency = false;

      final config = IvsPlayerConfig.fromSettings(
        settings,
        fallback: BufferFallback(),
      );

      expect(config.catchUp, LiveCatchUpMode.jumpToLive);
      expect(config.buffer, BufferProfile.ultra);
      expect(config.autoLatency, isFalse);
    });

    group('auto latency', () {
      final everyCombination = [
        for (final catchUp in LiveCatchUpMode.values)
          for (final buffer in BufferProfile.values) (catchUp, buffer),
      ];

      test('off leaves the create args exactly as before', () {
        final expected = {
          (LiveCatchUpMode.speedUp, BufferProfile.standard): {
            'speedUpCatchUp': true,
            'rebufferToLive': false,
            'initialBufferMs': 100,
          },
          (LiveCatchUpMode.speedUp, BufferProfile.ultra): {
            'speedUpCatchUp': true,
            'rebufferToLive': false,
            'initialBufferMs': 100,
            'llMinBufferSec': 0.5,
            'llMinBufferCeilingSec': 3.0,
          },
          (LiveCatchUpMode.jumpToLive, BufferProfile.standard): {
            'speedUpCatchUp': false,
            'rebufferToLive': true,
            'initialBufferMs': 100,
          },
          (LiveCatchUpMode.jumpToLive, BufferProfile.ultra): {
            'speedUpCatchUp': false,
            'rebufferToLive': true,
            'initialBufferMs': 100,
            'llMinBufferSec': 0.5,
            'llMinBufferCeilingSec': 3.0,
          },
        };
        for (final (catchUp, buffer) in everyCombination) {
          final settings = SettingsStore.fromJson({})
            ..liveCatchUpMode = catchUp
            ..bufferProfile = buffer
            ..autoLatency = false;
          expect(
            IvsPlayerConfig.fromSettings(
              settings,
              fallback: BufferFallback(),
            ).toCreateArgs(),
            expected[(catchUp, buffer)],
            reason: '$catchUp $buffer',
          );
        }
      });

      test('takes the rate over from the SDK speed-up', () {
        // The SDK speed-up resets any other rate on every buffer update.
        final args = const IvsPlayerConfig(
          catchUp: LiveCatchUpMode.speedUp,
          buffer: BufferProfile.ultra,
          autoLatency: true,
        ).toCreateArgs();

        expect(args['speedUpCatchUp'], isFalse);
        expect(args['rebufferToLive'], isFalse);
        expect(args['llMinBufferSec'], 0.5);
      });

      test('leaves jump to live as it is', () {
        expect(
          const IvsPlayerConfig(
            catchUp: LiveCatchUpMode.jumpToLive,
            buffer: BufferProfile.standard,
            autoLatency: true,
          ).toCreateArgs(),
          const IvsPlayerConfig(
            catchUp: LiveCatchUpMode.jumpToLive,
            buffer: BufferProfile.standard,
          ).toCreateArgs(),
        );
      });

      test('ultra falls back to standard after repeated stalls', () {
        var now = DateTime(2026, 10, 30, 20);
        final fallback = BufferFallback(now: () => now)
          ..onUltraRebuffer()
          ..onUltraRebuffer();
        final settings = SettingsStore.fromJson({});

        final config = IvsPlayerConfig.fromSettings(
          settings,
          fallback: fallback,
        );

        expect(config.buffer, BufferProfile.standard);
        expect(config.bufferFallback, isTrue);
        expect(config.toCreateArgs().containsKey('llMinBufferSec'), isFalse);
        expect(config.label(L10n.english), 'Auto · Standard (Ultra stalled)');
        expect(settings.bufferProfile, BufferProfile.ultra, reason: 'kept');

        now = now.add(BufferFallback.holdFor);
        expect(
          IvsPlayerConfig.fromSettings(settings, fallback: fallback).buffer,
          BufferProfile.ultra,
        );
      });

      test('the fallback only applies with auto latency on', () {
        final fallback = BufferFallback()
          ..onUltraRebuffer()
          ..onUltraRebuffer();
        final settings = SettingsStore.fromJson({})..autoLatency = false;

        expect(
          IvsPlayerConfig.fromSettings(settings, fallback: fallback).buffer,
          BufferProfile.ultra,
        );
      });

      test('a chosen standard stays standard', () {
        final settings = SettingsStore.fromJson({})
          ..bufferProfile = BufferProfile.standard;

        final config = IvsPlayerConfig.fromSettings(
          settings,
          fallback: BufferFallback(),
        );

        expect(config.buffer, BufferProfile.standard);
        expect(config.bufferFallback, isFalse);
      });

      test('the label says auto latency replaces the speed-up', () {
        expect(
          const IvsPlayerConfig(
            catchUp: LiveCatchUpMode.speedUp,
            buffer: BufferProfile.ultra,
            autoLatency: true,
          ).label(L10n.english),
          'Auto · Ultra',
        );
        expect(
          const IvsPlayerConfig(
            catchUp: LiveCatchUpMode.jumpToLive,
            buffer: BufferProfile.ultra,
            autoLatency: true,
          ).label(L10n.english),
          'Jump to live + auto · Ultra',
        );
      });
    });

    test('describes the active mode for the stats panel', () {
      expect(
        const IvsPlayerConfig(
          catchUp: LiveCatchUpMode.speedUp,
          buffer: BufferProfile.standard,
        ).label(L10n.english),
        'Speed up · Standard',
      );
      expect(
        const IvsPlayerConfig(
          catchUp: LiveCatchUpMode.jumpToLive,
          buffer: BufferProfile.ultra,
        ).label(L10n.english),
        'Jump to live · Ultra',
      );
    });
  });

  test('vod players are created in vod mode only', () {
    expect(IvsPlayerConfig.vodCreateArgs, {'vod': true});
    for (final catchUp in LiveCatchUpMode.values) {
      for (final buffer in BufferProfile.values) {
        for (final autoLatency in [false, true]) {
          expect(
            IvsPlayerConfig(
              catchUp: catchUp,
              buffer: buffer,
              autoLatency: autoLatency,
            ).toCreateArgs(),
            isNot(contains('vod')),
          );
        }
      }
    }
  });
}
