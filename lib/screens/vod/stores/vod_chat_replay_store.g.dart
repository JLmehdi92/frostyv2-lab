// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vod_chat_replay_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$VodChatReplayStore on VodChatReplayStoreBase, Store {
  late final _$_statusAtom = Atom(
    name: 'VodChatReplayStoreBase._status',
    context: context,
  );

  ReplayStatus get status {
    _$_statusAtom.reportRead();
    return super._status;
  }

  @override
  ReplayStatus get _status => status;

  @override
  set _status(ReplayStatus value) {
    _$_statusAtom.reportWrite(value, super._status, () {
      super._status = value;
    });
  }

  late final _$_autoScrollAtom = Atom(
    name: 'VodChatReplayStoreBase._autoScroll',
    context: context,
  );

  bool get autoScroll {
    _$_autoScrollAtom.reportRead();
    return super._autoScroll;
  }

  @override
  bool get _autoScroll => autoScroll;

  @override
  set _autoScroll(bool value) {
    _$_autoScrollAtom.reportWrite(value, super._autoScroll, () {
      super._autoScroll = value;
    });
  }

  late final _$VodChatReplayStoreBaseActionController = ActionController(
    name: 'VodChatReplayStoreBase',
    context: context,
  );

  @override
  void onPositionSecond(int second) {
    final _$actionInfo = _$VodChatReplayStoreBaseActionController.startAction(
      name: 'VodChatReplayStoreBase.onPositionSecond',
    );
    try {
      return super.onPositionSecond(second);
    } finally {
      _$VodChatReplayStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void retry() {
    final _$actionInfo = _$VodChatReplayStoreBaseActionController.startAction(
      name: 'VodChatReplayStoreBase.retry',
    );
    try {
      return super.retry();
    } finally {
      _$VodChatReplayStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void resumeScroll() {
    final _$actionInfo = _$VodChatReplayStoreBaseActionController.startAction(
      name: 'VodChatReplayStoreBase.resumeScroll',
    );
    try {
      return super.resumeScroll();
    } finally {
      _$VodChatReplayStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
