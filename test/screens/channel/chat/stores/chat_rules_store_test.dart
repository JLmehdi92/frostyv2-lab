import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_chat_rules_service.dart';
import 'package:onset/models/chat_rules.dart';
import 'package:onset/screens/channel/chat/stores/chat_rules_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockService extends Mock implements TwitchChatRulesService {}

const _rules = ChatRules(
  channelId: '71092938',
  channelName: 'xQc',
  rules: ['English please', 'Fresh memes'],
);

void main() {
  late _MockService service;
  String? viewer;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = _MockService();
    viewer = '999';
  });

  ChatRulesStore store() => ChatRulesStore(
    service: service,
    channelId: '71092938',
    viewerId: () => viewer,
  );

  test('a logged-in viewer who never accepted must see the rules', () async {
    when(() => service.getRules('71092938')).thenAnswer((_) async => _rules);
    final rules = store();
    await rules.load();

    expect(rules.rules, _rules);
    expect(rules.mustShowBeforeChatting, isTrue);
  });

  test('accepting is remembered for this viewer and channel', () async {
    when(() => service.getRules('71092938')).thenAnswer((_) async => _rules);
    final rules = store();
    await rules.load();
    await rules.accept();

    expect(rules.mustShowBeforeChatting, isFalse);
    final again = store();
    await again.load();
    expect(again.mustShowBeforeChatting, isFalse);

    // Another account on this phone has not accepted them.
    viewer = '1000';
    expect(again.mustShowBeforeChatting, isTrue);
  });

  test('nothing to show when not logged in, without rules or before load',
      () async {
    when(() => service.getRules('71092938')).thenAnswer((_) async => _rules);
    final rules = store();
    expect(rules.mustShowBeforeChatting, isFalse);
    await rules.load();
    viewer = null;
    expect(rules.mustShowBeforeChatting, isFalse);

    when(() => service.getRules('71092938')).thenAnswer(
      (_) async => const ChatRules(
        channelId: '71092938',
        channelName: 'xQc',
        rules: [],
      ),
    );
    viewer = '999';
    final none = store();
    await none.load();
    expect(none.mustShowBeforeChatting, isFalse);
  });

  test('a failing query shows nothing and is asked once', () async {
    when(() => service.getRules(any())).thenThrow(Exception('integrity'));
    final rules = store();
    await rules.load();
    await rules.load();

    expect(rules.rules, isNull);
    expect(rules.mustShowBeforeChatting, isFalse);
    verify(() => service.getRules('71092938')).called(1);
  });

  testWidgets('focusing the input asks for the rules instead of typing', (
    tester,
  ) async {
    when(() => service.getRules('71092938')).thenAnswer((_) async => _rules);
    final rules = store();
    await tester.runAsync(rules.load);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    rules.attach(focus);
    addTearDown(rules.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Focus(focusNode: focus, child: const SizedBox()),
      ),
    );

    focus.requestFocus();
    await tester.pump();

    expect(focus.hasFocus, isFalse);
    expect(rules.prompting, isTrue);

    await tester.runAsync(rules.accept);
    expect(rules.prompting, isFalse);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('closing the sheet without accepting asks again next time', (
    tester,
  ) async {
    when(() => service.getRules('71092938')).thenAnswer((_) async => _rules);
    final rules = store();
    await tester.runAsync(rules.load);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    rules.attach(focus);
    addTearDown(rules.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Focus(focusNode: focus, child: const SizedBox()),
      ),
    );

    focus.requestFocus();
    await tester.pump();
    rules.dismissPrompt();
    expect(rules.prompting, isFalse);

    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    expect(rules.prompting, isTrue);
  });

  test('sending without the input focused is gated too (emote picker)', () async {
    when(() => service.getRules('71092938')).thenAnswer((_) async => _rules);
    final rules = store();
    await rules.load();

    expect(rules.gate(), isTrue);
    expect(rules.prompting, isTrue);

    await rules.accept();
    expect(rules.gate(), isFalse);
    expect(rules.prompting, isFalse);
  });
}

