// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_videos_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$SearchVideosStore on SearchVideosStoreBase, Store {
  late final _$_queryAtom = Atom(
    name: 'SearchVideosStoreBase._query',
    context: context,
  );

  String get query {
    _$_queryAtom.reportRead();
    return super._query;
  }

  @override
  String get _query => query;

  @override
  set _query(String value) {
    _$_queryAtom.reportWrite(value, super._query, () {
      super._query = value;
    });
  }

  late final _$_videosAtom = Atom(
    name: 'SearchVideosStoreBase._videos',
    context: context,
  );

  ObservableList<Vod> get videos {
    _$_videosAtom.reportRead();
    return super._videos;
  }

  @override
  ObservableList<Vod> get _videos => videos;

  @override
  set _videos(ObservableList<Vod> value) {
    _$_videosAtom.reportWrite(value, super._videos, () {
      super._videos = value;
    });
  }

  late final _$_loadingAtom = Atom(
    name: 'SearchVideosStoreBase._loading',
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
    name: 'SearchVideosStoreBase._loadingMore',
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
    name: 'SearchVideosStoreBase._hasMore',
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
    name: 'SearchVideosStoreBase._error',
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

  late final _$searchAsyncAction = AsyncAction(
    'SearchVideosStoreBase.search',
    context: context,
  );

  @override
  Future<void> search(String query) {
    return _$searchAsyncAction.run(() => super.search(query));
  }

  late final _$loadMoreAsyncAction = AsyncAction(
    'SearchVideosStoreBase.loadMore',
    context: context,
  );

  @override
  Future<void> loadMore() {
    return _$loadMoreAsyncAction.run(() => super.loadMore());
  }

  late final _$SearchVideosStoreBaseActionController = ActionController(
    name: 'SearchVideosStoreBase',
    context: context,
  );

  @override
  Future<void> retry() {
    final _$actionInfo = _$SearchVideosStoreBaseActionController.startAction(
      name: 'SearchVideosStoreBase.retry',
    );
    try {
      return super.retry();
    } finally {
      _$SearchVideosStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
