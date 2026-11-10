import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/painting.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/emotes.dart';

enum NamePaintKind { linearGradient, radialGradient, image, solid }

class NamePaintStop {
  final double at;
  final Color color;

  const NamePaintStop(this.at, this.color);
}

class NamePaint {
  final String id;
  final String name;
  final NamePaintKind kind;
  final double angle;
  final bool repeating;
  final List<NamePaintStop> stops;
  final String? imageUrl;
  final Color? color;
  final List<Shadow> shadows;

  const NamePaint({
    required this.id,
    this.name = '',
    required this.kind,
    this.angle = 90,
    this.repeating = false,
    this.stops = const [],
    this.imageUrl,
    this.color,
    this.shadows = const [],
  });

  bool get isDrawable => switch (kind) {
    NamePaintKind.linearGradient ||
    NamePaintKind.radialGradient => stops.length >= 2,
    NamePaintKind.image => imageUrl != null,
    NamePaintKind.solid => color != null,
  };

  Color? get fallbackColor => color ?? stops.firstOrNull?.color;

  Shader? gradientShader(Rect bounds) {
    final colors = [for (final stop in stops) stop.color];
    final positions = [for (final stop in stops) stop.at.clamp(0.0, 1.0)];
    final tileMode = repeating ? TileMode.repeated : TileMode.clamp;
    return switch (kind) {
      NamePaintKind.linearGradient when stops.length >= 2 => () {
        final radians = angle * math.pi / 180;
        final direction = Alignment(math.sin(radians), -math.cos(radians));
        return LinearGradient(
          begin: -direction,
          end: direction,
          colors: colors,
          stops: positions,
          tileMode: tileMode,
        ).createShader(bounds);
      }(),
      NamePaintKind.radialGradient when stops.length >= 2 => RadialGradient(
        colors: colors,
        stops: positions,
        tileMode: tileMode,
      ).createShader(bounds),
      NamePaintKind.solid when color != null => LinearGradient(
        colors: [color!, color!],
      ).createShader(bounds),
      _ => null,
    };
  }

  static NamePaint? fromEventApi(Map<String, dynamic> data) {
    final id = data['id'];
    if (id is! String) return null;
    final gradient = (data['gradients'] as List?)?.firstOrNull;
    final source = data['function'] == null && gradient is Map
        ? Map<String, dynamic>.from(gradient)
        : data;
    final kind = switch (source['function']) {
      'LINEAR_GRADIENT' => NamePaintKind.linearGradient,
      'RADIAL_GRADIENT' => NamePaintKind.radialGradient,
      'URL' => NamePaintKind.image,
      _ => data['color'] is int ? NamePaintKind.solid : null,
    };
    if (kind == null) return null;
    return NamePaint(
      id: id,
      name: data['name'] as String? ?? '',
      kind: kind,
      angle: (source['angle'] as num?)?.toDouble() ?? 90,
      repeating: source['repeat'] == true,
      stops: [
        for (final stop in (source['stops'] as List?) ?? const [])
          if (stop is Map && stop['color'] is int)
            NamePaintStop(
              (stop['at'] as num?)?.toDouble() ?? 0,
              colorFromRgbaInt(stop['color'] as int),
            ),
      ],
      imageUrl: _https(source['image_url'] as String?),
      color: data['color'] is int
          ? colorFromRgbaInt(data['color'] as int)
          : null,
      shadows: [
        for (final shadow in (data['shadows'] as List?) ?? const [])
          if (shadow is Map && shadow['color'] is int)
            Shadow(
              color: colorFromRgbaInt(shadow['color'] as int),
              offset: Offset(
                (shadow['x_offset'] as num?)?.toDouble() ?? 0,
                (shadow['y_offset'] as num?)?.toDouble() ?? 0,
              ),
              blurRadius: (shadow['radius'] as num?)?.toDouble() ?? 0,
            ),
      ],
    );
  }

