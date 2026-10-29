// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AuthStore on AuthBase, Store {
  Computed<Map<String, String>>? _$headersTwitchComputed;

  @override
  Map<String, String> get headersTwitch =>
      (_$headersTwitchComputed ??= Computed<Map<String, String>>(
        () => super.headersTwitch,
        name: 'AuthBase.headersTwitch',
      )).value;

  late final _$_tokenAtom = Atom(name: 'AuthBase._token', context: context);

  String? get token {
    _$_tokenAtom.reportRead();
    return super._token;
  }

  @override
  String? get _token => token;

  @override
  set _token(String? value) {
    _$_tokenAtom.reportWrite(value, super._token, () {
      super._token = value;
    });
  }

  late final _$_tokenClientIdAtom = Atom(
    name: 'AuthBase._tokenClientId',
    context: context,
  );

  String? get tokenClientId {
    _$_tokenClientIdAtom.reportRead();
    return super._tokenClientId;
  }

  @override
  String? get _tokenClientId => tokenClientId;

  @override
  set _tokenClientId(String? value) {
    _$_tokenClientIdAtom.reportWrite(value, super._tokenClientId, () {
      super._tokenClientId = value;
    });
  }

  late final _$_isLoggedInAtom = Atom(
    name: 'AuthBase._isLoggedIn',
    context: context,
  );

  bool get isLoggedIn {
    _$_isLoggedInAtom.reportRead();
    return super._isLoggedIn;
  }

  @override
  bool get _isLoggedIn => isLoggedIn;

  @override
  set _isLoggedIn(bool value) {
    _$_isLoggedInAtom.reportWrite(value, super._isLoggedIn, () {
      super._isLoggedIn = value;
    });
  }

  late final _$_twitchWebTokenAtom = Atom(
    name: 'AuthBase._twitchWebToken',
    context: context,
  );

  String? get twitchWebToken {
    _$_twitchWebTokenAtom.reportRead();
    return super._twitchWebToken;
  }

  @override
  String? get _twitchWebToken => twitchWebToken;

  @override
  set _twitchWebToken(String? value) {
    _$_twitchWebTokenAtom.reportWrite(value, super._twitchWebToken, () {
      super._twitchWebToken = value;
    });
  }

  late final _$_webSessionExpiredAtom = Atom(
    name: 'AuthBase._webSessionExpired',
    context: context,
  );

  bool get webSessionExpired {
    _$_webSessionExpiredAtom.reportRead();
    return super._webSessionExpired;
  }

  @override
  bool get _webSessionExpired => webSessionExpired;

  @override
  set _webSessionExpired(bool value) {
    _$_webSessionExpiredAtom.reportWrite(value, super._webSessionExpired, () {
      super._webSessionExpired = value;
    });
  }

  late final _$_errorAtom = Atom(name: 'AuthBase._error', context: context);

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

  late final _$_tokenNoticeAtom = Atom(
    name: 'AuthBase._tokenNotice',
    context: context,
  );

  String? get tokenNotice {
    _$_tokenNoticeAtom.reportRead();
    return super._tokenNotice;
  }

  @override
  String? get _tokenNotice => tokenNotice;

  @override
  set _tokenNotice(String? value) {
    _$_tokenNoticeAtom.reportWrite(value, super._tokenNotice, () {
      super._tokenNotice = value;
    });
  }

  late final _$harvestTwitchWebTokenAsyncAction = AsyncAction(
    'AuthBase.harvestTwitchWebToken',
    context: context,
  );

  @override
  Future<bool> harvestTwitchWebToken() {
    return _$harvestTwitchWebTokenAsyncAction.run(
      () => super.harvestTwitchWebToken(),
    );
  }

  late final _$renewTwitchWebTokenAsyncAction = AsyncAction(
    'AuthBase.renewTwitchWebToken',
    context: context,
  );

  @override
  Future<String?> renewTwitchWebToken() {
    return _$renewTwitchWebTokenAsyncAction.run(
      () => super.renewTwitchWebToken(),
    );
  }

  late final _$setTwitchWebTokenAsyncAction = AsyncAction(
    'AuthBase.setTwitchWebToken',
    context: context,
  );

  @override
  Future<void> setTwitchWebToken(String? token) {
    return _$setTwitchWebTokenAsyncAction.run(
      () => super.setTwitchWebToken(token),
    );
  }

  late final _$initAsyncAction = AsyncAction('AuthBase.init', context: context);

  @override
  Future<void> init() {
    return _$initAsyncAction.run(() => super.init());
  }

  late final _$loginAsyncAction = AsyncAction(
    'AuthBase.login',
    context: context,
  );

  @override
  Future<void> login({required String token, bool acceptAnyApp = false}) {
    return _$loginAsyncAction.run(
      () => super.login(token: token, acceptAnyApp: acceptAnyApp),
    );
  }

  late final _$logoutAsyncAction = AsyncAction(
    'AuthBase.logout',
    context: context,
  );

  @override
  Future<void> logout() {
    return _$logoutAsyncAction.run(() => super.logout());
  }

  late final _$AuthBaseActionController = ActionController(
    name: 'AuthBase',
    context: context,
  );

  @override
  void clearTokenNotice() {
    final _$actionInfo = _$AuthBaseActionController.startAction(
      name: 'AuthBase.clearTokenNotice',
    );
    try {
      return super.clearTokenNotice();
    } finally {
      _$AuthBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  Future<void> _logoutFromReconnect(
    int generation,
    int epoch,
    String? checked,
  ) {
    final _$actionInfo = _$AuthBaseActionController.startAction(
      name: 'AuthBase._logoutFromReconnect',
    );
    try {
      return super._logoutFromReconnect(generation, epoch, checked);
    } finally {
      _$AuthBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
headersTwitch: ${headersTwitch}
    ''';
  }
}
