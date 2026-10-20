import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_directory_service.dart';
import 'package:frosty/apis/twitch_followed_categories_service.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/apis/twitch_watch_streak_service.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/home/followed_videos/followed_videos_screen.dart';
import 'package:frosty/screens/home/stream_list/followed_categories_section.dart';
import 'package:frosty/screens/home/stream_list/large_stream_card.dart';
import 'package:frosty/screens/home/stream_list/offline_channel_card.dart';
import 'package:frosty/screens/home/stream_list/stream_card.dart';
import 'package:frosty/screens/home/stream_list/stream_list_store.dart';
import 'package:frosty/screens/home/stream_list/stream_sort_button.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/expandable_section_header.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/scroll_to_top_button.dart';
import 'package:frosty/widgets/section_header.dart';
import 'package:frosty/widgets/skeleton_loader.dart';
import 'package:provider/provider.dart';

/// A widget that displays a list of followed or top streams based on the provided [listType].
/// For a widget that displays the top streams under a category, refer to [CategoryStreams].
class StreamsList extends StatefulWidget {
  /// The type of list to display.
  final ListType listType;

  final String? categoryId;

  /// The tag of a [ListType.tag] list.
  final String? tag;

  /// The order of a category or tag list.
  final StreamSort sort;

  /// The scroll controller to use for scroll to top functionality.
  final ScrollController? scrollController;

  final bool showJumpButton;

  const StreamsList({
    super.key,
    required this.listType,
    this.categoryId,
    this.tag,
    this.sort = StreamSort.viewersHigh,
    this.scrollController,
    this.showJumpButton = false,
  });

  @override
  State<StreamsList> createState() => _StreamsListState();
}

