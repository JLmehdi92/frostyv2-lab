// Community highlights shown above chat: polls, predictions, pinned chat
// messages and outgoing raids. Read from anonymous GQL (camelCase) and from
// Hermes PubSub payloads (snake_case); every parser tolerates both, never
// throws, and returns null when the id is missing.

/// The first of [camel] or [snake] present in [map].
Object? chField(Map<dynamic, dynamic>? map, String camel, [String? snake]) {
  if (map == null) return null;
  final value = map[camel];
  if (value != null || snake == null) return value;
  return map[snake];
}

/// [value] as a map, or null.
Map<dynamic, dynamic>? chMap(Object? value) => value is Map ? value : null;

/// [value] as a list, or an empty one.
List<Object?> chList(Object? value) => value is List ? value : const [];

/// [value] as non-empty text of at most [max] characters, or null.
String? chString(Object? value, {int max = 500}) {
  if (value is! String || value.isEmpty) return null;
  return value.length > max ? value.substring(0, max) : value;
}

/// A whole number from a number or a numeric string ("154").
int? chInt(Object? value) {
  if (value is num) return value.isFinite ? value.toInt() : null;
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// A date from an ISO string, or epoch seconds or milliseconds (number or
/// string). Anything before 2000 is treated as nonsense.
DateTime? chDate(Object? value) {
  final number = value is num
      ? value
      : value is String
      ? num.tryParse(value.trim())
      : null;
  if (number != null) {
    if (!number.isFinite) return null;
    // Seconds until year 33658; milliseconds after.
    final ms = number.abs() < 1e12 ? number * 1000 : number;
    if (ms < 946684800000) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true);
  }
  if (value is String) {
    final date = DateTime.tryParse(value);
    if (date == null || date.year < 2000) return null;
    return date.toUtc();
  }
  return null;
}

final _numericId = RegExp(r'^[0-9]{1,20}$');
final _login = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

// --- Polls ------------------------------------------------------------------

enum PollStatus { active, completed, terminated, archived, unknown }

PollStatus _pollStatus(Object? value) => switch (value) {
  'ACTIVE' => PollStatus.active,
  'COMPLETED' => PollStatus.completed,
  'TERMINATED' => PollStatus.terminated,
  'ARCHIVED' => PollStatus.archived,
  _ => PollStatus.unknown,
};

class PollChoice {
  const PollChoice({
    required this.id,
    required this.title,
    required this.votes,
    required this.voters,
  });

  final String id;
  final String title;
  final int votes;
  final int voters;
}

class Poll {
  const Poll({
    required this.id,
    required this.title,
    required this.status,
    required this.choices,
    required this.duration,
    required this.totalVotes,
    required this.totalVoters,
    this.channelId,
    this.startedAt,
    this.endedAt,
    this.remaining,
    this.multiChoice = false,
  });

  /// A GQL `viewablePoll`, or null.
  static Poll? fromGql(Object? node) => _parse(chMap(node), gql: true);

  /// A Hermes `data.poll`, or null.
  static Poll? fromPubsub(Object? node) => _parse(chMap(node), gql: false);

  static Poll? _parse(Map<dynamic, dynamic>? map, {required bool gql}) {
    final id = chString(map?[gql ? 'id' : 'poll_id'], max: 64);
    if (map == null || id == null) return null;
    final choices = <PollChoice>[];
    for (final item in chList(map['choices'])) {
      final choice = chMap(item);
      final choiceId = chString(
        chField(choice, gql ? 'id' : 'choice_id', 'choice_id'),
        max: 64,
      );
      if (choiceId == null) continue;
      choices.add(
        PollChoice(
          id: choiceId,
          title: chString(choice!['title'], max: 100) ?? '',
          votes: chInt(chMap(choice['votes'])?['total']) ?? 0,
          voters: chInt(chField(choice, 'totalVoters', 'total_voters')) ?? 0,
        ),
      );
    }
    final settings = chMap(map['settings']);
    final multi = chMap(chField(settings, 'multichoice', 'multi_choice'));
    final remainingMs = chInt(
      chField(
        map,
        'remainingDurationMilliseconds',
        'remaining_duration_milliseconds',
      ),
    );
    return Poll(
      id: id,
      title: chString(map['title'], max: 200) ?? '',
      status: _pollStatus(map['status']),
      choices: choices,
      duration: Duration(
        seconds:
            chInt(chField(map, 'durationSeconds', 'duration_seconds')) ?? 0,
      ),
      totalVotes:
          chInt(chMap(map['votes'])?['total']) ??
          choices.fold(0, (sum, c) => sum + c.votes),
      totalVoters: chInt(chField(map, 'totalVoters', 'total_voters')) ?? 0,
      channelId: chString(map['owned_by'], max: 20),
      startedAt: chDate(chField(map, 'startedAt', 'started_at')),
      endedAt: chDate(chField(map, 'endedAt', 'ended_at')),
      remaining: remainingMs == null || remainingMs < 0
          ? null
          : Duration(milliseconds: remainingMs),
      multiChoice: chField(multi, 'isEnabled', 'is_enabled') == true,
    );
  }

