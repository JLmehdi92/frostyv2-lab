import 'package:collection/collection.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/third_party_cosmetics.dart';

enum SevenTvEntitlementKind { badge, paint, emoteSet }

class SevenTvActor {
  final String username;
  final String displayName;

  const SevenTvActor(this.username, this.displayName);

  static SevenTvActor? parse(Object? actor) {
    if (actor is! Map) return null;
    final username = actor['username'] as String? ?? '';
    final displayName = actor['display_name'] as String? ?? username;
    if (username.isEmpty && displayName.isEmpty) return null;
    return SevenTvActor(username, displayName);
  }
}

sealed class SevenTvDispatch {
  const SevenTvDispatch();

  static SevenTvDispatch? parse(Object? decoded) {
    if (decoded is! Map || decoded['op'] != 0) return null;
    final data = decoded['d'];
    if (data is! Map) return null;
    final body = data['body'];
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);
    try {
      return switch (data['type']) {
        'emote_set.update' => SevenTvEmoteSetChange._parse(map),
        'user.update' => SevenTvActiveSetSwitch._parse(map),
        'cosmetic.create' => SevenTvCosmeticCreated._parse(map),
        'entitlement.create' => SevenTvEntitlement._parse(map, granted: true),
        'entitlement.delete' => SevenTvEntitlement._parse(map, granted: false),
        _ => null,
      };
    } on Object {
      return null;
    }
  }
}

class SevenTvEmoteRename {
  final String oldName;
  final Emote7TV emote;

  const SevenTvEmoteRename(this.oldName, this.emote);
}

class SevenTvEmoteSetChange extends SevenTvDispatch {
  final String setId;
  final SevenTvActor? actor;
  final List<Emote7TV> added;
  final List<String> removed;
  final List<SevenTvEmoteRename> renamed;

  const SevenTvEmoteSetChange({
    required this.setId,
    this.actor,
    this.added = const [],
    this.removed = const [],
    this.renamed = const [],
  });

  bool get isEmpty => added.isEmpty && removed.isEmpty && renamed.isEmpty;

  static SevenTvEmoteSetChange? _parse(Map<String, dynamic> body) {
    final setId = body['id'];
    if (setId is! String) return null;
    Iterable<Map<String, dynamic>> emoteChanges(String field) => [
      for (final change in (body[field] as List?) ?? const [])
        if (change is Map && change['key'] == 'emotes')
          Map<String, dynamic>.from(change),
    ];
    Emote7TV? emoteOf(Object? value) => value is Map && value['data'] is Map
        ? Emote7TV.fromJson(Map<String, dynamic>.from(value))
        : null;
    final renamed = <SevenTvEmoteRename>[];
    for (final change in emoteChanges('updated')) {
      final before = change['old_value'];
      final after = emoteOf(change['value']);
      final oldName = before is Map ? before['name'] as String? : null;
      if (after != null && oldName != null && oldName != after.name) {
        renamed.add(SevenTvEmoteRename(oldName, after));
      }
    }
    return SevenTvEmoteSetChange(
      setId: setId,
      actor: SevenTvActor.parse(body['actor']),
      added: [
        for (final change in emoteChanges('pushed')) ?emoteOf(change['value']),
      ],
      removed: [
        for (final change in emoteChanges('pulled'))
          if (change['old_value'] case {'name': final String name}) name,
      ],
      renamed: renamed,
    );
  }
}

class SevenTvActiveSetSwitch extends SevenTvDispatch {
  final String userId;
  final SevenTvActor? actor;
  final String setId;
  final String setName;

  const SevenTvActiveSetSwitch({
    required this.userId,
    this.actor,
    required this.setId,
    required this.setName,
  });

  static SevenTvActiveSetSwitch? _parse(Map<String, dynamic> body) {
    final userId = body['id'];
    if (userId is! String) return null;
    for (final change in (body['updated'] as List?) ?? const []) {
      if (change is! Map || change['key'] != 'connections') continue;
      final nested = change['value'];
      if (nested is! List) continue;
      for (final field in nested) {
        if (field is! Map || field['key'] != 'emote_set') continue;
        final set = field['value'];
        if (set is Map && set['id'] is String) {
          return SevenTvActiveSetSwitch(
            userId: userId,
            actor: SevenTvActor.parse(body['actor']),
            setId: set['id'] as String,
            setName: set['name'] as String? ?? '',
          );
        }
      }
    }
    return null;
  }
}

class SevenTvCosmeticCreated extends SevenTvDispatch {
  final String id;
  final NamePaint? paint;
  final ChatBadge? badge;

