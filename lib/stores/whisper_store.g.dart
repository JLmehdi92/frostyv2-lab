// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'whisper_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$WhisperThread on WhisperThreadBase, Store {
  late final _$unreadAtom = Atom(
    name: 'WhisperThreadBase.unread',
    context: context,
  );

  @override
  int get unread {
    _$unreadAtom.reportRead();
    return super.unread;
  }

  @override
  set unread(int value) {
    _$unreadAtom.reportWrite(value, super.unread, () {
      super.unread = value;
    });
  }

  late final _$lastAtAtom = Atom(
    name: 'WhisperThreadBase.lastAt',
    context: context,
  );

  @override
  DateTime? get lastAt {
    _$lastAtAtom.reportRead();
    return super.lastAt;
  }

  @override
  set lastAt(DateTime? value) {
    _$lastAtAtom.reportWrite(value, super.lastAt, () {
      super.lastAt = value;
    });
  }

  late final _$WhisperThreadBaseActionController = ActionController(
    name: 'WhisperThreadBase',
    context: context,
  );

  @override
  void _add(Whisper whisper) {
    final _$actionInfo = _$WhisperThreadBaseActionController.startAction(
      name: 'WhisperThreadBase._add',
    );
    try {
      return super._add(whisper);
    } finally {
      _$WhisperThreadBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
unread: ${unread},
lastAt: ${lastAt}
    ''';
  }
}

mixin _$WhisperStore on WhisperStoreBase, Store {
  Computed<String?>? _$openUserIdComputed;

  @override
  String? get openUserId => (_$openUserIdComputed ??= Computed<String?>(
    () => super.openUserId,
    name: 'WhisperStoreBase.openUserId',
  )).value;
  Computed<List<WhisperThread>>? _$threadsComputed;

  @override
  List<WhisperThread> get threads =>
      (_$threadsComputed ??= Computed<List<WhisperThread>>(
        () => super.threads,
        name: 'WhisperStoreBase.threads',
      )).value;
  Computed<int>? _$unreadCountComputed;

  @override
  int get unreadCount => (_$unreadCountComputed ??= Computed<int>(
    () => super.unreadCount,
    name: 'WhisperStoreBase.unreadCount',
  )).value;

  late final _$_meAtom = Atom(name: 'WhisperStoreBase._me', context: context);

  String? get me {
    _$_meAtom.reportRead();
    return super._me;
  }

  @override
  String? get _me => me;

  @override
  set _me(String? value) {
    _$_meAtom.reportWrite(value, super._me, () {
      super._me = value;
    });
  }

  late final _$_statusAtom = Atom(
    name: 'WhisperStoreBase._status',
    context: context,
  );

  WhisperStatus get status {
    _$_statusAtom.reportRead();
    return super._status;
  }

  @override
  WhisperStatus get _status => status;

  @override
  set _status(WhisperStatus value) {
    _$_statusAtom.reportWrite(value, super._status, () {
      super._status = value;
    });
  }

  late final _$WhisperStoreBaseActionController = ActionController(
    name: 'WhisperStoreBase',
    context: context,
  );

  @override
  void _follow(String? me) {
    final _$actionInfo = _$WhisperStoreBaseActionController.startAction(
      name: 'WhisperStoreBase._follow',
    );
    try {
      return super._follow(me);
    } finally {
      _$WhisperStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onEvent(EventSubTopicEvent event) {
    final _$actionInfo = _$WhisperStoreBaseActionController.startAction(
      name: 'WhisperStoreBase._onEvent',
    );
    try {
      return super._onEvent(event);
    } finally {
      _$WhisperStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  WhisperThread thread({
    required String userId,
    required String login,
    required String displayName,
  }) {
    final _$actionInfo = _$WhisperStoreBaseActionController.startAction(
      name: 'WhisperStoreBase.thread',
    );
    try {
      return super.thread(
        userId: userId,
        login: login,
        displayName: displayName,
      );
    } finally {
      _$WhisperStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  WhisperThread open({
    required String userId,
    required String login,
    required String displayName,
  }) {
    final _$actionInfo = _$WhisperStoreBaseActionController.startAction(
      name: 'WhisperStoreBase.open',
    );
    try {
      return super.open(userId: userId, login: login, displayName: displayName);
    } finally {
      _$WhisperStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void close(String userId) {
    final _$actionInfo = _$WhisperStoreBaseActionController.startAction(
      name: 'WhisperStoreBase.close',
    );
    try {
      return super.close(userId);
    } finally {
      _$WhisperStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
openUserId: ${openUserId},
threads: ${threads},
unreadCount: ${unreadCount}
    ''';
  }
}
