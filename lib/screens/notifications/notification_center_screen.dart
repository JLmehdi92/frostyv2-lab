import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/apis/twitch_social_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/onsite_notification.dart';
import 'package:onset/screens/notifications/stores/notification_center_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/screens/whispers/whisper_kit.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/state_glyph.dart';
import 'package:onset/widgets/state_views.dart';
import 'package:onset/widgets/twitch_web_page.dart';
import 'package:provider/provider.dart';

typedef TwitchInbox = ({
  TwitchSocialService service,
  String userId,
  String token,
});

TwitchInbox? twitchInboxOf(BuildContext context) {
  final service = context.read<TwitchSocialService?>();
  final auth = context.read<AuthStore?>();
  final token = auth?.twitchWebToken;
  final userId = auth != null && auth.isLoggedIn
      ? auth.user.details?.id
      : null;
  if (service == null || token == null || token.isEmpty || userId == null) {
    return null;
  }
  return (service: service, userId: userId, token: token);
}

NotificationCenterStore notificationCenterStoreFor(
  TwitchInbox inbox, {
  required String language,
}) => NotificationCenterStore(
  fetch: (cursor) => inbox.service.notifications(
    userId: inbox.userId,
    authToken: inbox.token,
    language: language,
    cursor: cursor,
  ),
  markRead: (ids) =>
      inbox.service.markNotificationsRead(ids: ids, authToken: inbox.token),
);

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({
    super.key,
    required this.store,
    required this.onOpenChannel,
    this.now = DateTime.now,
  });

  static const markAllKey = ValueKey('notification-center-mark-all');

  final NotificationCenterStore store;
  final void Function(String login) onOpenChannel;
  final DateTime Function() now;

  static Future<void> open(
    BuildContext context, {
    required NotificationCenterStore store,
    required void Function(String login) onOpenChannel,
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: 'NotificationCenter'),
      builder: (_) => NotificationCenterScreen(
        store: store,
        onOpenChannel: onOpenChannel,
      ),
    ),
  );

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(widget.store.refresh());
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    final position = _scroll.position;
    if (position.pixels > position.maxScrollExtent - 400) {
      unawaited(widget.store.loadMore());
    }
  }

  Future<void> _markAll() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    final outcome = await widget.store.markAllRead();
    if (outcome == null || !mounted) return;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l.viewerActionResult(status: outcome.name))),
      );
  }

  void _open(OnsiteNotification notification) {
    final login = notification.channelLogin;
    if (login != null) {
      widget.onOpenChannel(login);
      return;
    }
    final link = notification.link;
    if (link != null) {
      unawaited(
        TwitchWebPage.open(
          context,
          title: context.l10n.notificationCenterTitle,
          url: link,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = WhisperColors.of(context);
    final tablet = context.isLargeScreen;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notificationCenterTitle),
        actions: [
          Observer(
            builder: (_) => widget.store.unreadCount == 0
                ? const SizedBox.shrink()
                : IconButton(
                    key: NotificationCenterScreen.markAllKey,
                    tooltip: l.activityMarkAllRead,
                    onPressed: widget.store.marking
                        ? null
                        : () => unawaited(_markAll()),
                    icon: const Icon(Icons.done_all_rounded),
                  ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tablet ? 760 : double.infinity),
          child: Observer(
            builder: (context) {
              final store = widget.store;
              final notifications = store.notifications.toList();
              if (notifications.isEmpty) {
                if (store.loading) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 72),
                  children: [
                    if (store.failed)
                      FeedStatusView.error(
                        message: l.notificationCenterFailed,
                        onRetry: () => unawaited(store.refresh()),
                      )
                    else
                      FeedStatusView.empty(
                        message: l.notificationCenterEmpty,
                        glyph: StateGlyphKind.bell,
                      ),
                  ],
                );
              }
              final now = widget.now();
              return RefreshIndicator.adaptive(
                onRefresh: store.refresh,
                child: ListView.builder(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: tablet ? 12 : 4,
                    bottom: MediaQuery.paddingOf(context).bottom + 16,
                  ),
                  itemCount: notifications.length + (store.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= notifications.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      );
                    }
                    final notification = notifications[index];
                    return NotificationCenterRow(
                      notification: notification,
                      when: formatTimeAgo(notification.createdAt, l, now: now),
                      colors: colors,
                      tablet: tablet,
                      onTap:
                          notification.channelLogin == null &&
                              notification.link == null
                          ? null
                          : () => _open(notification),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class NotificationCenterRow extends StatelessWidget {
  const NotificationCenterRow({
    super.key,
    required this.notification,
    required this.when,
    required this.colors,
    required this.tablet,
    this.onTap,
  });

  final OnsiteNotification notification;
  final String when;
  final WhisperColors colors;
  final bool tablet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final avatarSize = tablet ? 48.0 : 44.0;
    final avatar = notification.avatarUrl ?? notification.thumbnailUrl;
    return Semantics(
      button: onTap != null,
      child: PressScale(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tablet ? 18 : 16,
                vertical: tablet ? 14 : 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipOval(
                    child: SizedBox.square(
                      dimension: avatarSize,
                      child: avatar == null
                          ? ColoredBox(
                              color: colors.raised,
                              child: Center(
                                child: StateGlyph(
                                  StateGlyphKind.bell,
                                  color: colors.secondary,
                                ),
                              ),
                            )
                          : OnsetCachedNetworkImage(
                              imageUrl: avatar,
                              width: avatarSize,
                              height: avatarSize,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 3,
                      children: [
                        Text(
                          notification.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: tablet ? 15 : 14,
                            height: 1.35,
                            letterSpacing: -0.07,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: unread ? colors.text : colors.secondary,
                          ),
                        ),
                        Text(
                          when,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unread)
                    Padding(
                      padding: const EdgeInsets.only(left: 10, top: 8),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: OnsetTokens.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TwitchInboxEntry extends StatefulWidget {
  const TwitchInboxEntry({
    super.key,
    required this.onOpenChannel,
    this.tablet = false,
  });

  static const tileKey = ValueKey('twitch-inbox-entry');

  final void Function(String login) onOpenChannel;
  final bool tablet;

  @override
  State<TwitchInboxEntry> createState() => _TwitchInboxEntryState();
}

class _TwitchInboxEntryState extends State<TwitchInboxEntry> {
  TwitchInbox? _inbox;
  int? _unseen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inbox = twitchInboxOf(context);
    if (inbox?.token == _inbox?.token && inbox?.userId == _inbox?.userId) {
      return;
    }
    _inbox = inbox;
    _unseen = null;
    if (inbox != null) unawaited(_count(inbox));
  }

  Future<void> _count(TwitchInbox inbox) async {
    final unseen = await inbox.service.unseenNotifications(
      userId: inbox.userId,
      authToken: inbox.token,
    );
    if (!mounted || !identical(inbox, _inbox)) return;
    setState(() => _unseen = unseen);
  }

  Future<void> _open(TwitchInbox inbox) async {
    final store = notificationCenterStoreFor(
      inbox,
      language: Localizations.localeOf(context).languageCode,
    );
    await NotificationCenterScreen.open(
      context,
      store: store,
      onOpenChannel: widget.onOpenChannel,
    );
    if (mounted) unawaited(_count(inbox));
  }

  @override
  Widget build(BuildContext context) {
    final inbox = _inbox;
    if (inbox == null) return const SizedBox.shrink();
    final l = context.l10n;
    final colors = WhisperColors.of(context);
    final unseen = _unseen ?? 0;
    return Padding(
      padding: widget.tablet
          ? const EdgeInsets.only(bottom: 16)
          : const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: PressScale(
        child: Material(
          color: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.tablet ? 20 : 16),
            side: BorderSide(
              color: colors.paneRing,
              width: OnsetTokens.hairlineWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: TwitchInboxEntry.tileKey,
            onTap: () => unawaited(_open(inbox)),
            splashFactory: NoSplash.splashFactory,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                spacing: 12,
                children: [
                  StateGlyph(
                    StateGlyphKind.bell,
                    color: colors.text,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          l.notificationCenterTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          l.notificationCenterEntryDetail,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unseen > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: OnsetTokens.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l.notificationCenterUnseen(count: unseen),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  StateGlyph(
                    StateGlyphKind.chevronRight,
                    color: colors.tertiary,
                    size: 18,
                    strokeWidth: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
