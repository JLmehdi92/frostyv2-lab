import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/channel/stores/channel_info_store.dart';
import 'package:onset/screens/channel/video/player_controller.dart';
import 'package:onset/screens/channel/video/player_glyph.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/home/top/categories/category_streams.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/shared_timer_service.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/twitch_links.dart';
import 'package:onset/widgets/follow/follow_flow.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:onset/widgets/twitch_web_page.dart';

/// "3 h 12" (or "45 min") since [startedAt]: the info row's short uptime,
/// in [l]'s language.
String shortUptime(Duration elapsed, AppLocalizations l) {
  if (elapsed.isNegative) return l.channelUptimeMinutes(minutes: 0);
  final hours = elapsed.inHours;
  final minutes = elapsed.inMinutes % 60;
  if (hours == 0) return l.channelUptimeMinutes(minutes: minutes);
  return l.channelUptimeHours(
    hours: hours,
    minutes: minutes.toString().padLeft(2, '0'),
  );
}

/// Whether the viewer can follow or subscribe to [login] (signed in, not
/// their own channel).
bool _canAct(String? viewerLogin, String login) =>
    viewerLogin != null && viewerLogin.toLowerCase() != login.toLowerCase();

/// The channel under the portrait video:
/// its picture in the live ring, its name, what it
/// streams (category · viewers · uptime on a phone, title — category on a
/// tablet) and Follow (+ Subscribe on a tablet).
class ChannelInfoRow extends StatelessWidget {
  const ChannelInfoRow({
    super.key,
    required this.player,
    required this.login,
    required this.displayName,
    required this.info,
    required this.viewerLogin,
    required this.onOpenProfile,
    this.large = false,
  });

  final PlayerController player;
  final String login;
  final String displayName;
  final ChannelInfoStore info;

  /// The signed-in viewer, null when signed out; read inside this row's
  /// observer, so signing in or out shows or hides Follow at once.
  final String? Function() viewerLogin;
  final VoidCallback onOpenProfile;

