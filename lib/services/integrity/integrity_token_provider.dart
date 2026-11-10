import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onset/services/integrity/integrity_token.dart';

enum IntegrityMintFailure { timedOut, failed }

typedef IntegrityMinter = Future<IntegrityToken> Function();

class IntegrityTokenProvider {
  IntegrityTokenProvider({
    required IntegrityMinter mint,
    required String? Function() webSession,
    VoidCallback? cancelMint,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 15),
    this.expiryMargin = const Duration(minutes: 1),
  }) : _mint = mint,
       _cancelMint = cancelMint,
       _webSession = webSession,
       _now = now ?? DateTime.now;

  final IntegrityMinter _mint;
  final VoidCallback? _cancelMint;
  final String? Function() _webSession;
  final DateTime Function() _now;
  final Duration timeout;
  final Duration expiryMargin;

  IntegrityToken? _cached;
  String? _cachedSession;
  Future<IntegrityToken?>? _inFlight;
  String? _inFlightSession;
  var _generation = 0;
  IntegrityMintFailure? _lastFailure;

  IntegrityMintFailure? get lastFailure => _lastFailure;

  bool get isMinting => _inFlight != null;

  Future<IntegrityToken?> tokenFor(String webToken) {
    if (webToken.isEmpty || _webSession() != webToken) {
      _lastFailure = IntegrityMintFailure.failed;
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
    final mint = _mintFor(webToken, _generation);
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

  void cancel() {
    _generation++;
    invalidate();
    _inFlight = null;
    _inFlightSession = null;
    _cancelMint?.call();
  }

  Future<IntegrityToken?> _mintFor(String webToken, int generation) async {
    _lastFailure = null;
    try {
      final minted = await _mint().timeout(timeout);
      final token = minted.cappedAt(_now().add(IntegrityToken.maxLifetime));
      if (generation != _generation ||
          !token.isUsableAt(_now().add(expiryMargin)) ||
          _webSession() != webToken) {
        _lastFailure = IntegrityMintFailure.failed;
        return null;
      }
      _cached = token;
      _cachedSession = webToken;
      return token;
    } on TimeoutException {
      debugPrint('Integrity token unavailable: timed out');
      _lastFailure = IntegrityMintFailure.timedOut;
      return null;
    } catch (e) {
      debugPrint('Integrity token unavailable: ${e.runtimeType}');
      _lastFailure = IntegrityMintFailure.failed;
      return null;
    }
  }
}
