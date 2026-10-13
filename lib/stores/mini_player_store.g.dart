// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mini_player_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$MiniPlayerStore on MiniPlayerStoreBase, Store {
  late final _$_visibleAtom = Atom(
    name: 'MiniPlayerStoreBase._visible',
    context: context,
  );

  bool get visible {
    _$_visibleAtom.reportRead();
    return super._visible;
  }

  @override
  bool get _visible => visible;

  @override
  set _visible(bool value) {
    _$_visibleAtom.reportWrite(value, super._visible, () {
      super._visible = value;
    });
  }

  late final _$_userLoginAtom = Atom(
    name: 'MiniPlayerStoreBase._userLogin',
    context: context,
  );

  String? get userLogin {
    _$_userLoginAtom.reportRead();
    return super._userLogin;
  }

  @override
  String? get _userLogin => userLogin;

  @override
  set _userLogin(String? value) {
    _$_userLoginAtom.reportWrite(value, super._userLogin, () {
      super._userLogin = value;
    });
  }

  late final _$_userIdAtom = Atom(
    name: 'MiniPlayerStoreBase._userId',
    context: context,
  );

  String? get userId {
    _$_userIdAtom.reportRead();
    return super._userId;
  }

  @override
  String? get _userId => userId;

  @override
  set _userId(String? value) {
    _$_userIdAtom.reportWrite(value, super._userId, () {
      super._userId = value;
    });
  }

  late final _$_displayNameAtom = Atom(
    name: 'MiniPlayerStoreBase._displayName',
    context: context,
  );

  String? get displayName {
    _$_displayNameAtom.reportRead();
    return super._displayName;
  }

  @override
  String? get _displayName => displayName;

  @override
  set _displayName(String? value) {
    _$_displayNameAtom.reportWrite(value, super._displayName, () {
      super._displayName = value;
    });
  }

  late final _$_playerAtom = Atom(
    name: 'MiniPlayerStoreBase._player',
    context: context,
  );

  IvsVideoStore? get player {
    _$_playerAtom.reportRead();
    return super._player;
  }

  @override
  IvsVideoStore? get _player => player;

  @override
  set _player(IvsVideoStore? value) {
    _$_playerAtom.reportWrite(value, super._player, () {
      super._player = value;
    });
  }

  late final _$_chatTabsStoreAtom = Atom(
    name: 'MiniPlayerStoreBase._chatTabsStore',
    context: context,
  );

  ChatTabsStore? get chatTabsStore {
    _$_chatTabsStoreAtom.reportRead();
    return super._chatTabsStore;
  }

  @override
  ChatTabsStore? get _chatTabsStore => chatTabsStore;

  @override
  set _chatTabsStore(ChatTabsStore? value) {
    _$_chatTabsStoreAtom.reportWrite(value, super._chatTabsStore, () {
      super._chatTabsStore = value;
    });
  }

  late final _$MiniPlayerStoreBaseActionController = ActionController(
    name: 'MiniPlayerStoreBase',
    context: context,
  );

  @override
  void adopt({
    required IvsVideoStore player,
    required ChatTabsStore chatTabsStore,
    required String userLogin,
    required String userId,
    required String displayName,
  }) {
    final _$actionInfo = _$MiniPlayerStoreBaseActionController.startAction(
      name: 'MiniPlayerStoreBase.adopt',
    );
    try {
      return super.adopt(
        player: player,
        chatTabsStore: chatTabsStore,
        userLogin: userLogin,
        userId: userId,
        displayName: displayName,
      );
    } finally {
      _$MiniPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  ({ChatTabsStore? chat, IvsVideoStore? player}) release() {
    final _$actionInfo = _$MiniPlayerStoreBaseActionController.startAction(
      name: 'MiniPlayerStoreBase.release',
    );
    try {
      return super.release();
    } finally {
      _$MiniPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void close() {
    final _$actionInfo = _$MiniPlayerStoreBaseActionController.startAction(
      name: 'MiniPlayerStoreBase.close',
    );
    try {
      return super.close();
    } finally {
      _$MiniPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
