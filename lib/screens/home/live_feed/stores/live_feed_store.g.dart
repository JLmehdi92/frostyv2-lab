// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_feed_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$LiveFeedStore on LiveFeedStoreBase, Store {
  Computed<ListStore>? _$listComputed;

  @override
  ListStore get list => (_$listComputed ??= Computed<ListStore>(
    () => super.list,
    name: 'LiveFeedStoreBase.list',
  )).value;
  Computed<List<StreamTwitch>>? _$streamsComputed;

  @override
  List<StreamTwitch> get streams =>
      (_$streamsComputed ??= Computed<List<StreamTwitch>>(
        () => super.streams,
        name: 'LiveFeedStoreBase.streams',
      )).value;
  Computed<StreamTwitch?>? _$currentComputed;

  @override
  StreamTwitch? get current => (_$currentComputed ??= Computed<StreamTwitch?>(
    () => super.current,
    name: 'LiveFeedStoreBase.current',
  )).value;

  late final _$_categoryIdAtom = Atom(
    name: 'LiveFeedStoreBase._categoryId',
    context: context,
  );

  String? get categoryId {
    _$_categoryIdAtom.reportRead();
    return super._categoryId;
  }

  @override
  String? get _categoryId => categoryId;

  @override
  set _categoryId(String? value) {
    _$_categoryIdAtom.reportWrite(value, super._categoryId, () {
      super._categoryId = value;
    });
  }

  late final _$_chipsAtom = Atom(
    name: 'LiveFeedStoreBase._chips',
    context: context,
  );

  List<({String id, String name})> get chips {
    _$_chipsAtom.reportRead();
    return super._chips;
  }

  @override
  List<({String id, String name})> get _chips => chips;

  @override
  set _chips(List<({String id, String name})> value) {
    _$_chipsAtom.reportWrite(value, super._chips, () {
      super._chips = value;
    });
  }

  late final _$_indexAtom = Atom(
    name: 'LiveFeedStoreBase._index',
    context: context,
  );

  int get index {
    _$_indexAtom.reportRead();
    return super._index;
  }

  @override
  int get _index => index;

  @override
  set _index(int value) {
    _$_indexAtom.reportWrite(value, super._index, () {
      super._index = value;
    });
  }

  late final _$LiveFeedStoreBaseActionController = ActionController(
    name: 'LiveFeedStoreBase',
    context: context,
  );

  @override
  void selectCategory(String? categoryId) {
    final _$actionInfo = _$LiveFeedStoreBaseActionController.startAction(
      name: 'LiveFeedStoreBase.selectCategory',
    );
    try {
      return super.selectCategory(categoryId);
    } finally {
      _$LiveFeedStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setIndex(int index) {
    final _$actionInfo = _$LiveFeedStoreBaseActionController.startAction(
      name: 'LiveFeedStoreBase.setIndex',
    );
    try {
      return super.setIndex(index);
    } finally {
      _$LiveFeedStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
list: ${list},
streams: ${streams},
current: ${current}
    ''';
  }
}
