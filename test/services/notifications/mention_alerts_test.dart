import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/services/notifications/activity_log.dart';
import 'package:frosty/services/notifications/mention_alerts.dart';

ChatMention _mention({
  String channelId = '42',
  String id = 'm1',
  String text = 'hey @viewer look',
  String from = 'Someone',
}) => (
  messageId: id,
  channelId: channelId,
  channelLogin: 'streamer',
  channelName: 'Streamer',
  fromName: from,
  text: text,
);

void main() {
  late List<MentionNotice> posted;
  late bool inFront;
  late DateTime now;
  late MentionAlerts alerts;

  setUp(() {
    posted = [];
    inFront = false;
    now = DateTime.utc(2026, 10, 20, 12);
    alerts = MentionAlerts(
      post: (notice) async => posted.add(notice),
      inFront: () => inFront,
      now: () => now,
    );
  });

  test('posts a mention while the app is not in front', () async {
    expect(await alerts.onMention(_mention()), isTrue);
    final notice = posted.single;
    expect(notice.title, 'Someone mentioned you in Streamer');
    expect(notice.body, 'hey @viewer look');
    expect(notice.channelLogin, 'streamer');
    expect(notice.channelId, '42');
  });

  test('nothing while the app is in front', () async {
    inFront = true;
    expect(await alerts.onMention(_mention()), isFalse);
    expect(posted, isEmpty);
  });

  test('one notice per channel per throttle window', () async {
    await alerts.onMention(_mention(id: 'a'));
    now = now.add(kMentionThrottle ~/ 2);
    expect(await alerts.onMention(_mention(id: 'b')), isFalse);
    // Another channel is not held back.
    expect(await alerts.onMention(_mention(id: 'c', channelId: '43')), isTrue);
    now = now.add(kMentionThrottle);
    expect(await alerts.onMention(_mention(id: 'd')), isTrue);
    expect(posted.map((n) => n.messageId), ['a', 'c', 'd']);
  });

  test('a failed post is not counted against the window', () async {
    var fail = true;
    final flaky = MentionAlerts(
      post: (notice) async {
        if (fail) throw StateError('plugin');
        posted.add(notice);
      },
      inFront: () => false,
      now: () => now,
    );
    expect(await flaky.onMention(_mention(id: 'a')), isFalse);
    fail = false;
    expect(await flaky.onMention(_mention(id: 'b')), isTrue);
  });

  test('text is one safe line, cut when long', () async {
    await alerts.onMention(
      _mention(text: 'line one\nline two \u202e${'x' * 300}', from: 'A\nB'),
    );
    final notice = posted.single;
    expect(notice.body, isNot(contains('\n')));
    expect(notice.body, isNot(contains('\u202e')));
    expect(notice.body.length, lessThanOrEqualTo(kMentionMaxLength + 1));
    expect(notice.body, endsWith('…'));
    expect(notice.title, 'A B mentioned you in Streamer');
  });

  test('emoji and scripts keep their joiners', () async {
    const family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}';
    const persian = '\u0645\u06CC\u200C\u062E\u0648\u0627\u0647\u0645';
    await alerts.onMention(_mention(text: '$family $persian', from: persian));
    final notice = posted.single;
    expect(notice.body, '$family $persian');
    expect(notice.title, '$persian mentioned you in Streamer');
  });

  test('a tapped notice: its channel, unless it is already open', () {
    // The chat that heard the mention is usually still open (the app was
    // only in the background): it comes back to the front, no second one.
    expect(
      mentionTapFor('streamer', openChannels: const {'streamer'}),
      MentionTap.bringToFront,
    );
    expect(
      mentionTapFor('Streamer', openChannels: const {'streamer'}),
      MentionTap.bringToFront,
    );
    // Its channel in the mini player: restored.
    expect(
      mentionTapFor('streamer', openChannels: const {}, miniLogin: 'streamer'),
      MentionTap.restoreMini,
    );
    // Closed meanwhile (or the app was killed): opened.
    expect(
      mentionTapFor('streamer', openChannels: const {'other'}, miniLogin: 'x'),
      MentionTap.openChannel,
    );
  });

  test('its Activity entry names the message', () {
    final entry = mentionEntry((
      messageId: 'm1',
      channelId: '42',
      channelLogin: 'streamer',
      title: 'Someone mentioned you in Streamer',
      body: 'hey',
    ), DateTime.utc(2026, 10, 20, 12));
    expect(entry.id, 'mention:42:m1');
    expect(entry.kind, ActivityKind.mention);
    expect(entry.login, 'streamer');
    expect(entry.title, 'Someone mentioned you in Streamer');
    expect(entry.body, 'hey');
  });

  test('a notice id is stable per channel and leaves go-live ids alone', () {
    expect(mentionNoticeId('42'), mentionNoticeId('42'));
    expect(mentionNoticeId('42'), isNot(mentionNoticeId('43')));
    expect(mentionNoticeId('42'), isNot(42));
    expect(mentionNoticeId('42'), greaterThan(1));
  });

  group('chatMentionOf', () {
    IRCMessage parse(String line) =>
        IRCMessage.fromString(line, userLogin: 'viewer');

    String privmsg(
      String text, {
      String login = 'someone',
      String extra = '',
    }) =>
        '@badge-info=;badges=;color=;display-name=Someone;emotes=;'
        'id=msg-1;mod=0;room-id=42;$extra'
        'tmi-sent-ts=1;user-id=9;user-type= '
        ':$login!$login@$login.tmi.twitch.tv PRIVMSG #streamer :$text';

    ChatMention? mentionOf(IRCMessage message) => chatMentionOf(
      message,
      ownLogin: 'viewer',
      channelId: '42',
      channelLogin: 'streamer',
      channelName: 'Streamer',
    );

    test('a message naming the viewer', () {
      final mention = mentionOf(parse(privmsg('hi @Viewer!')));
      expect(mention, isNotNull);
      expect(mention!.messageId, 'msg-1');
      expect(mention.fromName, 'Someone');
      expect(mention.text, 'hi @Viewer!');
      expect(mention.channelLogin, 'streamer');
    });

    test('not a message that does not name the viewer', () {
      expect(mentionOf(parse(privmsg('hi there'))), isNull);
      expect(mentionOf(parse(privmsg('previewer here'))), isNull);
    });

    test('not the recent messages loaded on joining', () {
      expect(
        mentionOf(parse(privmsg('hi @viewer', extra: 'historical=1;'))),
        isNull,
      );
    });

    test("not the viewer's own message", () {
      expect(mentionOf(parse(privmsg('I am viewer', login: 'viewer'))), isNull);
    });

    test('not a sub notice or a notice', () {
      final notice = parse(
        '@badge-info=;badges=;display-name=Someone;id=n1;login=someone;'
        'msg-id=resub;room-id=42;system-msg=resub;tmi-sent-ts=1;user-id=9 '
        ':tmi.twitch.tv USERNOTICE #streamer :thanks @viewer',
      );
      expect(mentionOf(notice), isNull);
    });

    test('logged out: nothing', () {
      expect(
        chatMentionOf(
          IRCMessage.fromString(privmsg('hi @viewer')),
          ownLogin: null,
          channelId: '42',
          channelLogin: 'streamer',
          channelName: 'Streamer',
        ),
        isNull,
      );
    });
  });

  group('alertChatMention (the chat store hook)', () {
    IRCMessage parse(String text) => IRCMessage.fromString(
      '@badge-info=;badges=;color=;display-name=Someone;emotes=;'
      'id=msg-1;mod=0;room-id=42;tmi-sent-ts=1;user-id=9;user-type= '
      ':someone!someone@someone.tmi.twitch.tv PRIVMSG #streamer :$text',
      userLogin: 'viewer',
    );

    Future<bool?> hook(String text, {bool enabled = true}) => alertChatMention(
      parse(text),
      enabled: enabled,
      ownLogin: 'viewer',
      channelId: '42',
      channelLogin: 'streamer',
      channelName: 'Streamer',
      alerts: alerts,
    );

    test('a mention reaches the alerts', () async {
      expect(await hook('hi @viewer'), isTrue);
      expect(posted.single.messageId, 'msg-1');
      expect(posted.single.channelLogin, 'streamer');
    });

    test('nothing when the setting is off or nobody is mentioned', () async {
      expect(await hook('hi @viewer', enabled: false), isNull);
      expect(await hook('hi there'), isNull);
      expect(posted, isEmpty);
    });
  });
}
