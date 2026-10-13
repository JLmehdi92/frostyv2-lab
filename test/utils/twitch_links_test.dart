import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/utils/twitch_links.dart';

TwitchLink _p(String s) => TwitchLink.parseText(s);

void main() {
  group('VOD links', () {
    test('videos/<id>', () {
      expect(
        _p('https://www.twitch.tv/videos/123456789'),
        const VodLink('123456789'),
      );
    });

    test('start times', () {
      expect(
        _p('https://www.twitch.tv/videos/1?t=1h2m3s'),
        const VodLink('1', startAt: Duration(seconds: 3723)),
      );
      expect(
        _p('https://twitch.tv/videos/1?t=01h02m03s'),
        const VodLink('1', startAt: Duration(seconds: 3723)),
      );
      expect(
        _p('https://twitch.tv/videos/1?t=90'),
        const VodLink('1', startAt: Duration(seconds: 90)),
      );
      expect(
        _p('https://twitch.tv/videos/1?t=5m'),
        const VodLink('1', startAt: Duration(minutes: 5)),
      );
      expect(_p('https://twitch.tv/videos/1?t=soon'), const VodLink('1'));
    });

    test('other path forms and hosts', () {
      for (final link in [
        'https://m.twitch.tv/videos/1',
        'https://twitch.tv/v/1',
        'https://www.twitch.tv/somechannel/v/1',
        'https://www.twitch.tv/somechannel/video/1',
        'twitch.tv/videos/1',
        'https://WWW.TWITCH.TV/videos/1/',
        'https://www.twitch.tv/videos/1).',
      ]) {
        expect(_p(link), const VodLink('1'), reason: link);
      }
    });

    test('ids must be numbers', () {
      expect(_p('https://twitch.tv/videos/abc'), isA<OtherLink>());
      expect(
        _p('https://twitch.tv/videos/../../x'),
        isNot(isA<VodLink>()),
        reason: 'dot segments are resolved like a browser does',
      );
      expect(_p('https://twitch.tv/videos/${'1' * 21}'), isA<OtherLink>());
    });
  });

  group('channel videos links', () {
    test('filters pick the tab', () {
      expect(
        _p('https://www.twitch.tv/somechannel/videos?filter=highlights'),
        const ChannelVideosLink('somechannel', type: VodType.highlight),
      );
      expect(
        _p('https://www.twitch.tv/somechannel/videos?filter=archives'),
        const ChannelVideosLink('somechannel', type: VodType.archive),
      );
      expect(
        _p('https://www.twitch.tv/somechannel/videos?filter=uploads'),
        const ChannelVideosLink('somechannel', type: VodType.upload),
      );
      expect(
        _p('https://www.twitch.tv/somechannel/videos/archive'),
        const ChannelVideosLink('somechannel', type: VodType.archive),
      );
      expect(
        _p('https://www.twitch.tv/SomeChannel/videos'),
        const ChannelVideosLink('somechannel'),
      );
    });
  });

  group('everything else', () {
    test('a channel is a channel link', () {
      expect(
        _p('https://www.twitch.tv/somechannel'),
        const ChannelLink('somechannel'),
      );
    });

    test('reserved pages are not channels', () {
      for (final page in [
        'directory/game/x',
        'videos',
        'settings',
        'search',
        'p/en/legal',
        'downloads',
        'subscriptions',
        'drops/inventory',
      ]) {
        expect(
          _p('https://www.twitch.tv/$page'),
          isA<OtherLink>(),
          reason: page,
        );
      }
    });

    test('other sites are other links', () {
      expect(_p('https://evil.com/videos/1'), isA<OtherLink>());
      expect(_p('https://twitch.tv.evil.com/videos/1'), isA<OtherLink>());
      expect(
        _p('https://clips.twitch.tv/SomeClip'),
        const ClipLink('SomeClip'),
      );
      expect(_p('not a link'), isA<OtherLink>());
      expect(_p('javascript://twitch.tv/videos/1'), isA<OtherLink>());
      expect(_p('ftp://twitch.tv/videos/1'), isA<OtherLink>());
      expect(_p('http://twitch.tv/videos/1'), const VodLink('1'));
    });
  });

  group('clip links', () {
    const slug = 'InexpensiveHotGrouseNerfBlueBlaster--wdg-mRtFp79lgSC';

    test('every clip URL form, slug case kept', () {
      for (final link in [
        'https://clips.twitch.tv/$slug',
        'https://CLIPS.twitch.tv/$slug',
        'clips.twitch.tv/$slug',
        'https://clips.twitch.tv/embed?clip=$slug&parent=x',
        'https://www.twitch.tv/xqc/clip/$slug',
        'https://twitch.tv/xqc/clip/$slug?filter=clips',
        'https://m.twitch.tv/xqc/clip/$slug',
        'https://m.twitch.tv/clip/$slug',
        'https://clips.twitch.tv/$slug.',
        '(https://clips.twitch.tv/$slug)',
      ]) {
        expect(
          _p(link.startsWith('(') ? link.substring(1) : link),
          const ClipLink(slug),
          reason: link,
        );
      }
    });

    test('not clips', () {
      for (final link in [
        'https://clips.twitch.tv/',
        'https://clips.twitch.tv/a/b',
        'https://clips.twitch.tv/embed',
        'https://clips.twitch.tv/create',
        'https://evil.com/xqc/clip/$slug',
        'https://clips.twitch.tv.evil.com/$slug',
        'https://www.twitch.tv/xqc/clip/-bad',
        'https://www.twitch.tv/xqc/clip/',
      ]) {
        expect(_p(link), isA<OtherLink>(), reason: link);
      }
    });

    test("a channel's clips, with its range", () {
      expect(
        _p('https://www.twitch.tv/xqc/clips'),
        const ChannelClipsLink('xqc'),
      );
      expect(
        _p('https://www.twitch.tv/xqc/clips?range=24hr'),
        const ChannelClipsLink('xqc', period: ClipPeriod.lastDay),
      );
      expect(
        _p('https://www.twitch.tv/xqc/clips?range=7d'),
        const ChannelClipsLink('xqc', period: ClipPeriod.lastWeek),
      );
      expect(
        _p('https://www.twitch.tv/xqc/clips?range=30d'),
        const ChannelClipsLink('xqc', period: ClipPeriod.lastMonth),
      );
      expect(
        _p('https://www.twitch.tv/xqc/clips?range=all'),
        const ChannelClipsLink('xqc', period: ClipPeriod.allTime),
      );
      expect(
        _p('https://www.twitch.tv/xqc/clips?range=bogus'),
        const ChannelClipsLink('xqc'),
      );
      // The old videos page filter.
      expect(
        _p('https://www.twitch.tv/xqc/videos?filter=clips&range=7d'),
        const ChannelClipsLink('xqc', period: ClipPeriod.lastWeek),
      );
    });

    test('clip is not a channel name', () {
      expect(_p('https://www.twitch.tv/clip'), isA<OtherLink>());
    });
  });

  test('a malformed escape is an other link, not an exception', () {
    expect(_p('https://clips.twitch.tv/%9a'), isA<OtherLink>());
    expect(_p('https://www.twitch.tv/%9a'), isA<OtherLink>());
  });
}
