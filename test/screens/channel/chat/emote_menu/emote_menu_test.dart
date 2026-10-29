import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/emotes.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/screens/channel/chat/emote_menu/emote_menu.dart';
import 'package:frosty/screens/channel/chat/emote_menu/emote_menu_section.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/sheet/onset_panel.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../../../helpers/chat_message_harness.dart';

Emote _emote(String name, EmoteType type) => Emote(
  name: name,
  zeroWidth: false,
  url: 'https://cdn.example/$name.png',
  type: type,
);

void main() {
  late MockChatStore chat;
  late ObservableList<Emote> recent;
  late SettingsStore settings;

  setUpAll(() => registerFallbackValue(_emote('x', EmoteType.twitchGlobal)));

  setUp(() {
    settings = SettingsStore.fromJson({});
    chat = fakeChatStore(settings: settings);
    recent = ObservableList.of([_emote('KEKW', EmoteType.sevenTVChannel)]);
    final assets = chat.assetsStore;
    when(() => assets.recentEmotes).thenReturn(recent);
    when(() => assets.userEmoteToObject).thenReturn({});
    when(
      () => assets.emoteToObject,
    ).thenReturn({'KEKW': _emote('KEKW', EmoteType.sevenTVChannel)});
    when(() => assets.userEmoteSectionToEmotes).thenReturn({
      'Global Emotes': [_emote('Kappa', EmoteType.twitchGlobal)],
    });
    when(() => assets.sevenTVEmotes).thenReturn([
      _emote('KEKW', EmoteType.sevenTVChannel),
      _emote('OMEGALUL', EmoteType.sevenTVGlobal),
    ]);
    when(
      () => assets.bttvEmotes,
    ).thenReturn([_emote('monkaW', EmoteType.bttvGlobal)]);
    when(
      () => assets.ffzEmotes,
    ).thenReturn([_emote('LULW', EmoteType.ffzGlobal)]);
    when(
      () => chat.addEmote(
        any(),
        autocompleteMode: any(named: 'autocompleteMode'),
      ),
    ).thenReturn(null);
    when(() => chat.userState).thenReturn(const USERSTATE());
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
    await tester.pumpWidget(
      Provider<SettingsStore>.value(
        value: settings,
        child: MaterialApp(
          theme: brightness == Brightness.dark ? themes.dark : themes.light,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  for (final brightness in Brightness.values) {
    testWidgets('phone: board tabs, set pills and the 8-column grid '
        '($brightness)', (tester) async {
      await pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(height: 281, child: EmoteMenu(chatStore: chat)),
        ),
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      for (final tab in ['Recent', 'Twitch', '7TV', 'BTTV', 'FFZ']) {
        expect(find.text(tab), findsOneWidget, reason: tab);
      }
      // Recent: its clear button, its emote.
      expect(find.byTooltip('Clear recent emotes'), findsOneWidget);
      expect(find.bySemanticsLabel('KEKW'), findsOneWidget);

      await tester.tap(find.text('7TV'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Clear recent emotes'), findsNothing);
      expect(find.widgetWithText(SheetChoicePill, 'Channel'), findsOneWidget);
      expect(find.widgetWithText(SheetChoicePill, 'Global'), findsOneWidget);
      final cell = tester.getSize(find.byType(EmoteCell).first);
      expect(cell.width, closeTo((390 - 8) / 8, 0.5));

      await tester.tap(find.byType(EmoteCell).first);
      verify(() => chat.addEmote(any())).called(1);

      await tester.tap(find.widgetWithText(SheetChoicePill, 'Global'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('OMEGALUL'), findsOneWidget);
    });
  }

  testWidgets('clearing the recents leaves the board empty state', (
    tester,
  ) async {
    await pump(
      tester,
      SizedBox(height: 281, child: EmoteMenu(chatStore: chat)),
    );
    await tester.tap(find.byTooltip('Clear recent emotes'));
    await tester.pumpAndSettle();
    expect(recent, isEmpty);
    expect(find.text('No recent emotes'), findsOneWidget);
    verify(() => chat.updateNotification('Recent emotes cleared')).called(1);
  });

  testWidgets('a sub emote of another channel is greyed and cannot be used', (
    tester,
  ) async {
    when(() => chat.userState).thenReturn(const USERSTATE());
    final assets = chat.assetsStore;
    when(() => assets.userEmoteSectionToEmotes).thenReturn({
      'Channel Emotes': [_emote('nisqyHype', EmoteType.twitchSub)],
    });
    await pump(
      tester,
      SizedBox(height: 281, child: EmoteMenu(chatStore: chat)),
    );
    await tester.tap(find.text('Twitch'));
    await tester.pumpAndSettle();
    final cell = tester.widget<EmoteCell>(find.byType(EmoteCell).first);
    expect(cell.locked, isTrue);
    expect(cell.onTap, isNull);
  });

  group('tablet panel', () {
    Widget overlay({required bool open, required VoidCallback onClose}) =>
        Stack(
          children: [
            Positioned(
              left: 880,
              right: 0,
              bottom: 0,
              height: 60,
              child: EmoteMenuPanelOverlay(
                chatStore: chat,
                open: open,
                onClose: onClose,
                placement: () => placePanel(
                  bounds: const Rect.fromLTWH(0, 0, 1280, 854),
                  anchor: const Rect.fromLTWH(896, 794, 36, 44),
                  size: EmoteMenu.panelSize,
                  sides: const [PanelSide.above],
                  region: const Rect.fromLTWH(880, 0, 400, 854),
                  gap: 18,
                ),
              ),
            ),
            const Positioned(
              left: 900,
              bottom: 10,
              width: 300,
              child: TextField(key: Key('input')),
            ),
          ],
        );

    testWidgets('a 376 x 372 panel over the input, 6 columns', (tester) async {
      var closed = 0;
      await pump(
        tester,
        overlay(open: true, onClose: () => closed++),
        size: const Size(1280, 854),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final panel = tester.getRect(find.byType(OnsetPanelSurface));
      expect(panel, const Rect.fromLTWH(892, 404, 376, 372));
      await tester.tap(find.text('7TV'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(EmoteCell).first).width,
        closeTo((376 - 12) / 6, 0.5),
      );
      expect(tester.getSize(find.byType(EmoteCell).first).height, 54);
      // Typing still works: the input is not covered by a barrier.
      await tester.tap(find.byKey(const Key('input')));
      await tester.pump();
      expect(closed, 0);
      // A tap elsewhere closes it.
      await tester.tapAt(const Offset(200, 200));
      await tester.pump();
      expect(closed, 1);
    });

    testWidgets('closed, nothing is drawn', (tester) async {
      await pump(
        tester,
        overlay(open: false, onClose: () {}),
        size: const Size(1280, 854),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OnsetPanelSurface), findsNothing);
      expect(find.byType(EmoteMenu), findsNothing);
    });
  });
}
