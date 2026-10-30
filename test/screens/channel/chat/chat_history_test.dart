import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/chat_history.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/chat_history.dart';

ChatHistoryMessage _message({
  String id = 'm-1',
  DateTime? sentAt,
  bool deleted = false,
  ChatHistoryUser? sender = const ChatHistoryUser(
    id: '111',
    login: 'viewer',
    displayName: 'Viewer',
  ),
  String? color = '#FF0000',
  List<({String setId, String version})> badges = const [
    (setId: 'subscriber', version: '12'),
  ],
  List<ChatHistoryFragment> fragments = const [
    ChatHistoryFragment(text: 'hello '),
    ChatHistoryFragment(text: 'Kappa', emoteId: '25'),
  ],
  String? sourceChannelId,
  ChatHistoryParent? parent,
  ChatHistoryParent? threadParent,
}) => ChatHistoryMessage(
  id: id,
  sentAt: sentAt ?? DateTime.utc(2026, 10, 30, 12),
  deleted: deleted,
  sender: sender,
  color: color,
  badges: badges,
  fragments: fragments,
  sourceChannelId: sourceChannelId,
  parent: parent,
  threadParent: threadParent,
);

List<IRCMessage> _lines(
  List<ChatHistoryMessage> history, {
  Set<String> hiddenUserIds = const {},
  Set<String> hiddenLogins = const {},
  bool Function(String text)? muted,
}) => chatHistoryLines(
  history,
  channelId: '12345',
  channelLogin: 'channel',
  viewerLogin: 'me',
  hiddenUserIds: hiddenUserIds,
  hiddenLogins: hiddenLogins,
  muted: muted,
);

