import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/vod_chapter.dart';

Map<String, Object?> _node({
  num position = 0,
  num duration = 60000,
  String? game = 'Chess',
  String? description,
}) => {
  'positionMilliseconds': position,
  'durationMilliseconds': duration,
  'description': ?description,
  'details': {
    'game': {
      'id': '743',
      'displayName': game,
      'boxArtURL': 'https://static-cdn.jtvnw.net/art.jpg',
    },
  },
};

void main() {
  test('reads a game chapter', () {
    final chapter = VodChapter.tryParse(_node(position: 5000))!;
    expect(chapter.start, const Duration(seconds: 5));
    expect(chapter.end, const Duration(seconds: 65));
    expect(chapter.title, 'Chess');
    expect(chapter.gameId, '743');
    expect(chapter.boxArtUrl, startsWith('https://'));
  });

  test('falls back to the description when the game has no name', () {
    final chapter = VodChapter.tryParse(
      _node(game: null, description: 'Just Chatting'),
    )!;
    expect(chapter.title, 'Just Chatting');
  });

  test('refuses nodes without a position or a title', () {
    expect(VodChapter.tryParse('x'), isNull);
    expect(VodChapter.tryParse(_node(position: -1)), isNull);
    expect(VodChapter.tryParse(_node(game: ' ')), isNull);
    expect(VodChapter.tryParse({'positionMilliseconds': 0}), isNull);
  });

  test('finds the chapter playing at a time', () {
    final chapters = sortedChapters([
      VodChapter.tryParse(_node(position: 60000, game: 'B'))!,
      VodChapter.tryParse(_node(game: 'A'))!,
    ]);
    expect(chapters.map((c) => c.title), ['A', 'B']);
    expect(chapterAt(chapters, const Duration(seconds: 30))?.title, 'A');
    expect(chapterAt(chapters, const Duration(seconds: 90))?.title, 'B');
    expect(chapterAt(const [], Duration.zero), isNull);
  });
}
