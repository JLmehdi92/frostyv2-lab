import 'package:flutter/material.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/badges.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:intl/intl.dart';

/// A Twitch badge someone wears, with what it says ("Subscriber · 14
/// months").
typedef UserCardBadge = ({ChatBadge badge, String label});

/// The Twitch badges of [latest] (someone's latest message) that chat
/// knows, in their order, with the months of a subscriber or founder badge.
List<UserCardBadge> userCardBadges(
  IRCMessage? latest,
  Map<String, ChatBadge> twitchBadges,
) {
  final badges = latest?.tags['badges'];
  if (badges == null || badges.isEmpty) return const [];
  final months = <String, String>{
    for (final info in (latest!.tags['badge-info'] ?? '').split(','))
      if (info.contains('/')) info.split('/').first: info.split('/').last,
  };
  return [
    for (final id in badges.split(','))
      if (twitchBadges[id] case final badge?)
        (badge: badge, label: _label(badge.name, id, months)),
  ];
}

String _label(String name, String id, Map<String, String> months) {
  final set = id.split('/').first;
  final count = int.tryParse(months[set] ?? '');
  if ((set == 'subscriber' || set == 'founder') && count != null && count > 0) {
    return '$name · $count month${count == 1 ? '' : 's'}';
  }
  return name;
}

/// What the user card tells about someone besides their messages: their
/// badges, when they made their account and, to a moderator, since when
/// they follow the channel (Twitch only tells moderators).
class UserCardInfo extends StatefulWidget {
  const UserCardInfo({
    super.key,
    required this.api,
    required this.userId,
    required this.channelId,
    required this.showFollowAge,
    required this.badges,
  });

  final TwitchApi api;
  final String userId;
  final String channelId;
  final bool showFollowAge;
  final List<UserCardBadge> badges;

  @override
  State<UserCardInfo> createState() => _UserCardInfoState();
}

class _UserCardInfoState extends State<UserCardInfo> {
  late final Future<DateTime?> _createdAt = _orNull(
    'account date',
    () async => (await widget.api.getUser(id: widget.userId)).createdAt,
  );
  late final Future<DateTime?>? _followedAt = widget.showFollowAge
      ? _orNull(
          'follow date',
          () => widget.api.getFollowedAt(
            broadcasterId: widget.channelId,
            userId: widget.userId,
          ),
        )
      : null;

  /// A line that cannot be read is left out: the card works without it.
  static Future<DateTime?> _orNull(
    String what,
    Future<DateTime?> Function() load,
  ) async {
    try {
      return await load();
    } catch (error) {
      debugPrint('User card $what failed: $error');
      return null;
    }
  }

  Widget _line(Future<DateTime?>? date, IconData icon, String label) =>
      FutureBuilder<DateTime?>(
        future: date,
        builder: (context, snapshot) {
          final value = snapshot.data;
          if (value == null) return const SizedBox.shrink();
          final theme = Theme.of(context);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '$label ${DateFormat.yMMMd().format(value.toLocal())}',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (:badge, :label) in widget.badges)
            Tooltip(
              message: label,
              triggerMode: TooltipTriggerMode.tap,
              child: Semantics(
                label: label,
                child: FrostyCachedNetworkImage(
                  imageUrl: badge.url,
                  width: 18,
                  height: 18,
                ),
              ),
            ),
          _line(_createdAt, Icons.cake_outlined, 'Account created'),
          if (_followedAt != null)
            _line(
              _followedAt,
              Icons.favorite_outline_rounded,
              'Following since',
            ),
        ],
      ),
    );
  }
}
