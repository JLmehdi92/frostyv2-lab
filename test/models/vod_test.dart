import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/vod.dart';

import '../fixtures/vod_responses.dart';

void main() {
  group('Vod.fromGql', () {
    test('parses an archive', () {
      final vod = Vod.fromGql(vodNodeArchive);

      expect(vod.id, '1000000001');
      expect(vod.title, 'Morning stream');
      expect(vod.lengthSeconds, 29580);
      expect(vod.createdAt, DateTime.utc(2026, 10, 12, 17, 33, 44));
      expect(vod.viewCount, 25919);
      expect(vod.type, VodType.archive);
      expect(vod.gameName, 'Just Chatting');
      expect(vod.gameId, '509658');
      expect(vod.ownerId, '42');
      expect(vod.ownerLogin, 'streamer');
      expect(vod.ownerDisplayName, 'Streamer');
      expect(vod.previewThumbnailUrl, contains('thumb0-320x180.jpg'));
      expect(vod.isRecording, isFalse);
      expect(vod.isRestricted, isFalse);
      expect(vod.duration, const Duration(seconds: 29580));
    });

    test('parses a highlight without game or thumbnail', () {
      final vod = Vod.fromGql(vodNodeHighlightNoGame);

      expect(vod.type, VodType.highlight);
      expect(vod.gameName, isNull);
      expect(vod.previewThumbnailUrl, isNull);
      expect(vod.isRestricted, isTrue);
    });

    test('flags a vod that is still recording', () {
      final vod = Vod.fromGql(vodNodeRecording);

      expect(vod.isRecording, isTrue);
      expect(vod.isRestricted, isFalse, reason: 'missing self defaults off');
    });

    test('takes the owner from the list owner when the node has none', () {
      final node = Map<String, dynamic>.of(vodNodeArchive)..remove('owner');

      final vod = Vod.fromGql(
        node,
        owner: const {'id': '7', 'login': 'other', 'displayName': 'Other'},
      );

      expect(vod.ownerLogin, 'other');
    });

    test('rejects a node without an id', () {
      final node = Map<String, dynamic>.of(vodNodeArchive)..remove('id');

      expect(() => Vod.fromGql(node), throwsFormatException);
    });

    test('unknown broadcast types are null', () {
      final node = Map<String, dynamic>.of(vodNodeArchive)
        ..['broadcastType'] = 'SOMETHING_NEW';

      expect(Vod.fromGql(node).type, isNull);
    });
  });

  test('VodType maps to GQL names', () {
    expect(VodType.archive.gqlName, 'ARCHIVE');
    expect(VodType.highlight.gqlName, 'HIGHLIGHT');
    expect(VodType.upload.gqlName, 'UPLOAD');
  });
}