class _StreamsListState extends State<StreamsList>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final ListStore _listStore;
  ScrollController? _scrollController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.scrollController == null && widget.showJumpButton) {
      _scrollController = ScrollController();
    }

    _listStore = ListStore(
      authStore: context.read<AuthStore>(),
      settingsStore: context.read<SettingsStore>(),
      twitchApi: context.read<TwitchApi>(),
      listType: widget.listType,
      categoryId: widget.categoryId,
      tag: widget.tag,
      sort: widget.sort,
      directoryService:
          widget.listType == ListType.category ||
              widget.listType == ListType.tag
          ? context.read<TwitchDirectoryService>()
          : null,
      scrollController: widget.scrollController ?? _scrollController,
      hypeTrainService: widget.listType == ListType.followed
          ? context.read<TwitchHypeTrainService>()
          : null,
      followedCategoriesService: widget.listType == ListType.followed
          ? context.read<TwitchFollowedCategoriesService?>()
          : null,
      watchStreakService: widget.listType == ListType.followed
          ? context.read<TwitchWatchStreakService?>()
          : null,
    );
  }

  @override
  void didUpdateWidget(StreamsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sort != oldWidget.sort) _listStore.sort = widget.sort;
  }

  @override
  void dispose() {
    _listStore.dispose();
    _scrollController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Whether a card should render large.
  ///
  /// On top of the existing [SettingsStore.largeStreamCard] setting, the very
  /// first live channel of the followed list is promoted to a large card. That
  /// gives the list a hierarchy — the channel you are most likely to open is
  /// the one you can actually see — without taking either card setting away.
  ///
  /// It deliberately does nothing in two cases. In large-card mode every card
  /// is already large, so promoting the first one would change nothing. And
  /// with thumbnails off, a large card carries no extra information and only
  /// costs height.
  ///
  /// Only the followed list gets it: on Top or in a category, singling out one
  /// channel would be arbitrary, since the list is not the user's own.
  bool _useLargeCard({
    required SettingsStore settingsStore,
    required int index,
    required bool isFirstSection,
  }) {
    if (settingsStore.largeStreamCard) return true;
    if (widget.listType != ListType.followed) return false;
    if (!settingsStore.showThumbnails) return false;

    return isFirstSection && index == 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _listStore.checkLastTimeRefreshedAndUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    _listStore.checkLastTimeRefreshedAndUpdate();

    final extraTopPadding = widget.listType == ListType.top
        ? kToolbarHeight
        : widget.listType == ListType.category
        ? kToolbarHeight + 122 + kCategorySectionsHeight
        : widget.listType == ListType.tag
        ? kToolbarHeight + kCategorySectionsHeight
        : 0.0;

    final topPadding = MediaQuery.of(context).padding.top + extraTopPadding;

    return RefreshIndicator.adaptive(
      edgeOffset: topPadding,
      onRefresh: () async {
        HapticFeedback.lightImpact();

        await _listStore.refreshStreams();

        if (_listStore.error != null) {
          final snackBar = SnackBar(
            content: AlertMessage(message: _listStore.error!, centered: false),
          );

          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
      },
      child: Observer(
        builder: (_) {
          Widget? statusWidget;

          if (_listStore.error != null) {
            statusWidget = AlertMessage(
              message: _listStore.error!,
              vertical: true,
            );
          }

          if (_listStore.streams.isEmpty) {
            if (_listStore.isLoading && _listStore.error == null) {
              // Show skeleton loaders while loading
              final settingsStore = context.watch<SettingsStore>();
              final isFollowingTab = widget.listType == ListType.followed;
              final pinnedChannelCount = settingsStore.pinnedChannelIds.length;

              return CustomScrollView(
                slivers: [
                  // Add padding for app bar
                  SliverTopPadding(extraTopPadding: extraTopPadding),

                  // Show pinned section if following tab and has pinned channels
                  if (isFollowingTab && pinnedChannelCount > 0) ...[
                    SliverToBoxAdapter(
                      child: Builder(
                        builder: (context) => SectionHeader(
                          'Pinned',
                          isFirst: true,
                          padding: EdgeInsets.fromLTRB(
                            16 + MediaQuery.of(context).padding.left,
                            8,
                            16 + MediaQuery.of(context).padding.right,
                            8,
                          ),
                        ),
                      ),
                    ),
                    SliverList.builder(
                      itemCount: pinnedChannelCount,
                      itemBuilder: (context, index) {
                        if (_useLargeCard(
                          settingsStore: settingsStore,
                          index: index,
                          isFirstSection: true,
                        )) {
                          return LargeStreamCardSkeletonLoader(
                            showThumbnail: settingsStore.showThumbnails,
                            showCategory: widget.listType != ListType.category,
                          );
                        } else {
                          return StreamCardSkeletonLoader(
                            showThumbnail: settingsStore.showThumbnails,
                            showCategory: widget.listType != ListType.category,
                          );
                        }
                      },
                    ),
                    SliverToBoxAdapter(
                      child: Builder(
                        builder: (context) => SectionHeader(
                          'All',
                          isFirst: true,
                          padding: EdgeInsets.fromLTRB(
                            16 + MediaQuery.of(context).padding.left,
                            8,
                            16 + MediaQuery.of(context).padding.right,
                            8,
                          ),
                        ),
                      ),
                    ),
                  ],

                  SliverList.builder(
                    itemCount: isFollowingTab && pinnedChannelCount > 0 ? 5 : 8,
                    itemBuilder: (context, index) {
                      if (_useLargeCard(
                        settingsStore: settingsStore,
                        index: index,
                        isFirstSection: pinnedChannelCount == 0,
                      )) {
                        return LargeStreamCardSkeletonLoader(
                          showThumbnail: settingsStore.showThumbnails,
                          showCategory: widget.listType != ListType.category,
                        );
                      } else {
                        return StreamCardSkeletonLoader(
                          showThumbnail: settingsStore.showThumbnails,
                          showCategory: widget.listType != ListType.category,
                        );
                      }
                    },
                  ),
                  SliverBottomPadding(),
                ],
              );
            } else if (_listStore.hiddenByLabels > 0) {
              // Everything loaded was hidden: say so, and offer it.
              statusWidget = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AlertMessage(
                    message: 'Every stream here has a label you hide',
                    vertical: true,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _listStore.showLabeledStreams,
                    child: const Text('Show them'),
                  ),
                ],
              );
            } else {
              statusWidget = AlertMessage(
                message: switch (widget.listType) {
                  ListType.followed => 'No followed streams',
                  ListType.top => 'No top streams',
                  ListType.category || ListType.tag => 'No live streams',
                },
                vertical: true,
              );
            }
          }

          if (statusWidget != null) {
            return CustomScrollView(
              slivers: [
                // Past videos are worth a look most when nobody is live.
                if (widget.listType == ListType.followed) ...[
                  SliverTopPadding(extraTopPadding: extraTopPadding),
                  const SliverToBoxAdapter(child: FollowedVideosTile()),
                  SliverToBoxAdapter(
                    child: FollowedCategoriesSection(
                      categories: _listStore.followedCategories,
                    ),
                  ),
                ],
                SliverFillRemaining(child: Center(child: statusWidget)),
              ],
            );
          }

          final settingsStore = context.watch<SettingsStore>();

          final unpinnedStreams = widget.listType == ListType.followed
              ? _listStore.streams
                    .where(
                      (stream) => !settingsStore.pinnedChannelIds.contains(
                        stream.userId,
                      ),
                    )
                    .toList()
              : _listStore.streams;

          final isFollowingTab = widget.listType == ListType.followed;

          return Stack(
            alignment: AlignmentDirectional.bottomCenter,
            children: [
              Column(
                children: [
                  Expanded(
                    child: FrostyScrollbar(
                      controller: _listStore.scrollController,
                      padding: EdgeInsets.only(
                        top:
                            MediaQuery.of(context).padding.top +
                            extraTopPadding,
                        bottom: MediaQuery.of(context).padding.bottom,
                      ),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        controller: _listStore.scrollController,
                        slivers: [
                          SliverTopPadding(extraTopPadding: extraTopPadding),
                          if (!isFollowingTab)
                            SliverToBoxAdapter(
                              child: Observer(
                                builder: (context) => HiddenStreamsBanner(
                                  hidden: _listStore.hiddenByLabels,
                                  onShow: _listStore.showLabeledStreams,
                                ),
                              ),
                            ),
                          if (isFollowingTab)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  16 + MediaQuery.paddingOf(context).left,
                                  0,
                                  16 + MediaQuery.paddingOf(context).right,
                                  0,
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: FollowedSortButton(
                                    settingsStore: settingsStore,
                                  ),
                                ),
                              ),
                            ),
                          if (isFollowingTab &&
                              _listStore.allPinnedChannels.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: Builder(
                                builder: (context) => SectionHeader(
                                  'Pinned',
                                  isFirst: true,
                                  padding: EdgeInsets.fromLTRB(
                                    16 + MediaQuery.of(context).padding.left,
                                    8,
                                    16 + MediaQuery.of(context).padding.right,
                                    8,
                                  ),
                                ),
                              ),
                            ),
                            Observer(
                              builder: (context) {
                                // Show actual pinned channels (live streams only)
                                return SliverList.builder(
                                  itemCount:
                                      _listStore.allPinnedChannels.length,
                                  itemBuilder: (context, index) {
                                    final stream =
                                        _listStore.allPinnedChannels[index]
                                            as StreamTwitch;
                                    return Observer(
                                      builder: (context) {
                                        // Only live stream cards since we removed offline pinned channels
                                        return _useLargeCard(
                                              settingsStore: settingsStore,
                                              index: index,
                                              isFirstSection: true,
                                            )
                                            ? LargeStreamCard(
                                                key: ValueKey(stream.userId),
                                                streamInfo: stream,
                                                showThumbnail: context
                                                    .read<SettingsStore>()
                                                    .showThumbnails,
                                                showCategory:
                                                    widget.categoryId == null,
                                                showPinOption: true,
                                                isPinned: true,
                                                hypeTrain: _listStore
                                                    .hypeTrains[stream.userId],
                                                watchStreak:
                                                    _listStore
                                                        .watchStreaks[stream
                                                        .userId],
                                              )
                                            : StreamCard(
                                                key: ValueKey(stream.userId),
                                                streamInfo: stream,
                                                showThumbnail: context
                                                    .read<SettingsStore>()
                                                    .showThumbnails,
                                                showCategory:
                                                    widget.categoryId == null,
                                                showPinOption: true,
                                                isPinned: true,
                                                hypeTrain: _listStore
                                                    .hypeTrains[stream.userId],
                                                watchStreak:
                                                    _listStore
                                                        .watchStreaks[stream
                                                        .userId],
                                              );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                            SliverToBoxAdapter(
                              child: Builder(
                                builder: (context) => SectionHeader(
                                  'All',
                                  isFirst: true,
                                  padding: EdgeInsets.fromLTRB(
                                    16 + MediaQuery.of(context).padding.left,
                                    8,
                                    16 + MediaQuery.of(context).padding.right,
                                    8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          SliverList.builder(
                            itemCount: unpinnedStreams.length,
                            itemBuilder: (context, index) {
                              if (index > unpinnedStreams.length - 10 &&
                                  _listStore.hasMore) {
                                _listStore.getStreams();
                              }
                              return Observer(
                                builder: (context) =>
                                    _useLargeCard(
                                      settingsStore: settingsStore,
                                      index: index,
                                      // Pinned channels already sit above and
                                      // carry the hero, if there are any.
                                      isFirstSection:
                                          _listStore.allPinnedChannels.isEmpty,
                                    )
                                    ? LargeStreamCard(
                                        key: ValueKey(
                                          unpinnedStreams[index].userId,
                                        ),
                                        streamInfo: unpinnedStreams[index],
                                        showThumbnail:
                                            settingsStore.showThumbnails,
                                        showCategory: widget.categoryId == null,
                                        showPinOption: isFollowingTab,
                                        isPinned: false,
                                        hypeTrain:
                                            _listStore
                                                .hypeTrains[unpinnedStreams[index]
                                                .userId],
                                        watchStreak:
                                            _listStore
                                                .watchStreaks[unpinnedStreams[index]
                                                .userId],
                                      )
                                    : StreamCard(
                                        key: ValueKey(
                                          unpinnedStreams[index].userId,
                                        ),
                                        streamInfo: unpinnedStreams[index],
                                        showThumbnail:
                                            settingsStore.showThumbnails,
                                        showCategory: widget.categoryId == null,
                                        showPinOption: isFollowingTab,
                                        isPinned: false,
                                        hypeTrain:
                                            _listStore
                                                .hypeTrains[unpinnedStreams[index]
                                                .userId],
                                        watchStreak:
                                            _listStore
                                                .watchStreaks[unpinnedStreams[index]
                                                .userId],
                                      ),
                              );
                            },
                          ),
                          // Add offline followed channels section for following tab
                          if (isFollowingTab) ...[
                            const SliverToBoxAdapter(
                              child: FollowedVideosTile(),
                            ),
                            SliverToBoxAdapter(
                              child: Observer(
                                builder: (context) => FollowedCategoriesSection(
                                  categories: _listStore.followedCategories,
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Observer(
                                builder: (context) => ExpandableSectionHeader(
                                  'Offline',
                                  isFirst: true,
                                  padding: EdgeInsets.fromLTRB(
                                    16 + MediaQuery.of(context).padding.left,
                                    16,
                                    16 + MediaQuery.of(context).padding.right,
                                    8,
                                  ),
                                  isExpanded:
                                      _listStore.isOfflineChannelsExpanded,
                                  onToggle: () =>
                                      _listStore.isOfflineChannelsExpanded =
                                          !_listStore.isOfflineChannelsExpanded,
                                ),
                              ),
                            ),
                            if (_listStore.isOfflineChannelsExpanded)
                              SliverList.builder(
                                itemCount: _listStore.offlineChannels.length,
                                itemBuilder: (context, index) {
                                  // Load more offline channels when nearing the end
                                  if (index >
                                          _listStore.offlineChannels.length -
                                              5 &&
                                      _listStore.hasMoreOfflineChannels) {
                                    _listStore.getOfflineChannels();
                                  }

                                  return Observer(
                                    builder: (context) => OfflineChannelCard(
                                      key: ValueKey(
                                        _listStore
                                            .offlineChannels[index]
                                            .broadcasterId,
                                      ),
                                      channelInfo:
                                          _listStore.offlineChannels[index],
                                      showPinOption: false,
                                      isPinned: false,
                                    ),
                                  );
                                },
                              ),
                          ],
                          // Add padding for bottom navigation bar
                          const SliverBottomPadding(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.showJumpButton)
                Observer(
                  builder: (context) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _listStore.showJumpButton
                        ? ScrollToTopButton(
                            scrollController: _listStore.scrollController!,
                          )
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Helper widget for consistent top padding in sliver lists
class SliverTopPadding extends StatelessWidget {
  final double extraTopPadding;

  const SliverTopPadding({super.key, this.extraTopPadding = 0.0});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: MediaQuery.of(context).padding.top + extraTopPadding,
      ),
    );
  }
}

/// Helper widget for consistent bottom padding in sliver lists
class SliverBottomPadding extends StatelessWidget {
  const SliverBottomPadding({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(height: MediaQuery.of(context).padding.bottom),
    );
  }
}

/// Says how many streams the viewer's content preferences left out of a
/// list, with a way to show them (nothing when none are hidden).
class HiddenStreamsBanner extends StatelessWidget {
  const HiddenStreamsBanner({
    super.key,
    required this.hidden,
    required this.onShow,
  });

  final int hidden;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    if (hidden == 0) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16 + MediaQuery.paddingOf(context).left,
        4,
        8 + MediaQuery.paddingOf(context).right,
        4,
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hidden == 1
                  ? '1 stream hidden by your content preferences'
                  : '$hidden streams hidden by your content preferences',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onShow, child: const Text('Show')),
        ],
      ),
    );
  }
}

/// Opens the newest videos of the followed channels.
class FollowedVideosTile extends StatelessWidget {
  const FollowedVideosTile({super.key});

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return ListTile(
      contentPadding: EdgeInsets.fromLTRB(
        16 + padding.left,
        8,
        16 + padding.right,
        0,
      ),
      leading: const Icon(Icons.video_library_outlined),
      title: const Text('Followed videos'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        final id = context.read<AuthStore>().user.details?.id;
        if (id == null) return;
        unawaited(FollowedVideosScreen.open(context, userId: id));
      },
    );
  }
}
