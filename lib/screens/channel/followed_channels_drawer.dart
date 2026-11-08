import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/followed_channel.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/channel_profile/channel_profile_screen.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:provider/provider.dart';

typedef FollowedDrawerSections = ({
  List<StreamTwitch> live,
  List<FollowedChannel> offline,
});

FollowedDrawerSections followedDrawerSections({
  required Iterable<StreamTwitch> pinned,
  required Iterable<StreamTwitch> streams,
  required Iterable<FollowedChannel> offline,
}) {
  final seen = <String>{};
  final live = [
    for (final stream in [...pinned, ...streams])
      if (seen.add(stream.userId)) stream,
  ];
  final sortedOffline =
      [
        for (final channel in offline)
          if (!seen.contains(channel.broadcasterId)) channel,
      ]..sort(
        (a, b) => getReadableName(a.broadcasterName, a.broadcasterLogin)
            .toLowerCase()
            .compareTo(
              getReadableName(
                b.broadcasterName,
                b.broadcasterLogin,
              ).toLowerCase(),
            ),
      );
  return (live: live, offline: sortedOffline);
}

class FollowedChannelsDrawer extends StatefulWidget {
  const FollowedChannelsDrawer({
    super.key,
    required this.currentLogin,
    this.store,
  });

  final String currentLogin;

  final ListStore? store;

  @override
  State<FollowedChannelsDrawer> createState() => _FollowedChannelsDrawerState();
}

class _FollowedChannelsDrawerState extends State<FollowedChannelsDrawer> {
  late final _ownStore = widget.store == null;

  late final ListStore _store =
      widget.store ??
      ListStore(
        listType: ListType.followed,
        authStore: context.read<AuthStore>(),
        settingsStore: context.read<SettingsStore>(),
        twitchApi: context.read<TwitchApi>(),
      );

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _store.isOfflineChannelsExpanded = true;
    _scrollController.addListener(_loadMoreNearTheEnd);
  }

  void _loadMoreNearTheEnd() {
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 200) return;
    if (_store.hasMore) {
      _store.getStreams();
    } else if (_store.hasMoreOfflineChannels) {
      _store.getOfflineChannels();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (_ownStore) _store.dispose();
    super.dispose();
  }

  void _openLive(StreamTwitch stream) {
    final navigator = Navigator.of(context);
    navigator.pop();
    if (stream.userLogin.toLowerCase() == widget.currentLogin.toLowerCase()) {
      return;
    }
    navigator.pushReplacement(streamRoute(stream));
  }

  void _openOffline(FollowedChannel channel) {
    final navigator = Navigator.of(context);
    navigator.pop();
    ChannelProfileScreen.open(
      navigator.context,
      login: channel.broadcasterLogin,
      displayName: channel.broadcasterName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final width = (MediaQuery.sizeOf(context).width * 0.82).clamp(260.0, 360.0);
    return Drawer(
      width: width,
      backgroundColor: OnsetTokens.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(OnsetTokens.radiusDialog),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Observer(
          builder: (context) {
            final sections = followedDrawerSections(
              pinned: _store.allPinnedChannels.whereType<StreamTwitch>(),
              streams: _store.streams,
              offline: _store.offlineChannels,
            );
            final loading = _store.isLoading;
            final empty = sections.live.isEmpty && sections.offline.isEmpty;
            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      OnsetSpacing.lg,
                      OnsetSpacing.lg,
                      OnsetSpacing.lg,
                      OnsetSpacing.sm,
                    ),
                    child: Text(
                      l.followedDrawerTitle,
                      style: OnsetType.screenTitle.copyWith(
                        color: OnsetTokens.textPrimaryDark,
                      ),
                    ),
                  ),
                ),
                if (empty && loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: OnsetTokens.accent,
                      ),
                    ),
                  )
                else if (empty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(OnsetSpacing.xl),
                        child: Text(
                          _store.error == null
                              ? l.followedDrawerEmpty
                              : l.followedDrawerFailed,
                          textAlign: TextAlign.center,
                          style: OnsetType.body.copyWith(
                            color: OnsetTokens.textSecondaryDark,
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  if (sections.live.isNotEmpty) ...[
                    _SectionHeader(l.followedDrawerLive),
                    SliverList.builder(
                      itemCount: sections.live.length,
                      itemBuilder: (context, index) {
                        final stream = sections.live[index];
                        return _ChannelRow(
                          login: stream.userLogin,
                          name: getReadableName(
                            stream.userName,
                            stream.userLogin,
                          ),
                          detail: stream.gameName.isNotEmpty
                              ? stream.gameName
                              : l.streamViewers(count: stream.viewerCount),
                          trailing: l.streamViewers(count: stream.viewerCount),
                          live: true,
                          current:
                              stream.userLogin.toLowerCase() ==
                              widget.currentLogin.toLowerCase(),
                          onTap: () => _openLive(stream),
                        );
                      },
                    ),
                  ],
                  if (sections.offline.isNotEmpty) ...[
                    _SectionHeader(l.streamOffline),
                    SliverList.builder(
                      itemCount: sections.offline.length,
                      itemBuilder: (context, index) {
                        final channel = sections.offline[index];
                        return _ChannelRow(
                          login: channel.broadcasterLogin,
                          name: getReadableName(
                            channel.broadcasterName,
                            channel.broadcasterLogin,
                          ),
                          live: false,
                          current: false,
                          onTap: () => _openOffline(channel),
                        );
                      },
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: SizedBox(height: OnsetSpacing.lg),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        OnsetSpacing.lg,
        OnsetSpacing.md,
        OnsetSpacing.lg,
        OnsetSpacing.xs,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: OnsetType.section.copyWith(
            color: OnsetTokens.textSecondaryDark,
          ),
        ),
      ),
    ),
  );
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.login,
    required this.name,
    required this.live,
    required this.current,
    required this.onTap,
    this.detail,
    this.trailing,
  });

  final String login;
  final String name;
  final String? detail;
  final String? trailing;
  final bool live;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return Material(
      color: current ? OnsetTokens.accentTint : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OnsetSpacing.lg,
              vertical: OnsetSpacing.sm,
            ),
            child: Row(
              children: [
                Opacity(
                  opacity: live ? 1 : 0.55,
                  child: ProfilePicture(userLogin: login, radius: 18),
                ),
                const SizedBox(width: OnsetSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OnsetType.channelName.copyWith(
                          color: live
                              ? OnsetTokens.textPrimaryDark
                              : OnsetTokens.textSecondaryDark,
                        ),
                      ),
                      if (detail != null)
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OnsetType.meta.copyWith(
                            color: OnsetTokens.textTertiaryDark,
                          ),
                        ),
                    ],
                  ),
                ),
                if (live) ...[
                  const SizedBox(width: OnsetSpacing.sm),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.onsetColors.live,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
