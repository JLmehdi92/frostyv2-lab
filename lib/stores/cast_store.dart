import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/services/cast_bridge.dart';

part 'cast_store.g.dart';

class CastStore = CastStoreBase with _$CastStore;

final sharedCastStore = CastStore();

abstract class CastStoreBase with Store {
  CastStoreBase({CastBridge? bridge}) : _bridge = bridge ?? CastBridge() {
    _bridge.listen(onDevices: _setDevices, onStatus: _setStatus);
  }

  final CastBridge _bridge;

  bool get supported => _bridge.supported;

  @readonly
  List<CastDevice> _devices = const [];

  @readonly
  CastStatus _status = CastStatus.disconnected;

  @readonly
  bool? _available;

  @readonly
  bool _loadFailed = false;

  @readonly
  CastMedia? _casting;

  CastMedia? _pending;
  VoidCallback? _onLoaded;

  @computed
  CastConnection get connection => _status.connection;

  @computed
  bool get connected => connection == CastConnection.connected;

  @action
  Future<void> beginDiscovery() async {
    final available = await _bridge.startDiscovery();
    runInAction(() => _available = available);
    if (available) _setStatus(await _bridge.status());
  }

  Future<void> endDiscovery() => _bridge.stopDiscovery();

  @action
  Future<bool> castTo(
    CastDevice device,
    CastMedia media, {
    VoidCallback? onLoaded,
  }) async {
    _pending = media;
    _onLoaded = onLoaded;
    _loadFailed = false;
    if (connected && _status.deviceId == device.id) {
      return _loadPending();
    }
    final requested = await _bridge.connect(device);
    if (!requested) {
      _pending = null;
      _onLoaded = null;
      runInAction(() => _loadFailed = true);
    }
    return requested;
  }

  @action
  Future<bool> castHere(CastMedia media, {VoidCallback? onLoaded}) {
    _pending = media;
    _onLoaded = onLoaded;
    _loadFailed = false;
    return _loadPending();
  }

  @action
  Future<void> stopCasting() async {
    _pending = null;
    _onLoaded = null;
    _casting = null;
    await _bridge.disconnect();
  }

  @action
  void _setDevices(List<CastDevice> devices) => _devices = devices;

  @action
  void _setStatus(CastStatus status) {
    _status = status;
    switch (status.connection) {
      case CastConnection.connected:
        if (_pending != null) unawaited(_loadPending());
      case CastConnection.disconnected:
        if (_pending != null) _loadFailed = true;
        _pending = null;
        _onLoaded = null;
        _casting = null;
      case CastConnection.connecting:
        break;
    }
  }

  Future<bool> _loadPending() async {
    final media = _pending;
    final onLoaded = _onLoaded;
    _pending = null;
    _onLoaded = null;
    if (media == null) return false;
    final loaded = await _bridge.load(media);
    runInAction(() {
      _loadFailed = !loaded;
      _casting = loaded ? media : null;
    });
    if (loaded) onLoaded?.call();
    return loaded;
  }
}
