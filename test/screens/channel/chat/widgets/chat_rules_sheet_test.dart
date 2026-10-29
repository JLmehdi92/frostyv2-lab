import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_chat_rules_service.dart';
import 'package:frosty/models/chat_rules.dart';
import 'package:frosty/screens/channel/chat/stores/chat_rules_store.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_rules_sheet.dart';
import 'package:frosty/theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockService extends Mock implements TwitchChatRulesService {}

const _rules = ChatRules(
  channelId: '71092938',
  channelName: 'xQc',
  rules: ['English please', 'Fresh memes'],
);

Widget _app(Widget child) {
  const themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
  return MaterialApp(
    theme: themes.dark,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets("shows Twitch's sheet: channel, title, rules, OK, Got it!", (
    tester,
  ) async {
    var accepted = 0;
    await tester.pumpWidget(
      _app(ChatRulesSheet(rules: _rules, onAccept: () => accepted++)),
    );

    expect(find.text('xQc'), findsOneWidget);
    expect(find.text('Chat Rules'), findsOneWidget);
    expect(find.text('English please'), findsOneWidget);
    expect(find.text('Fresh memes'), findsOneWidget);

    await tester.tap(find.text('OK, Got it!'));
    expect(accepted, 1);
  });

  group('prompt before chatting', () {
    late ChatRulesStore store;
    late FocusNode focus;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final service = _MockService();
      when(() => service.getRules(any())).thenAnswer((_) async => _rules);
      store = ChatRulesStore(
        service: service,
        channelId: '71092938',
        viewerId: () => '999',
      );
      focus = FocusNode();
    });

    tearDown(() {
      store.dispose();
      focus.dispose();
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.runAsync(store.load);
      store.attach(focus);
      await tester.pumpWidget(
        _app(
          ChatRulesPrompt(
            rules: store,
            focus: focus,
            child: TextField(focusNode: focus),
          ),
        ),
      );
    }

    testWidgets('tapping the input shows the rules; OK lets the viewer type', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('Chat Rules'), findsOneWidget);
      expect(focus.hasFocus, isFalse);

      await tester.tap(find.text('OK, Got it!'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chat Rules'), findsNothing);
      expect(store.mustShowBeforeChatting, isFalse);
      expect(focus.hasFocus, isTrue);
    });

    testWidgets('closing the sheet keeps the input closed and asks again', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Chat Rules'), findsNothing);
      expect(focus.hasFocus, isFalse);
      expect(store.mustShowBeforeChatting, isTrue);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('Chat Rules'), findsOneWidget);
    });
  });

  group('chat rules entry in the chat menu', () {
    testWidgets('opens the rules to read them again', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = _MockService();
      when(() => service.getRules(any())).thenAnswer((_) async => _rules);
      final store = ChatRulesStore(
        service: service,
        channelId: '71092938',
        viewerId: () => '999',
      );
      addTearDown(store.dispose);
      await tester.runAsync(store.load);

      await tester.pumpWidget(_app(ChatRulesTile(rules: store)));
      await tester.tap(find.text('Chat rules'));
      await tester.pumpAndSettle();
      expect(find.text('English please'), findsOneWidget);

      await tester.tap(find.text('OK, Got it!'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
      expect(find.text('English please'), findsNothing);
      // Reading them there counts as accepting them, as the button says.
      expect(store.mustShowBeforeChatting, isFalse);
    });

    testWidgets('is absent without rules', (tester) async {
      final service = _MockService();
      when(() => service.getRules(any())).thenAnswer(
        (_) async =>
            const ChatRules(channelId: '1', channelName: 'x', rules: []),
      );
      final store = ChatRulesStore(
        service: service,
        channelId: '1',
        viewerId: () => null,
      );
      addTearDown(store.dispose);
      await tester.runAsync(store.load);

      await tester.pumpWidget(_app(ChatRulesTile(rules: store)));
      expect(find.text('Chat rules'), findsNothing);

      await tester.pumpWidget(_app(const ChatRulesTile(rules: null)));
      expect(find.text('Chat rules'), findsNothing);
    });

    testWidgets('in the chat menu, the rules open in place', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = _MockService();
      when(() => service.getRules(any())).thenAnswer((_) async => _rules);
      final store = ChatRulesStore(
        service: service,
        channelId: '71092938',
        viewerId: () => '999',
      );
      addTearDown(store.dispose);
      await tester.runAsync(store.load);

      ChatRules? opened;
      await tester.pumpWidget(
        _app(ChatRulesTile(rules: store, onOpen: (rules) => opened = rules)),
      );
      await tester.tap(find.text('Chat rules'));
      await tester.pumpAndSettle();
      expect(opened, _rules);
      expect(find.byType(BottomSheet), findsNothing);
    });
  });
}