  const SevenTvCosmeticCreated({required this.id, this.paint, this.badge});

  static SevenTvCosmeticCreated? _parse(Map<String, dynamic> body) {
    final object = body['object'];
    if (object is! Map || object['data'] is! Map) return null;
    final data = Map<String, dynamic>.from(object['data'] as Map);
    final id = data['id'] ?? object['id'];
    if (id is! String) return null;
    return switch (object['kind']) {
      'PAINT' => SevenTvCosmeticCreated(
        id: id,
        paint: NamePaint.fromEventApi({...data, 'id': id}),
      ),
      'BADGE' => SevenTvCosmeticCreated(
        id: id,
        badge: sevenTvBadgeFromEventApi(data),
      ),
      _ => null,
    };
  }
}

class SevenTvEntitlement extends SevenTvDispatch {
  final SevenTvEntitlementKind kind;
  final String refId;
  final String twitchUserId;
  final bool granted;

  const SevenTvEntitlement({
    required this.kind,
    required this.refId,
    required this.twitchUserId,
    required this.granted,
  });

  static SevenTvEntitlement? _parse(
    Map<String, dynamic> body, {
    required bool granted,
  }) {
    final object = body['object'];
    if (object is! Map) return null;
    final kind = switch (object['kind']) {
      'BADGE' => SevenTvEntitlementKind.badge,
      'PAINT' => SevenTvEntitlementKind.paint,
      'EMOTE_SET' => SevenTvEntitlementKind.emoteSet,
      _ => null,
    };
    final refId = object['ref_id'];
    final user = object['user'];
    if (kind == null || refId is! String || user is! Map) return null;
    final twitch = ((user['connections'] as List?) ?? const [])
        .whereType<Map>()
        .firstWhereOrNull((connection) => connection['platform'] == 'TWITCH');
    final twitchUserId = twitch?['id'];
    if (twitchUserId is! String) return null;
    return SevenTvEntitlement(
      kind: kind,
      refId: refId,
      twitchUserId: twitchUserId,
      granted: granted,
    );
  }
}

sealed class BttvSocketEvent {
  const BttvSocketEvent();

  static BttvSocketEvent? parse(Object? decoded, {required String channelId}) {
    if (decoded is! Map) return null;
    final data = decoded['data'];
    if (data is! Map) return null;
    final channel = 'twitch:$channelId';
    try {
      return switch (decoded['name']) {
        'emote_create' when data['channel'] == channel => _created(data),
        'emote_update' when data['channel'] == channel => _updated(data),
        'emote_delete' when data['channel'] == channel => _deleted(data),
        'lookup_user' => _proUser(data),
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  static BttvEmoteCreated? _created(Map data) {
    final emote = data['emote'];
    if (emote is! Map) return null;
    return BttvEmoteCreated(
      EmoteBTTV.fromJson(Map<String, dynamic>.from(emote)),
    );
  }

  static BttvEmoteUpdated? _updated(Map data) {
    final emote = data['emote'];
    if (emote is! Map) return null;
    final id = emote['id'];
    final code = emote['code'];
    if (id is! String || code is! String || code.isEmpty) return null;
    return BttvEmoteUpdated(id, code);
  }

  static BttvEmoteDeleted? _deleted(Map data) {
    final id = data['emoteId'];
    return id is String ? BttvEmoteDeleted(id) : null;
  }

  static BttvProUser? _proUser(Map data) {
    final providerId = data['providerId'];
    if (providerId is! String) return null;
    return BttvProUser(
      providerId,
      pro: data['pro'] == true,
      emotes: [
        for (final emote in (data['emotes'] as List?) ?? const [])
          if (emote is Map && emote['id'] is String && emote['code'] is String)
            EmoteBTTV.fromJson(Map<String, dynamic>.from(emote)),
      ],
    );
  }
}

class BttvEmoteCreated extends BttvSocketEvent {
  final EmoteBTTV emote;

  const BttvEmoteCreated(this.emote);
}

class BttvEmoteUpdated extends BttvSocketEvent {
  final String id;
  final String code;

  const BttvEmoteUpdated(this.id, this.code);
}

class BttvEmoteDeleted extends BttvSocketEvent {
  final String id;

  const BttvEmoteDeleted(this.id);
}

class BttvProUser extends BttvSocketEvent {
  final String providerId;
  final bool pro;
  final List<EmoteBTTV> emotes;

  const BttvProUser(
    this.providerId, {
    required this.pro,
    this.emotes = const [],
  });
}
