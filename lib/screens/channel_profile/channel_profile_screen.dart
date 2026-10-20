import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel/channel.dart';
import 'package:frosty/screens/channel_profile/stores/channel_profile_store.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_about_tab.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_header.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_home_tab.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_schedule_tab.dart';
import 'package:frosty/screens/clips/stores/channel_clips_store.dart';
import 'package:frosty/screens/clips/widgets/channel_clips_tab.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/vod/stores/channel_videos_store.dart';
import 'package:frosty/screens/vod/widgets/channel_videos_tab.dart';
import 'package:frosty/services/notifications/schedule_reminders.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/link_router.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/utils/share_link.dart';
import 'package:frosty/utils/twitch_links.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/frosty_app_bar.dart';
import 'package:frosty/widgets/readable_width.dart';
import 'package:frosty/widgets/twitch_web_page.dart';
import 'package:frosty/widgets/user_actions_modal.dart';
import 'package:mobx/mobx.dart';
import 'package:provider/provider.dart';

enum ProfileTab {
  home('Home'),
  about('About'),
  schedule('Schedule'),
  videos('Videos'),
  clips('Clips');

  const ProfileTab(this.label);

  final String label;
}

/// A channel's profile page: header, then Home, About, Schedule, Videos
/// and Clips tabs. The header scrolls away; the tab bar stays.
class ChannelProfileScreen extends StatefulWidget {
  static const routeName = 'ChannelProfile';

  const ChannelProfileScreen({
    super.key,
    required this.login,
    this.userId,
    this.displayName,
    this.initialTab = ProfileTab.home,
    this.fromChannel = false,
  });

  final String login;

  /// Known by the caller: Chat and More work before (or without) the
  /// profile.
  final String? userId;

  /// Shown until the profile loads.
  final String? displayName;
  final ProfileTab initialTab;

  /// Opened from this channel's screen: Watch and Chat go back to it.
  final bool fromChannel;

  static Future<void> open(
    BuildContext context, {
    required String login,
    String? userId,
    String? displayName,
    ProfileTab initialTab = ProfileTab.home,
    bool fromChannel = false,
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => ChannelProfileScreen(
        login: login,
        userId: userId,
        displayName: displayName,
        initialTab: initialTab,
        fromChannel: fromChannel,
      ),
    ),
  );

  @override
  State<ChannelProfileScreen> createState() => _ChannelProfileScreenState();
}

