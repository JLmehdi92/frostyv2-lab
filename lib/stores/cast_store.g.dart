// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cast_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CastStore on CastStoreBase, Store {
  Computed<CastConnection>? _$connectionComputed;

  @override
  CastConnection get connection =>
      (_$connectionComputed ??= Computed<CastConnection>(
        () => super.connection,
        name: 'CastStoreBase.connection',
      )).value;
  Computed<bool>? _$connectedComputed;

  @override
  bool get connected => (_$connectedComputed ??= Computed<bool>(
    () => super.connected,
    name: 'CastStoreBase.connected',
  )).value;

  late final _$_devicesAtom = Atom(
    name: 'CastStoreBase._devices',
    context: context,
  );

  List<CastDevice> get devices {
    _$_devicesAtom.reportRead();
    return super._devices;
  }

  @override
  List<CastDevice> get _devices => devices;

  @override
  set _devices(List<CastDevice> value) {
    _$_devicesAtom.reportWrite(value, super._devices, () {
      super._devices = value;
    });
  }

  late final _$_statusAtom = Atom(
    name: 'CastStoreBase._status',
    context: context,
  );

  CastStatus get status {
    _$_statusAtom.reportRead();
    return super._status;
  }

  @override
  CastStatus get _status => status;

  @override
  set _status(CastStatus value) {
    _$_statusAtom.reportWrite(value, super._status, () {
      super._status = value;
    });
  }

  late final _$_availableAtom = Atom(
    name: 'CastStoreBase._available',
    context: context,
  );

  bool? get available {
    _$_availableAtom.reportRead();
    return super._available;
  }

  @override
  bool? get _available => available;

  @override
  set _available(bool? value) {
    _$_availableAtom.reportWrite(value, super._available, () {
      super._available = value;
    });
  }

  late final _$_loadFailedAtom = Atom(
    name: 'CastStoreBase._loadFailed',
    context: context,
  );

  bool get loadFailed {
    _$_loadFailedAtom.reportRead();
    return super._loadFailed;
  }

  @override
  bool get _loadFailed => loadFailed;

  @override
  set _loadFailed(bool value) {
    _$_loadFailedAtom.reportWrite(value, super._loadFailed, () {
      super._loadFailed = value;
    });
  }

  late final _$_castingAtom = Atom(
    name: 'CastStoreBase._casting',
    context: context,
  );

  CastMedia? get casting {
    _$_castingAtom.reportRead();
    return super._casting;
  }

  @override
  CastMedia? get _casting => casting;

  @override
  set _casting(CastMedia? value) {
    _$_castingAtom.reportWrite(value, super._casting, () {
      super._casting = value;
    });
  }

  late final _$beginDiscoveryAsyncAction = AsyncAction(
    'CastStoreBase.beginDiscovery',
    context: context,
  );

  @override
  Future<void> beginDiscovery() {
    return _$beginDiscoveryAsyncAction.run(() => super.beginDiscovery());
  }

  late final _$castToAsyncAction = AsyncAction(
    'CastStoreBase.castTo',
    context: context,
  );

  @override
  Future<bool> castTo(
    CastDevice device,
    CastMedia media, {
    VoidCallback? onLoaded,
  }) {
    return _$castToAsyncAction.run(
      () => super.castTo(device, media, onLoaded: onLoaded),
    );
  }

  late final _$stopCastingAsyncAction = AsyncAction(
    'CastStoreBase.stopCasting',
    context: context,
  );

  @override
  Future<void> stopCasting() {
    return _$stopCastingAsyncAction.run(() => super.stopCasting());
  }

  late final _$CastStoreBaseActionController = ActionController(
    name: 'CastStoreBase',
    context: context,
  );

  @override
  Future<bool> castHere(CastMedia media, {VoidCallback? onLoaded}) {
    final _$actionInfo = _$CastStoreBaseActionController.startAction(
      name: 'CastStoreBase.castHere',
    );
    try {
      return super.castHere(media, onLoaded: onLoaded);
    } finally {
      _$CastStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _setDevices(List<CastDevice> devices) {
    final _$actionInfo = _$CastStoreBaseActionController.startAction(
      name: 'CastStoreBase._setDevices',
    );
    try {
      return super._setDevices(devices);
    } finally {
      _$CastStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _setStatus(CastStatus status) {
    final _$actionInfo = _$CastStoreBaseActionController.startAction(
      name: 'CastStoreBase._setStatus',
    );
    try {
      return super._setStatus(status);
    } finally {
      _$CastStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
connection: ${connection},
connected: ${connected}
    ''';
  }
}
