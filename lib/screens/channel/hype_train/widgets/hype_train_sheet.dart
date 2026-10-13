import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_math.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/hype_train_avatar_stack.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';

/// Twitch's guide to hype trains.
const htHelpUrl = 'https://help.twitch.tv/s/article/hype-train-guide';

/// The train's details: what the variant unlocks, what completes the level,
/// shared channels, conductors, rewards, the record and a link to the
/// guide. It follows the store live. There is nothing to buy here (D4).
class HypeTrainSheet extends StatelessWidget {
  const HypeTrainSheet({
    super.key,
    required this.store,
    required this.onLearnMore,
  });

  final HypeTrainStore store;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final train = store.train;
        final approaching = store.approaching;
        if (store.phase == HtPhase.approaching && approaching != null) {
          return _ApproachingDetails(store: store, approaching: approaching);
        }
        if (train == null) return const SizedBox(width: double.infinity);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_variantLine(train) case final line?) ...[
                _Section(title: _variantTitle(train)),
                Text(line),
                if (train.variant == HtVariant.mythic &&
                    train.mythic != null) ...[
                  const SizedBox(height: 8),
                  _RewardRow(rewards: train.mythic!.pool, locked: true),
                ],
                const SizedBox(height: 12),
              ],
              Text(
                isFinalLevel(train)
                    ? HtCopy.finalLevel
                    : HtCopy.levelTarget(
                        store.levelTarget.subs,
                        store.levelTarget.bits,
                      ),
              ),
              if (train.shared case final shared?) ...[
                const _Section(title: 'Channels in this train'),
                for (final (channel, share) in topShares(shared, n: 6))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: HtAvatar(user: channel.user, size: 28),
                    title: Text(channel.user.displayName),
                    trailing: Text('$share%'),
                  ),
              ],
              const _Section(title: 'Conductors'),
              for (final source in const [HtSource.subs, HtSource.bits])
                _ConductorRow(
                  source: source,
                  conductor: train.conductors
                      .where((c) => c.source == source)
                      .firstOrNull,
                  badgeUrl: train.config.conductorBadges[source],
                ),
              _Section(title: 'Level ${train.level} rewards'),
              _RewardRow(rewards: train.progress.level.rewards, locked: true),
              if (store.unlockedRewards.isNotEmpty) ...[
                const _Section(title: 'Unlocked so far'),
                _RewardRow(rewards: store.unlockedRewards, locked: false),
              ],
              _UpcomingRewards(store: store, trainId: train.id),
              if (train.ath case final ath?) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Record: level ${ath.level} · '
                        '${athPercent(train.progress.total, ath)}% of the way',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onLearnMore,
                icon: const Icon(Icons.help_outline_rounded),
                label: const Text('How Hype Trains work'),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _variantTitle(HypeTrainExecution train) =>
      switch (train.variant) {
        HtVariant.treasure => 'Treasure Train',
        HtVariant.community => 'Community Train',
        HtVariant.mythic => 'Mythic Train',
        HtVariant.goldenKappa => 'Golden Kappa Train',
        HtVariant.regular => 'Hype Train',
      };

  static String? _variantLine(HypeTrainExecution train) {
    switch (train.variant) {
      case HtVariant.treasure:
        final treasure = train.treasure;
        if (treasure == null) return null;
        final unlocked = train.level >= treasure.threshold;
        return unlocked
            ? 'Treasure unlocked: ${treasure.discountPercentage}% off gift '
                  'subs for the rest of the train'
            : 'Reach level ${treasure.threshold} to unlock '
                  '${treasure.discountPercentage}% off gift subs';
      case HtVariant.community:
        final community = train.community;
        if (community == null) return null;
        final unlocked = train.level >= community.threshold;
        return unlocked
            ? 'Community emotes unlocked: ${community.current} viewers '
                  'in chat get one'
            : 'Reach level ${community.threshold} and '
                  '${community.next} viewers in chat get an emote';
      case HtVariant.mythic:
        final pool = train.mythic?.pool.length ?? 0;
        return 'One of these $pool emotes becomes the Mythic reward';
      case HtVariant.goldenKappa:
        return 'Everyone who takes part gets the Golden Kappa for 24 hours';
      case HtVariant.regular:
        return null;
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _ConductorRow extends StatelessWidget {
  const _ConductorRow({
    required this.source,
    required this.conductor,
    required this.badgeUrl,
  });

  final HtSource source;
  final HtConductor? conductor;
  final String? badgeUrl;

  String _amount(HtConductor conductor) {
    if (source == HtSource.bits) {
      return '${HtCopy.number(conductor.amount)} Bits';
    }
    final subs = conductor.amount;
    return '${HtCopy.number(subs)} ${subs == 1 ? 'sub' : 'subs'}';
  }

  @override
  Widget build(BuildContext context) {
    final conductor = this.conductor;
    final textTheme = Theme.of(context).textTheme;
    final label = source == HtSource.bits ? 'Top cheerer' : 'Top gifter';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 28,
            child: badgeUrl != null
                ? FrostyCachedNetworkImage(imageUrl: badgeUrl!)
                : Icon(
                    source == HtSource.bits
                        ? Icons.diamond_rounded
                        : Icons.star_rounded,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 8),
          if (conductor == null)
            Expanded(
              child: Text(
                source == HtSource.bits
                    ? 'No top cheerer yet'
                    : 'No top gifter yet',
                style: textTheme.bodyMedium?.copyWith(
                  color: textTheme.bodySmall?.color,
                ),
              ),
            )
          else ...[
            HtAvatar(user: conductor.user),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conductor.user.displayName),
                  Text(label, style: textTheme.bodySmall),
                ],
              ),
            ),
            Text(_amount(conductor)),
          ],
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.rewards, required this.locked});

  final List<HtReward> rewards;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final emotes = [
      for (final reward in rewards)
        if (reward.emoteUrl != null) reward,
    ];
    if (emotes.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final reward in emotes)
          Semantics(
            label:
                '${locked ? 'Locked' : 'Unlocked'} reward '
                '${reward.token ?? reward.id}',
            excludeSemantics: true,
            child: SizedBox.square(
              dimension: 36,
              child: Stack(
                children: [
                  Opacity(
                    opacity: locked ? 0.5 : 1,
                    child: FrostyCachedNetworkImage(
                      imageUrl: reward.emoteUrl.toString(),
                      width: 36,
                      height: 36,
                    ),
                  ),
                  if (locked)
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(Icons.lock_rounded, size: 14),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// "Coming up": fetched on first expand only.
class _UpcomingRewards extends StatefulWidget {
  const _UpcomingRewards({required this.store, required this.trainId});

  final HypeTrainStore store;
  final String trainId;

  @override
  State<_UpcomingRewards> createState() => _UpcomingRewardsState();
}

class _UpcomingRewardsState extends State<_UpcomingRewards> {
  var _requested = false;

  /// Null while loading.
  List<(int, List<HtReward>)>? _levels;

  void _load() {
    if (_requested) return;
    _requested = true;
    widget.store.loadUpcomingRewards().then((levels) {
      if (mounted) setState(() => _levels = levels);
    });
  }

  Widget _body() {
    final loaded = _levels;
    if (loaded == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final current = widget.store.train?.level ?? 0;
    final levels = loaded.where((l) => l.$1 > current).toList();
    if (levels.isEmpty) {
      return const Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text('Nothing more to show yet'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (level, rewards) in levels.take(10)) ...[
          Text('Level $level'),
          const SizedBox(height: 4),
          _RewardRow(rewards: rewards, locked: true),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('ht-upcoming-${widget.trainId}'),
        tilePadding: EdgeInsets.zero,
        title: Semantics(header: true, child: const Text('Coming up')),
        onExpansionChanged: (open) {
          if (open) _load();
        },
        children: [_body()],
      ),
    );
  }
}

class _ApproachingDetails extends StatelessWidget {
  const _ApproachingDetails({required this.store, required this.approaching});

  final HypeTrainStore store;
  final HypeTrainApproaching approaching;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'When enough viewers subscribe or cheer in a short time, they '
            'start a Hype Train. Each level unlocks emotes for everyone '
            'who took part.',
          ),
          const _Section(title: 'Level 1 rewards'),
          _RewardRow(rewards: approaching.levelOneRewards, locked: true),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: store.approachingCompleted ? 1 : store.approachingFraction,
          ),
        ],
      ),
    );
  }
}
