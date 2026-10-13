import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/vod_comment.dart';
import 'package:frosty/screens/vod/vod_comment_cache.dart';

VodComment _c(String id, int second, [String text = 'hi']) => VodComment(
  id: id,
  offsetSeconds: second,
  fragments: [VodFragment(text: text)],
  badges: const [],
);

VodCommentPage _page(List<VodComment> comments, {bool hasNext = true}) =>
    VodCommentPage(comments: comments, hasNextPage: hasNext);

void main() {
  late VodCommentCache cache;

  setUp(() => cache = VodCommentCache());

  group('addPage coverage', () {
    test(
      'a page with more after it covers up to the second before its last',
      () {
        cache.addPage(
          requestedSecond: 10,
          page: _page([_c('a', 10), _c('b', 14), _c('c', 20)]),
          videoLengthSeconds: 100,
        );

        expect(cache.isCovered(9), isFalse);
        expect(cache.isCovered(10), isTrue);
        expect(cache.isCovered(19), isTrue);
        expect(
          cache.isCovered(20),
          isFalse,
          reason: 'the page may stop in the middle of second 20',
        );
        expect(cache.firstUncoveredFrom(10), 20);
      },
    );

    test('the last page covers to the end of the video', () {
      cache.addPage(
        requestedSecond: 90,
        page: _page([_c('a', 91)], hasNext: false),
        videoLengthSeconds: 100,
      );

      expect(cache.isCovered(100), isTrue);
      expect(cache.firstUncoveredFrom(95), 101);
    });

    test('an empty last page covers to the end', () {
      cache.addPage(
        requestedSecond: 50,
        page: _page(const [], hasNext: false),
        videoLengthSeconds: 100,
      );

      expect(cache.isCovered(50), isTrue);
      expect(cache.isCovered(100), isTrue);
      expect(cache.isCovered(49), isFalse);
    });

    test('a page stuck in one busy second still moves past it', () {
      cache.addPage(
        requestedSecond: 30,
        page: _page([for (var i = 0; i < 50; i++) _c('x$i', 30)]),
        videoLengthSeconds: 100,
      );

      expect(cache.isCovered(30), isTrue);
      expect(cache.firstUncoveredFrom(30), 31);
    });

    test('earlier comments in the page do not widen coverage backwards', () {
      cache.addPage(
        requestedSecond: 40,
        page: _page([_c('a', 38), _c('b', 41), _c('c', 45)]),
        videoLengthSeconds: 100,
      );

      expect(cache.isCovered(38), isFalse);
      expect(cache.isCovered(40), isTrue);
      expect(cache.commentsIn(37, 38).map((c) => c.id), ['a']);
    });

    test('overlapping and adjacent ranges merge', () {
      cache.addPage(
        requestedSecond: 0,
        page: _page([_c('a', 0), _c('b', 10)]),
        videoLengthSeconds: 100,
      );
      cache.addPage(
        requestedSecond: 20,
        page: _page([_c('c', 20), _c('d', 30)]),
        videoLengthSeconds: 100,
      );
      expect(cache.firstUncoveredFrom(0), 10);

      cache.addPage(
        requestedSecond: 10,
        page: _page([_c('b', 10), _c('e', 25)]),
        videoLengthSeconds: 100,
      );

      expect(cache.firstUncoveredFrom(0), 30);
    });

    test('never covers past the end of the video', () {
      cache.addPage(
        requestedSecond: 98,
        page: _page([_c('a', 99), _c('b', 140)]),
        videoLengthSeconds: 100,
      );

      expect(cache.firstUncoveredFrom(98), 101);
    });
  });

  group('comments', () {
    test('overlapping pages do not duplicate comments', () {
      cache.addPage(
        requestedSecond: 0,
        page: _page([_c('a', 1), _c('b', 5)]),
        videoLengthSeconds: 100,
      );
      cache.addPage(
        requestedSecond: 5,
        page: _page([_c('b', 5), _c('c', 6)]),
        videoLengthSeconds: 100,
      );

      expect(cache.commentsIn(-1, 10).map((c) => c.id), ['a', 'b', 'c']);
      expect(cache.length, 3);
    });

    test('commentsIn excludes the start and includes the end, in order', () {
      cache.addPage(
        requestedSecond: 0,
        page: _page([
          _c('a', 1),
          _c('b', 2),
          _c('c', 2),
          _c('d', 3),
          _c('e', 4),
        ]),
        videoLengthSeconds: 100,
      );

      expect(cache.commentsIn(1, 3).map((c) => c.id), ['b', 'c', 'd']);
      expect(cache.commentsIn(4, 4), isEmpty);
    });

    test('lastN returns the newest n up to the second, oldest first', () {
      cache.addPage(
        requestedSecond: 0,
        page: _page([for (var i = 0; i < 10; i++) _c('m$i', i)]),
        videoLengthSeconds: 100,
      );

      expect(cache.lastN(6, 3).map((c) => c.id), ['m4', 'm5', 'm6']);
      expect(cache.lastN(1, 5).map((c) => c.id), ['m0', 'm1']);
    });
  });

  group('review', () {
    test('lastN stays inside the covered range of the second', () {
      cache.addPage(
        requestedSecond: 0,
        page: _page([for (var i = 0; i <= 60; i++) _c('a$i', i)]),
        videoLengthSeconds: 1000,
      );
      cache.addPage(
        requestedSecond: 600,
        page: _page([_c('x', 599), _c('y', 600), _c('z', 610)]),
        videoLengthSeconds: 1000,
      );

      expect(cache.lastN(600, 50).map((c) => c.id), ['y']);
    });

    test('a page starting before the requested second covers from the '
        'second after its first comment', () {
      cache.addPage(
        requestedSecond: 600,
        page: _page([_c('x', 595), _c('y', 600), _c('z', 610)]),
        videoLengthSeconds: 1000,
      );

      expect(cache.isCovered(595), isFalse);
      expect(cache.isCovered(596), isTrue);
    });

    test('a later page with earlier comments of a second keeps page order', () {
      cache.addPage(
        requestedSecond: 199,
        page: _page([_c('late', 199), _c('next', 200)]),
        videoLengthSeconds: 1000,
      );
      cache.addPage(
        requestedSecond: 190,
        page: _page([_c('early', 199), _c('late', 199), _c('n2', 205)]),
        videoLengthSeconds: 1000,
      );

      expect(cache.commentsIn(198, 199).map((c) => c.id), ['early', 'late']);
    });
  });

  group('evictFarFrom', () {
    test('drops comments and coverage outside the window', () {
      cache.addPage(
        requestedSecond: 0,
        page: _page([_c('a', 0), _c('b', 50), _c('c', 100), _c('d', 200)]),
        videoLengthSeconds: 1000,
      );

      cache.evictFarFrom(100, keepSeconds: 60);

      expect(cache.commentsIn(-1, 1000).map((c) => c.id), ['b', 'c']);
      expect(cache.isCovered(39), isFalse);
      expect(cache.isCovered(40), isTrue);
      expect(cache.isCovered(160), isTrue);
      expect(cache.isCovered(161), isFalse);
    });

    test('an evicted comment can be added again', () {
      cache.addPage(
        requestedSecond: 0,
        page: _page([_c('a', 0), _c('b', 500)]),
        videoLengthSeconds: 1000,
      );
      cache.evictFarFrom(500, keepSeconds: 10);

      cache.addPage(
        requestedSecond: 0,
        page: _page([_c('a', 0), _c('z', 5)]),
        videoLengthSeconds: 1000,
      );

      expect(cache.commentsIn(-1, 10).map((c) => c.id), ['a', 'z']);
    });

    test('shrinks the window when there are too many comments', () {
      cache.addPage(
        requestedSecond: 0,
        page: _page([for (var i = 0; i < 100; i++) _c('m$i', i)]),
        videoLengthSeconds: 1000,
      );

      cache.evictFarFrom(50, keepSeconds: 1000, maxComments: 20);

      expect(cache.length, lessThanOrEqualTo(20));
      expect(cache.commentsIn(49, 50).map((c) => c.id), ['m50']);
    });
  });
}
