// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clips_feed_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ClipsFeedStore on ClipsFeedStoreBase, Store {
  late final _$_clipsAtom = Atom(
    name: 'ClipsFeedStoreBase._clips',
    context: context,
  );

  ObservableList<Clip> get clips {
    _$_clipsAtom.reportRead();
    return super._clips;
  }

  @override
  ObservableList<Clip> get _clips => clips;

  @override
  set _clips(ObservableList<Clip> value) {
    _$_clipsAtom.reportWrite(value, super._clips, () {
      super._clips = value;
    });
  }

  late final _$_loadingAtom = Atom(
    name: 'ClipsFeedStoreBase._loading',
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

  late final _$_loadingMoreAtom = Atom(
    name: 'ClipsFeedStoreBase._loadingMore',
    context: context,
  );

  bool get loadingMore {
    _$_loadingMoreAtom.reportRead();
    return super._loadingMore;
  }

  @override
  bool get _loadingMore => loadingMore;

  @override
  set _loadingMore(bool value) {
    _$_loadingMoreAtom.reportWrite(value, super._loadingMore, () {
      super._loadingMore = value;
    });
  }

  late final _$_hasMoreAtom = Atom(
    name: 'ClipsFeedStoreBase._hasMore',
    context: context,
  );

  bool get hasMore {
    _$_hasMoreAtom.reportRead();
    return super._hasMore;
  }

  @override
  bool get _hasMore => hasMore;

  @override
  set _hasMore(bool value) {
    _$_hasMoreAtom.reportWrite(value, super._hasMore, () {
      super._hasMore = value;
    });
  }

  late final _$_errorAtom = Atom(
    name: 'ClipsFeedStoreBase._error',
    context: context,
  );

  Object? get error {
    _$_errorAtom.reportRead();
    return super._error;
  }

  @override
  Object? get _error => error;

  @override
  set _error(Object? value) {
    _$_errorAtom.reportWrite(value, super._error, () {
      super._error = value;
    });
  }

  late final _$_endedOnErrorAtom = Atom(
    name: 'ClipsFeedStoreBase._endedOnError',
    context: context,
  );

  bool get endedOnError {
    _$_endedOnErrorAtom.reportRead();
    return super._endedOnError;
  }

  @override
  bool get _endedOnError => endedOnError;

  @override
  set _endedOnError(bool value) {
    _$_endedOnErrorAtom.reportWrite(value, super._endedOnError, () {
      super._endedOnError = value;
    });
  }

  late final _$loadAsyncAction = AsyncAction(
    'ClipsFeedStoreBase.load',
    context: context,
  );

  @override
  Future<void> load() {
    return _$loadAsyncAction.run(() => super.load());
  }

  late final _$loadMoreAsyncAction = AsyncAction(
    'ClipsFeedStoreBase.loadMore',
    context: context,
  );

  @override
  Future<void> loadMore() {
    return _$loadMoreAsyncAction.run(() => super.loadMore());
  }

  late final _$retryMoreAsyncAction = AsyncAction(
    'ClipsFeedStoreBase.retryMore',
    context: context,
  );

  @override
  Future<void> retryMore() {
    return _$retryMoreAsyncAction.run(() => super.retryMore());
  }

  late final _$ClipsFeedStoreBaseActionController = ActionController(
    name: 'ClipsFeedStoreBase',
    context: context,
  );

  @override
  void clear() {
    final _$actionInfo = _$ClipsFeedStoreBaseActionController.startAction(
      name: 'ClipsFeedStoreBase.clear',
    );
    try {
      return super.clear();
    } finally {
      _$ClipsFeedStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
