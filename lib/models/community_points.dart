import 'package:flutter/material.dart';

/// A reward a channel offers for channel points.
@immutable
class PointsReward {
  final String id;
  final String title;
  final int cost;
  final bool isEnabled;

  /// Whether redeeming asks the viewer to type something.
  final bool requiresInput;

  /// The colour the streamer chose for the reward's tile.
  final Color? backgroundColor;

  /// Artwork, when the streamer uploaded any. Twitch returns null for rewards
  /// left with the default icon.
  final String? imageUrl;

  /// Set for Twitch's built-in rewards — `CHOSEN_SUB_EMOTE_UNLOCK` and the
  /// rest — and null for a reward the streamer wrote themselves.
  ///
  /// The distinction matters because they are spent through different
  /// mutations: `redeemCommunityPointsCustomReward` takes custom rewards only,
  /// and the built-in ones go through `unlockChosenSubscriberEmote` and
  /// friends, which need an emote chosen first.
  final String? automaticType;

  const PointsReward({
    required this.id,
    required this.title,
    required this.cost,
    this.isEnabled = true,
    this.requiresInput = false,
    this.backgroundColor,
    this.imageUrl,
    this.automaticType,
  });

  bool get isAutomatic => automaticType != null;

  /// Whether this app can currently spend on it.
  ///
  /// False for the built-in rewards: their mutations exist and were verified by
  /// name, but each needs a picker this app does not have yet. Showing them
  /// without a tap target is honest; offering one that cannot work is not.
  bool get isRedeemable => !isAutomatic;

  /// Whether [balance] is enough to redeem this.
  bool affordableWith(int? balance) => balance != null && balance >= cost;

  static PointsReward? tryParse(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    if (id is! String || title is! String) return null;

    final image = json['image'];
    return PointsReward(
      id: id,
      title: title,
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      isEnabled: json['isEnabled'] as bool? ?? true,
      requiresInput: json['isUserInputRequired'] as bool? ?? false,
      backgroundColor: _hexColor(json['backgroundColor'] as String?),
      imageUrl: image is Map<String, dynamic> ? image['url'] as String? : null,
    );
  }

  /// Parses one of Twitch's built-in rewards.
  ///
  /// Returns null for the power-ups. Measured on a live channel: an animated
  /// message, a gigantified emote and an on-screen celebration all come back
  /// with `cost: null`, because they are bought with bits and not with points.
  /// A null cost is therefore the discriminant between the two currencies —
  /// reading it as zero would list three free rewards that cannot be redeemed.
  static PointsReward? tryParseAutomatic(Map<String, dynamic> json) {
    final id = json['id'];
    final type = json['type'];
    if (id is! String || type is! String) return null;

    final cost = (json['cost'] as num?)?.toInt();
    if (cost == null) return null;

    final image = json['defaultImage'] ?? json['image'];
    return PointsReward(
      id: id,
      title: automaticRewardTitle(type),
      cost: cost,
      isEnabled: json['isEnabled'] as bool? ?? true,
      imageUrl: image is Map<String, dynamic> ? image['url'] as String? : null,
      automaticType: type,
    );
  }

  /// Twitch's own name for a built-in reward.
  ///
  /// These carry no title over the wire — the official clients hold the
  /// strings — so an unknown type falls back to its readable identifier rather
  /// than to a blank row.
  static String automaticRewardTitle(String type) => switch (type) {
    'SEND_HIGHLIGHTED_MESSAGE' => 'Highlight my message',
    'RANDOM_SUB_EMOTE_UNLOCK' => 'Unlock a random sub emote',
    'CHOSEN_SUB_EMOTE_UNLOCK' => 'Choose an emote to unlock',
    'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK' => 'Modify a single emote',
    'SINGLE_MESSAGE_BYPASS_SUB_MODE' => 'Send a message in sub-only mode',
    _ => type.toLowerCase().replaceAll('_', ' '),
  };
}

