import 'package:flutter/services.dart';

/// The few haptic moments of the redesign, each mapped to one of the
/// platform's predefined effects (Android's guidance: less is more, never a
/// buzz, and nothing on scroll).
///
/// Fired at the same instant as the visual it accompanies.
abstract final class Haptics {
  /// A tab, a chip, a segmented choice.
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// Follow, send a chat message, open the emote picker.
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Subscribe, gift, a hype train level: the moments that also get the
  /// green burst.
  static Future<void> medium() => HapticFeedback.mediumImpact();
}
