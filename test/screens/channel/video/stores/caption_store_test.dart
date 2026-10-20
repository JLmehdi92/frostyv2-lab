import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/stores/caption_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';

void main() {
  late SettingsStore settings;
  late List<(String, Map<String, Object?>?)> calls;
  late CaptionStore captions;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    settings = SettingsStore.fromJson({});
    calls = [];
    captions = CaptionStore(
      settings: settings,
      invoke: (method, [args]) async => calls.add((method, args)),
    );
  });

  tearDown(() => captions.dispose());

  void expectLast(String method, Map<String, Object?> args) {
    expect(calls.last.$1, method);
    expect(calls.last.$2, args);
  }

  Map<String, Object?> tracks({String? selected}) => {
    'type': 'textTracks',
    'list': [
      {'id': 'a', 'label': 'English', 'language': 'en'},
      {'id': 'b', 'label': 'Español', 'language': 'es'},
    ],
    'selected': selected,
  };

  test('off: cues are ignored, tracks still known', () {
    expect(captions.handleEvent({'type': 'caption', 'text': 'hi'}), isTrue);
    expect(captions.caption, isNull);

    expect(captions.handleEvent(tracks(selected: 'a')), isTrue);
    expect(captions.tracks.map((t) => t.id), ['a', 'b']);
    expect(captions.selectedTrackId, 'a');
    expect(captions.handleEvent({'type': 'latency'}), isFalse);
  });

  test('turning them on asks the player and shows cues', () async {
    captions.start();
    settings.showCaptions = true;
    await settle();
    expectLast('setCaptions', {'enabled': true});

    captions.handleEvent({'type': 'caption', 'text': 'hello'});
    expect(captions.caption, 'hello');

    settings.showCaptions = false;
    await settle();
    expect(captions.caption, isNull);
    expectLast('setCaptions', {'enabled': false});
  });

  test('picking a track selects it and remembers its language', () {
    captions.handleEvent(tracks(selected: 'a'));
    captions.selectTrack(captions.tracks[1]);

    expectLast('setTextTrack', {'id': 'b'});
    expect(captions.selectedTrackId, 'b');
    expect(settings.captionLanguage, 'es');
  });

  test('the remembered language is chosen when a stream offers it', () {
    settings
      ..showCaptions = true
      ..captionLanguage = 'es';
    captions.handleEvent(tracks(selected: 'a'));

    expectLast('setTextTrack', {'id': 'b'});
    expect(captions.selectedTrackId, 'b');

    calls.clear();
    captions.handleEvent(tracks(selected: 'b'));
    expect(calls, isEmpty);
  });

  test('turning them on mid-stream picks the remembered language', () async {
    settings.captionLanguage = 'es';
    captions
      ..start()
      ..handleEvent(tracks(selected: 'a'));
    expect(calls.where((c) => c.$1 == 'setTextTrack'), isEmpty);

    settings.showCaptions = true;
    await settle();

    expectLast('setTextTrack', {'id': 'b'});
    expect(captions.selectedTrackId, 'b');
  });

  test('each load asks for captions again when on', () {
    captions.onLoad();
    expect(calls, isEmpty);
    settings.showCaptions = true;
    captions.onLoad();
    expectLast('setCaptions', {'enabled': true});
  });
}
