import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/stream_push.dart';

const _stream = StreamTwitch(
  '42',
  'ninja',
  'Ninja',
  '1',
  'Fortnite',
  'Old title',
  100,
  '2026-01-01T00:00:00Z',
  'thumb',
  tags: ['English'],
  language: 'en',
  id: 'b1',
);

void main() {
  group('parseStreamPush', () {
    test('reads a viewer count', () {
      final push = parseStreamPush('viewcount', {
        'type': 'viewcount',
        'viewers': 1234,
      });
      expect(push, isA<ViewerCountPush>());
      expect((push! as ViewerCountPush).viewers, 1234);
    });

    test('ignores a viewer count that is not a number', () {
      expect(parseStreamPush('viewcount', {'viewers': 'x'}), isNull);
      expect(parseStreamPush('viewcount', {'viewers': -3}), isNull);
    });

    test('reads stream up and stream down', () {
      expect(parseStreamPush('stream-down', const {}), isA<StreamDownPush>());
      expect(parseStreamPush('stream-up', const {}), isA<StreamUpPush>());
    });

    test('reads a title and category change', () {
      final push = parseStreamPush('broadcast_settings_update', {
        'status': 'New title',
        'game': 'Chess',
        'game_id': 743,
      });
      expect(push, isA<BroadcastSettingsPush>());
      final settings = push! as BroadcastSettingsPush;
      expect(settings.title, 'New title');
      expect(settings.gameName, 'Chess');
      expect(settings.gameId, '743');
    });

    test('ignores unknown types and empty settings', () {
      expect(parseStreamPush('commercial', const {}), isNull);
      expect(parseStreamPush('broadcast_settings_update', const {}), isNull);
    });
  });

  group('patchStream', () {
    test('patches the viewer count and keeps the rest', () {
      final next = patchStream(_stream, const ViewerCountPush(9));
      expect(next!.viewerCount, 9);
      expect(next.title, 'Old title');
      expect(next.tags, ['English']);
      expect(next.language, 'en');
      expect(next.id, 'b1');
    });

    test('patches the title and category', () {
      final next = patchStream(
        _stream,
        const BroadcastSettingsPush(title: 'T', gameName: 'Chess', gameId: '7'),
      );
      expect(next!.title, 'T');
      expect(next.gameName, 'Chess');
      expect(next.gameId, '7');
      expect(next.viewerCount, 100);
    });

    test('keeps fields a partial change leaves out', () {
      final next = patchStream(
        _stream,
        const BroadcastSettingsPush(title: 'T'),
      );
      expect(next!.gameName, 'Fortnite');
    });

    test('leaves the stream alone when there is none or nothing to patch', () {
      expect(patchStream(null, const ViewerCountPush(9)), isNull);
      expect(patchStream(_stream, const StreamDownPush()), same(_stream));
    });
  });
}
