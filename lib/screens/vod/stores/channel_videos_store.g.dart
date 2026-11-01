// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel_videos_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ChannelVideosStore on ChannelVideosStoreBase, Store {
  late final _$_videosAtom = Atom(
    name: 'ChannelVideosStoreBase._videos',
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

  late final _$_isLoadingAtom = Atom(
    name: 'ChannelVideosStoreBase._isLoading',
    context: context,
  );

  bool get isLoading {
    _$_isLoadingAtom.reportRead();
    return super._isLoading;
  }

  @override
  bool get _isLoading => isLoading;

  @override
  set _isLoading(bool value) {
    _$_isLoadingAtom.reportWrite(value, super._isLoading, () {
      super._isLoading = value;
    });
  }

  late final _$_loadedAtom = Atom(
    name: 'ChannelVideosStoreBase._loaded',
    context: context,
  );

  bool get loaded {
    _$_loadedAtom.reportRead();
    return super._loaded;
  }

  @override
  bool get _loaded => loaded;

  @override
  set _loaded(bool value) {
    _$_loadedAtom.reportWrite(value, super._loaded, () {
      super._loaded = value;
    });
  }

  late final _$_errorAtom = Atom(
    name: 'ChannelVideosStoreBase._error',
    context: context,
  );

  ChannelVideosProblem? get error {
    _$_errorAtom.reportRead();
    return super._error;
  }

  @override
  ChannelVideosProblem? get _error => error;

  @override
  set _error(ChannelVideosProblem? value) {
    _$_errorAtom.reportWrite(value, super._error, () {
      super._error = value;
    });
  }

  late final _$_hasMoreAtom = Atom(
    name: 'ChannelVideosStoreBase._hasMore',
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

  late final _$_loadAsyncAction = AsyncAction(
    'ChannelVideosStoreBase._load',
    context: context,
  );

  @override
  Future<void> _load() {
    return _$_loadAsyncAction.run(() => super._load());
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
