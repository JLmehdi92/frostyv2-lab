import 'dart:async';

import 'package:flutter/material.dart' hide Clip;
import 'package:flutter/services.dart';
import 'package:onset/apis/twitch_account_gql_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/clips/stores/channel_clips_store.dart';
import 'package:onset/screens/clips/widgets/channel_clips_tab.dart';
import 'package:onset/screens/clips/widgets/clip_manage_sheet.dart';
import 'package:onset/screens/home/shell/shell_tabs.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:provider/provider.dart';

class MyClipsScreen extends StatefulWidget {
  const MyClipsScreen({super.key, required this.login, required this.userId});

  final String login;
  final String userId;

  static const routeName = '/my-clips';

  static Future<void> open(
    BuildContext context, {
    required String login,
    required String userId,
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => MyClipsScreen(login: login, userId: userId),
    ),
  );

  @override
  State<MyClipsScreen> createState() => _MyClipsScreenState();
}

class _MyClipsScreenState extends State<MyClipsScreen> {
  late final _channelClips = ChannelClipsStore(
    login: widget.login,
    clipService: context.twitchClipService,
    clipsBetween: (start, end) => context.twitchApi.getClipsBetween(
      broadcasterId: widget.userId,
      broadcasterLogin: widget.login,
      start: start,
      end: end,
    ),
  );

  late final _madeClips = ChannelClipsStore(
    login: widget.login,
    curatorId: widget.userId,
    clipService: context.twitchClipService,
  );

  var _shown = 0;

  @override
  void dispose() {
    _channelClips.dispose();
    _madeClips.dispose();
    super.dispose();
  }

  ClipManageActions? get _manageActions {
    final service = context.read<TwitchAccountGqlService?>();
    final auth = context.read<AuthStore?>();
    if (service == null || auth == null) return null;
    if ((auth.twitchWebToken ?? '').isEmpty) return null;
    return ClipManageActions.of(
      service,
      token: () => auth.twitchWebToken ?? '',
    );
  }

  Future<void> _manage(Clip clip, ChannelClipsStore store) async {
    final actions = _manageActions;
    if (actions == null) return;
    final change = await showClipManageSheet(
      context,
      slug: clip.slug,
      title: clip.title,
      actions: actions,
    );
    if (change != null && mounted) unawaited(store.refresh());
  }

  Widget _iconButton({
    required String tooltip,
    required VideoGlyphKind glyph,
    required VoidCallback onPressed,
  }) {
    final colors = FeedColors.of(context);
    return Tooltip(
      message: tooltip,
      child: PressScale(
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: VideoGlyph(glyph, color: colors.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FeedColors.of(context);
    final ground = theme.scaffoldBackgroundColor;
    final padding = MediaQuery.paddingOf(context);
    final l = context.l10n;
    final canManage = _manageActions != null;
    final header = DecoratedBox(
      decoration: BoxDecoration(
        color: ground.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: colors.hairline,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: padding.top,
          left: padding.left,
          right: padding.right,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
                child: Row(
                  spacing: 6,
                  children: [
                    _iconButton(
                      tooltip: l.commonBack,
                      glyph: VideoGlyphKind.back,
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l.myClipsTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: OnsetTokens.displayFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.27,
                            color: colors.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ShellTabs(
              labels: [l.myClipsOfMyChannel, l.myClipsMadeByMe],
              index: _shown,
              onSelect: (i) => setState(() => _shown = i),
              height: 44,
              fontSize: 15,
              gap: 22,
              bottomPadding: 11,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              activeColor: colors.text,
              idleColor: colors.tertiary,
              indicatorColor: context.onsetColors.live,
            ),
          ],
        ),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          theme.appBarTheme.systemOverlayStyle ??
          (theme.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark),
      child: Scaffold(
        backgroundColor: ground,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: IndexedStack(
                  index: _shown,
                  children: [
                    ChannelClipsTab(
                      key: const PageStorageKey('my-channel-clips'),
                      store: _channelClips,
                      onManage: canManage
                          ? (clip) => unawaited(_manage(clip, _channelClips))
                          : null,
                    ),
                    ChannelClipsTab(
                      key: const PageStorageKey('my-made-clips'),
                      store: _madeClips,
                      showChannel: true,
                      onManage: canManage
                          ? (clip) => unawaited(_manage(clip, _madeClips))
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
