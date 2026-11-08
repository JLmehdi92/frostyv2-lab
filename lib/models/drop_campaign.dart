enum DropState { unknown, locked, inProgress, claimable, claimed }

enum DropClaimResult {
  claimed,
  alreadyClaimed,
  needsAccountLink,
  expired,
  limitReached,
  refused,
  integrityRefused,
  signedOut,
  failed;

  bool get isClaimed => this == claimed || this == alreadyClaimed;

  static DropClaimResult fromBody(Object? body) {
    if (body is! Map) return failed;
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final text = errors
          .map((e) => e is Map ? '${e['message']}' : '$e')
          .join(' ')
          .toLowerCase();
      return text.contains('integrity') ? integrityRefused : failed;
    }
    final payload = (body['data'] as Map?)?['claimDropRewards'];
    if (payload is! Map) return failed;
    if (payload['isUserAccountConnected'] == false) return needsAccountLink;
    return switch (payload['status']) {
      'ELIGIBLE_FOR_ALL' => claimed,
      'DROP_INSTANCE_ALREADY_CLAIMED' => alreadyClaimed,
      'EXPIRED' => expired,
      'ENTITLEMENT_LIMIT_REACHED' => limitReached,
      _ => refused,
    };
  }
}

enum CommunityDropsOfferKind { watch, subs, turbo, several }

class CommunityDropsOffer {
  final CommunityDropsOfferKind kind;
  final int amount;

  const CommunityDropsOffer.watch(int minutes)
    : kind = CommunityDropsOfferKind.watch,
      amount = minutes;

  const CommunityDropsOffer.subs(int count)
    : kind = CommunityDropsOfferKind.subs,
      amount = count;

  const CommunityDropsOffer.turbo()
    : kind = CommunityDropsOfferKind.turbo,
      amount = 0;

  const CommunityDropsOffer.several()
    : kind = CommunityDropsOfferKind.several,
      amount = 0;

  @override
  bool operator ==(Object other) =>
      other is CommunityDropsOffer &&
      other.kind == kind &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(kind, amount);

  @override
  String toString() => 'CommunityDropsOffer(${kind.name}, $amount)';
}

class DropProgress {
  final int minutesWatched;
  final int subs;
  final bool preconditionsMet;
  final bool isClaimed;
  final String? dropInstanceId;

  const DropProgress({
    this.minutesWatched = 0,
    this.subs = 0,
    this.preconditionsMet = true,
    this.isClaimed = false,
    this.dropInstanceId,
  });

  static DropProgress? tryParse(Object? self) {
    if (self is! Map) return null;
    final instance = self['dropInstanceID'];
    return DropProgress(
      minutesWatched: _count(self['currentMinutesWatched']),
      subs: _count(self['currentSubs']),
      preconditionsMet: self['hasPreconditionsMet'] != false,
      isClaimed: self['isClaimed'] == true,
      dropInstanceId: instance is String && instance.isNotEmpty
          ? instance
          : null,
    );
  }
}

class TimedDrop {
  final String id;
  final String rewardName;
  final Uri? rewardImageUrl;
  final int requiredMinutes;
  final int requiredSubs;
  final int requiredTurboSubs;
  final DropProgress? progress;

  const TimedDrop({
    required this.id,
    required this.rewardName,
    this.rewardImageUrl,
    this.requiredMinutes = 0,
    this.requiredSubs = 0,
    this.requiredTurboSubs = 0,
    this.progress,
  });

  DropState get state {
    final progress = this.progress;
    if (progress == null) return DropState.unknown;
    if (progress.isClaimed) return DropState.claimed;
    if (progress.dropInstanceId != null) return DropState.claimable;
    if (!progress.preconditionsMet) return DropState.locked;
    return DropState.inProgress;
  }

  double get fraction {
    final progress = this.progress;
    if (progress == null) return 0;
    if (progress.isClaimed || progress.dropInstanceId != null) return 1;
    if (requiredMinutes > 0) {
      return (progress.minutesWatched / requiredMinutes).clamp(0, 1);
    }
    if (requiredSubs > 0) return (progress.subs / requiredSubs).clamp(0, 1);
    return 0;
  }

