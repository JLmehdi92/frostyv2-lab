import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/celebration.dart';

void main() {
  group('Celebration.tryParse', () {
    test('wrongly typed fields return null or are ignored, never throw', () {
      expect(Celebration.tryParse({'type': 5}), isNull);

      final celebration = Celebration.tryParse({
        'type': 'FIREWORKS',
        'area': 3,
        'intensity': true,
        'alert_event_id': 12,
        'celebration_source': ['x'],
        'primary_color_hex': 0xFF0000,
      });

      expect(celebration, isNotNull);
      expect(celebration!.area, CelebrationArea.everywhere);
      expect(celebration.intensity, CelebrationIntensity.cool);
      expect(celebration.eventId, isNull);
      expect(celebration.source, isNull);
      expect(celebration.primaryColor, isNull);
    });
  });

  test('every effect Twitch sends is parsed, anything else is dropped', () {
    const effects = {
      'FIREWORKS': CelebrationEffect.fireworks,
      'RAIN': CelebrationEffect.rain,
      'FLOAT': CelebrationEffect.float,
      'FLAMETHROWER': CelebrationEffect.flamethrower,
      'EXTINCTION_EVENT': CelebrationEffect.extinctionEvent,
    };
    for (final MapEntry(:key, :value) in effects.entries) {
      expect(Celebration.tryParse({'type': key})!.effect, value);
      expect(CelebrationPreset.values, contains(value.preset));
    }
    expect(Celebration.tryParse({'type': 'CONFETTI_CANNON'}), isNull);
    expect(Celebration.tryParse({}), isNull);
  });

  test('intensity and area, with their defaults', () {
    const intensities = {
      'COOL': CelebrationIntensity.cool,
      'CUTE': CelebrationIntensity.cute,
      'NOICE': CelebrationIntensity.noice,
      'POG_CHAMP': CelebrationIntensity.pogChamp,
      'OMEGA_POG': CelebrationIntensity.omegaPog,
      'LOUDER': CelebrationIntensity.cool,
    };
    for (final MapEntry(:key, :value) in intensities.entries) {
      expect(
        Celebration.tryParse({'type': 'RAIN', 'intensity': key})!.intensity,
        value,
      );
    }
    expect(
      Celebration.tryParse({'type': 'RAIN'})!.intensity,
      CelebrationIntensity.cool,
    );

    const areas = {
      'CHAT': CelebrationArea.chat,
      'VIDEO': CelebrationArea.video,
      'EVERYWHERE': CelebrationArea.everywhere,
      'SKY': CelebrationArea.everywhere,
    };
    for (final MapEntry(:key, :value) in areas.entries) {
      expect(Celebration.tryParse({'type': 'RAIN', 'area': key})!.area, value);
    }
  });

  test('the loudest tier is bigger and stronger than the quietest', () {
    expect(
      CelebrationIntensity.omegaPog.scale,
      greaterThan(CelebrationIntensity.cool.scale),
    );
    expect(CelebrationIntensity.omegaPog.opacity, 1);
    expect(CelebrationIntensity.cool.opacity, lessThan(1));
  });

  test('the duration is read in seconds and clamped to 0.5-15 s', () {
    Duration duration(Object? seconds) =>
        Celebration.tryParse({'type': 'FLOAT', 'duration': ?seconds})!.duration;

    expect(duration(null), const Duration(milliseconds: 5000));
    expect(duration(0.1), const Duration(milliseconds: 500));
    expect(duration(100), const Duration(milliseconds: 15000));
    expect(duration(3.5), const Duration(milliseconds: 3500));
    expect(duration('7'), const Duration(milliseconds: 5000));
  });

  test('event id, source and colour', () {
    final gifted = Celebration.tryParse({
      'type': 'FIREWORKS',
      'alert_event_id': 'COMMUNITY_GIFT_SUBSCRIPTION:abc',
      'celebration_source': 'system_gifting',
      'primary_color_hex': '#9146FF',
    })!;

    expect(gifted.eventId, 'COMMUNITY_GIFT_SUBSCRIPTION:abc');
    expect(gifted.source, 'system_gifting');
    expect(gifted.isAutomatic, isTrue);
    expect(gifted.primaryColor, const Color(0xFF9146FF));

    final streamer = Celebration.tryParse({
      'type': 'FIREWORKS',
      'celebration_source': 'alert_set',
      'primary_color_hex': '9146FF',
    })!;
    expect(streamer.isAutomatic, isFalse);
    expect(streamer.primaryColor, const Color(0xFF9146FF));

    for (final hex in ['#FFF', 'zzzzzz', '#12345678']) {
      expect(
        Celebration.tryParse({
          'type': 'FIREWORKS',
          'primary_color_hex': hex,
        })!.primaryColor,
        isNull,
        reason: hex,
      );
    }
  });
}
