import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/third_party_cosmetics.dart';

int _rgba(int r, int g, int b, int a) =>
    ((r << 24) | (g << 16) | (b << 8) | a).toSigned(32);

void main() {
  group('7TV colors', () {
    test('a packed RGBA integer, signed or not, becomes its color', () {
      expect(
        colorFromRgbaInt(_rgba(255, 0, 128, 255)),
        const Color.fromARGB(255, 255, 0, 128),
      );
      expect(
        colorFromRgbaInt(_rgba(10, 20, 30, 128)),
        const Color.fromARGB(128, 10, 20, 30),
      );
    });

    test('hex colors read with or without alpha', () {
      expect(colorFromHex('#39D21EFF'), const Color(0xFF39D21E));
      expect(colorFromHex('#00555780'), const Color(0x80005557));
      expect(colorFromHex('#112233'), const Color(0xFF112233));
      expect(colorFromHex('nope'), isNull);
      expect(colorFromHex(null), isNull);
    });
  });

  group('NamePaint.fromEventApi', () {
    test('reads a linear gradient with its stops and shadows', () {
      final paint = NamePaint.fromEventApi({
        'id': 'p1',
        'name': 'Sunset',
        'function': 'LINEAR_GRADIENT',
        'angle': 45,
        'repeat': true,
        'stops': [
          {'at': 0, 'color': _rgba(255, 0, 0, 255)},
          {'at': 1, 'color': _rgba(0, 0, 255, 255)},
        ],
        'shadows': [
          {
            'x_offset': 1,
            'y_offset': 2,
            'radius': 3,
            'color': _rgba(0, 0, 0, 255),
          },
        ],
      })!;

      expect(paint.kind, NamePaintKind.linearGradient);
      expect(paint.angle, 45);
      expect(paint.repeating, isTrue);
      expect(paint.stops.map((stop) => stop.color), [
        const Color(0xFFFF0000),
        const Color(0xFF0000FF),
      ]);
      expect(paint.shadows.single.offset, const Offset(1, 2));
      expect(paint.shadows.single.blurRadius, 3);
      expect(paint.isDrawable, isTrue);
      expect(
        paint.gradientShader(const Rect.fromLTWH(0, 0, 40, 10)),
        isNotNull,
      );
    });

    test('reads a radial gradient from the gradients list', () {
      final paint = NamePaint.fromEventApi({
        'id': 'p2',
        'gradients': [
          {
            'function': 'RADIAL_GRADIENT',
            'stops': [
              {'at': 0, 'color': _rgba(255, 255, 0, 255)},
              {'at': 1, 'color': _rgba(0, 255, 0, 255)},
            ],
          },
        ],
      })!;

      expect(paint.kind, NamePaintKind.radialGradient);
      expect(paint.isDrawable, isTrue);
    });

    test('an image paint keeps only an https address', () {
      final paint = NamePaint.fromEventApi({
        'id': 'p3',
        'function': 'URL',
        'image_url': '//cdn.7tv.app/paint/p3/layer/1x.webp',
      })!;
      expect(paint.kind, NamePaintKind.image);
      expect(paint.imageUrl, 'https://cdn.7tv.app/paint/p3/layer/1x.webp');

      final unsafe = NamePaint.fromEventApi({
        'id': 'p4',
        'function': 'URL',
        'image_url': 'http://example.com/x.webp',
      })!;
      expect(unsafe.imageUrl, isNull);
      expect(unsafe.isDrawable, isFalse);
    });

    test('an unknown kind without a color is no paint', () {
      expect(NamePaint.fromEventApi({'id': 'p5', 'function': 'X'}), isNull);
      expect(NamePaint.fromEventApi({'function': 'URL'}), isNull);
    });
  });

  group('NamePaint.fromGql', () {
    test('reads an image layer, preferring a still webp', () {
      final paint = NamePaint.fromGql({
        'id': 'g1',
        'name': 'Emerald',
        'data': {
          'layers': [
            {
              'opacity': 1.0,
              'ty': {
                '__typename': 'PaintLayerTypeImage',
                'images': [
                  {
                    'url': 'https://cdn.7tv.app/a/1x.avif',
                    'mime': 'image/avif',
                    'scale': 1,
                    'frameCount': 1,
                  },
                  {
                    'url': 'https://cdn.7tv.app/a/3x.webp',
                    'mime': 'image/webp',
                    'scale': 3,
                    'frameCount': 40,
                  },
                  {
                    'url': 'https://cdn.7tv.app/a/3x_static.webp',
                    'mime': 'image/webp',
                    'scale': 3,
                    'frameCount': 1,
                  },
                  {
                    'url': 'https://cdn.7tv.app/a/4x_static.webp',
                    'mime': 'image/webp',
                    'scale': 4,
                    'frameCount': 1,
                  },
                ],
              },
            },
          ],
          'shadows': [
            {
              'color': {'hex': '#39D21EFF'},
              'offsetX': 0.0,
              'offsetY': 1.0,
              'blur': 0.1,
            },
          ],
        },
      })!;

      expect(paint.kind, NamePaintKind.image);
      expect(paint.imageUrl, 'https://cdn.7tv.app/a/3x_static.webp');
      expect(paint.shadows.single.color, const Color(0xFF39D21E));
    });

    test('reads a linear gradient layer', () {
      final paint = NamePaint.fromGql({
        'id': 'g2',
        'data': {
          'layers': [
            {
              'ty': {
                '__typename': 'PaintLayerTypeLinearGradient',
                'angle': 90,
                'repeating': false,
                'stops': [
                  {
                    'at': 0.0,
                    'color': {'hex': '#FF0000FF'},
                  },
                  {
                    'at': 1.0,
                    'color': {'hex': '#0000FFFF'},
                  },
                ],
              },
            },
          ],
        },
      })!;
      expect(paint.kind, NamePaintKind.linearGradient);
      expect(paint.stops, hasLength(2));
      expect(paint.fallbackColor, const Color(0xFFFF0000));
    });

    test('a paint without layers is none', () {
      expect(
        NamePaint.fromGql({
          'id': 'g3',
          'data': {'layers': <Object>[]},
        }),
        isNull,
      );
    });
  });

  group('7TV badges', () {
    test('from the event API, the 3x file of the host', () {
      final badge = sevenTvBadgeFromEventApi({
        'id': 'b1',
        'tooltip': '7TV Subscriber',
        'host': {
          'url': '//cdn.7tv.app/badge/b1',
          'files': [
            {'name': '1x.webp', 'format': 'WEBP'},
            {'name': '3x.avif', 'format': 'AVIF'},
            {'name': '3x.webp', 'format': 'WEBP'},
          ],
        },
      })!;
      expect(badge.name, '7TV Subscriber');
      expect(badge.url, 'https://cdn.7tv.app/badge/b1/3x.webp');
      expect(badge.type, BadgeType.sevenTV);
    });

    test('a host that is not https is refused', () {
      expect(
        sevenTvBadgeFromEventApi({
          'tooltip': 'x',
          'host': {'url': 'http://evil.example/badge', 'files': <Object>[]},
        }),
        isNull,
      );
    });

    test('from GQL, the largest webp up to 3x', () {
      final badge = sevenTvBadgeFromGql({
        'description': 'Event winner',
        'images': [
          {
            'url': 'https://cdn.7tv.app/badge/b2/2x.webp',
            'mime': 'image/webp',
            'scale': 2,
            'frameCount': 1,
          },
          {
            'url': 'https://cdn.7tv.app/badge/b2/3x.webp',
            'mime': 'image/webp',
            'scale': 3,
            'frameCount': 1,
          },
          {
            'url': 'https://cdn.7tv.app/badge/b2/4x.webp',
            'mime': 'image/webp',
            'scale': 4,
            'frameCount': 1,
          },
        ],
      })!;
      expect(badge.url, 'https://cdn.7tv.app/badge/b2/3x.webp');
      expect(badge.name, 'Event winner');
    });
  });

  group('SevenTvUserCosmetics.fromGql', () {
    test('reads a paint, a badge and personal emotes', () {
      final cosmetics = SevenTvUserCosmetics.fromGql({
        'style': {
          'activePaint': {
            'id': 'p',
            'data': {
              'layers': [
                {
                  'ty': {
                    '__typename': 'PaintLayerTypeSingleColor',
                    'color': {'hex': '#C8FF3DFF'},
                  },
                },
              ],
            },
          },
          'activeBadge': {
            'name': 'Sub',
            'images': [
              {
                'url': 'https://cdn.7tv.app/badge/s/3x.webp',
                'mime': 'image/webp',
                'scale': 3,
                'frameCount': 1,
              },
            ],
          },
        },
        'personalEmoteSet': {
          'id': 'set1',
          'emotes': {
            'items': [
              {
                'alias': 'myPet',
                'flags': {'zeroWidth': false},
                'emote': {
                  'id': 'e1',
                  'defaultName': 'catPet',
                  'flags': {'defaultZeroWidth': false},
                  'images': [
                    {
                      'url': 'https://cdn.7tv.app/emote/e1/3x.webp',
                      'mime': 'image/webp',
                      'scale': 3,
                      'width': 96,
                      'height': 96,
                      'frameCount': 1,
                    },
                  ],
                },
              },
              {
                'alias': 'overlay',
                'flags': {'zeroWidth': true},
                'emote': {
                  'id': 'e2',
                  'defaultName': 'overlay',
                  'images': [
                    {
                      'url': 'https://cdn.7tv.app/emote/e2/1x.webp',
                      'mime': 'image/webp',
                      'scale': 1,
                      'width': 32,
                      'height': 32,
                      'frameCount': 5,
                    },
                  ],
                },
              },
            ],
          },
        },
      });

      expect(cosmetics.paint!.kind, NamePaintKind.solid);
      expect(cosmetics.badge!.url, 'https://cdn.7tv.app/badge/s/3x.webp');
      expect(cosmetics.personalSetId, 'set1');
      final pet = cosmetics.personalEmotes.first;
      expect(pet.name, 'myPet');
      expect(pet.realName, 'catPet');
      expect(pet.type, EmoteType.sevenTVPersonal);
      expect(pet.providerId, 'e1');
      expect(cosmetics.personalEmotes.last.zeroWidth, isTrue);
      expect(cosmetics.personalEmotes.last.animated, isTrue);
    });

    test('an unknown user has nothing', () {
      final none = SevenTvUserCosmetics.fromGql(null);
      expect(none.paint, isNull);
      expect(none.badge, isNull);
      expect(none.personalEmotes, isEmpty);
    });
  });
}
