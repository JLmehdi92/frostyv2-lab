import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/emotes.dart';
import 'package:frosty/screens/channel/chat/emote_menu/emote_menu_section.dart';
import 'package:frosty/screens/channel/chat/stores/chat_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mocktail/mocktail.dart';
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
