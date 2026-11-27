import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList, autorun;
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import '../../../../helpers/chat_store_harness.dart';

Emote _emote(String name, EmoteType type) => Emote(
  name: name,
  zeroWidth: false,
  url: 'https://cdn.example/$name',
  type: type,
);

void main() {
  final kappa = _emote('Kappa', EmoteType.twitchGlobal);
  final catUser = _emote('catJAM', EmoteType.twitchSub);
  final bttvCat = _emote('CatBop', EmoteType.bttvChannel);
  final bttvPepe = _emote('pepeD', EmoteType.bttvGlobal);
  final ffzCat = _emote('ScaredCat', EmoteType.ffzChannel);
  final sevenCat = _emote('catJAM', EmoteType.sevenTVChannel);
  final sevenTurkish = _emote('İstanbul', EmoteType.sevenTVGlobal);

  late ObservableList<Emote> ffz;

  Future<ChatStore> open(WidgetTester tester) async {
    ffz = ObservableList.of([ffzCat]);
    final store = createTestChatStore(
      settings: SettingsStore.fromJson({})
        ..showRecentMessages = false
        ..autoSyncChatDelay = false
        ..chatDelay = 0,
      sockets: [],
    );
    final assets = store.assetsStore;
    when(
      () => assets.userEmoteToObject,
    ).thenReturn({'Kappa': kappa, 'catJAM': catUser});
    when(() => assets.bttvEmotes).thenReturn([bttvCat, bttvPepe]);
    when(() => assets.ffzEmotes).thenAnswer((_) => ffz.toList());
    when(() => assets.sevenTVEmotes).thenReturn([sevenCat, sevenTurkish]);
    await tester.pumpWidget(
      Focus(focusNode: store.textFieldFocusNode, child: const SizedBox()),
    );
    store.textFieldFocusNode.requestFocus();
    await tester.pump();
    return store;
  }

  Future<void> close(WidgetTester tester, ChatStore store) async {
    store.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  testWidgets('matches the last word anywhere in the name, ignoring case, '
      'in source order with duplicates kept', (tester) async {
    final store = await open(tester);

    store.textController.text = 'hello CA';
    expect(store.matchingEmotes, [catUser, bttvCat, ffzCat, sevenCat]);

    store.textController.text = 'jam';
    expect(store.matchingEmotes, [catUser, sevenCat]);

    store.textController.text = 'pe';
    expect(store.matchingEmotes, [bttvPepe]);

    store.textController.text = 'STAN';
    expect(store.matchingEmotes, [sevenTurkish]);

    store.textController.text = 'nothing';
    expect(store.matchingEmotes, isEmpty);

    store.textController.text = 'cat ';
    expect(store.matchingEmotes, isEmpty);

    await close(tester, store);
  });

  testWidgets('follows emote sets that change after typing', (tester) async {
    final store = await open(tester);
    final dispose = autorun((_) => store.matchingEmotes);
    store.textController.text = 'cat';
    expect(store.matchingEmotes, hasLength(4));

    ffz.clear();
    expect(store.matchingEmotes, [catUser, bttvCat, sevenCat]);

    dispose();
    await close(tester, store);
  });

  testWidgets('reads the emote sets once while typing, not per keystroke', (
    tester,
  ) async {
    final store = await open(tester);
    final dispose = autorun((_) => store.matchingEmotes);
    clearInteractions(store.assetsStore);

    for (final text in ['c', 'ca', 'cat', 'catj']) {
      store.textController.text = text;
    }
    expect(store.matchingEmotes, [catUser, sevenCat]);
    verify(() => store.assetsStore.bttvEmotes).called(1);

    dispose();
    await close(tester, store);
  });
}
