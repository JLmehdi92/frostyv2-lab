import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/chat_rules.dart';

void main() {
  Map<String, Object?> user({required Object? rules, Object? icon}) => {
    'id': '71092938',
    'displayName': 'xQc',
    'profileImageURL':
        icon ??
        'https://static-cdn.jtvnw.net/jtv_user_pictures/xqc-150x150.jpeg',
    'chatSettings': {'rules': rules},
  };

  test('reads the rules, the channel name and its picture', () {
    final rules = ChatRules.fromGql(
      user(rules: ['English please', 'Fresh memes']),
    )!;

    expect(rules.channelId, '71092938');
    expect(rules.channelName, 'xQc');
    expect(
      rules.iconUrl,
      'https://static-cdn.jtvnw.net/jtv_user_pictures/xqc-150x150.jpeg',
    );
    expect(rules.rules, ['English please', 'Fresh memes']);
    expect(rules.hasRules, isTrue);
  });

  test('blank rules are dropped, like Twitch decides on non-blank ones', () {
    final rules = ChatRules.fromGql(user(rules: ['  ', '', ' Be nice ', 3]))!;

    expect(rules.rules, ['Be nice']);
    expect(rules.hasRules, isTrue);
  });

  test('a channel without rules has none', () {
    expect(ChatRules.fromGql(user(rules: []))!.hasRules, isFalse);
    expect(ChatRules.fromGql(user(rules: null))!.hasRules, isFalse);
    expect(ChatRules.fromGql(user(rules: ['   ']))!.hasRules, isFalse);
  });

  test('a picture off Twitch image hosts is not kept', () {
    final rules = ChatRules.fromGql(
      user(rules: ['x'], icon: 'https://evil.example/a.png'),
    )!;
    expect(rules.iconUrl, isNull);
  });

  test('no user or no id is null', () {
    expect(ChatRules.fromGql(null), isNull);
    expect(ChatRules.fromGql({'displayName': 'x'}), isNull);
  });

  test('at most 50 rules of at most 500 units each', () {
    final many = List.generate(80, (i) => 'rule $i');
    expect(ChatRules.fromGql(user(rules: many))!.rules, hasLength(50));

    final long = 'a' * 900;
    expect(ChatRules.fromGql(user(rules: [long]))!.rules.single.length, 500);
  });
}
