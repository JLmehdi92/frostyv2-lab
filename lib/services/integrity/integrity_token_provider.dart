import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onset/services/integrity/integrity_token.dart';

typedef IntegrityMinter = Future<IntegrityToken> Function();

class IntegrityTokenProvider {
  IntegrityTokenProvider({
    required IntegrityMinter mint,
    required String? Function() webSession,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 15),
    this.expiryMargin = const Duration(minutes: 1),
  }) : _mint = mint,
       _webSession = webSession,
       _now = now ?? DateTime.now;

  final IntegrityMinter _mint;
  final String? Function() _webSession;
  final DateTime Function() _now;
  final Duration timeout;
  final Duration expiryMargin;

  IntegrityToken? _cached;
  String? _cachedSession;
  Future<IntegrityToken?>? _inFlight;
  String? _inFlightSession;

  Future<IntegrityToken?> tokenFor(String webToken) {
    if (webToken.isEmpty || _webSession() != webToken) {
      return Future.value();
    }
    final cached = _cached;
    if (cached != null &&
        _cachedSession == webToken &&
        cached.isUsableAt(_now().add(expiryMargin))) {
      return Future.value(cached);
    }
    final inFlight = _inFlight;
    if (inFlight != null && _inFlightSession == webToken) return inFlight;
    final mint = _mintFor(webToken);
    _inFlight = mint;
    _inFlightSession = webToken;
    return mint.whenComplete(() {
      if (identical(_inFlight, mint)) {
        _inFlight = null;
        _inFlightSession = null;
      }
    });
  }

  void invalidate() {
    _cached = null;
    _cachedSession = null;
  }

  Future<IntegrityToken?> _mintFor(String webToken) async {
    try {
      final token = await _mint().timeout(timeout);
      if (!token.isUsableAt(_now().add(expiryMargin))) return null;
      if (_webSession() != webToken) return null;
      _cached = token;
      _cachedSession = webToken;
      return token;
    } catch (e) {
      debugPrint('Integrity token unavailable: ${e.runtimeType}');
      return null;
    }
  }
}
