/// Hype train animation timings, matching the behaviour observed on Twitch.
abstract final class HtTimings {
  static const textLong = Duration(milliseconds: 6000);
  static const scrollLong = Duration(milliseconds: 3000);
  static const scrollDefault = Duration(milliseconds: 2500);
  static const textShort = Duration(milliseconds: 2000);
  static const fade = Duration(milliseconds: 1000);
  static const short = Duration(milliseconds: 500);
  static const extraShort = Duration(milliseconds: 200);
  static const endStrip = Duration(milliseconds: 20000);
  static const stripTick = Duration(milliseconds: 500);
  static const approachingTick = Duration(milliseconds: 500);

  /// Ours: the length of the official coin/rocket animation is unknown.
  static const unlockEffect = Duration(milliseconds: 1600);

  /// A still unlock icon when animations are reduced.
  static const unlockIcon = Duration(milliseconds: 1000);

  /// One rainbow sweep; [rainbowCycles] of them play.
  static const rainbowLevelUp = Duration(milliseconds: 2000);
  static const rainbowComplete = Duration(milliseconds: 4500);
  static const rainbowAthComplete = Duration(milliseconds: 4200);
  static const rainbowCycles = 3;

  /// The approaching strip shows for at least this long.
  static const approachingMinWindow = Duration(seconds: 20);

  /// How long past `expiresAt` before an unended train is closed (D5).
  static const expiryGrace = Duration(seconds: 10);
}
