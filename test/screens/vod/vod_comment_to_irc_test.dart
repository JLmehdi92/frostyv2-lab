import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/vod_comment.dart';
import 'package:onset/screens/vod/vod_comment_to_irc.dart';

final _createdAt = DateTime.utc(2026, 10, 12, 17, 33, 44);

VodComment _comment({
  String? id = 'comment-1',
  int offset = 90,
  List<VodFragment> fragments = const [VodFragment(text: 'hello world')],
  List<({String setId, String version})> badges = const [],
  String? commenterId = '1001',
  String? login = 'viewer_one',
  String? displayName = 'Viewer_One',
  String? color = '#FF4500',
}) => VodComment(
  id: id,
  offsetSeconds: offset,
  fragments: fragments,
  badges: badges,
  commenterId: commenterId,
  commenterLogin: login,
  commenterDisplayName: displayName,
  color: color,
);

IRCMessage _convert(VodComment c, {String? viewerLogin}) =>
    vodCommentToIrcMessage(
      c,
      channelId: '42',
      channelLogin: 'streamer',
      vodCreatedAt: _createdAt,
      viewerLogin: viewerLogin,
    );

void main() {
  test('plain text becomes a chat message with the usual tags', () {
    final m = _convert(_comment());

    expect(m.command, Command.privateMessage);
    expect(m.message, 'hello world');
    expect(m.split, ['hello', 'world']);
    expect(m.user, 'viewer_one');
    expect(m.tags['display-name'], 'Viewer_One');
    expect(m.tags['color'], '#FF4500');
    expect(m.tags['user-id'], '1001');
    expect(m.tags['room-id'], '42');
    expect(m.tags['id'], 'comment-1');
    expect(m.mention, isFalse);
  });

  test('tmi-sent-ts is the broadcast start plus the offset (90 s)', () {
    final m = _convert(_comment());

    expect(
      m.tags['tmi-sent-ts'],
      '${_createdAt.add(const Duration(seconds: 90)).millisecondsSinceEpoch}',
    );
  });

  test('badges use the setId/version keys of the badge map', () {
    final m = _convert(
      _comment(
        badges: const [
          (setId: 'subscriber', version: '12'),
          (setId: 'moderator', version: '1'),
        ],
      ),
    );

    expect(m.tags['badges'], 'subscriber/12,moderator/1');
  });

  test('a Twitch emote fragment becomes a local emote', () {
    final m = _convert(
      _comment(
        fragments: const [
          VodFragment(text: 'hi '),
          VodFragment(text: 'Kappa', emoteId: '25'),
          VodFragment(text: ' catJAM'),
        ],
      ),
    );

    expect(m.split, ['hi', 'Kappa', 'catJAM']);
    expect(m.localEmotes?.keys, ['Kappa']);
    expect(
      m.localEmotes?['Kappa']?.url,
      'https://static-cdn.jtvnw.net/emoticons/v2/25/default/dark/3.0',
    );
    expect(
      m.localEmotes?.containsKey('catJAM'),
      isFalse,
      reason: '7TV/BTTV/FFZ words stay plain and resolve from the assets store',
    );
  });

  test('emote ranges count UTF-16 code units after an emoji', () {
    final m = _convert(
      _comment(
        fragments: const [
          VodFragment(text: '😂 '),
          VodFragment(text: 'Kappa', emoteId: '25'),
        ],
      ),
    );

    expect(m.localEmotes?.keys, ['Kappa']);
  });

  test('a repeated emote gets both ranges', () {
    final m = _convert(
      _comment(
        fragments: const [
          VodFragment(text: 'Kappa', emoteId: '25'),
          VodFragment(text: ' '),
          VodFragment(text: 'Kappa', emoteId: '25'),
          VodFragment(text: ' '),
          VodFragment(text: 'LUL', emoteId: '425618'),
        ],
      ),
    );

    expect(m.tags['emotes'], '25:0-4,6-10/425618:12-14');
    expect(m.localEmotes?.keys.toSet(), {'Kappa', 'LUL'});
  });

  test('a missing colour sends no color tag', () {
    final m = _convert(_comment(color: null));

    expect(m.tags.containsKey('color'), isFalse);
  });

  test('newlines and carriage returns become spaces', () {
    final m = _convert(
      _comment(fragments: const [VodFragment(text: 'one\ntwo\r\nthree')]),
    );

    expect(m.split, ['one', 'two', 'three']);
  });

  test('a display name with a space or tag separators is escaped', () {
    final m = _convert(_comment(displayName: 'Bad Name;x=1\\s'));

    expect(m.tags['display-name'], 'Bad Namex1s');
    expect(m.tags['user-id'], '1001');
  });

  test('a deleted commenter renders as a deleted user without an id', () {
    final m = _convert(
      _comment(commenterId: null, login: null, displayName: null),
    );

    expect(m.user, 'deleted_user');
    // Data as the chat always had it (a reply quotes it): the name is
    // worded where it shows.
    expect(m.tags['display-name'], 'Deleted user');
    expect(m.tags.containsKey('user-id'), isFalse);
    expect(m.isFromDeletedUser, isTrue);
    expect(m.shownDisplayName(L10n.english), 'Deleted user');
    expect(
      m.shownDisplayName(lookupAppLocalizations(const Locale('fr'))),
      'Utilisateur supprimé',
    );
  });

  test('an account really named deleted_user keeps its own name', () {
    final m = _convert(
      _comment(commenterId: null, login: 'deleted_user', displayName: null),
    );

    expect(m.tags['display-name'], 'deleted_user');
    expect(m.isFromDeletedUser, isFalse);
    expect(
      m.shownDisplayName(lookupAppLocalizations(const Locale('fr'))),
      'deleted_user',
    );
  });

  test('a login that is not a Twitch login is treated as deleted', () {
    final m = _convert(_comment(login: 'evil!x@y PRIVMSG'));

    expect(m.user, 'deleted_user');
    expect(m.command, Command.privateMessage);
  });

  test('a comment without an id uses its dedupe key', () {
    final c = _comment(id: null);
    final m = _convert(c);

    expect(m.tags['id'], isNotEmpty);
    expect(m.tags['id'], isNot(contains(' ')));
  });

  test('mentioning the viewer sets mention', () {
    final m = _convert(
      _comment(fragments: const [VodFragment(text: 'hey @Me_Myself')]),
      viewerLogin: 'me_myself',
    );

    expect(m.mention, isTrue);
  });

  test('an empty or fully stripped display name falls back to the login', () {
    for (final name in ['', ';=\\', ' ']) {
      final m = _convert(_comment(displayName: name));
      expect(m.tags['display-name'], 'viewer_one', reason: name);
    }
  });

  test('a colour that is not #RRGGBB is dropped', () {
    for (final color in ['red', '#FFF', '#GG0000', '#FF000000', '']) {
      final m = _convert(_comment(color: color));
      expect(m.tags.containsKey('color'), isFalse, reason: color);
    }
    expect(_convert(_comment(color: '#a1B2c3')).tags['color'], '#a1B2c3');
  });

  test('badges with separators in them are dropped', () {
    final m = _convert(
      _comment(
        badges: const [
          (setId: 'broadcaster/1,moderator', version: '1'),
          (setId: 'subscriber', version: '12,x'),
          (setId: 'sub-gifter', version: '5'),
        ],
      ),
    );

    expect(m.tags['badges'], 'sub-gifter/5');
  });

  test('an empty message still parses', () {
    final m = _convert(_comment(fragments: const []));

    expect(m.command, Command.privateMessage);
    expect(m.split, isEmpty);
  });
}
