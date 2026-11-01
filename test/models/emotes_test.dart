import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/emotes.dart';

void main() {
  group('Emote.fromTwitch', () {
    test('creates emote with correct URL', () {
      final twitchEmote = EmoteTwitch('25', 'Kappa', 'bitstier', null);

      final emote = Emote.fromTwitch(twitchEmote, EmoteType.twitchGlobal);

      expect(
        emote.url,
        'https://static-cdn.jtvnw.net/emoticons/v2/25/default/dark/3.0',
      );
      expect(emote.name, 'Kappa');
      expect(emote.type, EmoteType.twitchGlobal);
      expect(emote.zeroWidth, isFalse);
    });

    test('preserves owner ID when provided', () {
      final twitchEmote = EmoteTwitch(
        '12345',
        'SubEmote',
        'subscriptions',
        '67890',
      );

      final emote = Emote.fromTwitch(twitchEmote, EmoteType.twitchSub);

      expect(emote.ownerId, '67890');
    });

    test('handles null owner ID', () {
      final twitchEmote = EmoteTwitch('25', 'Kappa', 'bitstier', null);

      final emote = Emote.fromTwitch(twitchEmote, EmoteType.twitchGlobal);

      expect(emote.ownerId, isNull);
    });
  });

  group('Emote.fromBTTV', () {
    test('creates emote with correct URL', () {
      final bttvEmote = EmoteBTTV('abc123', 'PogChamp');

      final emote = Emote.fromBTTV(bttvEmote, EmoteType.bttvGlobal);

      expect(emote.url, 'https://cdn.betterttv.net/emote/abc123/3x');
      expect(emote.name, 'PogChamp');
      expect(emote.type, EmoteType.bttvGlobal);
    });

    for (final name in [
      'SoSnowy',
      'IceCold',
      'SantaHat',
      'TopHat',
      'ReinDeer',
      'CandyCane',
      'cvMask',
      'cvHazmat',
    ]) {
      test('marks $name as zero-width', () {
        final emote = Emote.fromBTTV(
          EmoteBTTV('id', name),
          EmoteType.bttvGlobal,
        );
        expect(emote.zeroWidth, isTrue);
      });
    }

    test('regular emotes are not zero-width', () {
      final bttvEmote = EmoteBTTV('regularid', 'RegularEmote');

      final emote = Emote.fromBTTV(bttvEmote, EmoteType.bttvGlobal);

      expect(emote.zeroWidth, isFalse);
    });
  });

  group('Emote.fromFFZ', () {
    test('creates emote with static URL when no animation', () {
      final ffzEmote = EmoteFFZ(
        'TestFFZ',
        28,
        28,
        const OwnerFFZ(displayName: 'Owner', name: 'owner'),
        const ImagesFFZ(
          'https://cdn.ffz.net/1x.png',
          'https://cdn.ffz.net/2x.png',
          'https://cdn.ffz.net/4x.png',
        ),
        null, // No animation
      );

      final emote = Emote.fromFFZ(ffzEmote, EmoteType.ffzChannel);

      expect(emote.url, 'https://cdn.ffz.net/4x.png');
      expect(emote.name, 'TestFFZ');
      expect(emote.type, EmoteType.ffzChannel);
      expect(emote.width, 28);
      expect(emote.height, 28);
      expect(emote.ownerDisplayName, 'Owner');
      expect(emote.ownerUsername, 'owner');
    });

    test('prefers animated URL when available', () {
      final ffzEmote = EmoteFFZ(
        'AnimatedFFZ',
        32,
        32,
        const OwnerFFZ(displayName: 'AnimOwner', name: 'animowner'),
        const ImagesFFZ(
          'https://cdn.ffz.net/static/1x.png',
          'https://cdn.ffz.net/static/2x.png',
          'https://cdn.ffz.net/static/4x.png',
        ),
        const ImagesFFZ(
          'https://cdn.ffz.net/anim/1x.gif',
          'https://cdn.ffz.net/anim/2x.gif',
          'https://cdn.ffz.net/anim/4x.gif',
        ),
      );

      final emote = Emote.fromFFZ(ffzEmote, EmoteType.ffzGlobal);

      expect(emote.url, 'https://cdn.ffz.net/anim/4x.gif');
    });

    test('falls back to 2x then 1x when 4x not available', () {
      final ffzEmote = EmoteFFZ(
        'NoFourX',
        20,
        20,
        const OwnerFFZ(displayName: 'Owner', name: 'owner'),
        const ImagesFFZ(
          'https://cdn.ffz.net/1x.png',
          'https://cdn.ffz.net/2x.png',
          null, // No 4x
        ),
        null,
      );

      final emote = Emote.fromFFZ(ffzEmote, EmoteType.ffzChannel);

      expect(emote.url, 'https://cdn.ffz.net/2x.png');
    });

    test('falls back to 1x when only 1x available', () {
      final ffzEmote = EmoteFFZ(
        'OnlyOneX',
        18,
        18,
        const OwnerFFZ(displayName: 'Owner', name: 'owner'),
        const ImagesFFZ(
          'https://cdn.ffz.net/1x.png',
          null, // No 2x
          null, // No 4x
        ),
        null,
      );

      final emote = Emote.fromFFZ(ffzEmote, EmoteType.ffzChannel);

      expect(emote.url, 'https://cdn.ffz.net/1x.png');
    });

    test('prefers animated fallback chain over static', () {
      final ffzEmote = EmoteFFZ(
        'AnimFallback',
        24,
        24,
        const OwnerFFZ(displayName: 'Owner', name: 'owner'),
        const ImagesFFZ(
          'https://cdn.ffz.net/static/1x.png',
          'https://cdn.ffz.net/static/2x.png',
          'https://cdn.ffz.net/static/4x.png',
        ),
        const ImagesFFZ(
          'https://cdn.ffz.net/anim/1x.gif',
          'https://cdn.ffz.net/anim/2x.gif',
          null, // No animated 4x
        ),
      );

      final emote = Emote.fromFFZ(ffzEmote, EmoteType.ffzGlobal);

      // Should use animated 2x since animated 4x is not available
      expect(emote.url, 'https://cdn.ffz.net/anim/2x.gif');
    });

    test('animated with only 1x falls back to animated 1x', () {
      final ffzEmote = EmoteFFZ(
        'AnimOnly1x',
        24,
        24,
        const OwnerFFZ(displayName: 'Owner', name: 'owner'),
        const ImagesFFZ(
          'https://cdn.ffz.net/static/1x.png',
          'https://cdn.ffz.net/static/2x.png',
          'https://cdn.ffz.net/static/4x.png',
        ),
        const ImagesFFZ(
          'https://cdn.ffz.net/anim/1x.gif',
          null, // No animated 2x
          null, // No animated 4x
        ),
      );

      final emote = Emote.fromFFZ(ffzEmote, EmoteType.ffzGlobal);

      expect(emote.url, 'https://cdn.ffz.net/anim/1x.gif');
    });
  });

  group('Emote.from7TV', () {
    test('creates emote with WEBP URL (filters AVIF)', () {
      final emote7TV = Emote7TV(
        '7tvid123',
        'TestEmote',
        Emote7TVData(
          '7tvid123',
          'TestEmote',
          0, // No flags
          const Owner7TV(username: 'owner', displayName: 'Owner'),
          Emote7TVHost('//cdn.7tv.app/emote/7tvid123', [
            Emote7TVFile('1x.webp', 32, 32, 'WEBP'),
            Emote7TVFile('2x.webp', 64, 64, 'WEBP'),
            Emote7TVFile('3x.webp', 96, 96, 'WEBP'),
            Emote7TVFile('4x.webp', 128, 128, 'WEBP'),
            Emote7TVFile('1x.avif', 32, 32, 'AVIF'),
            Emote7TVFile('2x.avif', 64, 64, 'AVIF'),
            Emote7TVFile('3x.avif', 96, 96, 'AVIF'),
            Emote7TVFile('4x.avif', 128, 128, 'AVIF'),
          ]),
        ),
      );

      final emote = Emote.from7TV(emote7TV, EmoteType.sevenTVChannel);

      // Should use WEBP, not AVIF
      expect(emote.url, contains('webp'));
      expect(emote.url, isNot(contains('avif')));
      expect(emote.url, 'https://cdn.7tv.app/emote/7tvid123/4x.webp');
    });

    test('detects zero-width from flag bit 8 (256)', () {
      final emote7TV = Emote7TV(
        'zw123',
        'ZeroWidth',
        Emote7TVData(
          'zw123',
          'ZeroWidth',
          256, // Bit 8 set = zero-width
          null,
          Emote7TVHost('//cdn.7tv.app/emote/zw123', [
            Emote7TVFile('1x.webp', 32, 32, 'WEBP'),
          ]),
        ),
      );

      final emote = Emote.from7TV(emote7TV, EmoteType.sevenTVGlobal);

      expect(emote.zeroWidth, isTrue);
    });

    test('non-zero-width when flag bit 8 not set', () {
      final emote7TV = Emote7TV(
        'regular123',
        'RegularEmote',
        Emote7TVData(
          'regular123',
          'RegularEmote',
          128, // Different flag, not 256
          null,
          Emote7TVHost('//cdn.7tv.app/emote/regular123', [
            Emote7TVFile('1x.webp', 32, 32, 'WEBP'),
          ]),
        ),
      );

      final emote = Emote.from7TV(emote7TV, EmoteType.sevenTVChannel);

      expect(emote.zeroWidth, isFalse);
    });

    test('sets realName when different from emote name', () {
      final emote7TV = Emote7TV(
        'alias123',
        'AliasName', // The alias used in channel
        Emote7TVData(
          'alias123',
          'OriginalName', // The original name
          0,
          null,
          Emote7TVHost('//cdn.7tv.app/emote/alias123', [
            Emote7TVFile('1x.webp', 32, 32, 'WEBP'),
          ]),
        ),
      );

      final emote = Emote.from7TV(emote7TV, EmoteType.sevenTVChannel);

      expect(emote.name, 'AliasName');
      expect(emote.realName, 'OriginalName');
    });

    test('realName is null when name matches', () {
      final emote7TV = Emote7TV(
        'same123',
        'SameName',
        Emote7TVData(
          'same123',
          'SameName', // Same as emote.name
          0,
          null,
          Emote7TVHost('//cdn.7tv.app/emote/same123', [
            Emote7TVFile('1x.webp', 32, 32, 'WEBP'),
          ]),
        ),
      );

      final emote = Emote.from7TV(emote7TV, EmoteType.sevenTVGlobal);

      expect(emote.name, 'SameName');
      expect(emote.realName, isNull);
    });

    test('extracts owner info when available', () {
      final emote7TV = Emote7TV(
        'owned123',
        'OwnedEmote',
        Emote7TVData(
          'owned123',
          'OwnedEmote',
          0,
          const Owner7TV(username: 'creator', displayName: 'EmoteCreator'),
          Emote7TVHost('//cdn.7tv.app/emote/owned123', [
            Emote7TVFile('1x.webp', 32, 32, 'WEBP'),
          ]),
        ),
      );

      final emote = Emote.from7TV(emote7TV, EmoteType.sevenTVChannel);

      expect(emote.ownerUsername, 'creator');
      expect(emote.ownerDisplayName, 'EmoteCreator');
    });

    test('handles null owner', () {
      final emote7TV = Emote7TV(
        'noowner123',
        'NoOwner',
        Emote7TVData(
          'noowner123',
          'NoOwner',
          0,
          null, // No owner
          Emote7TVHost('//cdn.7tv.app/emote/noowner123', [
            Emote7TVFile('1x.webp', 32, 32, 'WEBP'),
          ]),
        ),
      );

      final emote = Emote.from7TV(emote7TV, EmoteType.sevenTVGlobal);

      expect(emote.ownerUsername, isNull);
      expect(emote.ownerDisplayName, isNull);
    });

    test('uses first file dimensions', () {
      final emote7TV = Emote7TV(
        'dim123',
        'Dimensions',
        Emote7TVData(
          'dim123',
          'Dimensions',
          0,
          null,
          Emote7TVHost('//cdn.7tv.app/emote/dim123', [
            Emote7TVFile('1x.webp', 28, 32, 'WEBP'),
            Emote7TVFile('2x.webp', 56, 64, 'WEBP'),
          ]),
        ),
      );

      final emote = Emote.from7TV(emote7TV, EmoteType.sevenTVChannel);

      expect(emote.width, 28);
      expect(emote.height, 32);
    });

    test('handles empty file list', () {
      final emote7TV = Emote7TV(
        'empty123',
        'EmptyFiles',
        Emote7TVData(
          'empty123',
          'EmptyFiles',
          0,
          null,
          Emote7TVHost(
            '//cdn.7tv.app/emote/empty123',
            [], // No files
          ),
        ),
      );

      final emote = Emote.from7TV(emote7TV, EmoteType.sevenTVGlobal);

      // Should return empty URL when no files
      expect(emote.url, '');
      expect(emote.width, isNull);
      expect(emote.height, isNull);
    });

    test('filters AVIF-only files and returns empty URL', () {
      final emote7TV = Emote7TV(
        'avifonly123',
        'AvifOnly',
        Emote7TVData(
          'avifonly123',
          'AvifOnly',
          0,
          null,
          Emote7TVHost('//cdn.7tv.app/emote/avifonly123', [
            Emote7TVFile('1x.avif', 32, 32, 'AVIF'),
            Emote7TVFile('2x.avif', 64, 64, 'AVIF'),
          ]),
        ),
      );

      final emote = Emote.from7TV(emote7TV, EmoteType.sevenTVChannel);

      // All files are AVIF, so should return empty URL
      expect(emote.url, '');
    });
  });

  group('EmoteType', () {
    test('toString returns human-readable string', () {
      expect(EmoteType.twitchBits.toString(), 'Twitch bits emote');
      expect(EmoteType.twitchFollower.toString(), 'Twitch follower emote');
      expect(EmoteType.twitchSub.toString(), 'Twitch sub emote');
      expect(EmoteType.twitchGlobal.toString(), 'Twitch global emote');
      expect(EmoteType.twitchUnlocked.toString(), 'Twitch unlocked emote');
      expect(EmoteType.twitchChannel.toString(), 'Twitch channel emote');
      expect(EmoteType.ffzGlobal.toString(), 'FrankerFaceZ global emote');
      expect(EmoteType.ffzChannel.toString(), 'FrankerFaceZ channel emote');
      expect(EmoteType.bttvGlobal.toString(), 'BetterTTV global emote');
      expect(EmoteType.bttvChannel.toString(), 'BetterTTV channel emote');
      expect(EmoteType.bttvShared.toString(), 'BetterTTV shared emote');
      expect(EmoteType.sevenTVGlobal.toString(), '7TV global emote');
      expect(EmoteType.sevenTVChannel.toString(), '7TV channel emote');
    });
  });

  group('EmoteBTTVChannel', () {
    test('combines channel and shared emotes', () {
      final json = {
        'channelEmotes': [
          {'id': 'ch1', 'code': 'ChannelEmote'},
        ],
        'sharedEmotes': [
          {'id': 'sh1', 'code': 'SharedEmote1'},
          {'id': 'sh2', 'code': 'SharedEmote2'},
        ],
      };

      final result = EmoteBTTVChannel.fromJson(json);

      expect(result.channelEmotes.length, 1);
      expect(result.channelEmotes.first.code, 'ChannelEmote');
      expect(result.sharedEmotes.length, 2);
      expect(result.sharedEmotes.first.code, 'SharedEmote1');
    });
  });

  group('Emote JSON serialization', () {
    test('roundtrip serialization works', () {
      const original = Emote(
        name: 'TestEmote',
        realName: 'RealName',
        width: 32,
        height: 32,
        zeroWidth: true,
        url: 'https://example.com/emote.png',
        type: EmoteType.sevenTVChannel,
        ownerDisplayName: 'Owner',
        ownerUsername: 'owner',
        ownerId: '12345',
      );

      final json = original.toJson();
      final restored = Emote.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.realName, original.realName);
      expect(restored.width, original.width);
      expect(restored.height, original.height);
      expect(restored.zeroWidth, original.zeroWidth);
      expect(restored.url, original.url);
      expect(restored.type, original.type);
      expect(restored.ownerDisplayName, original.ownerDisplayName);
      expect(restored.ownerUsername, original.ownerUsername);
      expect(restored.ownerId, original.ownerId);
    });
  });

  group('still frames', () {
    test('Twitch has one for every emote', () {
      final emote = Emote.fromTwitch(
        EmoteTwitch('25', 'Kappa', 'bitstier', null),
        EmoteType.twitchGlobal,
      );
      expect(
        emote.urlFor(animate: false),
        'https://static-cdn.jtvnw.net/emoticons/v2/25/static/dark/3.0',
      );
      expect(emote.urlFor(animate: true), emote.url);
    });

    test('BTTV only for GIFs', () {
      final gif = Emote.fromBTTV(
        const EmoteBTTV('5f1b', 'catJAM', animated: true),
        EmoteType.bttvShared,
      );
      final png = Emote.fromBTTV(
        const EmoteBTTV('566c', 'FeelsBadMan'),
        EmoteType.bttvGlobal,
      );
      expect(
        gif.urlFor(animate: false),
        'https://cdn.betterttv.net/emote/5f1b/static/3x.webp',
      );
      expect(png.staticUrl, isNull);
      expect(png.urlFor(animate: false), png.url);
      expect(
        EmoteBTTV.fromJson({'id': '1', 'code': 'a', 'animated': true}).animated,
        isTrue,
      );
      expect(EmoteBTTV.fromJson({'id': '1', 'code': 'a'}).animated, isFalse);
    });

    test('FFZ uses the plain image of an animated emote', () {
      final emote = Emote.fromFFZ(
        const EmoteFFZ(
          'A',
          32,
          32,
          OwnerFFZ(displayName: 'O', name: 'o'),
          ImagesFFZ('https://ffz/1.png', null, 'https://ffz/4.png'),
          ImagesFFZ('https://ffz/a1.webp', null, 'https://ffz/a4.webp'),
        ),
        EmoteType.ffzChannel,
      );
      expect(emote.url, 'https://ffz/a4.webp');
      expect(emote.urlFor(animate: false), 'https://ffz/4.png');
    });

    test('7TV uses the file\'s still twin', () {
      final emote = Emote.from7TV(
        Emote7TV(
          'id',
          'catJAM',
          Emote7TVData(
            'id',
            'catJAM',
            0,
            null,
            Emote7TVHost('//cdn.7tv.app/emote/id', [
              Emote7TVFile(
                '1x.webp',
                32,
                32,
                'WEBP',
                staticName: '1x_static.webp',
              ),
              Emote7TVFile(
                '4x.webp',
                128,
                128,
                'WEBP',
                staticName: '4x_static.webp',
              ),
            ]),
          ),
        ),
        EmoteType.sevenTVChannel,
      );
      expect(
        emote.urlFor(animate: false),
        'https://cdn.7tv.app/emote/id/4x_static.webp',
      );
      expect(
        Emote7TVFile.fromJson({
          'name': '1x.webp',
          'static_name': '1x_static.webp',
          'width': 1,
          'height': 1,
          'format': 'WEBP',
        }).staticName,
        '1x_static.webp',
      );
    });

    test('a saved emote keeps its still frame', () {
      final emote = Emote.fromTwitch(
        EmoteTwitch('25', 'Kappa', 'bitstier', null),
        EmoteType.twitchGlobal,
      );
      expect(Emote.fromJson(emote.toJson()).staticUrl, emote.staticUrl);
      expect(
        Emote.fromJson({
          'name': 'old',
          'zeroWidth': false,
          'url': 'https://x/1.png',
          'type': 'twitchGlobal',
        }).urlFor(animate: false),
        'https://x/1.png',
      );
    });
  });

  group('unlock hints', () {
    Emote twitch(String type, EmoteType kind, {String? tier}) =>
        Emote.fromTwitch(EmoteTwitch('1', 'E', type, '9', tier: tier), kind);

    test('say how a viewer gets each Twitch emote', () {
      expect(
        twitch(
          'subscriptions',
          EmoteType.twitchChannel,
          tier: '2000',
        ).unlockHint(L10n.english),
        'Subscribe to this channel at Tier 2 to use it.',
      );
      expect(
        twitch(
          'subscriptions',
          EmoteType.twitchChannel,
          tier: '',
        ).unlockHint(L10n.english),
        'Subscribe to this channel to use it.',
      );
      expect(
        twitch('follower', EmoteType.twitchFollower).unlockHint(L10n.english),
        'Follow this channel to use it.',
      );
      expect(
        twitch('bitstier', EmoteType.twitchBits).unlockHint(L10n.english),
        'Cheer Bits in this channel to unlock it.',
      );
      expect(
        twitch('globals', EmoteType.twitchGlobal).unlockHint(L10n.english),
        'Available to everyone on Twitch.',
      );
      expect(
        twitch('subscriptions', EmoteType.twitchSub).unlockHint(L10n.english),
        'You can use it.',
      );
    });

    test('third-party emotes have none', () {
      expect(
        Emote.fromBTTV(
          const EmoteBTTV('1', 'a'),
          EmoteType.bttvGlobal,
        ).unlockHint(L10n.english),
        isNull,
      );
    });

    test('the tier comes from Helix and survives saving', () {
      final parsed = EmoteTwitch.fromJson({
        'id': '1',
        'name': 'E',
        'emote_type': 'subscriptions',
        'tier': '3000',
      });
      final emote = Emote.fromTwitch(parsed, EmoteType.twitchChannel);
      expect(emote.subTier, 3);
      expect(Emote.fromJson(emote.toJson()).subTier, 3);
    });
  });
}