  /// The tablet-portrait version.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    // On a phone, while the keyboard is up, the chat's input, a reply and
    // the autocomplete need the room.
    return _HiddenWhileTyping(
      enabled: !large,
      child: Observer(
        builder: (context) {
          final stream = player.streamInfo;
          final offline = player.offlineChannelInfo;
          final live = stream != null;
          final name = live
              ? getReadableName(stream.userName, stream.userLogin)
              : getReadableName(
                  offline?.broadcasterName.isNotEmpty == true
                      ? offline!.broadcasterName
                      : displayName,
                  login,
                );
          final category = live ? stream.gameName : offline?.gameName ?? '';
          final categoryId = live ? stream.gameId : offline?.gameId ?? '';

          final meta = TextStyle(
            fontSize: large ? 14 : 12,
            height: 1.35,
            color: large ? colors.body : colors.secondary,
          );
          // The category opens its streams, on a phone and a tablet alike.
          Widget categoryLink(String text) => Semantics(
            link: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => CategoryStreams.open(context, categoryId),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: meta,
              ),
            ),
          );
          Widget metaLine;
          if (large) {
            final title = live
                ? stream.title.trim()
                : context.l10n.streamOffline;
            metaLine = Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: meta,
                  ),
                ),
                if (category.isNotEmpty) ...[
                  Text(' — ', style: meta),
                  Flexible(child: categoryLink(category)),
                ],
              ],
            );
          } else if (live) {
            // The facts take the room a short category leaves (« Dota 2 ·
            // 2 445 spectateurs · 3 h 12 »), and at least half the row
            // beside a long one, which then gives way first.
            metaLine = LayoutBuilder(
              builder: (context, constraints) {
                var room = constraints.maxWidth;
                if (category.isNotEmpty && room.isFinite) {
                  // Measured as the Text draws it (the app's font).
                  final painter = TextPainter(
                    text: TextSpan(
                      text: category,
                      style: DefaultTextStyle.of(context).style.merge(meta),
                    ),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                    maxLines: 1,
                  )..layout();
                  room = math.max(
                    room - painter.width.ceilToDouble(),
                    room / 2,
                  );
                  painter.dispose();
                }
                return Row(
                  children: [
                    if (category.isNotEmpty)
                      Flexible(child: categoryLink(category)),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: room),
                      child: _LiveFacts(
                        prefix: category.isEmpty ? '' : ' · ',
                        viewers: stream.viewerCount,
                        startedAt: stream.startedAt,
                        style: meta,
                      ),
                    ),
                  ],
                );
              },
            );
          } else {
            metaLine = Row(
              children: [
                if (category.isNotEmpty)
                  Flexible(child: categoryLink(category)),
                Flexible(
                  child: Text(
                    category.isEmpty
                        ? context.l10n.streamOffline
                        : ' · ${context.l10n.streamOffline}',
                    maxLines: 1,
                    style: meta,
                  ),
                ),
              ],
            );
          }

          final avatar = large ? 48.0 : 40.0;
          final canAct = _canAct(viewerLogin(), login);
          return Container(
            padding: large
                ? const EdgeInsets.fromLTRB(24, 4, 24, 16)
                : const EdgeInsets.fromLTRB(16, 0, 16, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.hairline,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
            ),
            child: Row(
              spacing: large ? 14 : 10,
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: context.l10n.channelProfile,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onOpenProfile,
                      child: Row(
                        spacing: large ? 14 : 10,
                        children: [
                          _RingedPicture(
                            login: live ? stream.userLogin : login,
                            size: avatar,
                            live: live,
                            ring: large ? 2 : 1.5,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              spacing: large ? 3 : 1,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: large ? 18 : 15,
                                    fontWeight: large
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    letterSpacing: large ? -0.36 : 0,
                                    height: 1.25,
                                    color: colors.text,
                                  ),
                                ),
                                metaLine,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (canAct)
                  FollowButton(
                    info: info,
                    login: login,
                    name: name,
                    height: large ? 40 : 36,
                  ),
                if (large && canAct) SubscribeButton(login: login, name: name),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Folds [child] away while the keyboard is up (when [enabled]), and back
/// when it goes: the height and the opacity follow the motion kit (a short
/// cross-fade under reduce motion). Asked of the window (the channel's
/// Scaffold takes the inset out of its body), rebuilt only when the
/// keyboard comes or goes, not at each of its frames.
class _HiddenWhileTyping extends StatefulWidget {
  const _HiddenWhileTyping({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_HiddenWhileTyping> createState() => _HiddenWhileTypingState();
}

class _HiddenWhileTypingState extends State<_HiddenWhileTyping>
    with WidgetsBindingObserver {
  var _typing = false;

  bool _readTyping() {
    final view = View.maybeOf(context);
    return view != null && view.viewInsets.bottom > 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _typing = _readTyping();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final typing = _readTyping();
    if (typing != _typing) setState(() => _typing = typing);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = widget.enabled && _typing;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: hidden ? 0 : 1),
      duration: motionDuration(
        context,
        hidden ? OnsetMotion.exit : OnsetMotion.enter,
      ),
      curve: hidden
          ? OnsetMotion.emphasizedAccelerate
          : OnsetMotion.emphasizedDecelerate,
      child: widget.child,
      builder: (context, shown, child) => IgnorePointer(
        ignoring: hidden,
        child: ExcludeSemantics(
          excluding: hidden,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: shown,
              child: Opacity(opacity: shown, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// " · 2,445 watching · 3 h 12", the uptime moving once a minute.
class _LiveFacts extends StatefulWidget {
  const _LiveFacts({
    required this.prefix,
    required this.viewers,
    required this.startedAt,
    required this.style,
  });

  final String prefix;
  final int viewers;
  final String startedAt;
  final TextStyle style;

  @override
  State<_LiveFacts> createState() => _LiveFactsState();
}

class _LiveFactsState extends State<_LiveFacts> {
  final _clock = SharedTimerService.instance;
  int? _minutes;

  int? _elapsedMinutes() {
    final start = DateTime.tryParse(widget.startedAt);
    if (start == null) return null;
    // The shared clock only says when to look: its last tick can be old
    // when it has just started again.
    return DateTime.now().difference(start).inMinutes;
  }

  void _tick() {
    // The clock ticks every second; the text changes once a minute.
    final minutes = _elapsedMinutes();
    if (minutes != _minutes && mounted) setState(() => _minutes = minutes);
  }

  @override
  void initState() {
    super.initState();
    _minutes = _elapsedMinutes();
    _clock.addListener(_tick);
  }

  @override
  void didUpdateWidget(_LiveFacts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) _minutes = _elapsedMinutes();
  }

  @override
  void dispose() {
    _clock.removeListener(_tick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final minutes = _minutes;
    final uptime = minutes == null
        ? null
        : shortUptime(Duration(minutes: minutes), l);
    String line(String viewers) =>
        [widget.prefix + viewers, ?uptime].join(' · ');
    final full = line(l.streamWatching(count: widget.viewers));
    final style = OnsetType.tabular(widget.style);
    // Measured as the Text draws it, in the app's font.
    final measured = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Beside the category on a phone the line can run out of room
        // (French words run longer): it shrinks a little, then the number
        // goes short (« 2,4 k spectateurs »), then stands alone, rather
        // than lose its words to an ellipsis (« 2 445 spectate… »). A
        // screen reader always hears it in full.
        var shown = full;
        if (constraints.hasBoundedWidth) {
          final room = constraints.maxWidth / _minShrink;
          final scaler = MediaQuery.textScalerOf(context);
          final direction = Directionality.of(context);
          final number = formatViewers(widget.viewers);
          for (final candidate in [
            full,
            line(l.streamWatchingShort(count: widget.viewers, viewers: number)),
            line(number),
          ]) {
            shown = candidate;
            final painter = TextPainter(
              text: TextSpan(text: candidate, style: measured),
              textDirection: direction,
              textScaler: scaler,
              maxLines: 1,
            )..layout();
            final fits = painter.width <= room;
            painter.dispose();
            if (fits) break;
          }
        }
        return Semantics(
          label: full,
          excludeSemantics: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(shown, maxLines: 1, softWrap: false, style: style),
          ),
        );
      },
    );
  }

  /// How much the line may shrink before it says less.
  static const _minShrink = 0.85;
}

/// A channel's picture, in the live ring when it streams (2 dp of ground,
/// then the signal).
class _RingedPicture extends StatelessWidget {
  const _RingedPicture({
    required this.login,
    required this.size,
    required this.live,
    required this.ring,
  });

  final String login;
  final double size;
  final bool live;
  final double ring;

  @override
  Widget build(BuildContext context) {
    final picture = ProfilePicture(userLogin: login, radius: size / 2);
    if (!live) return picture;
    return Container(
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        color: context.onsetColors.live,
        shape: BoxShape.circle,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          shape: BoxShape.circle,
        ),
        child: picture,
      ),
    );
  }
}

class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.info,
    required this.login,
    required this.name,
    required this.height,
    this.fontSize = 13,
  });

  final ChannelInfoStore info;
  final String login;
  final String name;
  final double height;
  final double fontSize;

  Future<void> _toggle(BuildContext context) async {
    final now = await FollowFlow.toggle(
      context,
      target: FollowTarget.channel,
      id: info.channelId,
      name: name,
      following: info.following.value,
      onChanged: (now) => info.following.value = now,
    );
    if (now == true && context.mounted) {
      await FollowFlow.suggestAfterFollowing(
        context,
        channelId: info.channelId,
        name: name,
      );
    }
  }

  /// A login twitch.tv takes (the check of [twitchSubscribeUrl]): anything
  /// else is never put in a URL.
  static final _login = RegExp(r'^[a-z0-9_]{1,25}$');

  @override
  Widget build(BuildContext context) {
    if (!_login.hasMatch(login.toLowerCase())) return const SizedBox.shrink();
    final colors = FeedColors.of(context);
    return FollowPendingGate(
      id: info.channelId,
      child: ValueListenableBuilder<bool?>(
        valueListenable: info.following,
        builder: (context, following, _) {
          final follows = following ?? false;
          final style = TextStyle(
            fontFamily: OnsetTokens.bodyFamily,
            fontSize: fontSize,
            fontWeight: follows ? FontWeight.w600 : FontWeight.w700,
          );
          return Tooltip(
            message: follows
                ? context.l10n.channelFollowingTooltip(name: name)
                : context.l10n.channelFollowTooltip(name: name),
            child: PressScale(
              child: follows
                  ? OutlinedButton(
                      onPressed: () => _toggle(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.text,
                        backgroundColor: colors.raised,
                        minimumSize: Size(0, height),
                        padding: EdgeInsets.symmetric(
                          horizontal: height > 36 ? 18 : 16,
                        ),
                        side: BorderSide(
                          color: colors.pillBorder,
                          width: OnsetTokens.hairlineWidth,
                        ),
                        shape: const StadiumBorder(),
                        textStyle: style,
                      ),
                      child: OneLineLabel(context.l10n.channelFollowing),
                    )
                  : FilledButton(
                      onPressed: () => _toggle(context),
                      style: FilledButton.styleFrom(
                        foregroundColor: OnsetTokens.backgroundDark,
                        backgroundColor: context.onsetColors.live,
                        minimumSize: Size(0, height),
                        padding: EdgeInsets.symmetric(
                          horizontal: height > 36 ? 18 : 16,
                        ),
                        shape: const StadiumBorder(),
                        textStyle: style,
                      ),
                      child: OneLineLabel(context.l10n.channelFollow),
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// "Subscribe", in the community green: the channel's subscription page on
/// twitch.tv (purchases happen there).
class SubscribeButton extends StatelessWidget {
  const SubscribeButton({
    super.key,
    required this.login,
    required this.name,
    this.height = 40,
    this.fontSize = 13,
  });

  final String login;
  final String name;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final url = twitchSubscribeUrl(login);
    if (url == null) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: context.l10n.channelSubscribeTooltip(name: name),
      child: PressScale(
        child: OutlinedButton(
          onPressed: () => TwitchWebPage.open(
            context,
            title: context.l10n.channelSubscribe,
            url: url,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: dark
                ? OnsetTokens.hypeText
                : OnsetTokens.hypeTextLight,
            backgroundColor: OnsetTokens.hype.withValues(alpha: 0.12),
            minimumSize: Size(0, height),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            side: const BorderSide(
              color: OnsetTokens.hype,
              width: OnsetTokens.hairlineWidth,
            ),
            shape: const StadiumBorder(),
            textStyle: TextStyle(
              fontFamily: OnsetTokens.bodyFamily,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: OneLineLabel(context.l10n.channelSubscribe),
        ),
      ),
    );
  }
}

/// Under a tablet's video beside the chat: the title, its
/// chips (category, language, watch streak), Follow and Subscribe, and the
/// viewer's other followed channels live now.
class TabletChannelPanel extends StatefulWidget {
  const TabletChannelPanel({
    super.key,
    required this.player,
    required this.login,
    required this.displayName,
    required this.info,
    required this.viewerLogin,
    required this.onOpenChannel,
    this.watchStreak,
  });

  final PlayerController player;
  final String login;
  final String displayName;
  final ChannelInfoStore info;

  /// The signed-in viewer, read inside the panel's observer.
  final String? Function() viewerLogin;

  /// Another live channel picked from "Also live from your follows".
  final ValueChanged<StreamTwitch> onOpenChannel;

  /// The viewer's watch streak here, read inside an observer (MobX).
  final int? Function()? watchStreak;

  @override
  State<TabletChannelPanel> createState() => _TabletChannelPanelState();
}

class _TabletChannelPanelState extends State<TabletChannelPanel> {
  @override
  void initState() {
    super.initState();
    widget.info.wantAlsoLive();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Observer(
            builder: (context) {
              final stream = widget.player.streamInfo;
              final offline = widget.player.offlineChannelInfo;
              final title = stream?.title.trim() ?? offline?.title.trim() ?? '';
              final category = stream?.gameName ?? offline?.gameName ?? '';
              final categoryId = stream?.gameId ?? offline?.gameId ?? '';
              final language = switch (stream?.language) {
                final code? when code.isNotEmpty && code != 'other' =>
                  code.toUpperCase(),
                _ => null,
              };
              final streak = widget.watchStreak?.call();
              final canAct = _canAct(widget.viewerLogin(), widget.login);
              final name = stream != null
                  ? getReadableName(stream.userName, stream.userLogin)
                  : getReadableName(widget.displayName, widget.login);
              return Row(
                spacing: 14,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 5,
                      children: [
                        Text(
                          title.isEmpty ? name : title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            height: 1.25,
                            color: colors.text,
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (category.isNotEmpty)
                              _Chip(
                                label: category,
                                onTap: categoryId.isEmpty
                                    ? null
                                    : () => CategoryStreams.open(
                                        context,
                                        categoryId,
                                      ),
                              ),
                            if (language != null) _Chip(label: language),
                            if (streak != null && streak > 0)
                              _Chip(
                                label: context.l10n.channelWatchStreak(
                                  value: streak,
                                ),
                                green: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (canAct) ...[
                    FollowButton(
                      info: widget.info,
                      login: widget.login,
                      name: name,
                      height: 40,
                    ),
                    SubscribeButton(login: widget.login, name: name),
                  ],
                ],
              );
            },
          ),
          ValueListenableBuilder<List<StreamTwitch>>(
            valueListenable: widget.info.alsoLive,
            builder: (context, streams, _) {
              if (streams.isEmpty) return const SizedBox.shrink();
              return _AlsoLive(
                streams: streams,
                onOpenChannel: widget.onOpenChannel,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A 24 dp chip of the tablet info area.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.onTap, this.green = false});

  final String label;
  final VoidCallback? onTap;
  final bool green;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = Text(
      label,
      maxLines: 1,
      // A category too long for a narrow column ends in an ellipsis.
      overflow: green ? TextOverflow.visible : TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        height: 1,
        fontWeight: green ? FontWeight.w600 : FontWeight.w400,
        color: green
            ? (dark ? OnsetTokens.hypeText : OnsetTokens.hypeTextLight)
            : colors.body,
      ),
    );
    final chip = Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: green
            ? OnsetTokens.hype.withValues(alpha: 0.16)
            : (dark ? const Color(0xFF1A1A1A) : colors.raised),
        borderRadius: BorderRadius.circular(12),
      ),
      child: green
          // The streak's number is all it says: it shrinks rather than go.
          ? FittedBox(fit: BoxFit.scaleDown, child: text)
          : text,
    );
    if (onTap == null) return chip;
    return Semantics(
      link: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: chip,
      ),
    );
  }
}

/// "Also live from your follows": as many 262 dp cards as fit in a row.
class _AlsoLive extends StatelessWidget {
  const _AlsoLive({required this.streams, required this.onOpenChannel});

  final List<StreamTwitch> streams;
  final ValueChanged<StreamTwitch> onOpenChannel;

  static const _cardWidth = 262.0;
  static const _gap = 14.0;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Text(
          context.l10n.channelAlsoLive,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.54,
            color: colors.secondary,
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final fit = ((constraints.maxWidth + _gap) / (_cardWidth + _gap))
                .floor()
                .clamp(1, streams.length);
            // A panel narrower than one card gets one card that fits.
            final width = math.min(_cardWidth, constraints.maxWidth);
            return Row(
              spacing: _gap,
              children: [
                for (final stream in streams.take(fit))
                  SizedBox(
                    width: width,
                    child: _AlsoLiveCard(
                      stream: stream,
                      onTap: () => onOpenChannel(stream),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AlsoLiveCard extends StatelessWidget {
  const _AlsoLiveCard({required this.stream, required this.onTap});

  final StreamTwitch stream;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final name = getReadableName(stream.userName, stream.userLogin);
    final radius = BorderRadius.circular(10);
    return PressScale(
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        onTapDown: (_) => preloadStream(context, stream),
        child: Row(
          spacing: 10,
          children: [
            SizedBox(
              width: 112,
              height: 63,
              child: ClipRRect(
                borderRadius: radius,
                child: StreamThumbnail(
                  stream: stream,
                  enlarge: false,
                  borderRadius: radius,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  Text(
                    [
                      if (stream.gameName.isNotEmpty) stream.gameName,
                      formatViewers(stream.viewerCount),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The top of a tablet's side chat: "Chat", whether it
/// waits for the video ("synced to video", or the manual delay) and "⋯",
/// the chat's details.
class TabletChatHeader extends StatelessWidget {
  const TabletChatHeader({
    super.key,
    required this.settings,
    required this.onMore,
  });

  final SettingsStore settings;
  final VoidCallback onMore;

  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final live = context.onsetColors.live;
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.hairline,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
      ),
      child: Row(
        spacing: 10,
        children: [
          Text(
            context.l10n.channelChat,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          Observer(
            builder: (context) {
              final delay = settings.chatDelay.round();
              final label = settings.autoSyncChatDelay
                  ? context.l10n.channelChatSynced
                  : delay > 0
                  ? context.l10n.channelChatDelay(seconds: delay)
                  : null;
              if (label == null) return const SizedBox.shrink();
              return Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: live.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 5,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: live,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        color: live,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const Spacer(),
          IconButton(
            tooltip: context.l10n.channelChatSettings,
            onPressed: onMore,
            icon: PlayerGlyph(PlayerGlyphKind.more, color: colors.secondary),
          ),
        ],
      ),
    );
  }
}

/// A pill's label on one line, scaled down rather than broken mid-word when
/// large text leaves it too little room.
class OneLineLabel extends StatelessWidget {
  const OneLineLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, softWrap: false),
  );
}
