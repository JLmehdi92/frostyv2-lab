// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mod_tools_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ModToolsStore on ModToolsBase, Store {
  Computed<bool>? _$isBroadcasterComputed;

  @override
  bool get isBroadcaster => (_$isBroadcasterComputed ??= Computed<bool>(
    () => super.isBroadcaster,
    name: 'ModToolsBase.isBroadcaster',
  )).value;
  Computed<int>? _$pendingHeldCountComputed;

  @override
  int get pendingHeldCount => (_$pendingHeldCountComputed ??= Computed<int>(
    () => super.pendingHeldCount,
    name: 'ModToolsBase.pendingHeldCount',
  )).value;

  late final _$_moderatorIdAtom = Atom(
    name: 'ModToolsBase._moderatorId',
    context: context,
  );

  String? get moderatorId {
    _$_moderatorIdAtom.reportRead();
    return super._moderatorId;
  }

  @override
  String? get _moderatorId => moderatorId;

  @override
  set _moderatorId(String? value) {
    _$_moderatorIdAtom.reportWrite(value, super._moderatorId, () {
      super._moderatorId = value;
    });
  }

  late final _$_scopesAtom = Atom(
    name: 'ModToolsBase._scopes',
    context: context,
  );

  Set<String>? get scopes {
    _$_scopesAtom.reportRead();
    return super._scopes;
  }

  @override
  Set<String>? get _scopes => scopes;

  @override
  set _scopes(Set<String>? value) {
    _$_scopesAtom.reportWrite(value, super._scopes, () {
      super._scopes = value;
    });
  }

  late final _$_shieldActiveAtom = Atom(
    name: 'ModToolsBase._shieldActive',
    context: context,
  );

  bool get shieldActive {
    _$_shieldActiveAtom.reportRead();
    return super._shieldActive;
  }

  @override
  bool get _shieldActive => shieldActive;

  @override
  set _shieldActive(bool value) {
    _$_shieldActiveAtom.reportWrite(value, super._shieldActive, () {
      super._shieldActive = value;
    });
  }

  late final _$ModToolsBaseActionController = ActionController(
    name: 'ModToolsBase',
    context: context,
  );

  @override
  void stop() {
    final _$actionInfo = _$ModToolsBaseActionController.startAction(
      name: 'ModToolsBase.stop',
    );
    try {
      return super.stop();
    } finally {
      _$ModToolsBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onModerate(Map<String, Object?> event) {
    final _$actionInfo = _$ModToolsBaseActionController.startAction(
      name: 'ModToolsBase._onModerate',
    );
    try {
      return super._onModerate(event);
    } finally {
      _$ModToolsBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void noteClearChat(String? userId, int? banSeconds) {
    final _$actionInfo = _$ModToolsBaseActionController.startAction(
      name: 'ModToolsBase.noteClearChat',
    );
    try {
      return super.noteClearChat(userId, banSeconds);
    } finally {
      _$ModToolsBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void noteShieldMode(bool active) {
    final _$actionInfo = _$ModToolsBaseActionController.startAction(
      name: 'ModToolsBase.noteShieldMode',
    );
    try {
      return super.noteShieldMode(active);
    } finally {
      _$ModToolsBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void noteSuspicion(String userId, SuspiciousStatus? status) {
    final _$actionInfo = _$ModToolsBaseActionController.startAction(
      name: 'ModToolsBase.noteSuspicion',
    );
    try {
      return super.noteSuspicion(userId, status);
    } finally {
      _$ModToolsBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onShield(Map<String, Object?> event, {required bool active}) {
    final _$actionInfo = _$ModToolsBaseActionController.startAction(
      name: 'ModToolsBase._onShield',
    );
    try {
      return super._onShield(event, active: active);
    } finally {
      _$ModToolsBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onHeld(Map<String, Object?> event) {
    final _$actionInfo = _$ModToolsBaseActionController.startAction(
      name: 'ModToolsBase._onHeld',
    );
    try {
      return super._onHeld(event);
    } finally {
      _$ModToolsBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onHeldUpdate(Map<String, Object?> event) {
    final _$actionInfo = _$ModToolsBaseActionController.startAction(
      name: 'ModToolsBase._onHeldUpdate',
    );
    try {
      return super._onHeldUpdate(event);
    } finally {
      _$ModToolsBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearResolvedHeld() {
    final _$actionInfo = _$ModToolsBaseActionController.startAction(
      name: 'ModToolsBase.clearResolvedHeld',
    );
    try {
      return super.clearResolvedHeld();
    } finally {
      _$ModToolsBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isBroadcaster: ${isBroadcaster},
pendingHeldCount: ${pendingHeldCount}
    ''';
  }
}
