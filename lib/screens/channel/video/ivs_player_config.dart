import 'package:frosty/screens/settings/stores/settings_store.dart';

/// Native IVS player tuning derived from the user's settings, passed as the
/// `config` argument of `frosty/ivs-texture-manager.create`.
class IvsPlayerConfig {
  const IvsPlayerConfig({required this.catchUp, required this.buffer});

  factory IvsPlayerConfig.fromSettings(SettingsStore settings) =>
      IvsPlayerConfig(
        catchUp: settings.liveCatchUpMode,
        buffer: settings.bufferProfile,
      );

  /// Initial buffer before the first frame (the official app uses 100 ms on
  /// the live theatre).
  static const initialBufferMs = 100;

  /// Ultra profile low-latency buffer targets, in seconds.
  static const ultraMinBufferSec = 0.5;
  static const ultraMinBufferCeilingSec = 3.0;

  final LiveCatchUpMode catchUp;
  final BufferProfile buffer;

  /// Short description shown in the stats panel.
  String get label =>
      '${liveCatchUpModeNames[catchUp.index]} · '
      '${bufferProfileNames[buffer.index]}';

  Map<String, Object> toCreateArgs() => {
    ...switch (catchUp) {
      LiveCatchUpMode.speedUp => {
        'speedUpCatchUp': true,
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