class _ChannelProfileScreenState extends State<ChannelProfileScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: ProfileTab.values.length,
    vsync: this,
    initialIndex: widget.initialTab.index,
  );

  late final _store = ChannelProfileStore(
    login: widget.login,
    profileService: context.twitchChannelProfileService,
    helixUser: (login) => context.twitchApi.getUser(userLogin: login),
  );

  late final _videos = ChannelVideosStore(
    login: widget.login,
    type: VodType.archive,
    vodService: context.twitchVodService,
  );

  late final _clips = ChannelClipsStore(
    login: widget.login,
    clipService: context.twitchClipService,
  );

  /// Home's "Popular clips": this week's top, whatever the Clips tab picks.
  late final _homeClips = ChannelClipsStore(
    login: widget.login,
    clipService: context.twitchClipService,
  );

  late final ReactionDisposer _syncReminders;

  @override
  void initState() {
    super.initState();
    unawaited(_store.load());
    // Reminders follow the schedule as read: a moved segment's moves, a
    // cancelled one's goes.
    _syncReminders = reaction((_) => _store.schedule, (
      ChannelSchedule? schedule,
    ) {
      if (schedule == null) return;
      unawaited(
        ScheduleReminders.shared?.sync(widget.login, schedule.segments),
      );
    });
    _tabs.addListener(_onTab);
    _onTab();
  }

  void _onTab() {
    if (ProfileTab.values[_tabs.index] == ProfileTab.schedule &&
        _store.schedule == null &&
        !_store.scheduleLoading) {
      unawaited(_store.loadSchedule());
    }
  }

  @override
  void dispose() {
    _syncReminders();
    _tabs
      ..removeListener(_onTab)
      ..dispose();
    _store.dispose();
    _videos.dispose();
    _clips.dispose();
    _homeClips.dispose();
    super.dispose();
  }

  String get _name => _store.displayName ?? widget.displayName ?? widget.login;

  String? get _userId => _store.userId ?? widget.userId;

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AlertMessage(message: message, centered: false)),
    );
  }

  /// Pull to refresh; a failure over a shown profile is said, not silent.
  Future<void> _refresh() async {
    await _store.refresh();
    if (_store.error != null && _store.profile != null) {
      _say("Couldn't refresh this channel");
    }
  }

  void _openChannel() {
    if (widget.fromChannel) {
      Navigator.of(context).pop();
      return;
    }
    final id = _userId;
    if (id == null) {
      _say("Couldn't open this channel, check your connection");
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: VideoChat.routeName),
        builder: (context) =>
            VideoChat(userId: id, userName: _name, userLogin: widget.login),
      ),
    );
  }

  /// Twitch's Subscribe: the channel's subscription page on twitch.tv.
  void _subscribe() {
    final url = twitchSubscribeUrl(widget.login);
    if (url == null) return;
    unawaited(
      TwitchWebPage.open(context, title: 'Subscribe to $_name', url: url),
    );
  }

  /// Not on the viewer's own channel (signed out, twitch.tv asks to log
  /// in first).
  bool get _canSubscribe {
    final auth = context.read<AuthStore?>();
    if (auth == null || !auth.isLoggedIn) return true;
    return auth.user.details?.login.toLowerCase() != widget.login.toLowerCase();
  }

  Future<void> _share() =>
      shareLink(context, 'https://www.twitch.tv/${widget.login}');

  void _more() {
    final id = _userId;
    if (id == null) return;
    final settings = context.settingsStore;
    showModalBottomSheetWithProperFocus(
      context: context,
      builder: (context) => UserActionsModal(
        authStore: context.authStore,
        name: _name,
        userLogin: widget.login,
        userId: id,
        showPinOption: true,
        isPinned: settings.pinnedChannelIds.contains(id),
        showProfile: false,
      ),
    );
  }

  void _openLink(String url) => unawaited(
    LinkRouter.open(
      url,
      launchExternal: context.settingsStore.launchUrlExternal,
    ),
  );

  /// One of Home, About and Schedule: padded, readable on a tablet, pull to
  /// refresh.
  Widget _scrollTab(String key, Widget child) => RefreshIndicator.adaptive(
    onRefresh: _refresh,
    child: CustomScrollView(
      key: PageStorageKey(key),
      slivers: [
        SliverReadableWidth(
          sliver: SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.paddingOf(context).bottom + 16,
            ),
            sliver: SliverToBoxAdapter(child: child),
          ),
        ),
      ],
    ),
  );

  Widget _status(String message, {VoidCallback? onRetry}) => AlertMessage(
    message: message,
    vertical: onRetry == null,
    trailingIcon: onRetry == null ? null : Icons.refresh_rounded,
    onTrailingIconPressed: onRetry,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FrostyAppBar(title: Observer(builder: (_) => Text(_name))),
      body: Observer(
        builder: (context) {
          if (_store.notFound) {
            return Center(
              child: _status(
                'Channel not found',
                onRetry: () => unawaited(_store.load()),
              ),
            );
          }
          final profile = _store.profile;
          // Read here: the header builder runs outside this Observer.
          final name = _name;
          final canMore = _userId != null;
          final canSubscribe = _canSubscribe;
          final retrying = _store.isLoading && profile == null;
          return SafeArea(
            bottom: false,
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverReadableWidth(
                  sliver: SliverToBoxAdapter(
                    child: ProfileHeader(
                      login: widget.login,
                      displayName: name,
                      profile: profile,
                      onOpenChannel: _openChannel,
                      onShare: _share,
                      onMore: canMore ? _more : null,
                      onSubscribe: canSubscribe ? _subscribe : null,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    tabs: [
                      for (final tab in ProfileTab.values) Tab(text: tab.label),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _scrollTab(
                          'home',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (retrying)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator.adaptive(),
                                  ),
                                )
                              else if (_store.error != null && profile == null)
                                _status(
                                  _store.error!,
                                  onRetry: () => unawaited(_store.load()),
                                ),
                              ProfileHomeContent(
                                login: widget.login,
                                profile: profile,
                                videos: _videos,
                                clips: _homeClips,
                                onOpenChannel: _openChannel,
                                onViewAllVideos: () =>
                                    _tabs.animateTo(ProfileTab.videos.index),
                                onViewAllClips: () =>
                                    _tabs.animateTo(ProfileTab.clips.index),
                              ),
                            ],
                          ),
                        ),
                        _scrollTab(
                          'about',
                          profile == null
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 48),
                                  child: _store.loaded && !retrying
                                      ? _status(
                                          _store.error ?? 'No details',
                                          onRetry: () =>
                                              unawaited(_store.load()),
                                        )
                                      : const Center(
                                          child:
                                              CircularProgressIndicator.adaptive(),
                                        ),
                                )
                              : ProfileAboutContent(
                                  profile: profile,
                                  onOpenLink: _openLink,
                                ),
                        ),
                        _scrollTab('schedule', _scheduleContent()),
                        ChannelVideosTab(
                          store: _videos,
                          emptyMessage: 'No past broadcasts',
                          nested: true,
                        ),
                        ChannelClipsTab(store: _clips, nested: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _scheduleContent() {
    final schedule = _store.schedule;
    if (schedule != null) {
      return ProfileScheduleContent(
        schedule: schedule,
        now: DateTime.now(),
        reminders: ScheduleReminders.shared,
        login: widget.login,
        channelName: _name,
      );
    }
    final error = _store.scheduleError;
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: error != null
          ? _status(error, onRetry: () => unawaited(_store.loadSchedule()))
          : const Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}