  final String id;
  final String title;
  final PollStatus status;
  final List<PollChoice> choices;
  final Duration duration;
  final int totalVotes;
  final int totalVoters;

  /// The channel the poll belongs to (Hermes only).
  final String? channelId;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Time left when the snapshot was taken (GQL and Hermes give it).
  final Duration? remaining;
  final bool multiChoice;

  bool get isActive => status == PollStatus.active;

  /// When voting closes, from the start and the duration.
  DateTime? get endsAt => startedAt?.add(duration);
}

// --- Predictions -------------------------------------------------------------

enum PredictionStatus {
  active,
  locked,
  resolvePending,
  resolved,
  cancelPending,
  canceled,
  unknown,
}

PredictionStatus _predictionStatus(Object? value) => switch (value) {
  'ACTIVE' => PredictionStatus.active,
  'LOCKED' => PredictionStatus.locked,
  'RESOLVE_PENDING' => PredictionStatus.resolvePending,
  'RESOLVED' => PredictionStatus.resolved,
  'CANCEL_PENDING' => PredictionStatus.cancelPending,
  'CANCELED' || 'CANCELLED' => PredictionStatus.canceled,
  _ => PredictionStatus.unknown,
};

enum PredictionColor { blue, pink, unknown }

class TopPredictor {
  const TopPredictor({
    required this.name,
    required this.points,
    this.pointsWon,
  });

  final String name;
  final int points;

  /// Set once the prediction is resolved in this predictor's favour.
  final int? pointsWon;
}

class PredictionOutcome {
  const PredictionOutcome({
    required this.id,
    required this.title,
    required this.color,
    required this.points,
    required this.users,
    this.topPredictors = const [],
  });

  final String id;
  final String title;
  final PredictionColor color;
  final int points;
  final int users;
  final List<TopPredictor> topPredictors;
}

class Prediction {
  const Prediction({
    required this.id,
    required this.title,
    required this.status,
    required this.outcomes,
    required this.window,
    this.channelId,
    this.createdAt,
    this.lockedAt,
    this.endedAt,
    this.winningOutcomeId,
  });

  /// A GQL `PredictionEvent`, or null.
  static Prediction? fromGql(Object? node) => _parse(chMap(node));

  /// A Hermes `data.event`, or null.
  static Prediction? fromPubsub(Object? node) => _parse(chMap(node));

  static Prediction? _parse(Map<dynamic, dynamic>? map) {
    final id = chString(map?['id'], max: 64);
    if (map == null || id == null) return null;
    final outcomes = <PredictionOutcome>[];
    for (final item in chList(map['outcomes'])) {
      final outcome = chMap(item);
      final outcomeId = chString(outcome?['id'], max: 64);
      if (outcomeId == null) continue;
      outcomes.add(
        PredictionOutcome(
          id: outcomeId,
          title: chString(outcome!['title'], max: 100) ?? '',
          color: switch (outcome['color']) {
            'BLUE' => PredictionColor.blue,
            'PINK' => PredictionColor.pink,
            _ => PredictionColor.unknown,
          },
          points: chInt(chField(outcome, 'totalPoints', 'total_points')) ?? 0,
          users: chInt(chField(outcome, 'totalUsers', 'total_users')) ?? 0,
          topPredictors: [
            for (final p in chList(
              chField(outcome, 'topPredictors', 'top_predictors'),
            ))
              if (chMap(p) case final predictor?)
                TopPredictor(
                  name:
                      chString(
                        chField(chMap(predictor['user']), 'displayName'),
                        max: 64,
                      ) ??
                      chString(predictor['user_display_name'], max: 64) ??
                      '',
                  points: chInt(predictor['points']) ?? 0,
                  pointsWon: chInt(chMap(predictor['result'])?['points_won']),
                ),
          ],
        ),
      );
    }
    final winner =
        chString(map['winning_outcome_id'], max: 64) ??
        chString(chMap(map['winningOutcome'])?['id'], max: 64);
    return Prediction(
      id: id,
      title: chString(map['title'], max: 200) ?? '',
      status: _predictionStatus(map['status']),
      outcomes: outcomes,
      window: Duration(
        seconds:
            chInt(
              chField(
                map,
                'predictionWindowSeconds',
                'prediction_window_seconds',
              ),
            ) ??
            0,
      ),
      channelId: chString(map['channel_id'], max: 20),
      createdAt: chDate(chField(map, 'createdAt', 'created_at')),
      lockedAt: chDate(chField(map, 'lockedAt', 'locked_at')),
      endedAt: chDate(chField(map, 'endedAt', 'ended_at')),
      winningOutcomeId: winner,
    );
  }

