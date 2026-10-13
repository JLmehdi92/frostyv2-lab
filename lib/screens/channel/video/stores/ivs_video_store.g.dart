// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ivs_video_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$IvsVideoStore on IvsVideoStoreBase, Store {
  late final _$_textureIdAtom = Atom(
    name: 'IvsVideoStoreBase._textureId',
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

  late final _$_urlAtom = Atom(
    name: 'IvsVideoStoreBase._url',
    context: context,
  );

  String? get url {
    _$_urlAtom.reportRead();
    return super._url;
  }

  @override
  String? get _url => url;

  @override
  set _url(String? value) {
    _$_urlAtom.reportWrite(value, super._url, () {
      super._url = value;
    });
  }

  late final _$_availableStreamQualitiesAtom = Atom(
    name: 'IvsVideoStoreBase._availableStreamQualities',
    context: context,
  );

  List<String> get availableStreamQualities {
    _$_availableStreamQualitiesAtom.reportRead();
    return super._availableStreamQualities;
  }

  @override
  List<String> get _availableStreamQualities => availableStreamQualities;

  @override
  set _availableStreamQualities(List<String> value) {
    _$_availableStreamQualitiesAtom.reportWrite(
      value,
      super._availableStreamQualities,
      () {
        super._availableStreamQualities = value;
      },
    );
  }

  late final _$_streamQualityIndexAtom = Atom(
    name: 'IvsVideoStoreBase._streamQualityIndex',
    context: context,
  );

  int get streamQualityIndex {
    _$_streamQualityIndexAtom.reportRead();
    return super._streamQualityIndex;
  }

  @override
  int get _streamQualityIndex => streamQualityIndex;

  @override
  set _streamQualityIndex(int value) {
    _$_streamQualityIndexAtom.reportWrite(value, super._streamQualityIndex, () {
      super._streamQualityIndex = value;
    });
  }

  late final _$_pausedAtom = Atom(
    name: 'IvsVideoStoreBase._paused',
    context: context,
  );

  bool get paused {
    _$_pausedAtom.reportRead();
    return super._paused;
  }

  @override
  bool get _paused => paused;

  @override
  set _paused(bool value) {
    _$_pausedAtom.reportWrite(value, super._paused, () {
      super._paused = value;
    });
  }

  late final _$_overlayVisibleAtom = Atom(
    name: 'IvsVideoStoreBase._overlayVisible',
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

  late final _$_streamInfoAtom = Atom(
    name: 'IvsVideoStoreBase._streamInfo',
    context: context,
  );

  StreamTwitch? get streamInfo {
    _$_streamInfoAtom.reportRead();
    return super._streamInfo;
  }

  @override
  StreamTwitch? get _streamInfo => streamInfo;

  @override
  set _streamInfo(StreamTwitch? value) {
    _$_streamInfoAtom.reportWrite(value, super._streamInfo, () {
      super._streamInfo = value;
    });
  }

  late final _$_offlineChannelInfoAtom = Atom(
    name: 'IvsVideoStoreBase._offlineChannelInfo',
    context: context,
  );

  Channel? get offlineChannelInfo {
    _$_offlineChannelInfoAtom.reportRead();
    return super._offlineChannelInfo;
  }

  @override
  Channel? get _offlineChannelInfo => offlineChannelInfo;

  @override
  set _offlineChannelInfo(Channel? value) {
    _$_offlineChannelInfoAtom.reportWrite(value, super._offlineChannelInfo, () {
      super._offlineChannelInfo = value;
    });
  }

  late final _$_latencyAtom = Atom(
    name: 'IvsVideoStoreBase._latency',
    context: context,
  );

  String? get latency {
    _$_latencyAtom.reportRead();
    return super._latency;
  }

  @override
  String? get _latency => latency;

  @override
  set _latency(String? value) {
    _$_latencyAtom.reportWrite(value, super._latency, () {
      super._latency = value;
    });
  }

  late final _$_isInPipModeAtom = Atom(
    name: 'IvsVideoStoreBase._isInPipMode',
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

  late final _$_fillScreenAtom = Atom(
    name: 'IvsVideoStoreBase._fillScreen',
    context: context,
  );

  bool get fillScreen {
    _$_fillScreenAtom.reportRead();
    return super._fillScreen;
  }

  @override
  bool get _fillScreen => fillScreen;

  @override
  set _fillScreen(bool value) {
    _$_fillScreenAtom.reportWrite(value, super._fillScreen, () {
      super._fillScreen = value;
    });
  }

  late final _$_resolveUrlAsyncAction = AsyncAction(
    'IvsVideoStoreBase._resolveUrl',
    context: context,
  );

  @override
  Future<void> _resolveUrl() {
    return _$_resolveUrlAsyncAction.run(() => super._resolveUrl());
  }

  late final _$handleRefreshAsyncAction = AsyncAction(
    'IvsVideoStoreBase.handleRefresh',
    context: context,
  );

  @override
  Future<void> handleRefresh() {
    return _$handleRefreshAsyncAction.run(() => super.handleRefresh());
  }

  late final _$updateStreamInfoAsyncAction = AsyncAction(
    'IvsVideoStoreBase.updateStreamInfo',
    context: context,
  );

  @override
  Future<void> updateStreamInfo({bool forceUpdate = false}) {
    return _$updateStreamInfoAsyncAction.run(
      () => super.updateStreamInfo(forceUpdate: forceUpdate),
    );
  }

  late final _$IvsVideoStoreBaseActionController = ActionController(
    name: 'IvsVideoStoreBase',
    context: context,
  );

  @override
  void toggleFillScreen() {
    final _$actionInfo = _$IvsVideoStoreBaseActionController.startAction(
      name: 'IvsVideoStoreBase.toggleFillScreen',
    );
    try {
      return super.toggleFillScreen();
    } finally {
      _$IvsVideoStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void onPipEntered() {
    final _$actionInfo = _$IvsVideoStoreBaseActionController.startAction(
      name: 'IvsVideoStoreBase.onPipEntered',
    );
    try {
      return super.onPipEntered();
    } finally {
      _$IvsVideoStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void onPipExited() {
    final _$actionInfo = _$IvsVideoStoreBaseActionController.startAction(
      name: 'IvsVideoStoreBase.onPipExited',
    );
    try {
      return super.onPipExited();
    } finally {
      _$IvsVideoStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onEvent(Map<String, dynamic> e) {
    final _$actionInfo = _$IvsVideoStoreBaseActionController.startAction(
      name: 'IvsVideoStoreBase._onEvent',
    );
    try {
      return super._onEvent(e);
    } finally {
      _$IvsVideoStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setStreamQuality(String quality) {
    final _$actionInfo = _$IvsVideoStoreBaseActionController.startAction(
      name: 'IvsVideoStoreBase.setStreamQuality',
    );
    try {
      return super.setStreamQuality(quality);
    } finally {
      _$IvsVideoStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void handleVideoTap() {
    final _$actionInfo = _$IvsVideoStoreBaseActionController.startAction(
      name: 'IvsVideoStoreBase.handleVideoTap',
    );
    try {
      return super.handleVideoTap();
    } finally {
      _$IvsVideoStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void dispose() {
    final _$actionInfo = _$IvsVideoStoreBaseActionController.startAction(
      name: 'IvsVideoStoreBase.dispose',
    );
    try {
      return super.dispose();
    } finally {
      _$IvsVideoStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
