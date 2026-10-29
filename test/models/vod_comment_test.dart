import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/vod_comment.dart';

import '../fixtures/vod_responses.dart';

List<Map<String, dynamic>> _nodes() =>
    ((vodCommentsResponse['data']! as Map)['video']!
            as Map)['comments']['edges']
        .map<Map<String, dynamic>>(
          (e) => Map<String, dynamic>.from(e['node'] as Map),
        )
        .toList();

void main() {
  group('VodComment.fromGql', () {
    test('parses text and emote fragments, badges and colour', () {
      final comment = VodComment.fromGql(_nodes().first);

      expect(comment.id, 'comment-1');
      expect(comment.offsetSeconds, 3591);
      expect(comment.commenterId, '1001');
      expect(comment.commenterLogin, 'viewer_one');
      expect(comment.commenterDisplayName, 'Viewer_One');
      expect(comment.fragments, hasLength(3));
      expect(comment.fragments[1].text, 'Kappa');
      expect(comment.fragments[1].emoteId, '25');
      expect(comment.fragments[0].emoteId, isNull);
      expect(comment.text, 'hello Kappa catJAM');
      expect(comment.badges, [
        (setId: 'subscriber', version: '12'),
        (setId: 'premium', version: '1'),
      ]);
      expect(comment.color, '#FF4500');
    });

    test('tolerates a deleted commenter and missing colour', () {
      final comment = VodComment.fromGql(_nodes()[1]);

      expect(comment.commenterId, isNull);
      expect(comment.commenterLogin, isNull);
      expect(comment.color, isNull);
      expect(comment.badges, isEmpty);
    });

    test('tolerates empty fragments', () {
      final comment = VodComment.fromGql({
        'id': 'x',
        'contentOffsetSeconds': 1,
        'message': {'fragments': <Object>[]},
      });

      expect(comment.fragments, isEmpty);
      expect(comment.text, '');
    });

    test('wrong-typed fields fall back instead of throwing', () {
      final comment = VodComment.fromGql({
        'id': 7,
        'contentOffsetSeconds': '5',
        'commenter': {'id': 9, 'login': 1, 'displayName': false},
        'message': {
          'fragments': [
            {
              'text': 3,
              'emote': {'emoteID': 25},
            },
            {'text': 'ok'},
          ],
          'userBadges': 'none',
          'userColor': 16711680,
        },
      });

      expect(comment.id, isNull);
      expect(comment.offsetSeconds, 0);
      expect(comment.commenterId, isNull);
      expect(comment.commenterLogin, isNull);
      expect(comment.commenterDisplayName, isNull);
      expect(comment.fragments.map((f) => (f.text, f.emoteId)), [
        ('', null),
        ('ok', null),
      ]);
      expect(comment.badges, isEmpty);
      expect(comment.color, isNull);
    });

    test('a non-list fragments field is no fragments', () {
      final comment = VodComment.fromGql({
        'id': 'x',
        'message': {'fragments': 'oops'},
      });

      expect(comment.fragments, isEmpty);
    });

    test('dedupe key falls back when there is no id', () {
      final comment = VodComment.fromGql({
        'contentOffsetSeconds': 5,
        'commenter': {'id': '9', 'login': 'a', 'displayName': 'A'},
        'message': {
          'fragments': [
            {'text': 'hi'},
          ],
        },
      });

      expect(comment.key, '5|9|hi');
    });
  });
}
