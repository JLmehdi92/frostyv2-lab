import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/emotes.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_bottom_bar.dart';
import 'package:frosty/screens/channel/stores/channel_events_store.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../../../helpers/chat_message_harness.dart';

class MockAuthStore extends Mock implements AuthStore {}

const _kappa = Emote(
  name: 'Kappa',
  zeroWidth: false,
  url: 'https://static-cdn.jtvnw.net/emoticons/v2/25/3.0',
  type: EmoteType.twitchGlobal,
);

void main() {
  late MockChatStore chat;
  late TextEditingController text;
  late FocusNode focus;

  setUpAll(() => registerFallbackValue(_kappa));

  setUp(() {
    chat = fakeChatStore();
    text = TextEditingController();
    focus = FocusNode();
    final auth = MockAuthStore();
    when(() => auth.isLoggedIn).thenReturn(true);
    when(() => chat.auth).thenReturn(auth);
    final assets = chat.assetsStore;
    when(() => assets.userEmoteToObject).thenReturn({});
    when(() => chat.matchingEmotes).thenReturn(const []);
    when(() => chat.matchingChatters).thenReturn(const []);
    when(() => chat.matchingCommands).thenReturn(const []);
    when(() => chat.showEmoteAutocomplete).thenReturn(false);
    when(() => chat.showMentionAutocomplete).thenReturn(false);
    when(() => chat.expandChat).thenReturn(false);
    when(() => chat.restriction).thenReturn(null);
    when(() => chat.replyingToMessage).thenReturn(null);
    when(() => chat.isWaitingForAck).thenReturn(false);
    when(() => chat.isConnected).thenReturn(true);
    when(() => chat.hasConnected).thenReturn(true);
    when(() => chat.textFieldFocusNode).thenReturn(focus);
    when(() => chat.textController).thenReturn(text);
    when(() => chat.showSendButton).thenReturn(false);
    when(
      () => chat.addEmote(
        any(),
        autocompleteMode: any(named: 'autocompleteMode'),
      ),
    ).thenReturn(null);
  });

  tearDown(() {
    text.dispose();
    focus.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
    await tester.pumpWidget(
      Provider<ChannelEventsStore?>.value(
        value: null,
        child: MaterialApp(
          theme: brightness == Brightness.dark ? themes.dark : themes.light,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              disableAnimations: reduceMotion,
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ChatBottomBar(chatStore: chat, onAddChat: () {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('emote suggestions are 40 dp chips with the name '
        '($brightness)', (tester) async {
      when(() => chat.showEmoteAutocomplete).thenReturn(true);
      when(() => chat.matchingEmotes).thenReturn(const [_kappa]);
      await pump(tester, brightness: brightness);
      expect(tester.takeException(), isNull);
      expect(find.text('Kappa'), findsOneWidget);
      final chip = find.ancestor(
        of: find.text('Kappa'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(chip.first).height, 40);
      await tester.tap(find.text('Kappa'));
      verify(() => chat.addEmote(_kappa, autocompleteMode: true)).called(1);
    });
  }

  testWidgets('a command fills the input with itself', (tester) async {
    when(() => chat.matchingCommands).thenReturn(const [
      (name: 'me', usage: '/me <message>', description: 'Third person'),
    ]);
    await pump(tester);
    expect(find.text('/me'), findsOneWidget);
    expect(find.text('/me <message> · Third person'), findsOneWidget);
    await tester.tap(find.text('/me'));
    expect(text.text, '/me ');
    expect(text.selection.baseOffset, 4);
  });

  testWidgets('a mention replaces the word being typed', (tester) async {
    text.text = 'gg @ka';
    when(() => chat.showMentionAutocomplete).thenReturn(true);
    when(() => chat.matchingChatters).thenReturn(const ['kaelith']);
    await pump(tester);
    expect(find.text('@kaelith'), findsOneWidget);
    await tester.tap(find.text('@kaelith'));
    expect(text.text, 'gg @kaelith ');
  });

  testWidgets('send pops in with text, and only then', (tester) async {
    await pump(tester);
    expect(find.byTooltip('Send'), findsNothing);
    when(() => chat.showSendButton).thenReturn(true);
    await pump(tester);
    expect(find.byTooltip('Send'), findsOneWidget);
  });

  testWidgets('reduce motion: suggestions only fade in', (tester) async {
    when(() => chat.showEmoteAutocomplete).thenReturn(true);
    when(() => chat.matchingEmotes).thenReturn(const [_kappa]);
    await pump(tester, reduceMotion: true);
    expect(
      find.ancestor(
        of: find.text('Kappa'),
        matching: find.byType(SizeTransition),
      ),
      findsNothing,
    );
  });
}
