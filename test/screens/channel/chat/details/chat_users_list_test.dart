import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/channel/chat/details/chat_details_store.dart';
import 'package:frosty/screens/channel/chat/details/chat_users_list.dart';
import 'package:frosty/theme.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/chat_message_harness.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

void main() {
  late ChatDetailsStore details;

  setUp(() {
    details = ChatDetailsStore(
      twitchApi: MockTwitchApi(),
      channelName: 'channel',
    );
  });

  tearDown(() => details.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: const FrostyThemes(colorSchemeSeed: FrostyTokens.accent).dark,
        home: Scaffold(
          body: ChattersList(
            chatDetailsStore: details,
            chatStore: fakeChatStore(),
            userLogin: 'viewer',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the filter follows its focus: ring and Cancel', (tester) async {
    await pump(tester);
    expect(find.byTooltip('Cancel'), findsNothing);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    // Focused with nothing typed: Cancel shows at once.
    expect(find.byTooltip('Cancel'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(details.textFieldFocusNode.hasFocus, isFalse);
    expect(find.byTooltip('Cancel'), findsNothing);
  });
}
