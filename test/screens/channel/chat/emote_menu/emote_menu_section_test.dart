import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/screens/channel/chat/emote_menu/emote_menu_section.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:provider/provider.dart';

class MockChatStore extends Mock implements ChatStore {}

void main() {
  testWidgets('each emote cell is read by its name', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      Provider<SettingsStore>.value(
        value: SettingsStore.fromJson({}),
        child: MaterialApp(
          home: Scaffold(
            body: EmoteMenuSection(
              chatStore: MockChatStore(),
              emotes: const [
                Emote(
                  name: 'Kappa',
                  zeroWidth: false,
                  url: 'https://static-cdn.jtvnw.net/emoticons/v2/25/3.0',
                  type: EmoteType.twitchGlobal,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Kappa'), findsOneWidget);
    semantics.dispose();
  });
}
