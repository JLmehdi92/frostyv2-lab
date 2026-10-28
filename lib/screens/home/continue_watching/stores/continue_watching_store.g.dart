// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'continue_watching_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ContinueWatchingStore on ContinueWatchingStoreBase, Store {
  late final _$_itemsAtom = Atom(
    name: 'ContinueWatchingStoreBase._items',
    context: context,
  );

  List<ContinueWatchingItem> get items {
    _$_itemsAtom.reportRead();
    return super._items;
  }

  @override
  List<ContinueWatchingItem> get _items => items;

  @override
  set _items(List<ContinueWatchingItem> value) {
    _$_itemsAtom.reportWrite(value, super._items, () {
      super._items = value;
    });
  }

  late final _$_loadingAtom = Atom(
    name: 'ContinueWatchingStoreBase._loading',
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

  @override
  String toString() {
    return '''

    ''';
  }
}