  int get minutesLeft {
    final watched = progress?.minutesWatched ?? 0;
    return (requiredMinutes - watched).clamp(0, requiredMinutes);
  }

  static TimedDrop? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    final edges = raw['benefitEdges'];
    final benefit = edges is List && edges.isNotEmpty && edges.first is Map
        ? (edges.first as Map)['benefit']
        : null;
    final name = benefit is Map ? benefit['name'] : null;
    final image = benefit is Map ? benefit['imageAssetURL'] : null;
    return TimedDrop(
      id: id,
      rewardName: name is String ? name.trim() : '',
      rewardImageUrl: image is String ? Uri.tryParse(image) : null,
      requiredMinutes: _count(raw['requiredMinutesWatched']),
      requiredSubs: _count(raw['requiredSubs']),
      requiredTurboSubs: _count(raw['requiredTurboSubs']),
      progress: DropProgress.tryParse(raw['self']),
    );
  }
}

class DropCampaign {
  final String id;
  final String name;
  final String gameName;
  final Uri? imageUrl;
  final Uri? accountLinkUrl;
  final Uri? detailsUrl;
  final DateTime? endAt;
  final bool? isAccountConnected;
  final List<TimedDrop> drops;

  const DropCampaign({
    required this.id,
    required this.name,
    this.gameName = '',
    this.imageUrl,
    this.accountLinkUrl,
    this.detailsUrl,
    this.endAt,
    this.isAccountConnected,
    this.drops = const [],
  });

  int get claimableCount =>
      drops.where((drop) => drop.state == DropState.claimable).length;

  CommunityDropsOffer get offer {
    if (drops.length != 1) return const CommunityDropsOffer.several();
    final drop = drops.single;
    if (drop.requiredTurboSubs > 0) return const CommunityDropsOffer.turbo();
    final watch = drop.requiredMinutes > 0;
    final subs = drop.requiredSubs > 0;
    if (watch && !subs) return CommunityDropsOffer.watch(drop.requiredMinutes);
    if (subs && !watch) return CommunityDropsOffer.subs(drop.requiredSubs);
    return const CommunityDropsOffer.several();
  }

  static List<DropCampaign>? listFrom(Object? body) {
    if (body is! Map) return null;
    final user = (body['data'] as Map?)?['user'];
    final channel = user is Map ? user['channel'] : null;
    if (channel is! Map) return null;
    final campaigns = channel['viewerDropCampaigns'];
    if (campaigns == null) {
      final errors = body['errors'];
      return errors is List && errors.isNotEmpty ? null : const [];
    }
    if (campaigns is! List) return null;
    return [
      for (final raw in campaigns)
        ?tryParse(raw),
    ];
  }

  static DropCampaign? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    final name = raw['name'];
    final game = raw['game'];
    final gameName = game is Map ? game['name'] : null;
    final self = raw['self'];
    final drops = raw['timeBasedDrops'];
    return DropCampaign(
      id: id,
      name: name is String ? name.trim() : '',
      gameName: gameName is String ? gameName.trim() : '',
      imageUrl: _uri(raw['imageURL']),
      accountLinkUrl: _uri(raw['accountLinkURL']),
      detailsUrl: _uri(raw['detailsURL']),
      endAt: raw['endAt'] is String
          ? DateTime.tryParse(raw['endAt'] as String)
          : null,
      isAccountConnected: self is Map && self['isAccountConnected'] is bool
          ? self['isAccountConnected'] as bool
          : null,
      drops: [
        if (drops is List)
          for (final drop in drops)
            ?TimedDrop.tryParse(drop),
      ],
    );
  }
}

Uri? _uri(Object? value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value);
  return uri != null && uri.scheme == 'https' ? uri : null;
}

int _count(Object? value) => value is num && value > 0 ? value.toInt() : 0;
