import 'package:flutter/material.dart';

/// The animation Twitch asks for.
///
/// Values come from `CelebrationEffect` in the official Android app. Twitch
/// fires these itself for community gifts — a captured event carried
/// `celebration_source: "system_gifting"` — as well as for the alert sets a
/// streamer configures.
enum CelebrationEffect {
  fireworks,
  rain,
  float,
  flamethrower,
  extinctionEvent,
  unknown;

  static CelebrationEffect parse(String? value) => switch (value) {
    'FIREWORKS' => fireworks,
    'RAIN' => rain,
    'FLOAT' => float,
    'FLAMETHROWER' => flamethrower,
    'EXTINCTION_EVENT' => extinctionEvent,
    _ => unknown,
  };

  /// Which bundled animation plays this effect.
  ///
  /// **This mapping is ours, not Twitch's.** The official app does not
  /// reference these files by name for celebrations, so the pairing could not
  /// be extracted; it was chosen so the motion matches the word — a burst for
  /// fireworks, falling pieces for rain, a drifting shape for float. The
  /// animations themselves are Twitch's, recoloured to the app's palette.
  String get asset => switch (this) {
    fireworks => 'assets/animations/celebration_confetti.json',
    extinctionEvent => 'assets/animations/celebration_explosion.json',
    flamethrower => 'assets/animations/celebration_flame.json',
    rain => 'assets/animations/celebration_sparkles.json',
    float => 'assets/animations/celebration_star_bonk.json',
    unknown => 'assets/animations/celebration_sparkles.json',
  };
}

/// How big Twitch wants the celebration to feel.
enum CelebrationIntensity {
  cool,
  cute,
  noice,
  pogChamp,
  omegaPog;

  static CelebrationIntensity parse(String? value) => switch (value) {
    'COOL' => cool,
    'CUTE' => cute,
    'NOICE' => noice,
    'POG_CHAMP' => pogChamp,
    'OMEGA_POG' => omegaPog,
    _ => cool,
  };

  /// How much of the available space the animation fills.
  ///
  /// A celebration has to be legible without hiding the stream, so even the
  /// loudest tier stops short of covering everything.
  double get scale => switch (this) {
    cool => 0.55,
    cute => 0.65,
    noice => 0.8,
    pogChamp => 0.95,
    omegaPog => 1.1,
  };

  /// Peak opacity. The quieter tiers stay deliberately restrained: this app's
  /// whole visual system is flat and dark, and a full-strength overlay on
  /// every gifted sub would be exhausting.
  double get opacity => switch (this) {
    cool => 0.55,
    cute => 0.65,
    noice => 0.78,
    pogChamp => 0.9,
    omegaPog => 1,
  };
}

/// Where the animation plays.
enum CelebrationArea {
  chat,
  video,
  everywhere;

  static CelebrationArea parse(String? value) => switch (value) {
    'CHAT' => chat,
    'VIDEO' => video,
    'EVERYWHERE' => everywhere,
    _ => everywhere,
  };
}

/// A celebration to play, as delivered on `celebration-events-v1`.
@immutable
class Celebration {
  final CelebrationEffect effect;
  final CelebrationArea area;
  final CelebrationIntensity intensity;
  final Duration duration;

  /// Identifies what triggered it, e.g.
  /// `COMMUNITY_GIFT_SUBSCRIPTION:abef17e6-…`. Used to avoid replaying the
  /// same celebration twice.
  final String? eventId;

  /// `system_gifting` when Twitch fired it itself, otherwise the streamer's
  /// alert set.
  final String? source;

  /// The colour the streamer picked, when they picked one.
  final Color? primaryColor;

  const Celebration({
    required this.effect,
    required this.area,
    required this.intensity,
    required this.duration,
    this.eventId,
    this.source,
    this.primaryColor,
  });

  /// True when Twitch triggered this rather than a streamer's alert set.
  bool get isAutomatic => source == 'system_gifting';

  /// Parses the payload of an `alert_sets_celebration` event.
  ///
  /// Returns null for an effect this build cannot draw, so an effect Twitch
  /// adds later degrades to nothing rather than to a wrong animation.
  static Celebration? tryParse(Map<String, dynamic> data) {
    final effect = CelebrationEffect.parse(data['type'] as String?);
    if (effect == CelebrationEffect.unknown) return null;

    final seconds = data['duration'];
    return Celebration(
      effect: effect,
      area: CelebrationArea.parse(data['area'] as String?),
      intensity: CelebrationIntensity.parse(data['intensity'] as String?),
      // Clamped: a hostile or buggy duration must not pin an overlay over the
      // stream indefinitely.
      duration: Duration(
        milliseconds: ((seconds is num ? seconds.toDouble() : 5.0) * 1000)
            .clamp(500, 15000)
            .round(),
      ),
      eventId: data['alert_event_id'] as String?,
      source: data['celebration_source'] as String?,
      primaryColor: _hexColor(data['primary_color_hex'] as String?),
    );
  }

  static Color? _hexColor(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.replaceFirst('#', '').trim();
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
}