void main() {
  test('a history line is the live IRC line: emotes, badges, colour', () {
    final line = _lines([_message()]).single;

    expect(line.command, Command.privateMessage);
    expect(line.user, 'viewer');
    expect(line.message, 'hello Kappa');
    expect(line.tags['id'], 'm-1');
    expect(line.tags['display-name'], 'Viewer');
    expect(line.tags['user-id'], '111');
    expect(line.tags['room-id'], '12345');
    expect(line.tags['color'], '#FF0000');
    expect(line.tags['badges'], 'subscriber/12');
    expect(line.tags['emotes'], '25:6-10');
    expect(line.localEmotes!['Kappa'], isNotNull);
    expect(
      line.tags['tmi-sent-ts'],
      '${DateTime.utc(2026, 10, 30, 12).millisecondsSinceEpoch}',
    );
  });

  test('every line is marked historical', () {
    final lines = _lines([_message(), _message(id: 'm-2', deleted: true)]);
    expect(lines.map((l) => l.tags['historical']), everyElement('1'));
  });

  test('a deleted line is shown deleted, like a CLEARMSG leaves it', () {
    final line = _lines([_message(deleted: true)]).single;
    expect(line.command, Command.clearMessage);
    expect(line.tags['id'], 'm-1');
    expect(line.message, 'hello Kappa');
  });

  test('lines of blocked people are dropped, by id or by login', () {
    final lines = _lines(
      [
        _message(id: 'a'),
        _message(
          id: 'b',
          sender: const ChatHistoryUser(id: '222', login: 'Troll'),
        ),
        _message(
          id: 'c',
          sender: const ChatHistoryUser(id: '333', login: 'other'),
        ),
      ],
      hiddenUserIds: {'333'},
      hiddenLogins: {'troll'},
    );
    expect(lines.map((l) => l.tags['id']), ['a']);
  });

  test('a line without a usable sender is dropped', () {
    final lines = _lines([
      _message(id: 'none', sender: null),
      _message(
        id: 'no-login',
        sender: const ChatHistoryUser(id: '1', displayName: 'Ghost'),
      ),
      _message(
        id: 'bad-login',
        sender: const ChatHistoryUser(id: '1', login: 'not a login'),
      ),
      _message(id: 'kept'),
    ]);
    expect(lines.map((l) => l.tags['id']), ['kept']);
  });

  test('muted words hide a line, as live', () {
    final lines = _lines([
      _message(id: 'a'),
      _message(
        id: 'b',
        fragments: const [ChatHistoryFragment(text: 'spoiler here')],
      ),
    ], muted: (text) => text.contains('spoiler'));
    expect(lines.map((l) => l.tags['id']), ['a']);
  });

  test('oldest first, whatever order Twitch answers in', () {
    final lines = _lines([
      _message(id: 'late', sentAt: DateTime.utc(2026, 1, 1, 0, 2)),
      _message(id: 'early', sentAt: DateTime.utc(2026)),
      _message(id: 'mid-a', sentAt: DateTime.utc(2026, 1, 1, 0, 1)),
      _message(id: 'mid-b', sentAt: DateTime.utc(2026, 1, 1, 0, 1)),
    ]);
    expect(lines.map((l) => l.tags['id']), ['early', 'mid-a', 'mid-b', 'late']);
  });

  test('hostile text cannot forge tags, lines or a sender', () {
    final line = _lines([
      _message(
        sender: const ChatHistoryUser(
          id: '1;mod=1',
          login: 'viewer',
          displayName: 'Vi;ewer=\\x\r\n',
        ),
        color: 'red;mod=1',
        badges: const [(setId: 'broadcaster;x', version: '1')],
        fragments: const [
          ChatHistoryFragment(
            text:
                'hi\r\n@badges=broadcaster/1;mod=1 :evil!evil@evil PRIVMSG #channel :pwn',
          ),
          ChatHistoryFragment(text: ' \x01ACTION x\x01', emoteId: '25;mod=1'),
        ],
      ),
    ]).single;

    expect(line.user, 'viewer');
    expect(line.tags['display-name'], 'Viewerx');
    expect(line.tags.containsKey('mod'), isFalse);
    expect(line.tags.containsKey('badges'), isFalse);
    expect(line.tags.containsKey('color'), isFalse);
    expect(line.tags.containsKey('emotes'), isFalse);
    expect(line.tags['user-id'], '1mod1');
    expect(line.action, isFalse);
    expect(line.message, isNot(contains('\n')));
    expect(line.message, startsWith('hi'));
    expect(line.message, contains('@badges=broadcaster/1;mod=1'));
  });

  test('cheers add up to the bits tag', () {
    final line = _lines([
      _message(
        fragments: const [
          ChatHistoryFragment(text: 'Cheer100', bits: 100),
          ChatHistoryFragment(text: ' '),
          ChatHistoryFragment(text: 'Cheer50', bits: 50),
        ],
      ),
    ]).single;
    expect(line.tags['bits'], '150');
    expect(line.message, 'Cheer100 Cheer50');
  });

  test('a GIF keeps its place, from an allowed host only', () {
    final lines = _lines([
      _message(
        id: 'ok',
        fragments: const [
          ChatHistoryFragment(text: 'look '),
          ChatHistoryFragment(
            text: 'Dancing',
            gif: (id: 'g1', url: 'https://media.giphy.com/media/g1/giphy.gif'),
          ),
        ],
      ),
      _message(
        id: 'evil',
        fragments: const [
          ChatHistoryFragment(
            text: 'Dancing',
            gif: (id: 'g2', url: 'https://192.168.1.1/x.gif'),
          ),
        ],
      ),
    ]);
    expect(lines.first.gifParts.last.gif!.id, 'g1');
    expect(lines.first.gifParts.last.text, 'Dancing');
    expect(lines.last.gifParts, isEmpty);
    expect(lines.last.message, 'Dancing');
  });

  test('a reply carries the reply tags and its @name, like live', () {
    final lines = _lines([
      _message(
        id: 'with-name',
        fragments: const [ChatHistoryFragment(text: '@Asker yes it is')],
        parent: const ChatHistoryParent(
          id: 'parent-1',
          text: 'is it live?',
          sender: ChatHistoryUser(
            id: '222',
            login: 'asker',
            displayName: 'Asker',
          ),
        ),
        threadParent: const ChatHistoryParent(
          id: 'root-1',
          sender: ChatHistoryUser(login: 'starter', displayName: 'Starter'),
        ),
      ),
      _message(
        id: 'without-name',
        fragments: const [ChatHistoryFragment(text: 'yes it is')],
        parent: const ChatHistoryParent(
          id: 'parent-1',
          text: 'is it live?',
          sender: ChatHistoryUser(
            id: '222',
            login: 'asker',
            displayName: 'Asker',
          ),
        ),
      ),
    ]);

    final first = lines.first;
    expect(first.tags['reply-parent-msg-id'], 'parent-1');
    expect(first.tags['reply-parent-msg-body'], 'is it live?');
    expect(first.tags['reply-parent-user-id'], '222');
    expect(first.tags['reply-parent-user-login'], 'asker');
    expect(first.tags['reply-parent-display-name'], 'Asker');
    expect(first.tags['reply-thread-parent-msg-id'], 'root-1');
    expect(first.tags['reply-thread-parent-user-login'], 'starter');
    expect(first.tags['reply-thread-parent-display-name'], 'Starter');
    expect(first.message, '@Asker yes it is');
    // The reply row hides the first word: it must be the @name, as live.
    expect(lines.last.message, '@asker yes it is');
    expect(lines.last.split!.first, '@asker');
  });

  test('a reply without its parent text is a plain line', () {
    final line = _lines([
      _message(
        fragments: const [ChatHistoryFragment(text: 'yes')],
        parent: const ChatHistoryParent(id: 'parent-1'),
      ),
    ]).single;
    expect(line.tags.containsKey('reply-parent-display-name'), isFalse);
    expect(line.tags.containsKey('reply-parent-msg-body'), isFalse);
    expect(line.message, 'yes');
  });

  test('Shared Chat lines name their source channel', () {
    final line = _lines([_message(sourceChannelId: '999')]).single;
    expect(line.tags['source-room-id'], '999');
  });

  test('mentions of the viewer are highlighted as live', () {
    final line = _lines([
      _message(fragments: const [ChatHistoryFragment(text: 'hey @me')]),
    ]).single;
    expect(line.mention, isTrue);
  });

  group('newHistoryLines', () {
    IRCMessage withId(String? id) =>
        IRCMessage(raw: '', command: Command.privateMessage, tags: {'id': ?id});

    test('drops what is already shown and repeats', () {
      final fresh = newHistoryLines(
        [withId('a'), withId('b'), withId('b'), withId('c'), withId(null)],
        shown: [withId('b'), withId(null)],
      );
      expect(fresh.map((m) => m.tags['id']), ['a', 'c', null]);
    });
  });
}
