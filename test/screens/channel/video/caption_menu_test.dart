import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/caption_menu.dart';
import 'package:frosty/screens/channel/video/stores/caption_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';

void main() {
  late SettingsStore settings;
  late CaptionStore captions;
  late List<String> calls;

  setUp(() {
    settings = SettingsStore.fromJson({});
    calls = [];
    captions = CaptionStore(
      settings: settings,
      invoke: (method, [args]) async => calls.add('$method $args'),
    );
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(children: [CaptionMenu(captions: captions)]),
      ),
    ),
  );

  testWidgets("Twitch's Closed Captions switch turns them on", (tester) async {
    await pump(tester);

    await tester.tap(find.text('Closed Captions'));
    await tester.pump();

    expect(settings.showCaptions, isTrue);
  });

  testWidgets('with captions on, a stream with several tracks lists them', (
    tester,
  ) async {
    settings.showCaptions = true;
    captions.handleEvent({
      'type': 'textTracks',
      'list': [
        {'id': 'a', 'label': 'English', 'language': 'en'},
        {'id': 'b', 'label': 'Español', 'language': 'es'},
      ],
      'selected': 'a',
    });
    await pump(tester);

    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('Español'));
    await tester.pump();

    expect(captions.selectedTrackId, 'b');
    expect(calls.last, 'setTextTrack {id: b}');
  });

  testWidgets('one track, or captions off, needs no list', (tester) async {
    captions.handleEvent({
      'type': 'textTracks',
      'list': [
        {'id': 'a', 'label': 'English', 'language': 'en'},
        {'id': 'b', 'label': 'Español', 'language': 'es'},
      ],
    });
    await pump(tester);
    expect(find.text('English'), findsNothing);

    settings.showCaptions = true;
    captions.handleEvent({
      'type': 'textTracks',
      'list': [
        {'id': 'a', 'label': 'English', 'language': 'en'},
      ],
    });
    await tester.pump();
    expect(find.text('English'), findsNothing);
  });
}
