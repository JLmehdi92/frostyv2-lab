import 'dart:async';

import 'package:flutter/foundation.dart';

class FollowPrompts {
  FollowPrompts({
    required this.following,
    required this.canFollow,
    required this.onCallout,
    required this.onOfferFollow,
    this.offerFollow = false,
    this.calloutDelay = defaultCalloutDelay,
  });

  static const defaultCalloutDelay = Duration(minutes: 10);

  final ValueListenable<bool?> following;
  final bool Function() canFollow;
  final VoidCallback onCallout;
  final VoidCallback onOfferFollow;
  final bool offerFollow;
  final Duration calloutDelay;

  Timer? _timer;
  var _offerPending = false;
  var _disposed = false;

  void start() {
    _timer = Timer(calloutDelay, _calloutDue);
    if (offerFollow) {
      _offerPending = true;
      following.addListener(_followKnown);
      _followKnown();
    }
  }

  void _calloutDue() {
    if (_disposed || following.value != false || !canFollow()) return;
    onCallout();
  }

  void _followKnown() {
    final follows = following.value;
    if (_disposed || !_offerPending || follows == null) return;
    _offerPending = false;
    following.removeListener(_followKnown);
    if (!follows && canFollow()) onOfferFollow();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_offerPending) following.removeListener(_followKnown);
  }
}
