import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/utils/twitch_links.dart';

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

    test('a collection queue rides with the video', () {
      expect(
        _p('https://www.twitch.tv/videos/1?collection=Ab_c-12'),
        const VodLink('1', collectionId: 'Ab_c-12'),
      );
      expect(
        _p('https://www.twitch.tv/videos/1?collection=bad/id'),
        const VodLink('1'),
      );
      expect(
        const VodLink('1', collectionId: 'a'),
        isNot(const VodLink('1')),
      );
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
        'videos',
        'settings',
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

  group('category links', () {
    test('directory/category/<slug>, and the old directory/game/<name>', () {
      expect(
        _p('https://www.twitch.tv/directory/category/just-chatting'),
        const CategoryLink(slug: 'just-chatting'),
      );
      expect(
        _p('twitch.tv/directory/category/grand-theft-auto-v?sort=VIEWERS'),
        const CategoryLink(slug: 'grand-theft-auto-v'),
      );
      expect(
        _p('https://m.twitch.tv/directory/game/Just%20Chatting'),
        const CategoryLink(name: 'Just Chatting'),
      );
      // A category is never mistaken for a channel named "directory".
      expect(
        _p('https://www.twitch.tv/directory/category/chess'),
        isNot(isA<ChannelLink>()),
      );
      // Chat keeps launching them; the deep link handler opens them.
      expect(_p('twitch.tv/directory/category/chess').opensInApp, isFalse);
    });

    test('not category links', () {
      for (final page in [
        'directory/category',
        'directory/category/Bad%20Slug!',
        'directory/category/chess/clips/extra/more',
        'directory/game/',
      ]) {
        expect(
          _p('https://www.twitch.tv/$page'),
          isA<OtherLink>(),
          reason: page,
        );
      }
    });

    test('a name that would leave the category page is not one', () {
      for (final page in [
        'directory/game/..%2F..%2Fsettings%2Fconnections',
        'directory/game/a%2Fb',
        'directory/game/..',
        'directory/game/a%5Cb',
      ]) {
        expect(
          _p('https://www.twitch.tv/$page'),
          isA<OtherLink>(),
          reason: page,
        );
      }
    });

    test('its twitch.tv page keeps the name in one segment', () {
      final byName = twitchCategoryUrl(
        const CategoryLink(name: 'Just Chatting'),
      );
      expect(byName.host, 'www.twitch.tv');
      expect(byName.pathSegments, ['directory', 'game', 'Just Chatting']);
      final odd = twitchCategoryUrl(const CategoryLink(name: 'a/../b?c#d'));
      expect(odd.pathSegments, ['directory', 'game', 'a/../b?c#d']);
      expect(odd.query, isEmpty);
      expect(odd.fragment, isEmpty);
      expect(
        twitchCategoryUrl(const CategoryLink(slug: 'chess')).toString(),
        'https://www.twitch.tv/directory/category/chess',
      );
    });

    test("a category name's slug, as twitch.tv writes it", () {
      expect(twitchCategorySlug('Just Chatting'), 'just-chatting');
      expect(twitchCategorySlug('Grand Theft Auto V'), 'grand-theft-auto-v');
      expect(
        twitchCategorySlug("Tom Clancy's Rainbow Six Siege"),
        'tom-clancys-rainbow-six-siege',
      );
      expect(
        twitchCategorySlug('Pokémon Legends: Arceus'),
        'pokemon-legends-arceus',
      );
      expect(twitchCategorySlug('  Art  '), 'art');
      expect(twitchCategorySlug('Straße Œuvre Łódź'), 'strasse-oeuvre-lodz');
      expect(twitchCategorySlug('Ratchet & Clank'), 'ratchet-clank');
    });
  });

  group('profile links', () {
    test('about and schedule open the profile in-app', () {
      final about = _p('https://www.twitch.tv/xqc/about');
      expect(about, const ChannelProfileLink('xqc', ProfileSection.about));
      expect(about.opensInApp, isTrue);
      expect(
        _p('twitch.tv/lirik/schedule'),
        const ChannelProfileLink('lirik', ProfileSection.schedule),
      );
      expect(
        _p('https://www.twitch.tv/xqc/About'),
        const ChannelProfileLink('xqc', ProfileSection.about),
      );
    });

    test('other pages and reserved names do not', () {
      expect(_p('https://www.twitch.tv/xqc/about/more'), isA<OtherLink>());
      expect(_p('https://www.twitch.tv/directory/about'), isA<OtherLink>());
      expect(_p('https://www.twitch.tv/team/about'), isA<OtherLink>());
      expect(_p('https://www.twitch.tv/xqc'), const ChannelLink('xqc'));
    });
  });

  test('followChannel=true asks to follow the channel', () {
    expect(
      _p('https://www.twitch.tv/xqc?followChannel=true'),
      const ChannelLink('xqc', followRequested: true),
    );
    expect(
      _p('https://www.twitch.tv/xqc?followChannel=false'),
      const ChannelLink('xqc'),
    );
    expect(
      _p('https://www.twitch.tv/xqc/videos?followChannel=true'),
      isNot(const ChannelLink('xqc', followRequested: true)),
    );
  });

  group('app destinations', () {
    test('browse, following and activity', () {
      expect(_p('https://www.twitch.tv/directory'), const BrowseLink());
      expect(
        _p('https://www.twitch.tv/directory/following'),
        const FollowingLink(),
      );
      expect(
        _p('https://www.twitch.tv/directory/following/live'),
        const FollowingLink(),
      );
      expect(_p('https://www.twitch.tv/following'), const FollowingLink());
      expect(_p('https://www.twitch.tv/activity'), const ActivityLink());
    });

    test('search with a term', () {
      expect(
        _p('https://www.twitch.tv/search?term=speed%20runs'),
        const SearchLink('speed runs'),
      );
      expect(_p('https://www.twitch.tv/search'), const SearchLink(''));
      expect(
        _p('https://www.twitch.tv/search?term=${'a' * 300}'),
        SearchLink('a' * 100),
      );
    });

    test("a channel's chat", () {
      expect(
        _p('https://www.twitch.tv/Streamer/chat'),
        const ChannelChatLink('streamer'),
      );
      expect(
        _p('https://www.twitch.tv/popout/streamer/chat'),
        isA<OtherLink>(),
      );
    });

    test('a video with a comment or in a collection', () {
      expect(
        _p('https://www.twitch.tv/videos/12?comment=abc'),
        const VodLink('12'),
      );
      expect(
        _p('https://www.twitch.tv/videos/12?collection=Xy_9-a'),
        const VodLink('12', collectionId: 'Xy_9-a'),
      );
    });

    test('a collection', () {
      expect(
        _p('https://www.twitch.tv/collections/Xy_9-a'),
        const CollectionLink('Xy_9-a'),
      );
      expect(_p('https://www.twitch.tv/collections/a%2Fb'), isA<OtherLink>());
      expect(_p('https://www.twitch.tv/collections'), isA<OtherLink>());
    });

    test("a category's videos", () {
      expect(
        _p('https://www.twitch.tv/directory/category/just-chatting/videos'),
        const CategoryVideosLink(CategoryLink(slug: 'just-chatting')),
      );
      expect(
        _p('https://www.twitch.tv/directory/game/Just%20Chatting/videos/all'),
        const CategoryVideosLink(CategoryLink(name: 'Just Chatting')),
      );
      expect(
        _p('https://www.twitch.tv/directory/category/just-chatting/clips'),
        isA<OtherLink>(),
      );
    });

    test('opened by the deep link handler, not from chat', () {
      for (final link in const <TwitchLink>[
        BrowseLink(),
        FollowingLink(),
        ActivityLink(),
        SearchLink('x'),
        ChannelChatLink('x'),
        CollectionLink('x'),
        CategoryVideosLink(CategoryLink(slug: 'x')),
      ]) {
        expect(link.opensInApp, isFalse, reason: '$link');
      }
    });
  });

  group('app schemes and go.twitch.tv', () {
    test('twitch:// and ttv:// name the same pages', () {
      for (final scheme in ['twitch', 'ttv']) {
        expect(_p('$scheme://stream/Streamer'), const ChannelLink('streamer'));
        expect(_p('$scheme://channel/streamer'), const ChannelLink('streamer'));
        expect(_p('$scheme://profile/streamer'), const ChannelLink('streamer'));
        expect(
          _p('$scheme://open?stream=streamer'),
          const ChannelLink('streamer'),
        );
        expect(_p('$scheme://open'), const FollowingLink());
        expect(_p('$scheme://following'), const FollowingLink());
        expect(_p('$scheme://directory'), const BrowseLink());
        expect(_p('$scheme://activity'), const ActivityLink());
        expect(_p('$scheme://search?query=chess'), const SearchLink('chess'));
        expect(_p('$scheme://search?term=chess'), const SearchLink('chess'));
        expect(
          _p('$scheme://video/123?t=1m'),
          const VodLink('123', startAt: Duration(minutes: 1)),
        );
        expect(
          _p('$scheme://game/Just%20Chatting'),
          const CategoryLink(name: 'Just Chatting'),
        );
        expect(
          _p('$scheme://directory/game/Chess'),
          const CategoryLink(name: 'Chess'),
        );
        expect(
          _p('$scheme://game/Chess/videos'),
          const CategoryVideosLink(CategoryLink(name: 'Chess')),
        );
      }
    });

    test('unknown or unsafe app links are not opened', () {
      expect(_p('twitch://login'), isA<OtherLink>());
      expect(_p('twitch://stream'), isA<OtherLink>());
      expect(_p('twitch://stream/not a login'), isA<OtherLink>());
      expect(_p('twitch://video/abc'), isA<OtherLink>());
      expect(_p('ttv://user/x'), isA<OtherLink>());
      expect(_p('other://stream/streamer'), isA<OtherLink>());
    });

    test('go.twitch.tv is twitch.tv', () {
      expect(
        _p('https://go.twitch.tv/streamer'),
        const ChannelLink('streamer'),
      );
      expect(_p('https://go.twitch.tv/videos/5'), const VodLink('5'));
    });

    test('the web address of an app link', () {
      expect(
        TwitchLink.webUri(Uri.parse('twitch://stream/streamer')),
        Uri.parse('https://www.twitch.tv/streamer'),
      );
      expect(
        TwitchLink.webUri(Uri.parse('ttv://search?query=a%20b')),
        Uri.https('www.twitch.tv', '/search', {'term': 'a b'}),
      );
      expect(
        TwitchLink.webUri(Uri.parse('https://m.twitch.tv/x')),
        Uri.parse('https://m.twitch.tv/x'),
      );
      expect(TwitchLink.webUri(Uri.parse('twitch://login')), isNull);
    });
  });
}
