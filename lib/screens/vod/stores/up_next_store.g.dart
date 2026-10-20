// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'up_next_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$UpNextStore on UpNextStoreBase, Store {
  late final _$_phaseAtom = Atom(
    name: 'UpNextStoreBase._phase',
    context: context,
  );

  UpNextPhase get phase {
    _$_phaseAtom.reportRead();
    return super._phase;
  }

  @override
  UpNextPhase get _phase => phase;

  @override
  set _phase(UpNextPhase value) {
    _$_phaseAtom.reportWrite(value, super._phase, () {
      super._phase = value;
    });
  }

  late final _$_nextAtom = Atom(
    name: 'UpNextStoreBase._next',
    context: context,
  );

  Vod? get next {
    _$_nextAtom.reportRead();
    return super._next;
  }

  @override
  Vod? get _next => next;

  @override
  set _next(Vod? value) {
    _$_nextAtom.reportWrite(value, super._next, () {
      super._next = value;
    });
  }

  late final _$_similarAtom = Atom(
    name: 'UpNextStoreBase._similar',
    context: context,
  );

  bool get similar {
    _$_similarAtom.reportRead();
    return super._similar;
  }

  @override
  bool get _similar => similar;

  @override
  set _similar(bool value) {
    _$_similarAtom.reportWrite(value, super._similar, () {
      super._similar = value;
    });
  }

  late final _$_secondsLeftAtom = Atom(
    name: 'UpNextStoreBase._secondsLeft',
    context: context,
  );

  int get secondsLeft {
    _$_secondsLeftAtom.reportRead();
    return super._secondsLeft;
  }

  @override
  int get _secondsLeft => secondsLeft;

  @override
  set _secondsLeft(int value) {
    _$_secondsLeftAtom.reportWrite(value, super._secondsLeft, () {
      super._secondsLeft = value;
    });
  }

  late final _$onEndedAsyncAction = AsyncAction(
    'UpNextStoreBase.onEnded',
    context: context,
  );

  @override
  Future<void> onEnded() {
    return _$onEndedAsyncAction.run(() => super.onEnded());
  }

  late final _$UpNextStoreBaseActionController = ActionController(
    name: 'UpNextStoreBase',
    context: context,
  );

  @override
  void _tick() {
    final _$actionInfo = _$UpNextStoreBaseActionController.startAction(
      name: 'UpNextStoreBase._tick',
    );
    try {
      return super._tick();
    } finally {
      _$UpNextStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void cancel() {
    final _$actionInfo = _$UpNextStoreBaseActionController.startAction(
      name: 'UpNextStoreBase.cancel',
    );
    try {
      return super.cancel();
    } finally {
      _$UpNextStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void playNow() {
    final _$actionInfo = _$UpNextStoreBaseActionController.startAction(
      name: 'UpNextStoreBase.playNow',
    );
    try {
      return super.playNow();
    } finally {
      _$UpNextStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void reset() {
    final _$actionInfo = _$UpNextStoreBaseActionController.startAction(
      name: 'UpNextStoreBase.reset',
    );
    try {
      return super.reset();
    } finally {
      _$UpNextStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void hold(bool held) {
    final _$actionInfo = _$UpNextStoreBaseActionController.startAction(
      name: 'UpNextStoreBase.hold',
    );
    try {
      return super.hold(held);
    } finally {
      _$UpNextStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
