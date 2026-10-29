import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/frosty_cached_network_image.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

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
/// badges (as the board's pills), when they made their account and, to a
/// moderator, since when they follow the channel (Twitch only tells
/// moderators).
class UserCardInfo extends StatefulWidget {
  const UserCardInfo({
    super.key,
    required this.api,
    required this.userId,
    required this.channelId,
    required this.showFollowAge,
    required this.badges,
    this.dense = false,
  });

  final TwitchApi api;
  final String userId;
  final String channelId;
  final bool showFollowAge;
  final List<UserCardBadge> badges;

  /// The tablet panel's smaller sizes.
  final bool dense;

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

  Widget _line(Future<DateTime?>? date, SheetGlyphKind glyph, String label) =>
      FutureBuilder<DateTime?>(
        future: date,
        builder: (context, snapshot) {
          final value = snapshot.data;
          if (value == null) return const SizedBox.shrink();
          final color = SheetColors.of(context).secondary;
          return Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 5,
            children: [
              SheetGlyph(glyph, size: widget.dense ? 13 : 14, color: color),
              Flexible(
                child: Text(
                  '$label ${DateFormat.yMMMd().format(value.toLocal())}',
                  overflow: TextOverflow.ellipsis,
                  style: SheetText.status.copyWith(
                    fontSize: widget.dense ? 12 : 12.5,
                    color: color,
                  ),
                ),
              ),
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final dense = widget.dense;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.badges.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(16, dense ? 10 : 12, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (:badge, :label) in widget.badges)
                  Tooltip(
                    message: label,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Semantics(
                      label: label,
                      child: ExcludeSemantics(
                        child: Container(
                          height: dense ? 26 : 28,
                          padding: EdgeInsetsDirectional.only(
                            start: 4,
                            end: dense ? 9 : 10,
                          ),
                          decoration: ShapeDecoration(
                            color: dense ? colors.chip : colors.raised,
                            shape: StadiumBorder(
                              side: dense
                                  ? BorderSide.none
                                  : BorderSide(
                                      color: colors.ring,
                                      width: FrostyTokens.hairlineWidth,
                                    ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 6,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  dense ? 5 : 6,
                                ),
                                child: FrostyCachedNetworkImage(
                                  imageUrl: badge.url,
                                  width: dense ? 18 : 20,
                                  height: dense ? 18 : 20,
                                ),
                              ),
                              Text(
                                label,
                                style: TextStyle(
                                  fontFamily: FrostyTokens.bodyFamily,
                                  fontSize: dense ? 11.5 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, dense ? 8 : 10, 16, 0),
          child: Wrap(
            spacing: dense ? 12 : 14,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _line(_createdAt, SheetGlyphKind.cake, 'Account created'),
              if (_followedAt != null)
                _line(_followedAt, SheetGlyphKind.heart, 'Following since'),
            ],
          ),
        ),
      ],
    );
  }
}
