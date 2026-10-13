// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel_profile_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ChannelProfileStore on ChannelProfileStoreBase, Store {
  Computed<String?>? _$userIdComputed;

  @override
  String? get userId => (_$userIdComputed ??= Computed<String?>(
    () => super.userId,
    name: 'ChannelProfileStoreBase.userId',
  )).value;
  Computed<String?>? _$displayNameComputed;

  @override
  String? get displayName => (_$displayNameComputed ??= Computed<String?>(
    () => super.displayName,
    name: 'ChannelProfileStoreBase.displayName',
  )).value;

  late final _$_profileAtom = Atom(
    name: 'ChannelProfileStoreBase._profile',
    context: context,
  );

  ChannelProfile? get profile {
    _$_profileAtom.reportRead();
    return super._profile;
  }

  @override
  ChannelProfile? get _profile => profile;

  @override
  set _profile(ChannelProfile? value) {
    _$_profileAtom.reportWrite(value, super._profile, () {
      super._profile = value;
    });
  }

  late final _$_fallbackAtom = Atom(
    name: 'ChannelProfileStoreBase._fallback',
    context: context,
  );

  UserTwitch? get fallback {
    _$_fallbackAtom.reportRead();
    return super._fallback;
  }

  @override
  UserTwitch? get _fallback => fallback;

  @override
  set _fallback(UserTwitch? value) {
    _$_fallbackAtom.reportWrite(value, super._fallback, () {
      super._fallback = value;
    });
  }

  late final _$_isLoadingAtom = Atom(
    name: 'ChannelProfileStoreBase._isLoading',
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
    name: 'ChannelProfileStoreBase._loaded',
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

  late final _$_notFoundAtom = Atom(
    name: 'ChannelProfileStoreBase._notFound',
    context: context,
  );

  bool get notFound {
    _$_notFoundAtom.reportRead();
    return super._notFound;
  }

  @override
  bool get _notFound => notFound;

  @override
  set _notFound(bool value) {
    _$_notFoundAtom.reportWrite(value, super._notFound, () {
      super._notFound = value;
    });
  }

  late final _$_errorAtom = Atom(
    name: 'ChannelProfileStoreBase._error',
    context: context,
  );

  String? get error {
    _$_errorAtom.reportRead();
    return super._error;
  }

  @override
  String? get _error => error;

  @override
  set _error(String? value) {
    _$_errorAtom.reportWrite(value, super._error, () {
      super._error = value;
    });
  }

  late final _$_scheduleAtom = Atom(
    name: 'ChannelProfileStoreBase._schedule',
    context: context,
  );

  ChannelSchedule? get schedule {
    _$_scheduleAtom.reportRead();
    return super._schedule;
  }

  @override
  ChannelSchedule? get _schedule => schedule;

  @override
  set _schedule(ChannelSchedule? value) {
    _$_scheduleAtom.reportWrite(value, super._schedule, () {
      super._schedule = value;
    });
  }

  late final _$_scheduleLoadingAtom = Atom(
    name: 'ChannelProfileStoreBase._scheduleLoading',
    context: context,
  );

  bool get scheduleLoading {
    _$_scheduleLoadingAtom.reportRead();
    return super._scheduleLoading;
  }

  @override
  bool get _scheduleLoading => scheduleLoading;

  @override
  set _scheduleLoading(bool value) {
    _$_scheduleLoadingAtom.reportWrite(value, super._scheduleLoading, () {
      super._scheduleLoading = value;
    });
  }

  late final _$_scheduleErrorAtom = Atom(
    name: 'ChannelProfileStoreBase._scheduleError',
    context: context,
  );

  String? get scheduleError {
    _$_scheduleErrorAtom.reportRead();
    return super._scheduleError;
  }

  @override
  String? get _scheduleError => scheduleError;

  @override
  set _scheduleError(String? value) {
    _$_scheduleErrorAtom.reportWrite(value, super._scheduleError, () {
      super._scheduleError = value;
    });
  }

  late final _$_loadAsyncAction = AsyncAction(
    'ChannelProfileStoreBase._load',
    context: context,
  );

  @override
  Future<void> _load() {
    return _$_loadAsyncAction.run(() => super._load());
  }

  late final _$_loadScheduleAsyncAction = AsyncAction(
    'ChannelProfileStoreBase._loadSchedule',
    context: context,
  );

  @override
  Future<void> _loadSchedule() {
    return _$_loadScheduleAsyncAction.run(() => super._loadSchedule());
  }

  @override
  String toString() {
    return '''
userId: ${userId},
displayName: ${displayName}
    ''';
  }
}
