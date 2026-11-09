// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_center_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$NotificationCenterStore on NotificationCenterStoreBase, Store {
  Computed<int>? _$unreadCountComputed;

  @override
  int get unreadCount => (_$unreadCountComputed ??= Computed<int>(
    () => super.unreadCount,
    name: 'NotificationCenterStoreBase.unreadCount',
  )).value;
  Computed<bool>? _$hasMoreComputed;

  @override
  bool get hasMore => (_$hasMoreComputed ??= Computed<bool>(
    () => super.hasMore,
    name: 'NotificationCenterStoreBase.hasMore',
  )).value;

  late final _$_loadingAtom = Atom(
    name: 'NotificationCenterStoreBase._loading',
    context: context,
  );

  bool get loading {
    _$_loadingAtom.reportRead();
    return super._loading;
  }

  @override
  bool get _loading => loading;

  @override
  set _loading(bool value) {
    _$_loadingAtom.reportWrite(value, super._loading, () {
      super._loading = value;
    });
  }

  late final _$_failedAtom = Atom(
    name: 'NotificationCenterStoreBase._failed',
    context: context,
  );

  bool get failed {
    _$_failedAtom.reportRead();
    return super._failed;
  }

  @override
  bool get _failed => failed;

  @override
  set _failed(bool value) {
    _$_failedAtom.reportWrite(value, super._failed, () {
      super._failed = value;
    });
  }

  late final _$_markingAtom = Atom(
    name: 'NotificationCenterStoreBase._marking',
    context: context,
  );

  bool get marking {
    _$_markingAtom.reportRead();
    return super._marking;
  }

  @override
  bool get _marking => marking;

  @override
  set _marking(bool value) {
    _$_markingAtom.reportWrite(value, super._marking, () {
      super._marking = value;
    });
  }

  late final _$_cursorAtom = Atom(
    name: 'NotificationCenterStoreBase._cursor',
    context: context,
  );

  String? get cursor {
    _$_cursorAtom.reportRead();
    return super._cursor;
  }

  @override
  String? get _cursor => cursor;

  @override
  set _cursor(String? value) {
    _$_cursorAtom.reportWrite(value, super._cursor, () {
      super._cursor = value;
    });
  }

  late final _$refreshAsyncAction = AsyncAction(
    'NotificationCenterStoreBase.refresh',
    context: context,
  );

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$loadMoreAsyncAction = AsyncAction(
    'NotificationCenterStoreBase.loadMore',
    context: context,
  );

  @override
  Future<void> loadMore() {
    return _$loadMoreAsyncAction.run(() => super.loadMore());
  }

  late final _$sendReadAsyncAction = AsyncAction(
    'NotificationCenterStoreBase.sendRead',
    context: context,
  );

  @override
  Future<ViewerActionOutcome> sendRead(List<String> ids) {
    return _$sendReadAsyncAction.run(() => super.sendRead(ids));
  }

  late final _$NotificationCenterStoreBaseActionController = ActionController(
    name: 'NotificationCenterStoreBase',
    context: context,
  );

  @override
  List<String> markAllReadLocally() {
    final _$actionInfo = _$NotificationCenterStoreBaseActionController
        .startAction(name: 'NotificationCenterStoreBase.markAllReadLocally');
    try {
      return super.markAllReadLocally();
    } finally {
      _$NotificationCenterStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void restoreUnread(List<String> ids) {
    final _$actionInfo = _$NotificationCenterStoreBaseActionController
        .startAction(name: 'NotificationCenterStoreBase.restoreUnread');
    try {
      return super.restoreUnread(ids);
    } finally {
      _$NotificationCenterStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
unreadCount: ${unreadCount},
hasMore: ${hasMore}
    ''';
  }
}
