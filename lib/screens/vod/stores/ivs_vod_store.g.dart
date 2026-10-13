// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ivs_vod_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$IvsVodStore on IvsVodStoreBase, Store {
  Computed<Duration>? _$durationComputed;

  @override
  Duration get duration => (_$durationComputed ??= Computed<Duration>(
    () => super.duration,
    name: 'IvsVodStoreBase.duration',
  )).value;
  Computed<int>? _$positionSecondsComputed;

  @override
  int get positionSeconds => (_$positionSecondsComputed ??= Computed<int>(
    () => super.positionSeconds,
    name: 'IvsVodStoreBase.positionSeconds',
  )).value;

  late final _$_textureIdAtom = Atom(
    name: 'IvsVodStoreBase._textureId',
    context: context,
  );

  int? get textureId {
    _$_textureIdAtom.reportRead();
    return super._textureId;
  }

  @override
  int? get _textureId => textureId;

  @override
  set _textureId(int? value) {
    _$_textureIdAtom.reportWrite(value, super._textureId, () {
      super._textureId = value;
    });
  }

  late final _$_statusAtom = Atom(
    name: 'IvsVodStoreBase._status',
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

  late final _$_problemAtom = Atom(
    name: 'IvsVodStoreBase._problem',
    context: context,
  );

  VodPlaybackProblem? get problem {
    _$_problemAtom.reportRead();
    return super._problem;
  }

  @override
  VodPlaybackProblem? get _problem => problem;

  @override
  set _problem(VodPlaybackProblem? value) {
    _$_problemAtom.reportWrite(value, super._problem, () {
      super._problem = value;
    });
  }

  late final _$_positionAtom = Atom(
    name: 'IvsVodStoreBase._position',
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

  late final _$_nativeDurationAtom = Atom(
    name: 'IvsVodStoreBase._nativeDuration',
    context: context,
  );

  Duration? get nativeDuration {
    _$_nativeDurationAtom.reportRead();
    return super._nativeDuration;
  }

  @override
  Duration? get _nativeDuration => nativeDuration;

  @override
  set _nativeDuration(Duration? value) {
    _$_nativeDurationAtom.reportWrite(value, super._nativeDuration, () {
      super._nativeDuration = value;
    });
  }

  late final _$_bufferedAtom = Atom(
    name: 'IvsVodStoreBase._buffered',
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

  late final _$_endedAtom = Atom(
    name: 'IvsVodStoreBase._ended',
    context: context,
  );

  bool get ended {
    _$_endedAtom.reportRead();
    return super._ended;
  }

  @override
  bool get _ended => ended;

  @override
  set _ended(bool value) {
    _$_endedAtom.reportWrite(value, super._ended, () {
      super._ended = value;
    });
  }

  late final _$_playbackRateAtom = Atom(
    name: 'IvsVodStoreBase._playbackRate',
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

  late final _$_qualitiesAtom = Atom(
    name: 'IvsVodStoreBase._qualities',
    context: context,
  );

  List<String> get qualities {
    _$_qualitiesAtom.reportRead();
    return super._qualities;
  }

  @override
  List<String> get _qualities => qualities;

  @override
  set _qualities(List<String> value) {
    _$_qualitiesAtom.reportWrite(value, super._qualities, () {
      super._qualities = value;
    });
  }

  late final _$_qualityAtom = Atom(
    name: 'IvsVodStoreBase._quality',
    context: context,
  );

  String get quality {
    _$_qualityAtom.reportRead();
    return super._quality;
  }

  @override
  String get _quality => quality;

  @override
  set _quality(String value) {
    _$_qualityAtom.reportWrite(value, super._quality, () {
      super._quality = value;
    });
  }

  late final _$_mutedAtom = Atom(
    name: 'IvsVodStoreBase._muted',
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
    name: 'IvsVodStoreBase._volume',
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
    name: 'IvsVodStoreBase._overlayVisible',
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
    name: 'IvsVodStoreBase._isInPipMode',
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

  late final _$_focusedAtom = Atom(
    name: 'IvsVodStoreBase._focused',
    context: context,
  );

  @override
  bool get _focused {
    _$_focusedAtom.reportRead();
    return super._focused;
  }

  @override
  set _focused(bool value) {
    _$_focusedAtom.reportWrite(value, super._focused, () {
      super._focused = value;
    });
  }

  late final _$IvsVodStoreBaseActionController = ActionController(
    name: 'IvsVodStoreBase',
    context: context,
  );

  @override
  void setFocused(bool focused) {
    final _$actionInfo = _$IvsVodStoreBaseActionController.startAction(
      name: 'IvsVodStoreBase.setFocused',
    );
    try {
      return super.setFocused(focused);
    } finally {
      _$IvsVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onEvent(Map<String, dynamic> e) {
    final _$actionInfo = _$IvsVodStoreBaseActionController.startAction(
      name: 'IvsVodStoreBase._onEvent',
    );
    try {
      return super._onEvent(e);
    } finally {
      _$IvsVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void play() {
    final _$actionInfo = _$IvsVodStoreBaseActionController.startAction(
      name: 'IvsVodStoreBase.play',
    );
    try {
      return super.play();
    } finally {
      _$IvsVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void seekTo(Duration target) {
    final _$actionInfo = _$IvsVodStoreBaseActionController.startAction(
      name: 'IvsVodStoreBase.seekTo',
    );
    try {
      return super.seekTo(target);
    } finally {
      _$IvsVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setPlaybackRate(double rate) {
    final _$actionInfo = _$IvsVodStoreBaseActionController.startAction(
      name: 'IvsVodStoreBase.setPlaybackRate',
    );
    try {
      return super.setPlaybackRate(rate);
    } finally {
      _$IvsVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _applyQuality(String quality) {
    final _$actionInfo = _$IvsVodStoreBaseActionController.startAction(
      name: 'IvsVodStoreBase._applyQuality',
    );
    try {
      return super._applyQuality(quality);
    } finally {
      _$IvsVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleMute() {
    final _$actionInfo = _$IvsVodStoreBaseActionController.startAction(
      name: 'IvsVodStoreBase.toggleMute',
    );
    try {
      return super.toggleMute();
    } finally {
      _$IvsVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setVolume(double volume) {
    final _$actionInfo = _$IvsVodStoreBaseActionController.startAction(
      name: 'IvsVodStoreBase.setVolume',
    );
    try {
      return super.setVolume(volume);
    } finally {
      _$IvsVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void handleVideoTap() {
    final _$actionInfo = _$IvsVodStoreBaseActionController.startAction(
      name: 'IvsVodStoreBase.handleVideoTap',
    );
    try {
      return super.handleVideoTap();
    } finally {
      _$IvsVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void showOverlay() {
    final _$actionInfo = _$IvsVodStoreBaseActionController.startAction(
      name: 'IvsVodStoreBase.showOverlay',
    );
    try {
      return super.showOverlay();
    } finally {
      _$IvsVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void onPipEntered() {
    final _$actionInfo = _$IvsVodStoreBaseActionController.startAction(
      name: 'IvsVodStoreBase.onPipEntered',
    );
    try {
      return super.onPipEntered();
    } finally {
      _$IvsVodStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void onPipExited() {
    final _$actionInfo = _$IvsVodStoreBaseActionController.startAction(
      name: 'IvsVodStoreBase.onPipExited',
    );
    try {
      return super.onPipExited();
    } finally {
      _$IvsVodStoreBaseActionController.endAction(_$actionInfo);
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
