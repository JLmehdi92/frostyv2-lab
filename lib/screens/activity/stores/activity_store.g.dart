// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ActivityStore on ActivityStoreBase, Store {
  Computed<int>? _$unreadCountComputed;

  @override
  int get unreadCount => (_$unreadCountComputed ??= Computed<int>(
    () => super.unreadCount,
    name: 'ActivityStoreBase.unreadCount',
  )).value;
  Computed<int>? _$newCountComputed;

  @override
  int get newCount => (_$newCountComputed ??= Computed<int>(
    () => super.newCount,
    name: 'ActivityStoreBase.newCount',
  )).value;

  late final _$_entriesAtom = Atom(
    name: 'ActivityStoreBase._entries',
    context: context,
  );

  ObservableList<ActivityEntry> get entries {
    _$_entriesAtom.reportRead();
    return super._entries;
  }

  @override
  ObservableList<ActivityEntry> get _entries => entries;

  @override
  set _entries(ObservableList<ActivityEntry> value) {
    _$_entriesAtom.reportWrite(value, super._entries, () {
      super._entries = value;
    });
  }

  late final _$_viewedAtAtom = Atom(
    name: 'ActivityStoreBase._viewedAt',
    context: context,
  );

  DateTime? get viewedAt {
    _$_viewedAtAtom.reportRead();
    return super._viewedAt;
  }

  @override
  DateTime? get _viewedAt => viewedAt;

  @override
  set _viewedAt(DateTime? value) {
    _$_viewedAtAtom.reportWrite(value, super._viewedAt, () {
      super._viewedAt = value;
    });
  }

  late final _$ActivityStoreBaseActionController = ActionController(
    name: 'ActivityStoreBase',
    context: context,
  );

  @override
  void _show(List<ActivityEntry> entries) {
    final _$actionInfo = _$ActivityStoreBaseActionController.startAction(
      name: 'ActivityStoreBase._show',
    );
    try {
      return super._show(entries);
    } finally {
      _$ActivityStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
unreadCount: ${unreadCount},
newCount: ${newCount}
    ''';
  }
}
