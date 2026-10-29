import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/models/channel.dart';
import 'package:frosty/screens/channel/channel.dart';
import 'package:frosty/screens/channel_profile/channel_profile_screen.dart';
import 'package:frosty/screens/home/search/featured_channel.dart';
import 'package:frosty/screens/home/search/search_store.dart';
import 'package:frosty/screens/home/stream_list/stream_card_parts.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/motion/press_scale.dart';
import 'package:frosty/widgets/motion/staggered_entrance.dart';
import 'package:frosty/widgets/skeleton_loader.dart';
import 'package:frosty/widgets/state_views.dart';
import 'package:frosty/widgets/uptime.dart';
import 'package:frosty/widgets/user_actions_modal.dart';
import 'package:mobx/mobx.dart';

/// How "Go to channel" is drawn: a row under a list, or a pill under the
/// tablet's grid.
enum GoToStyle { row, pill }

/// The channels found by a search (boards Recherche and RechercheTablette):
/// the exact match first in its card, then the others (at most [limit]),
/// then "Go to channel" for a login the search did not list.
///
/// A live channel opens its stream, an offline one its profile; a long
/// press opens the channel's actions. Blocked channels never show.
class SearchResultsChannels extends StatefulWidget {
  final SearchStore searchStore;
  final String query;

  /// How many channels besides the exact match (null: all).
  final int? limit;

  /// The tablet's sizes (picture 44, the larger card).
  final bool large;

  /// Channels side by side (the tablet's Channels tab).
  final int columns;

  /// The sides of the rows (a phone's gutter, plus the window's side
  /// insets; none in a tablet column, which is inset already).
  final double gutter;

  final GoToStyle goTo;

  const SearchResultsChannels({
    super.key,
    required this.searchStore,
    required this.query,
    this.limit,
    this.large = false,
    this.columns = 1,
    this.gutter = FrostySpacing.gutterPhone,
    this.goTo = GoToStyle.row,
  });

  @override
  State<SearchResultsChannels> createState() => _SearchResultsChannelsState();
}

class _SearchResultsChannelsState extends State<SearchResultsChannels> {
  Future<void> _handleSearch(BuildContext context, String search) async {
    try {
      final channelInfo = await widget.searchStore.searchChannel(search);

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: VideoChat.routeName),
          builder: (context) => VideoChat(
            userId: channelInfo.broadcasterId,
            userName: channelInfo.broadcasterName,
            userLogin: channelInfo.broadcasterLogin,
          ),
        ),
      );
    } on ApiException catch (e) {
      debugPrint('Search channels ApiException: $e');
      final snackBar = SnackBar(
        content: AlertMessage(message: e.message, centered: false),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (error) {
      debugPrint('Search channels error: $error');
      final snackBar = SnackBar(
        content: AlertMessage(
          message: 'Unable to find channel',
          centered: false,
        ),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  /// Live: the stream; offline: the profile, like Twitch.
  void _open(BuildContext context, ChannelQuery channel) {
    if (channel.isLive) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: VideoChat.routeName),
          builder: (context) => VideoChat(
            userId: channel.id,
            userName: channel.displayName,
            userLogin: channel.broadcasterLogin,
          ),
        ),
      );
    } else {
      ChannelProfileScreen.open(
        context,
        login: channel.broadcasterLogin,
        userId: channel.id,
        displayName: getReadableName(
          channel.displayName,
          channel.broadcasterLogin,
        ),
      );
    }
  }

  void _showActions(BuildContext context, ChannelQuery channel) {
    HapticFeedback.mediumImpact();

    showModalBottomSheetWithProperFocus(
      context: context,
      builder: (context) => UserActionsModal(
        authStore: widget.searchStore.authStore,
        name: getReadableName(channel.displayName, channel.broadcasterLogin),
        userLogin: channel.broadcasterLogin,
        userId: channel.id,
      ),
    );
  }

  EdgeInsets get _sides {
    final gutter = widget.gutter;
    if (gutter == 0) return EdgeInsets.zero;
    final window = MediaQuery.paddingOf(context);
    return EdgeInsets.only(
      left: gutter + window.left,
      right: gutter + window.right,
    );
  }

  Widget _skeleton() => Column(
    children: [
      for (var i = 0; i < (widget.limit ?? 8); i++)
        Padding(
          padding: _sides,
          child: SearchRowSkeleton(index: i, large: widget.large),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final future = widget.searchStore.channelFuture;

        // Show skeletons immediately while waiting for debounce.
        if (future == null) {
          if (widget.searchStore.isSearching) return _skeleton();
          return const SizedBox.shrink();
        }

        switch (future.status) {
          case FutureStatus.pending:
            return _skeleton();
          case FutureStatus.rejected:
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 100),
              child: Center(
                child: InlineStatus.error(message: 'Unable to load channels'),
              ),
            );
          case FutureStatus.fulfilled:
            final blocked = {
              for (final user in widget.searchStore.authStore.user.blockedUsers)
                user.userId,
            };
            final results = (future.result as List<ChannelQuery>)
                .where((channel) => !blocked.contains(channel.id))
                .toList();

            final featured = featuredChannel(results, widget.query);
            final others = results.where((channel) => channel != featured);
            final limit = widget.limit;
            final shown = (limit == null ? others : others.take(limit))
                .toList();
            final rows = [
              for (var i = 0; i < shown.length; i++)
                StaggeredEntrance(
                  key: ValueKey(shown[i].id),
                  index: i + 1,
                  offset: 6,
                  child: SearchChannelRow(
                    channel: shown[i],
                    large: widget.large,
                    padding: widget.columns > 1 ? EdgeInsets.zero : _sides,
                    onTap: () => _open(context, shown[i]),
                    onLongPress: () => _showActions(context, shown[i]),
                  ),
                ),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (featured != null)
                  Padding(
                    padding: _sides.copyWith(bottom: widget.large ? 6 : 8),
                    child: StaggeredEntrance(
                      index: 0,
                      offset: 6,
                      child: FeaturedChannelCard(
                        channel: featured,
                        large: widget.large,
                        onTap: () => _open(context, featured),
                        onLongPress: () => _showActions(context, featured),
                      ),
                    ),
                  ),
                if (widget.columns > 1)
                  Padding(
                    padding: _sides,
                    child: _Grid(
                      columns: widget.columns,
                      gap: 24,
                      rowGap: 4,
                      children: rows,
                    ),
                  )
                else
                  ...rows,
                Padding(
                  padding: widget.goTo == GoToStyle.pill
                      ? _sides.copyWith(top: 12)
                      : EdgeInsets.zero,
                  child: _GoToChannel(
                    query: widget.query,
                    style: widget.goTo,
                    large: widget.large,
                    padding: _sides,
                    onTap: () => _handleSearch(context, widget.query),
                  ),
                ),
              ],
            );
        }
      },
    );
  }
}