  final String id;
  final String title;
  final PredictionStatus status;
  final List<PredictionOutcome> outcomes;

  /// How long viewers can predict after creation.
  final Duration window;

  /// The channel (Hermes only).
  final String? channelId;
  final DateTime? createdAt;
  final DateTime? lockedAt;
  final DateTime? endedAt;
  final String? winningOutcomeId;

  /// When predictions close (unless locked earlier).
  DateTime? get locksAt => createdAt?.add(window);

  int get totalPoints => outcomes.fold(0, (sum, o) => sum + o.points);
}

// --- Pinned chat messages -----------------------------------------------------

class PinnedBadge {
  const PinnedBadge({required this.setId, required this.version});

  final String setId;
  final String version;
}

/// A piece of a pinned message: text, an emote, or a mention.
class PinnedFragment {
  const PinnedFragment({required this.text, this.emoteId});

  final String text;
  final String? emoteId;
}

class PinnedChatMessage {
  const PinnedChatMessage({
    required this.id,
    required this.senderLogin,
    required this.senderDisplayName,
    required this.text,
    required this.fragments,
    required this.badges,
    this.messageId,
    this.senderId,
    this.color,
    this.pinnedBy,
    this.startsAt,
    this.updatedAt,
    this.endsAt,
  });

  /// A GQL `pinnedChatMessages` edge node, or null.
  static PinnedChatMessage? fromGql(Object? node) {
    final map = chMap(node);
    final id = chString(map?['id'], max: 64);
    final message = chMap(map?['pinnedMessage']);
    if (id == null || message == null) return null;
    final sender = chMap(message['sender']);
    final content = chMap(message['content']);
    final fragments = <PinnedFragment>[];
    for (final item in chList(content?['fragments'])) {
      final fragment = chMap(item);
      final text = fragment?['text'];
      if (text is! String) continue;
      final inner = chMap(fragment!['content']);
      fragments.add(
        PinnedFragment(
          text: text,
          emoteId: inner?['__typename'] == 'Emote'
              ? chString(inner!['emoteID'] ?? inner['id'], max: 64)
              : null,
        ),
      );
    }
    return PinnedChatMessage(
      id: id,
      messageId: chString(message['id'], max: 64),
      senderId: chString(sender?['id'], max: 20),
      senderLogin: chString(sender?['login'], max: 25) ?? '',
      senderDisplayName: chString(sender?['displayName'], max: 64) ?? '',
      color: chString(sender?['chatColor'], max: 7),
      badges: [
        for (final badge in chList(sender?['displayBadges']))
          if (chMap(badge) case final b?
              when chString(b['setID'], max: 64) != null)
            PinnedBadge(
              setId: b['setID'] as String,
              version: chString(b['version'], max: 64) ?? '1',
            ),
      ],
      text: _text(content?['text'], fragments),
      fragments: fragments,
      pinnedBy: chString(chMap(map!['pinnedBy'])?['displayName'], max: 64),
      startsAt: chDate(map['startsAt']),
      updatedAt: chDate(map['updatedAt']),
      endsAt: chDate(map['endsAt']),
    );
  }

