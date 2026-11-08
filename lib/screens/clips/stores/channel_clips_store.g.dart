// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel_clips_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ChannelClipsStore on ChannelClipsStoreBase, Store {
  Computed<bool>? _$isFilteredComputed;

  @override
  bool get isFiltered => (_$isFilteredComputed ??= Computed<bool>(
    () => super.isFiltered,
    name: 'ChannelClipsStoreBase.isFiltered',
  )).value;
  Computed<List<ClipSort>>? _$sortsComputed;

  @override
  List<ClipSort> get sorts => (_$sortsComputed ??= Computed<List<ClipSort>>(
    () => super.sorts,
    name: 'ChannelClipsStoreBase.sorts',
  )).value;

  late final _$_rangeAtom = Atom(
    name: 'ChannelClipsStoreBase._range',
    context: context,
  );

  ({DateTime end, DateTime start})? get range {
    _$_rangeAtom.reportRead();
    return super._range;
  }

  @override
  ({DateTime end, DateTime start})? get _range => range;

  @override
  set _range(({DateTime end, DateTime start})? value) {
    _$_rangeAtom.reportWrite(value, super._range, () {
      super._range = value;
    });
  }

  late final _$_periodAtom = Atom(
    name: 'ChannelClipsStoreBase._period',
    context: context,
  );

  ClipPeriod get period {
    _$_periodAtom.reportRead();
    return super._period;
  }

  @override
  ClipPeriod get _period => period;

  @override
  set _period(ClipPeriod value) {
    _$_periodAtom.reportWrite(value, super._period, () {
      super._period = value;
    });
  }

  late final _$_sortAtom = Atom(
    name: 'ChannelClipsStoreBase._sort',
    context: context,
  );

  ClipSort get sort {
    _$_sortAtom.reportRead();
    return super._sort;
  }

  @override
  ClipSort get _sort => sort;

  @override
  set _sort(ClipSort value) {
    _$_sortAtom.reportWrite(value, super._sort, () {
      super._sort = value;
    });
  }

  late final _$_clipsAtom = Atom(
    name: 'ChannelClipsStoreBase._clips',
    context: context,
  );

  List<Clip> get clips {
    _$_clipsAtom.reportRead();
    return super._clips;
  }

  @override
  List<Clip> get _clips => clips;

  @override
  set _clips(List<Clip> value) {
    _$_clipsAtom.reportWrite(value, super._clips, () {
      super._clips = value;
    });
  }

  late final _$_isLoadingAtom = Atom(
    name: 'ChannelClipsStoreBase._isLoading',
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
    name: 'ChannelClipsStoreBase._loaded',
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
    name: 'ChannelClipsStoreBase._error',
    context: context,
  );

  ChannelClipsProblem? get error {
    _$_errorAtom.reportRead();
    return super._error;
  }

  @override
  ChannelClipsProblem? get _error => error;

  @override
  set _error(ChannelClipsProblem? value) {
    _$_errorAtom.reportWrite(value, super._error, () {
      super._error = value;
    });
  }

  late final _$_hasMoreAtom = Atom(
    name: 'ChannelClipsStoreBase._hasMore',
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

  late final _$ChannelClipsStoreBaseActionController = ActionController(
    name: 'ChannelClipsStoreBase',
    context: context,
  );

  @override
  void _show(ClipPage page) {
    final _$actionInfo = _$ChannelClipsStoreBaseActionController.startAction(
      name: 'ChannelClipsStoreBase._show',
    );
    try {
      return super._show(page);
    } finally {
      _$ChannelClipsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isFiltered: ${isFiltered},
sorts: ${sorts}
    ''';
  }
}