/// Children in [columns], top-aligned, [gap] apart.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.columns,
    required this.gap,
    required this.rowGap,
    required this.children,
  });

  final int columns;
  final double gap;
  final double rowGap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = (children.length / columns).ceil();
    return Column(
      spacing: rowGap,
      children: [
        for (var row = 0; row < rows; row++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: gap,
            children: [
              for (var column = 0; column < columns; column++)
                Expanded(
                  child: row * columns + column < children.length
                      ? children[row * columns + column]
                      : const SizedBox.shrink(),
                ),
            ],
          ),
      ],
    );
  }
}

/// A found channel: the picture (ringed when live), the name, then the
/// uptime and category when live, "Offline · category" when not.
class SearchChannelRow extends StatelessWidget {
  const SearchChannelRow({
    super.key,
    required this.channel,
    required this.onTap,
    required this.onLongPress,
    this.large = false,
    this.padding = EdgeInsets.zero,
  });

  final ChannelQuery channel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool large;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final name = getReadableName(channel.displayName, channel.broadcasterLogin);
    final meta = TextStyle(fontSize: 12, color: colors.secondary);
    return PressScale(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: large ? 60 : 56),
          child: Padding(
            padding: padding + const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              spacing: 12,
              children: [
                SearchAvatar(
                  login: channel.broadcasterLogin,
                  size: large ? 44 : 40,
                  live: channel.isLive,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 3,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      if (channel.isLive)
                        Row(
                          spacing: 6,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: context.frostyColors.live,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Uptime(
                              startTime: channel.startedAt,
                              style: FrostyType.tabular(meta),
                            ),
                            if (channel.gameName.isNotEmpty)
                              Flexible(
                                child: Text(
                                  '· ${channel.gameName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: meta,
                                ),
                              ),
                          ],
                        )
                      else
                        Text(
                          offlineLine(channel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: meta.copyWith(color: colors.tertiary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Go to channel “query”": opens a channel by its exact login, for one
/// the search did not list.
class _GoToChannel extends StatelessWidget {
  const _GoToChannel({
    required this.query,
    required this.style,
    required this.large,
    required this.padding,
    required this.onTap,
  });

  final String query;
  final GoToStyle style;
  final bool large;
  final EdgeInsets padding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final label = 'Go to channel "$query"';
    final text = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: colors.body,
    );
    if (style == GoToStyle.pill) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: PressScale(
          child: Material(
            color: colors.surface,
            shape: StadiumBorder(
              side: BorderSide(
                color: colors.pillBorder,
                width: FrostyTokens.hairlineWidth,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.tertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final circle = large ? 44.0 : 40.0;
    return PressScale(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: padding + const EdgeInsets.only(top: 2),
            child: Row(
              spacing: 12,
              children: [
                Container(
                  width: circle,
                  height: circle,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface,
                    border: Border.all(
                      color: colors.pillBorder,
                      width: FrostyTokens.hairlineWidth,
                    ),
                  ),
                  child: Icon(
                    Icons.north_east_rounded,
                    size: 18,
                    color: colors.secondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colors.tertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A result row, loading (board Recherche: a 40 dp circle and two lines).
class SearchRowSkeleton extends StatelessWidget {
  const SearchRowSkeleton({super.key, required this.index, this.large = false});

  final int index;
  final bool large;

  static const _widths = [
    (0.46, 0.28),
    (0.38, 0.22),
    (0.52, 0.30),
    (0.34, 0.20),
    (0.44, 0.26),
    (0.40, 0.24),
  ];

  @override
  Widget build(BuildContext context) {
    final (first, second) = _widths[index % _widths.length];
    final avatar = large ? 44.0 : 40.0;
    return SizedBox(
      height: large ? 60 : 56,
      child: Row(
        spacing: 12,
        children: [
          SkeletonLoader(
            width: avatar,
            height: avatar,
            borderRadius: BorderRadius.all(Radius.circular(avatar / 2)),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 7,
                children: [
                  SkeletonLoader(
                    width: constraints.maxWidth * first,
                    height: 12,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                  SkeletonLoader(
                    width: constraints.maxWidth * second,
                    height: 10,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
