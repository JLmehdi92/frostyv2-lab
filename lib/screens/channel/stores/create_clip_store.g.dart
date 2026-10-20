// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_clip_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CreateClipStore on CreateClipStoreBase, Store {
  late final _$_statusAtom = Atom(
    name: 'CreateClipStoreBase._status',
    context: context,
  );

  CreateClipStatus get status {
    _$_statusAtom.reportRead();
    return super._status;
  }

  @override
  CreateClipStatus get _status => status;

  @override
  set _status(CreateClipStatus value) {
    _$_statusAtom.reportWrite(value, super._status, () {
      super._status = value;
    });
  }

  late final _$_failureAtom = Atom(
    name: 'CreateClipStoreBase._failure',
    context: context,
  );

  ClipCreateFailure? get failure {
    _$_failureAtom.reportRead();
    return super._failure;
  }

  @override
  ClipCreateFailure? get _failure => failure;

  @override
  set _failure(ClipCreateFailure? value) {
    _$_failureAtom.reportWrite(value, super._failure, () {
      super._failure = value;
    });
  }

  late final _$_creationAtom = Atom(
    name: 'CreateClipStoreBase._creation',
    context: context,
  );

  ClipCreation? get creation {
    _$_creationAtom.reportRead();
    return super._creation;
  }

  @override
  ClipCreation? get _creation => creation;

  @override
  set _creation(ClipCreation? value) {
    _$_creationAtom.reportWrite(value, super._creation, () {
      super._creation = value;
    });
  }

  late final _$_thumbnailUrlAtom = Atom(
    name: 'CreateClipStoreBase._thumbnailUrl',
    context: context,
  );

  String? get thumbnailUrl {
    _$_thumbnailUrlAtom.reportRead();
    return super._thumbnailUrl;
  }

  @override
  String? get _thumbnailUrl => thumbnailUrl;

  @override
  set _thumbnailUrl(String? value) {
    _$_thumbnailUrlAtom.reportWrite(value, super._thumbnailUrl, () {
      super._thumbnailUrl = value;
    });
  }

  late final _$startAsyncAction = AsyncAction(
    'CreateClipStoreBase.start',
    context: context,
  );

  @override
  Future<void> start() {
    return _$startAsyncAction.run(() => super.start());
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
