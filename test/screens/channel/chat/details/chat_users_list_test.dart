import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/channel/chat/details/chat_details_store.dart';
import 'package:frosty/screens/channel/chat/details/chat_users_list.dart';
import 'package:frosty/theme.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/chat_message_harness.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

/// Counts every chatter the list walks through.
class _CountingStore extends ChatDetailsStore {
  _CountingStore() : super(twitchApi: MockTwitchApi(), channelName: 'channel');

  var steps = 0;

  @override
  Iterable<String> get filteredUsers => super.filteredUsers.where((_) {
    steps++;
    return true;
  });
}

void main() {
  late ChatDetailsStore details;

  setUp(() {
    details = ChatDetailsStore(
      twitchApi: MockTwitchApi(),
      channelName: 'channel',
    );
  });

  tearDown(() => details.dispose());

  Future<void> pump(WidgetTester tester, {ChatDetailsStore? store}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: const FrostyThemes(colorSchemeSeed: FrostyTokens.accent).dark,
        home: Scaffold(
          body: ChattersList(
            chatDetailsStore: store ?? details,
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

  testWidgets('a long list is walked once per build, not once per row', (
    tester,
  ) async {
    final store = _CountingStore();
    addTearDown(store.dispose);
    store.chatUsers.addAll([
      for (var i = 0; i < 2000; i++) 'chatter${i.toString().padLeft(4, '0')}',
    ]);
    await pump(tester, store: store);
    expect(find.text('chatter0000'), findsOneWidget);
    // Jump to the end: the rows there sit near index 2000.
    store.steps = 0;
    store.scrollController.jumpTo(
      store.scrollController.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();
    expect(find.text('chatter1999'), findsOneWidget);
    // One pass over the 2000 per build; indexing a lazy filter would walk
    // up to each visible row again (about 2000 per row).
    expect(store.steps, lessThan(2000 * 3));
  });
}
