import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/clips/stores/channel_clips_store.dart';
import 'package:frosty/screens/clips/widgets/channel_clips_tab.dart';
import 'package:frosty/screens/vod/stores/channel_videos_store.dart';
import 'package:frosty/screens/vod/widgets/channel_videos_tab.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/frosty_app_bar.dart';
import 'package:frosty/widgets/frosty_page_view.dart';

/// A channel's past broadcasts, highlights and uploads, each played in-app.
class ChannelVideosScreen extends StatefulWidget {
  static const routeName = 'ChannelVideos';

  const ChannelVideosScreen({
    super.key,
    required this.userLogin,
    required this.displayName,
    this.initialTab = VodType.archive,
    this.startOnClips = false,
    this.clipPeriod = ClipPeriod.lastWeek,
  });

  final String userLogin;
  final String displayName;
  final VodType initialTab;

  /// Opens on the Clips tab (a `/<channel>/clips` link), for [clipPeriod].
  final bool startOnClips;
  final ClipPeriod clipPeriod;

  static Future<void> open(
    BuildContext context, {
    required String userLogin,
    required String displayName,
    VodType initialTab = VodType.archive,
    bool startOnClips = false,
    ClipPeriod clipPeriod = ClipPeriod.lastWeek,
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => ChannelVideosScreen(
        userLogin: userLogin,
        displayName: displayName,
        initialTab: initialTab,
        startOnClips: startOnClips,
        clipPeriod: clipPeriod,
      ),
    ),
  );

  @override
  State<ChannelVideosScreen> createState() => _ChannelVideosScreenState();
}

class _ChannelVideosScreenState extends State<ChannelVideosScreen> {
  static const _tabs = [
    (VodType.archive, 'Past broadcasts', 'No past broadcasts'),
    (VodType.highlight, 'Highlights', 'No highlights'),
    (VodType.upload, 'Uploads', 'No uploads'),
  ];

  late final _stores = {
    for (final (type, _, _) in _tabs)
      type: ChannelVideosStore(
        login: widget.userLogin,
        type: type,
        vodService: context.twitchVodService,
      ),
  };

  late final _clipsStore = ChannelClipsStore(
    login: widget.userLogin,
    clipService: context.twitchClipService,
    period: widget.clipPeriod,
  );

  @override
  void dispose() {
    for (final store in _stores.values) {
      store.dispose();
    }
    _clipsStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FrostyAppBar(title: Text('${widget.displayName} · Videos')),
      body: SafeArea(
        bottom: false,
        child: FrostyPageView(
          initialIndex: widget.startOnClips
              ? _tabs.length
              : _tabs.indexWhere((t) => t.$1 == widget.initialTab),
          headers: [for (final (_, header, _) in _tabs) header, 'Clips'],
          children: [
            for (final (type, _, empty) in _tabs)
              ChannelVideosTab(store: _stores[type]!, emptyMessage: empty),
            ChannelClipsTab(store: _clipsStore),
          ],
        ),
      ),
    );
  }
}
