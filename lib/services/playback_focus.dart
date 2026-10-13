import 'package:flutter/foundation.dart';

/// Keeps exactly one player audible: the live stream screen and the VOD
/// screen claim focus when they show up, which pauses the player beneath,
/// and release it when they close, which resumes it.
///
/// Owners form a stack; only player screens claim (never sheets or dialogs).
class PlaybackFocus {
  /// The app-wide instance used by player screens.
  static final shared = PlaybackFocus();

  final _callbacks =
      <Object, ({VoidCallback onLost, VoidCallback onRegained})>{};
  final _stack = <Object>[];

  /// The owner currently holding focus.
  Object? get top => _stack.isEmpty ? null : _stack.last;

  /// Makes [owner] known; it holds nothing until it [claim]s.
  void register(
    Object owner, {
    required VoidCallback onLost,
    required VoidCallback onRegained,
  }) => _callbacks[owner] = (onLost: onLost, onRegained: onRegained);

  /// Puts [owner] on top, pausing the previous top.
  void claim(Object owner) {
    if (!_callbacks.containsKey(owner) || top == owner) return;
    final previous = top;
    _stack
      ..remove(owner)
      ..add(owner);
    if (previous != null) _callbacks[previous]?.onLost();
  }

  /// Forgets [owner]; when it was on top, the new top resumes.
  void release(Object owner) {
    if (_callbacks.remove(owner) == null) return;
    final wasTop = top == owner;
    _stack.remove(owner);
    final next = top;
    if (wasTop && next != null) _callbacks[next]?.onRegained();
  }
}