  static NamePaint? fromGql(Map<String, dynamic> paint) {
    final id = paint['id'];
    final data = paint['data'];
    if (id is! String || data is! Map) return null;
    final layers = (data['layers'] as List?) ?? const [];
    final layer = layers.whereType<Map>().firstWhereOrNull(
      (layer) => layer['ty'] is Map,
    );
    if (layer == null) return null;
    final type = Map<String, dynamic>.from(layer['ty'] as Map);
    final stops = [
      for (final stop in (type['stops'] as List?) ?? const [])
        if (stop is Map && colorFromHex(_hexOf(stop['color'])) != null)
          NamePaintStop(
            (stop['at'] as num?)?.toDouble() ?? 0,
            colorFromHex(_hexOf(stop['color']))!,
          ),
    ];
    final kind = switch (type['__typename']) {
      'PaintLayerTypeLinearGradient' => NamePaintKind.linearGradient,
      'PaintLayerTypeRadialGradient' => NamePaintKind.radialGradient,
      'PaintLayerTypeImage' => NamePaintKind.image,
      'PaintLayerTypeSingleColor' => NamePaintKind.solid,
      _ => null,
    };
    if (kind == null) return null;
    return NamePaint(
      id: id,
      name: paint['name'] as String? ?? '',
      kind: kind,
      angle: (type['angle'] as num?)?.toDouble() ?? 90,
      repeating: type['repeating'] == true,
      stops: stops,
      imageUrl: kind == NamePaintKind.image
          ? pickStillImage((type['images'] as List?) ?? const [])
          : null,
      color: colorFromHex(_hexOf(type['color'])),
      shadows: [
        for (final shadow in (data['shadows'] as List?) ?? const [])
          if (shadow is Map && colorFromHex(_hexOf(shadow['color'])) != null)
            Shadow(
              color: colorFromHex(_hexOf(shadow['color']))!,
              offset: Offset(
                (shadow['offsetX'] as num?)?.toDouble() ?? 0,
                (shadow['offsetY'] as num?)?.toDouble() ?? 0,
              ),
              blurRadius: (shadow['blur'] as num?)?.toDouble() ?? 0,
            ),
      ],
    );
  }
}

Color colorFromRgbaInt(int value) {
  final rgba = value & 0xFFFFFFFF;
  return Color.fromARGB(
    rgba & 0xFF,
    (rgba >> 24) & 0xFF,
    (rgba >> 16) & 0xFF,
    (rgba >> 8) & 0xFF,
  );
}

Color? colorFromHex(String? hex) {
  if (hex == null) return null;
  final digits = hex.replaceFirst('#', '');
  final rgba = switch (digits.length) {
    6 => '${digits}FF',
    8 => digits,
    _ => null,
  };
  final value = rgba == null ? null : int.tryParse(rgba, radix: 16);
  return value == null ? null : colorFromRgbaInt(value);
}

String? _hexOf(Object? color) => color is Map ? color['hex'] as String? : null;

String? _https(String? url) {
  if (url == null || url.isEmpty) return null;
  final absolute = url.startsWith('//') ? 'https:$url' : url;
  final uri = Uri.tryParse(absolute);
  return uri != null && uri.scheme == 'https' ? absolute : null;
}

String? pickStillImage(List<dynamic> images) {
  final candidates = [
    for (final image in images)
      if (image is Map &&
          image['mime'] != 'image/avif' &&
          _https(image['url'] as String?) != null)
        image,
  ];
  final still = candidates.where((image) => image['frameCount'] == 1).toList();
  final pool = still.isNotEmpty ? still : candidates;
  final best = pool
      .where((image) => ((image['scale'] as num?) ?? 1) <= 3)
      .sortedBy<num>((image) => (image['scale'] as num?) ?? 1)
      .lastOrNull;
  return _https((best ?? pool.firstOrNull)?['url'] as String?);
}

String? pickAnimatedImage(List<dynamic> images) {
  final candidates = [
    for (final image in images)
      if (image is Map &&
          image['mime'] != 'image/avif' &&
          _https(image['url'] as String?) != null &&
          ((image['scale'] as num?) ?? 1) <= 3)
        image,
  ].sortedBy<num>((image) => (image['scale'] as num?) ?? 1);
  final moving = candidates.where((image) => (image['frameCount'] ?? 1) > 1);
  return _https(
    (moving.lastOrNull ?? candidates.lastOrNull)?['url'] as String?,
  );
}

