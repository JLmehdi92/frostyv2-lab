// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_vod_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$WebVodStore on WebVodStoreBase, Store {
  Computed<Duration>? _$durationComputed;

  @override
  Duration get duration => (_$durationComputed ??= Computed<Duration>(
    () => super.duration,
    name: 'WebVodStoreBase.duration',
  )).value;
  Computed<int>? _$positionSecondsComputed;

  @override
  int get positionSeconds => (_$positionSecondsComputed ??= Computed<int>(
    () => super.positionSeconds,
    name: 'WebVodStoreBase.positionSeconds',
  )).value;

  late final _$_statusAtom = Atom(
    name: 'WebVodStoreBase._status',
    context: context,
  );

  VodPlaybackStatus get status {
    _$_statusAtom.reportRead();
    return super._status;
  }

  @override
  VodPlaybackStatus get _status => status;

  @override
  set _status(VodPlaybackStatus value) {
    _$_statusAtom.reportWrite(value, super._status, () {
      super._status = value;
    });
  }

  late final _$_positionAtom = Atom(
    name: 'WebVodStoreBase._position',
    context: context,
  );

  Duration get position {
    _$_positionAtom.reportRead();
    return super._position;
  }

  @override
  Duration get _position => position;

  @override
  set _position(Duration value) {
    _$_positionAtom.reportWrite(value, super._position, () {
      super._position = value;
    });
  }

  late final _$_reportedDurationAtom = Atom(
    name: 'WebVodStoreBase._reportedDuration',
    context: context,
  );

  Duration? get reportedDuration {
    _$_reportedDurationAtom.reportRead();
    return super._reportedDuration;
  }

  @override
  Duration? get _reportedDuration => reportedDuration;

  @override
  set _reportedDuration(Duration? value) {
    _$_reportedDurationAtom.reportWrite(value, super._reportedDuration, () {
      super._reportedDuration = value;
    });
  }

  late final _$_bufferedAtom = Atom(
    name: 'WebVodStoreBase._buffered',
    context: context,
  );

  Duration get buffered {
    _$_bufferedAtom.reportRead();
    return super._buffered;
  }

  @override
  Duration get _buffered => buffered;

  @override
  set _buffered(Duration value) {
    _$_bufferedAtom.reportWrite(value, super._buffered, () {
      super._buffered = value;
    });
  }

  late final _$_playbackRateAtom = Atom(
    name: 'WebVodStoreBase._playbackRate',
    context: context,
  );

  double get playbackRate {
    _$_playbackRateAtom.reportRead();
    return super._playbackRate;
  }

  @override
  double get _playbackRate => playbackRate;

  @override
  set _playbackRate(double value) {
    _$_playbackRateAtom.reportWrite(value, super._playbackRate, () {
      super._playbackRate = value;
    });
  }

  late final _$_mutedAtom = Atom(
    name: 'WebVodStoreBase._muted',
    context: context,
  );

  bool get muted {
    _$_mutedAtom.reportRead();
    return super._muted;
  }

  @override
  bool get _muted => muted;

  @override
  set _muted(bool value) {
    _$_mutedAtom.reportWrite(value, super._muted, () {
      super._muted = value;
    });
  }

  late final _$_volumeAtom = Atom(
    name: 'WebVodStoreBase._volume',
    context: context,
  );

  double get volume {
    _$_volumeAtom.reportRead();
    return super._volume;
  }

  @override
  double get _volume => volume;

  @override
  set _volume(double value) {
    _$_volumeAtom.reportWrite(value, super._volume, () {
      super._volume = value;
    });
  }

  late final _$_overlayVisibleAtom = Atom(
    name: 'WebVodStoreBase._overlayVisible',
    context: context,
  );

  bool get overlayVisible {
    _$_overlayVisibleAtom.reportRead();
    return super._overlayVisible;
  }

  @override
  bool get _overlayVisible => overlayVisible;

  @override
  set _overlayVisible(bool value) {
    _$_overlayVisibleAtom.reportWrite(value, super._overlayVisible, () {
      super._overlayVisible = value;
    });
  }

  late final _$_isInPipModeAtom = Atom(
    name: 'WebVodStoreBase._isInPipMode',
    context: context,
  );

  bool get isInPipMode {
    _$_isInPipModeAtom.reportRead();
    return super._isInPipMode;
  }

  @override
  bool get _isInPipMode => isInPipMode;

  @override
  set _isInPipMode(bool value) {
    _$_isInPipModeAtom.reportWrite(value, super._isInPipMode, () {
      super._isInPipMode = value;
    });
  }

  late final _$WebVodStoreBaseActionController = ActionController(
    name: 'WebVodStoreBase',
    context: context,
  );

  @override
  @visibleForTesting
  void onStateMessage(String json) {
    final _$actionInfo = _$WebVodStoreBaseActionController.startAction(
      name: 'WebVodStoreBase.onStateMessage',
    );
    try {
      return super.onStateMessage(json);
    } finally {
      _$WebVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void play() {
    final _$actionInfo = _$WebVodStoreBaseActionController.startAction(
      name: 'WebVodStoreBase.play',
    );
    try {
      return super.play();
    } finally {
      _$WebVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void seekTo(Duration target) {
    final _$actionInfo = _$WebVodStoreBaseActionController.startAction(
      name: 'WebVodStoreBase.seekTo',
    );
    try {
      return super.seekTo(target);
    } finally {
      _$WebVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setPlaybackRate(double rate) {
    final _$actionInfo = _$WebVodStoreBaseActionController.startAction(
      name: 'WebVodStoreBase.setPlaybackRate',
    );
    try {
      return super.setPlaybackRate(rate);
    } finally {
      _$WebVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleMute() {
    final _$actionInfo = _$WebVodStoreBaseActionController.startAction(
      name: 'WebVodStoreBase.toggleMute',
    );
    try {
      return super.toggleMute();
    } finally {
      _$WebVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setVolume(double volume) {
    final _$actionInfo = _$WebVodStoreBaseActionController.startAction(
      name: 'WebVodStoreBase.setVolume',
    );
    try {
      return super.setVolume(volume);
    } finally {
      _$WebVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void handleVideoTap() {
    final _$actionInfo = _$WebVodStoreBaseActionController.startAction(
      name: 'WebVodStoreBase.handleVideoTap',
    );
    try {
      return super.handleVideoTap();
    } finally {
      _$WebVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void showOverlay() {
    final _$actionInfo = _$WebVodStoreBaseActionController.startAction(
      name: 'WebVodStoreBase.showOverlay',
    );
    try {
      return super.showOverlay();
    } finally {
      _$WebVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void onPipEntered() {
    final _$actionInfo = _$WebVodStoreBaseActionController.startAction(
      name: 'WebVodStoreBase.onPipEntered',
    );
    try {
      return super.onPipEntered();
    } finally {
      _$WebVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void onPipExited() {
    final _$actionInfo = _$WebVodStoreBaseActionController.startAction(
      name: 'WebVodStoreBase.onPipExited',
    );
    try {
      return super.onPipExited();
    } finally {
      _$WebVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
duration: ${duration},
positionSeconds: ${positionSeconds}
    ''';
  }
}