/// One side of a prediction.
@immutable
class PredictionOutcome {
  final String id;
  final String title;

  /// Twitch's own colour name — `BLUE` or `PINK`.
  final String color;

  /// Points staked on this outcome, across everyone.
  final int totalPoints;

  /// How many people backed it.
  final int totalUsers;

  const PredictionOutcome({
    required this.id,
    required this.title,
    required this.color,
    this.totalPoints = 0,
    this.totalUsers = 0,
  });

  /// The payout multiplier shown to viewers, given the whole pot.
  ///
  /// Returns null when nothing is staked yet: Twitch shows no odds at that
  /// point either, and a "1x" would wrongly suggest a break-even bet.
  double? odds(int potTotal) {
    if (totalPoints <= 0 || potTotal <= 0) return null;
    return potTotal / totalPoints;
  }

  static PredictionOutcome? tryParse(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    if (id is! String || title is! String) return null;

    return PredictionOutcome(
      id: id,
      title: title,
      color: json['color'] as String? ?? 'BLUE',
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
      totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A prediction viewers can bet channel points on.
@immutable
class Prediction {
  final String id;
  final String title;

  /// `ACTIVE` while betting is open, `LOCKED` once closed, `RESOLVED` when
  /// paid out, `CANCELED` when refunded.
  final String status;

  final List<PredictionOutcome> outcomes;

  const Prediction({
    required this.id,
    required this.title,
    required this.status,
    this.outcomes = const [],
  });

  bool get isOpen => status == 'ACTIVE';
  bool get isLocked => status == 'LOCKED';

  /// Everything staked across all outcomes.
  int get totalPoints =>
      outcomes.fold(0, (sum, outcome) => sum + outcome.totalPoints);

  int get totalUsers =>
      outcomes.fold(0, (sum, outcome) => sum + outcome.totalUsers);

  static Prediction? tryParse(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    if (id is! String || title is! String) return null;

    final rawOutcomes = json['outcomes'];
    return Prediction(
      id: id,
      title: title,
      status: json['status'] as String? ?? 'ACTIVE',
      outcomes: rawOutcomes is List
          ? rawOutcomes
                .whereType<Map<String, dynamic>>()
                .map(PredictionOutcome.tryParse)
                .nonNulls
                .toList()
          : const [],
    );
  }
}

/// Everything the channel points panel needs for one channel.
@immutable
class CommunityPointsContext {
  /// The viewer's balance, or null when signed out — Twitch returns null for
  /// `self` rather than an error, so an absent balance is normal, not a fault.
  final int? balance;

  /// What the streamer named their points, e.g. "Tomcoins".
  final String? pointsName;

  /// The icon the streamer chose for their points.
  final String? pointsImageUrl;

  final List<PointsReward> rewards;
  final List<Prediction> predictions;

  /// The bonus chest waiting to be collected, when there is one.
  ///
  /// Twitch offers it for a couple of minutes at a time, so this is null far
  /// more often than not — an absent claim is the normal state, not a fault.
  final String? availableClaimId;

  const CommunityPointsContext({
    this.balance,
    this.pointsName,
    this.pointsImageUrl,
    this.rewards = const [],
    this.predictions = const [],
    this.availableClaimId,
  });

  bool get hasClaim => availableClaimId != null;

  /// The streamer's own points icon at a given density.
  ///
  /// Twitch hands back the 1x URL and publishes the denser copies beside it —
  /// verified on a live icon: `icon-1`, `icon-2` and `icon-4` all resolve,
  /// `icon-3` is a 404. A URL that does not match the pattern is returned
  /// untouched, and every caller falls back to a plain icon if the image fails
  /// to load, so a change in this convention costs sharpness, not the feature.
  String? pointsImageUrlAt(int scale) {
    final url = pointsImageUrl;
    if (url == null) return null;
    if (scale == 1) return url;

    return url.replaceFirst(
      RegExp(r'icon-1\.png$'),
      'icon-${scale == 4 ? 4 : 2}.png',
    );
  }

  static const empty = CommunityPointsContext();

  bool get hasAnything =>
      balance != null || rewards.isNotEmpty || predictions.isNotEmpty;

  /// The prediction worth showing: the open one, else the locked one.
  Prediction? get activePrediction {
    for (final prediction in predictions) {
      if (prediction.isOpen) return prediction;
    }
    for (final prediction in predictions) {
      if (prediction.isLocked) return prediction;
    }
    return null;
  }
}

/// Why a points action ended the way it did.
///
/// Twitch reports failures as free-form strings, and one of them matters more
/// than the rest: `failed integrity check` is an anti-abuse refusal, not a
/// fault. Collapsing it into a generic "failed" would hide the single most
/// informative answer the server gives, so it gets its own case.
///
/// Anything unrecognised stays [unknown] and carries its raw text through, so a
/// code we have never seen is shown rather than swallowed.
enum PointsActionStatus {
  success,

  /// Twitch demanded an integrity attestation this client does not produce.
  integrityRefused,

  /// The token was missing, expired or rejected.
  notAuthenticated,

  /// The request never reached a verdict — no network, timeout, bad status.
  network,

  /// A refusal we have not seen before. [PointsActionResult.rawCode] has it.
  unknown,
}

/// The outcome of spending points.
@immutable
class PointsActionResult {
  final PointsActionStatus status;

  /// Exactly what Twitch said, kept even on success (where it is null) so a
  /// surprising refusal can be read off the screen instead of the logs.
  final String? rawCode;

  const PointsActionResult(this.status, [this.rawCode]);

  static const ok = PointsActionResult(PointsActionStatus.success);

  /// The code the store answers with when another action is still running.
  /// Ours, not Twitch's: nothing was sent, so nothing was refused.
  static const busyCode = 'busy';

  bool get isSuccess => status == PointsActionStatus.success;

  /// Classifies what [_mutate] returned.
  ///
  /// Matching is done on substrings and case-insensitively because these are
  /// human-readable server messages, not a stable code enum: the observed
  /// integrity refusal arrives as the sentence `failed integrity check`.
  ///
  /// Only refusals actually observed against the live endpoint are given a
  /// case. Inventing more would be guessing at strings we have never seen, and
  /// a wrong guess here silently relabels a real error.
  factory PointsActionResult.fromError(String? code) {
    if (code == null) return ok;

    final normalised = code.toLowerCase();

    if (normalised.contains('integrity')) {
      return PointsActionResult(PointsActionStatus.integrityRefused, code);
    }
    if (normalised.contains('unauthenticated') ||
        normalised.contains('unauthorized') ||
        normalised.contains('login')) {
      return PointsActionResult(PointsActionStatus.notAuthenticated, code);
    }
    if (code == 'request_failed') {
      return PointsActionResult(PointsActionStatus.network, code);
    }
    return PointsActionResult(PointsActionStatus.unknown, code);
  }

  /// What to put in front of the viewer.
  ///
  /// The integrity case says who refused and why rather than blaming the app:
  /// nothing is broken here, and no amount of retrying will change it.
  String get message => switch (status) {
    PointsActionStatus.success => 'Done.',
    PointsActionStatus.integrityRefused =>
      'Twitch refused: anti-bot check. Not something this app can pass.',
    PointsActionStatus.notAuthenticated =>
      'Twitch rejected the login. Sign in again to spend points.',
    PointsActionStatus.network => 'Could not reach Twitch. Try again.',
    PointsActionStatus.unknown when rawCode == busyCode =>
      'Already in progress.',
    PointsActionStatus.unknown => 'Twitch refused: ${rawCode ?? 'no reason'}',
  };
}

Color? _hexColor(String? hex) {
  if (hex == null) return null;
  final cleaned = hex.replaceFirst('#', '').trim();
  if (cleaned.length != 6) return null;
  final value = int.tryParse(cleaned, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}
