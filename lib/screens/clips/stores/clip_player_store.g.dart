// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip_player_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ClipPlayerStore on ClipPlayerStoreBase, Store {
  Computed<Duration>? _$durationComputed;

  @override
  Duration get duration => (_$durationComputed ??= Computed<Duration>(
    () => super.duration,
    name: 'ClipPlayerStoreBase.duration',
  )).value;
  Computed<int>? _$positionSecondsComputed;

  @override
  int get positionSeconds => (_$positionSecondsComputed ??= Computed<int>(
    () => super.positionSeconds,
    name: 'ClipPlayerStoreBase.positionSeconds',
  )).value;

  late final _$_statusAtom = Atom(
    name: 'ClipPlayerStoreBase._status',
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
    name: 'ClipPlayerStoreBase._problem',
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
    name: 'ClipPlayerStoreBase._position',
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
    name: 'ClipPlayerStoreBase._reportedDuration',
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
    name: 'ClipPlayerStoreBase._buffered',
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
    name: 'ClipPlayerStoreBase._playbackRate',
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
    name: 'ClipPlayerStoreBase._muted',
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
    name: 'ClipPlayerStoreBase._volume',
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
    name: 'ClipPlayerStoreBase._overlayVisible',
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
    name: 'ClipPlayerStoreBase._isInPipMode',
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

  late final _$_loopingAtom = Atom(
    name: 'ClipPlayerStoreBase._looping',
    context: context,
  );

  bool get looping {
    _$_loopingAtom.reportRead();
    return super._looping;
  }

  @override
  bool get _looping => looping;

  @override
  set _looping(bool value) {
    _$_loopingAtom.reportWrite(value, super._looping, () {
      super._looping = value;
    });
  }

  late final _$_qualitiesAtom = Atom(
    name: 'ClipPlayerStoreBase._qualities',
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
    name: 'ClipPlayerStoreBase._quality',
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

  late final _$_focusedAtom = Atom(
    name: 'ClipPlayerStoreBase._focused',
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

  late final _$ClipPlayerStoreBaseActionController = ActionController(
    name: 'ClipPlayerStoreBase',
    context: context,
  );

  @override
  void setFocused(bool focused) {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase.setFocused',
    );
    try {
      return super.setFocused(focused);
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _setProblem(VodPlaybackProblem problem) {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase._setProblem',
    );
    try {
      return super._setProblem(problem);
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onPlaying(bool playing) {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase._onPlaying',
    );
    try {
      return super._onPlaying(playing);
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onPosition(Duration position) {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase._onPosition',
    );
    try {
      return super._onPosition(position);
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onDuration(Duration duration) {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase._onDuration',
    );
    try {
      return super._onDuration(duration);
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onBuffer(Duration buffer) {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase._onBuffer',
    );
    try {
      return super._onBuffer(buffer);
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onBuffering(bool buffering) {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase._onBuffering',
    );
    try {
      return super._onBuffering(buffering);
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onCompleted(bool completed) {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase._onCompleted',
    );
    try {
      return super._onCompleted(completed);
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void play() {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase.play',
    );
    try {
      return super.play();
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void seekTo(Duration target) {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase.seekTo',
    );
    try {
      return super.seekTo(target);
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setPlaybackRate(double rate) {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase.setPlaybackRate',
    );
    try {
      return super.setPlaybackRate(rate);
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setQuality(String quality) {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase.setQuality',
    );
    try {
      return super.setQuality(quality);
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleLoop() {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase.toggleLoop',
    );
    try {
      return super.toggleLoop();
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleMute() {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase.toggleMute',
    );
    try {
      return super.toggleMute();
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setVolume(double volume) {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase.setVolume',
    );
    try {
      return super.setVolume(volume);
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void handleVideoTap() {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase.handleVideoTap',
    );
    try {
      return super.handleVideoTap();
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void showOverlay() {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase.showOverlay',
    );
    try {
      return super.showOverlay();
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void onPipEntered() {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase.onPipEntered',
    );
    try {
      return super.onPipEntered();
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void onPipExited() {
    final _$actionInfo = _$ClipPlayerStoreBaseActionController.startAction(
      name: 'ClipPlayerStoreBase.onPipExited',
    );
    try {
      return super.onPipExited();
    } finally {
      _$ClipPlayerStoreBaseActionController.endAction(_$actionInfo);
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
