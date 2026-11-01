// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'followed_videos_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$FollowedVideosStore on FollowedVideosStoreBase, Store {
  late final _$_videosAtom = Atom(
    name: 'FollowedVideosStoreBase._videos',
    context: context,
  );

  List<Vod> get videos {
    _$_videosAtom.reportRead();
    return super._videos;
  }

  @override
  List<Vod> get _videos => videos;

  @override
  set _videos(List<Vod> value) {
    _$_videosAtom.reportWrite(value, super._videos, () {
      super._videos = value;
    });
  }

  late final _$_loadingAtom = Atom(
    name: 'FollowedVideosStoreBase._loading',
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

  late final _$_errorAtom = Atom(
    name: 'FollowedVideosStoreBase._error',
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

  late final _$loadAsyncAction = AsyncAction(
    'FollowedVideosStoreBase.load',
    context: context,
  );

  @override
  Future<void> load() {
    return _$loadAsyncAction.run(() => super.load());
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
