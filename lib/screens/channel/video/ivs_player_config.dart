import 'package:onset/screens/channel/video/buffer_fallback.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

/// Native IVS player tuning derived from the user's settings, passed as the
/// `config` argument of `onset/ivs-texture-manager.create`.
class IvsPlayerConfig {
  const IvsPlayerConfig({
    required this.catchUp,
    required this.buffer,
    this.autoLatency = false,
    this.bufferFallback = false,
  });

  /// The settings as they are when the stream opens. With auto latency on, a
  /// chosen Ultra becomes Standard while [fallback] is active (Ultra stalled
  /// repeatedly on a recent stream).
  factory IvsPlayerConfig.fromSettings(
    SettingsStore settings, {
    BufferFallback? fallback,
  }) {
    final autoLatency = settings.autoLatency;
    final fellBack =
        autoLatency &&
        settings.bufferProfile == BufferProfile.ultra &&
        (fallback ?? BufferFallback.shared).active;
    return IvsPlayerConfig(
      catchUp: settings.liveCatchUpMode,
      buffer: fellBack ? BufferProfile.standard : settings.bufferProfile,
      autoLatency: autoLatency,
      bufferFallback: fellBack,
    );
  }

  /// Initial buffer before the first frame (the official app uses 100 ms on
  /// the live theatre).
  static const initialBufferMs = 100;

  /// Ultra profile low-latency buffer targets, in seconds.
  static const ultraMinBufferSec = 0.5;
  static const ultraMinBufferCeilingSec = 3.0;

  /// `create` arguments for a past broadcast: VOD mode, none of the live
  /// low-latency tuning.
  static const Map<String, Object> vodCreateArgs = {'vod': true};

  final LiveCatchUpMode catchUp;
  final BufferProfile buffer;

  /// Dart's auto latency drives the live playback rate (see
  /// `LatencyController`).
  final bool autoLatency;

  /// [buffer] is Standard only because Ultra stalled on a recent stream.
  final bool bufferFallback;

  /// Short description shown in the stats panel.
  String get label {
    final mode = switch ((catchUp, autoLatency)) {
      (LiveCatchUpMode.speedUp, true) => 'Auto',
      (LiveCatchUpMode.jumpToLive, true) => 'Jump to live + auto',
      (_, false) => liveCatchUpModeNames[catchUp.index],
    };
    return '$mode · ${bufferProfileNames[buffer.index]}'
        '${bufferFallback ? ' (Ultra stalled)' : ''}';
  }

  Map<String, Object> toCreateArgs() => {
    ...switch (catchUp) {
      // With auto latency the SDK speed-up is left off: it resets the rate
      // to its own on every buffer update (1.0x unless the buffer is above
      // its target), so it would undo every catch-up. Auto latency drains
      // the same excess buffer, and the buffer the target grew by.
      LiveCatchUpMode.speedUp => {
        'speedUpCatchUp': !autoLatency,
        'rebufferToLive': false,
      },
      LiveCatchUpMode.jumpToLive => {
        'speedUpCatchUp': false,
        'rebufferToLive': true,
      },
    },
    'initialBufferMs': initialBufferMs,
    ...switch (buffer) {
      BufferProfile.standard => const <String, Object>{},
      BufferProfile.ultra => {
        'llMinBufferSec': ultraMinBufferSec,
        'llMinBufferCeilingSec': ultraMinBufferCeilingSec,
      },
    },
  };
}