ChatBadge? sevenTvBadgeFromEventApi(Map<String, dynamic> data) {
  final host = data['host'];
  if (host is! Map) return null;
  final base = _https(host['url'] as String?);
  if (base == null) return null;
  final files = [
    for (final file in (host['files'] as List?) ?? const [])
      if (file is Map &&
          file['format'] != 'AVIF' &&
          file['name'] is String &&
          !(file['name'] as String).contains('/'))
        file['name'] as String,
  ];
  final name =
      files.firstWhereOrNull((name) => name.startsWith('3x')) ??
      files.lastOrNull ??
      '3x.webp';
  return ChatBadge(
    name: data['tooltip'] as String? ?? data['name'] as String? ?? '',
    url: '$base/$name',
    type: BadgeType.sevenTV,
  );
}

ChatBadge? sevenTvBadgeFromGql(Map<String, dynamic> badge) {
  final url = pickAnimatedImage((badge['images'] as List?) ?? const []);
  if (url == null) return null;
  return ChatBadge(
    name: badge['description'] as String? ?? badge['name'] as String? ?? '',
    url: url,
    type: BadgeType.sevenTV,
  );
}

Emote? sevenTvEmoteFromGql(Map<String, dynamic> item, EmoteType type) {
  final emote = item['emote'];
  if (emote is! Map) return null;
  final images = (emote['images'] as List?) ?? const [];
  final url = pickAnimatedImage(images);
  final alias = item['alias'] as String?;
  if (url == null || alias == null || alias.isEmpty) return null;
  final animated = images.whereType<Map>().any(
    (image) => ((image['frameCount'] as num?) ?? 1) > 1,
  );
  final hasStill = images.whereType<Map>().any(
    (image) => image['frameCount'] == 1,
  );
  final still = animated && hasStill ? pickStillImage(images) : null;
  final firstImage = images.whereType<Map>().firstOrNull;
  final itemFlags = item['flags'];
  final emoteFlags = emote['flags'];
  final zeroWidth =
      (itemFlags is Map && itemFlags['zeroWidth'] == true) ||
      (emoteFlags is Map && emoteFlags['defaultZeroWidth'] == true);
  final defaultName = emote['defaultName'] as String?;
  return Emote(
    name: alias,
    realName: defaultName != null && defaultName != alias ? defaultName : null,
    width: (firstImage?['width'] as num?)?.toInt(),
    height: (firstImage?['height'] as num?)?.toInt(),
    zeroWidth: zeroWidth,
    url: url,
    staticUrl: still,
    type: type,
    animated: animated,
    providerId: emote['id'] as String?,
  );
}

class SevenTvUserCosmetics {
  final NamePaint? paint;
  final ChatBadge? badge;
  final String? personalSetId;
  final List<Emote> personalEmotes;

  const SevenTvUserCosmetics({
    this.paint,
    this.badge,
    this.personalSetId,
    this.personalEmotes = const [],
  });

  static const none = SevenTvUserCosmetics();

  static SevenTvUserCosmetics fromGql(Map<String, dynamic>? user) {
    if (user == null) return none;
    final style = user['style'];
    final paint = style is Map ? style['activePaint'] : null;
    final badge = style is Map ? style['activeBadge'] : null;
    final set = user['personalEmoteSet'];
    final items = set is Map && set['emotes'] is Map
        ? (set['emotes']['items'] as List?) ?? const []
        : const [];
    return SevenTvUserCosmetics(
      paint: paint is Map
          ? NamePaint.fromGql(Map<String, dynamic>.from(paint))
          : null,
      badge: badge is Map
          ? sevenTvBadgeFromGql(Map<String, dynamic>.from(badge))
          : null,
      personalSetId: set is Map ? set['id'] as String? : null,
      personalEmotes: [
        for (final item in items)
          if (item is Map)
            ?sevenTvEmoteFromGql(
              Map<String, dynamic>.from(item),
              EmoteType.sevenTVPersonal,
            ),
      ],
    );
  }
}
