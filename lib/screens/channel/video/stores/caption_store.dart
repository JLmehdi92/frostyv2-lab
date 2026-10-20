import 'dart:async';

import 'package:frosty/screens/channel/video/captions.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mobx/mobx.dart';

part 'caption_store.g.dart';

class CaptionStore = CaptionStoreBase with _$CaptionStore;

/// The closed captions of one IVS player, live or VOD: the line on screen,
/// the caption tracks the stream offers and the one shown.
///
/// Twitch's app has one "Closed Captions" switch; ONSET adds a track
/// choice when a stream offers several (the language picked is chosen
/// again on the next stream) and a size and background for the line.
abstract class CaptionStoreBase with Store {
  CaptionStoreBase({required this.settings, required this.invoke});

  final SettingsStore settings;

  /// Calls the native player (`setCaptions`, `setTextTrack`).
  final Future<void> Function(String method, [Map<String, Object?>? args])
  invoke;

  ReactionDisposer? _disposeReaction;
  Timer? _timer;

  /// The caption line on screen, when captions are on and a cue is live.
  @readonly
  String? _caption;

  /// The caption tracks the stream offers (empty until it says).
  @readonly
  var _tracks = const <CaptionTrack>[];

  /// The track the player shows.
  @readonly
  String? _selectedTrackId;

  /// Follows the setting: tells the player at once, clears the line when
  /// turned off.
  void start() {
    _disposeReaction ??= reaction((_) => settings.showCaptions, (bool on) {
      if (!on) _clear();
      unawaited(invoke('setCaptions', {'enabled': on}));
    });
  }

  /// A new load: the player is asked for captions again when they are on.
  void onLoad() {
    if (settings.showCaptions) unawaited(invoke('setCaptions', {'enabled': true}));
  }

  /// Handles a caption event from the native player; false for any other.
  bool handleEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'caption':
        if (!settings.showCaptions) return true;
        final caption = captionFromEvent(e);
        _timer?.cancel();
        runInAction(() => _caption = caption?.text);
        if (caption != null) _timer = Timer(caption.shownFor, _clear);
        return true;
      case 'textTracks':
        final (:list, :selected) = captionTracksFromEvent(e);
        runInAction(() {
          _tracks = list;
          _selectedTrackId = selected;
        });
        _pickRememberedLanguage();
        return true;
    }
    return false;
  }

  /// Shows [track] and remembers its language for the next streams.
  @action
  void selectTrack(CaptionTrack track) {
    _selectedTrackId = track.id;
    settings.captionLanguage = track.language ?? '';
    unawaited(invoke('setTextTrack', {'id': track.id}));
  }

  void _pickRememberedLanguage() {
    final language = settings.captionLanguage;
    if (!settings.showCaptions || language.isEmpty) return;
    final selected = _tracks.where((t) => t.id == _selectedTrackId).firstOrNull;
    if (selected?.language == language) return;
    final wanted = _tracks.where((t) => t.language == language).firstOrNull;
    if (wanted == null) return;
    runInAction(() => _selectedTrackId = wanted.id);
    unawaited(invoke('setTextTrack', {'id': wanted.id}));
  }

  void _clear() {
    _timer?.cancel();
    runInAction(() => _caption = null);
  }

  void dispose() {
    _disposeReaction?.call();
    _timer?.cancel();
  }
}
