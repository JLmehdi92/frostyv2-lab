// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_session_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$WebSessionStore on WebSessionStoreBase, Store {
  Computed<bool>? _$isConnectedComputed;

  @override
  bool get isConnected => (_$isConnectedComputed ??= Computed<bool>(
    () => super.isConnected,
    name: 'WebSessionStoreBase.isConnected',
  )).value;

  late final _$_loginAtom = Atom(
    name: 'WebSessionStoreBase._login',
    context: context,
  );

  String? get login {
    _$_loginAtom.reportRead();
    return super._login;
  }

  @override
  String? get _login => login;

  @override
  set _login(String? value) {
    _$_loginAtom.reportWrite(value, super._login, () {
      super._login = value;
    });
  }

  late final _$_errorAtom = Atom(
    name: 'WebSessionStoreBase._error',
    context: context,
  );

  String? get error {
    _$_errorAtom.reportRead();
    return super._error;
  }

  @override
  String? get _error => error;

  @override
  set _error(String? value) {
    _$_errorAtom.reportWrite(value, super._error, () {
      super._error = value;
    });
  }

  @override
  String toString() {
    return '''
isConnected: ${isConnected}
    ''';
  }
}