  /// A Hermes `pin-message` `data`, or null.
  static PinnedChatMessage? fromPubsub(Object? node) {
    final map = chMap(node);
    final id = chString(map?['id'], max: 64);
    final message = chMap(map?['message']);
    if (id == null || message == null) return null;
    final sender = chMap(message['sender']);
    final content = chMap(message['content']);
    final fragments = <PinnedFragment>[];
    for (final item in chList(content?['fragments'])) {
      final fragment = chMap(item);
      final text = fragment?['text'];
      if (text is! String) continue;
      final emote = chMap(fragment!['emote']) ?? chMap(fragment['emoticon']);
      fragments.add(
        PinnedFragment(
          text: text,
          emoteId: chString(
            emote?['id'] ?? emote?['emoticon_id'] ?? emote?['emote_id'],
            max: 64,
          ),
        ),
      );
    }
    return PinnedChatMessage(
      id: id,
      messageId: chString(message['id'], max: 64),
      senderId: chString(sender?['id'], max: 20),
      senderLogin: chString(sender?['login'], max: 25) ?? '',
      senderDisplayName: chString(sender?['display_name'], max: 64) ?? '',
      color: chString(sender?['chat_color'], max: 7),
      badges: [
        for (final badge in chList(sender?['badges']))
          if (chMap(badge) case final b?
              when chString(b['id'], max: 64) != null)
            PinnedBadge(
              setId: b['id'] as String,
              version: chString(b['version'], max: 64) ?? '1',
            ),
      ],
      text: _text(content?['text'], fragments),
      fragments: fragments,
      pinnedBy: chString(
        chField(chMap(map!['pinned_by']), 'display_name'),
        max: 64,
      ),
      startsAt: chDate(message['starts_at']),
      updatedAt: chDate(message['updated_at']),
      endsAt: chDate(message['ends_at']),
    );
  }

  static String _text(Object? text, List<PinnedFragment> fragments) =>
      chString(text) ?? chString(fragments.map((f) => f.text).join()) ?? '';

  /// The pin's id (what unpin and update events name).
  final String id;

  /// The chat message that was pinned.
  final String? messageId;
  final String? senderId;
  final String senderLogin;
  final String senderDisplayName;

  /// `#RRGGBB`, unchecked (the IRC builder validates it).
  final String? color;
  final List<PinnedBadge> badges;

  /// At most 500 characters.
  final String text;
  final List<PinnedFragment> fragments;
  final String? pinnedBy;
  final DateTime? startsAt;
  final DateTime? updatedAt;

  /// When the pin ends by itself; null when it stays until unpinned.
  final DateTime? endsAt;
}

// --- Outgoing raids ----------------------------------------------------------

class OutgoingRaid {
  const OutgoingRaid({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.targetLogin,
    required this.targetDisplayName,
    required this.viewerCount,
    this.targetProfileImage,
    this.targetViewerCount,
    this.createdAt,
    this.forceRaidNowSeconds = 90,
  });

  /// A Hermes `raid` object, or null when it does not name a valid target.
  static OutgoingRaid? fromPubsub(Object? node) {
    final map = chMap(node);
    final id = chString(map?['id'], max: 64);
    final sourceId = chString(map?['source_id'], max: 20);
    final targetId = chString(map?['target_id'], max: 20);
    final targetLogin = chString(map?['target_login'], max: 25);
    if (id == null ||
        sourceId == null ||
        targetId == null ||
        targetLogin == null ||
        !_numericId.hasMatch(sourceId) ||
        !_numericId.hasMatch(targetId) ||
        !_login.hasMatch(targetLogin)) {
      return null;
    }
    final image = chString(map!['target_profile_image'], max: 300);
    return OutgoingRaid(
      id: id,
      sourceId: sourceId,
      targetId: targetId,
      targetLogin: targetLogin,
      targetDisplayName:
          chString(map['target_display_name'], max: 64) ?? targetLogin,
      viewerCount: chInt(map['viewer_count']) ?? 0,
      targetProfileImage: image != null && image.startsWith('https://')
          ? image
          : null,
      targetViewerCount: chInt(map['target_viewer_count']),
      createdAt: chDate(map['raid_created_at']),
      forceRaidNowSeconds: chInt(map['force_raid_now_seconds']) ?? 90,
    );
  }

  final String id;
  final String sourceId;
  final String targetId;
  final String targetLogin;
  final String targetDisplayName;

  /// Viewers going along.
  final int viewerCount;
  final String? targetProfileImage;
  final int? targetViewerCount;
  final DateTime? createdAt;
  final int forceRaidNowSeconds;

  /// When the raid leaves on its own.
  DateTime? get goAt => createdAt?.add(Duration(seconds: forceRaidNowSeconds));
}
