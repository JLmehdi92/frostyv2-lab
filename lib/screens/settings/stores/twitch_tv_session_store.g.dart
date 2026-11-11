// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'twitch_tv_session_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$TwitchTvSessionStore on TwitchTvSessionBase, Store {
  late final _$_sessionAtom = Atom(
    name: 'TwitchTvSessionBase._session',
    context: context,
  );

  TwitchTvSession? get session {
    _$_sessionAtom.reportRead();
    return super._session;
  }

  @override
  TwitchTvSession? get _session => session;

  @override
  set _session(TwitchTvSession? value) {
    _$_sessionAtom.reportWrite(value, super._session, () {
      super._session = value;
    });
  }

  late final _$_statusAtom = Atom(
    name: 'TwitchTvSessionBase._status',
    context: context,
  );

  TwitchTvSessionStatus get status {
    _$_statusAtom.reportRead();
    return super._status;
  }

  @override
  TwitchTvSessionStatus get _status => status;

  @override
  set _status(TwitchTvSessionStatus value) {
    _$_statusAtom.reportWrite(value, super._status, () {
      super._status = value;
    });
  }

  late final _$attachAsyncAction = AsyncAction(
    'TwitchTvSessionBase.attach',
    context: context,
  );

  @override
  Future<void> attach(String accountId) {
    return _$attachAsyncAction.run(() => super.attach(accountId));
  }

  late final _$_adoptAsyncAction = AsyncAction(
    'TwitchTvSessionBase._adopt',
    context: context,
  );

  @override
  Future<void> _adopt(TwitchTvSession stored, int generation) {
    return _$_adoptAsyncAction.run(() => super._adopt(stored, generation));
  }

  late final _$forgetAsyncAction = AsyncAction(
    'TwitchTvSessionBase.forget',
    context: context,
  );

  @override
  Future<void> forget() {
    return _$forgetAsyncAction.run(() => super.forget());
  }

  late final _$endAccountSessionAsyncAction = AsyncAction(
    'TwitchTvSessionBase.endAccountSession',
    context: context,
  );

  @override
  Future<void> endAccountSession() {
    return _$endAccountSessionAsyncAction.run(() => super.endAccountSession());
  }

  late final _$TwitchTvSessionBaseActionController = ActionController(
    name: 'TwitchTvSessionBase',
    context: context,
  );

  @override
  void markRejected() {
    final _$actionInfo = _$TwitchTvSessionBaseActionController.startAction(
      name: 'TwitchTvSessionBase.markRejected',
    );
    try {
      return super.markRejected();
    } finally {
      _$TwitchTvSessionBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
