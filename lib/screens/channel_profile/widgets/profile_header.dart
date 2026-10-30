import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/screens/channel/channel_info.dart';
import 'package:onset/screens/channel/stores/channel_info_store.dart';
import 'package:onset/screens/channel/video/player_glyph.dart';
import 'package:onset/screens/channel_profile/widgets/profile_about_tab.dart';
import 'package:onset/screens/channel_profile/widgets/profile_live_card.dart';
import 'package:onset/screens/channel_profile/widgets/profile_parts.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/twitch_links.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/skeleton_loader.dart';

/// The channel's banner (boards Profil and ProfilTablette): its picture
/// dimmed on black, fading into the ground at the bottom; without one, the
/// channel's colour.
class ProfileBanner extends StatelessWidget {
  const ProfileBanner({super.key, this.profile, this.large = false});

  final ChannelProfile? profile;

  /// The tablet's fade (darker at the top too, under the buttons).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final ground = Theme.of(context).scaffoldBackgroundColor;
    final url = profile?.bannerUrl;
    final accent = profile?.accentColor;
    final Widget picture;
    if (url != null) {
      final ratio = MediaQuery.devicePixelRatioOf(context);
      picture = Opacity(
        opacity: large ? 0.6 : 0.7,
        // Decoded wide enough to cover the box (a banner is 2.5:1), never
        // larger: the box keeps its size while the header folds.
        child: LayoutBuilder(
          builder: (context, box) => OnsetCachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: box.hasBoundedWidth && box.hasBoundedHeight
                ? (math.max(box.maxWidth, box.maxHeight * 2.5) * ratio).round()
                : null,
          ),
        ),
      );
    } else {
      picture = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(accent ?? 0xFF2A2A2A).withValues(alpha: 0.55),
              const Color(0xFF000000),
            ],
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            picture,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: large ? const [0, 0.4, 1] : const [0.3, 1],
                  colors: large
                      ? [
                          ground.withValues(alpha: 0.2),
                          ground.withValues(alpha: 0),
                          ground,
                        ]
                      : [ground.withValues(alpha: 0), ground],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "48.2k followers · Partner": the channel's followers and its role.
String profileMeta(ChannelProfile? profile) {
  final followers = profile?.followers;
  return [
    if (followers != null)
      '${formatViewers(followers)} ${followers == 1 ? 'follower' : 'followers'}',
    if (profile?.role == BroadcasterRole.partner) 'Partner',
    if (profile?.role == BroadcasterRole.affiliate) 'Affiliate',
  ].join(' · ');
}

/// Whether the profile offers Subscribe, as Twitch's profile card does: a
/// partner or an affiliate, not the [viewerLogin]'s own channel (signed
/// out, twitch.tv asks to log in first), and a login twitch.tv takes.
bool profileOffersSubscribe({
  required ChannelProfile? profile,
  required String login,
  String? viewerLogin,
}) =>
    viewerLogin?.toLowerCase() != login.toLowerCase() &&
    twitchSubscribeUrl(login) != null &&
    (profile?.role == BroadcasterRole.partner ||
        profile?.role == BroadcasterRole.affiliate);

/// The channel's name (24 / 800, 30 on a tablet) over its followers and
/// role; a sheen line while the profile loads.
class ProfileIdentity extends StatelessWidget {
  const ProfileIdentity({
    super.key,
    required this.name,
    required this.profile,
    this.loading = false,
    this.large = false,
  });

  final String name;
  final ChannelProfile? profile;
  final bool loading;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final size = large ? 30.0 : 24.0;
    final meta = profileMeta(profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: large ? 4 : 2,
      children: [
        Semantics(
          header: true,
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: OnsetTokens.displayFamily,
              fontSize: size,
              fontWeight: FontWeight.w800,
              letterSpacing: (large ? -0.03 : -0.025) * size,
              height: 1.2,
              color: colors.text,
            ),
          ),
        ),
        if (meta.isNotEmpty)
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OnsetType.tabular(
              TextStyle(
                fontSize: large ? 14 : 13,
                height: 1.3,
                color: colors.secondary,
              ),
            ),
          )
        else if (loading)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SkeletonLoader(width: large ? 160 : 130, height: 12),
          ),
      ],
    );
  }
}

/// Watch (live) or Chat (offline), Follow and Subscribe (boards: pills of
/// 44 dp side by side on a phone; on a tablet "Watch live" 48 dp across,
/// the other two under it).
class ProfileActions extends StatelessWidget {
  const ProfileActions({
    super.key,
    required this.login,
    required this.name,
    required this.live,
    required this.onOpenChannel,
    this.onPreload,
    this.follow,
    this.showSubscribe = false,
    this.large = false,
  });

  final String login;
  final String name;
  final bool live;
  final VoidCallback onOpenChannel;

  /// The finger is down on Watch: the playback token is asked for.
  final VoidCallback? onPreload;

  /// The follow state, when the viewer can follow this channel.
  final ChannelInfoStore? follow;
  final bool showSubscribe;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final watch = _WatchButton(
      label: live ? (large ? 'Watch live' : 'Watch') : 'Chat',
      live: live,
      height: large ? 48 : 44,
      fontSize: large ? 15 : 14,
      onPressed: onOpenChannel,
      onPreload: live ? onPreload : null,
      colors: colors,
    );
    final follow = this.follow;
    final others = [
      if (follow != null)
        Expanded(
          child: FollowButton(
            info: follow,
            login: login,
            name: name,
            height: 44,
            fontSize: 14,
          ),
        ),
      if (showSubscribe)
        Expanded(
          child: SubscribeButton(
            login: login,
            name: name,
            height: 44,
            fontSize: 14,
          ),
        ),
    ];
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          watch,
          if (others.isNotEmpty) Row(spacing: 10, children: others),
        ],
      );
    }
    return Row(
      spacing: 8,
      children: [
        Expanded(child: watch),
        ...others,
      ],
    );
  }
}

class _WatchButton extends StatelessWidget {
  const _WatchButton({
    required this.label,
    required this.live,
    required this.height,
    required this.fontSize,
    required this.onPressed,
    required this.onPreload,
    required this.colors,
  });

  final String label;
  final bool live;
  final double height;
  final double fontSize;
  final VoidCallback onPressed;
  final VoidCallback? onPreload;
  final FeedColors colors;

  @override
  Widget build(BuildContext context) {
    final signal = context.onsetColors.live;
    final style = TextStyle(
      fontFamily: OnsetTokens.bodyFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
    );
    // Live: the signal pill. Offline, the chat is no live moment: the
    // raised pill.
    final button = live
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              foregroundColor: OnsetTokens.backgroundDark,
              backgroundColor: signal,
              minimumSize: Size(0, height),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: const StadiumBorder(),
              textStyle: style,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                if (height > 44)
                  const PlayerGlyph(
                    PlayerGlyphKind.play,
                    color: OnsetTokens.backgroundDark,
                    size: 16,
                  ),
                Flexible(child: OneLineLabel(label)),
              ],
            ),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.text,
              backgroundColor: colors.raised,
              minimumSize: Size(0, height),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              side: BorderSide(
                color: colors.pillBorder,
                width: OnsetTokens.hairlineWidth,
              ),
              shape: const StadiumBorder(),
              textStyle: style.copyWith(fontWeight: FontWeight.w600),
            ),
            child: OneLineLabel(label),
          );
    return PressScale(
      child: Listener(
        // Down on Watch: the token is on its way before the tap lands.
        onPointerDown: onPreload == null ? null : (_) => onPreload!(),
        child: button,
      ),
    );
  }
}

/// The part of a phone's header under the banner (board Profil): the
/// avatar hanging over the banner's edge, the name and followers, the
/// channel's stream, then Watch, Follow and Subscribe.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.login,
    required this.displayName,
    required this.profile,
    required this.onOpenChannel,
    this.onPreload,
    this.follow,
    this.showSubscribe = false,
    this.loading = false,
  });

  /// The avatar's size and how far it rises over the banner.
  static const avatarSize = 88.0;
  static const avatarOverhang = 44.0;

  final String login;
  final String displayName;

  /// Null while loading, or when only the Helix header is known.
  final ChannelProfile? profile;
  final VoidCallback onOpenChannel;
  final VoidCallback? onPreload;
  final ChannelInfoStore? follow;
  final bool showSubscribe;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    final showCard = profile != null && !ProfileStreamFacts(profile).isEmpty;
    // Clear of a landscape phone's cutout.
    final sides = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16 + sides.left, 0, 16 + sides.right, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: avatarOverhang),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(width: avatarSize + 14),
                    Expanded(
                      child: ProfileIdentity(
                        name: displayName,
                        profile: profile,
                        loading: loading,
                      ),
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                start: 0,
                top: -avatarOverhang,
                child: ProfileAvatar(
                  login: login,
                  imageUrl: profile?.profileImageUrl,
                  size: avatarSize,
                  live: profile?.live != null,
                ),
              ),
            ],
          ),
          if (showCard)
            ProfileLiveCard(
              profile: profile,
              onOpen: onOpenChannel,
              onPreload: onPreload,
            ),
          ProfileActions(
            login: login,
            name: displayName,
            live: profile?.live != null,
            onOpenChannel: onOpenChannel,
            onPreload: onPreload,
            follow: follow,
            showSubscribe: showSubscribe,
          ),
        ],
      ),
    );
  }
}

/// A phone's whole header as one pinned sliver (board Profil): the banner
/// with Back, Share and More over it, then [content] ([ProfileHeader],
/// [contentHeight] tall) and the [tabs]. Scrolled, the banner folds into a
/// 56 dp bar on the ground with the channel's name, the content slides
/// under it, and the tabs stay pinned under the bar.
class ProfilePhoneHeader extends SliverPersistentHeaderDelegate {
  ProfilePhoneHeader({
    required this.topPadding,
    required this.bannerHeight,
    required this.contentHeight,
    required this.tabsHeight,
    required this.title,
    required this.banner,
    required this.content,
    required this.tabs,
    required this.actions,
    required this.onBack,
  });

  static const barHeight = 56.0;

  final double topPadding;
  final double bannerHeight;
  final double contentHeight;
  final double tabsHeight;
  final String title;
  final Widget banner;
  final Widget content;
  final Widget tabs;

  /// Share and More, for how far the bar has folded (0 to 1).
  final List<Widget> Function(double onBar) actions;
  final VoidCallback onBack;

  @override
  double get minExtent => topPadding + barHeight + tabsHeight;

  @override
  double get maxExtent =>
      topPadding + bannerHeight + contentHeight + tabsHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool _) {
    final range = bannerHeight - barHeight;
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final ground = Theme.of(context).scaffoldBackgroundColor;
    final colors = FeedColors.of(context);
    final titleOpacity = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
    final bar = topPadding + barHeight;
    final sides = MediaQuery.paddingOf(context);
    return AnnotatedRegion(
      value: profileOverlayStyle(context, collapsed: t > 0.6),
      child: Stack(
        children: [
          // Everything scrolls up with the finger; the bar and the tabs
          // stay.
          Positioned(
            left: 0,
            right: 0,
            top: -shrinkOffset,
            height: topPadding + bannerHeight,
            child: banner,
          ),
          Positioned(
            left: 0,
            right: 0,
            top: topPadding + bannerHeight - shrinkOffset,
            // Once the avatar is under the bar, its pulse stops.
            child: ProfileAvatarShown(
              shown:
                  shrinkOffset <
                  bannerHeight + ProfileHeader.avatarOverhang - barHeight,
              child: content,
            ),
          ),
          // The bar takes its taps: what slid under it is out of reach.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: bar,
            child: AbsorbPointer(
              child: DecoratedBox(
                decoration: BoxDecoration(color: ground.withValues(alpha: t)),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            left: 8 + sides.left,
            right: 8 + sides.right,
            top: topPadding + 6,
            height: 44,
            child: Row(
              spacing: 4,
              children: [
                ProfileRoundButton(
                  glyph: SheetGlyphKind.chevronLeft,
                  tooltip: 'Back',
                  onPressed: onBack,
                  onBar: t,
                ),
                Expanded(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      excluding: titleOpacity == 0,
                      child: Opacity(
                        opacity: titleOpacity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ...actions(t),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: tabsHeight,
            child: ColoredBox(color: ground, child: tabs),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(ProfilePhoneHeader oldDelegate) => true;
}

/// Tells [onSize] the height [child] lays out at, when it changes (the
/// phone header's content, whose height the pinned header needs).
class ProfileMeasured extends SingleChildRenderObjectWidget {
  const ProfileMeasured({super.key, required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderProfileMeasured(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderProfileMeasured renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

/// The render object of [ProfileMeasured].
class RenderProfileMeasured extends RenderProxyBox {
  RenderProfileMeasured(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (_reported == height) return;
    _reported = height;
    // Told after the frame: the header's extent changes on the next one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}

/// A tablet's profile column (board ProfilTablette): the avatar, the name,
/// "Watch live", Follow and Subscribe, the bio and the social links.
class ProfileRail extends StatelessWidget {
  const ProfileRail({
    super.key,
    required this.login,
    required this.displayName,
    required this.profile,
    required this.onOpenChannel,
    required this.onOpenLink,
    this.onPreload,
    this.follow,
    this.showSubscribe = false,
    this.loading = false,
  });

  final String login;
  final String displayName;
  final ChannelProfile? profile;
  final VoidCallback onOpenChannel;
  final ValueChanged<String> onOpenLink;
  final VoidCallback? onPreload;
  final ChannelInfoStore? follow;
  final bool showSubscribe;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final profile = this.profile;
    final bio = profile?.description?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 18,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ProfileAvatar(
            login: login,
            imageUrl: profile?.profileImageUrl,
            size: 120,
            border: 4,
            pulse: 16,
            live: profile?.live != null,
          ),
        ),
        ProfileIdentity(
          name: displayName,
          profile: profile,
          loading: loading,
          large: true,
        ),
        ProfileActions(
          login: login,
          name: displayName,
          live: profile?.live != null,
          onOpenChannel: onOpenChannel,
          onPreload: onPreload,
          follow: follow,
          showSubscribe: showSubscribe,
          large: true,
        ),
        if (bio != null && bio.isNotEmpty)
          Text(
            bio,
            style: TextStyle(fontSize: 14, height: 1.55, color: colors.body),
          ),
        if (profile != null && profile.socials.isNotEmpty)
          ProfileSocials(socials: profile.socials, onOpenLink: onOpenLink),
      ],
    );
  }
}

/// A social link as the boards' pill (32 dp, the surface, the inner ring),
/// with its site's mark.
class ProfileSocialPill extends StatelessWidget {
  const ProfileSocialPill({
    super.key,
    required this.social,
    required this.onOpenLink,
  });

  final SocialLink social;
  final ValueChanged<String> onOpenLink;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Tooltip(
      message: social.url,
      child: Semantics(
        link: true,
        button: true,
        label: social.title,
        onTap: () => onOpenLink(social.url),
        excludeSemantics: true,
        child: PressScale(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onOpenLink(social.url),
            // 32 dp drawn, a 44 dp target.
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                constraints: const BoxConstraints(minHeight: 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: ShapeDecoration(
                  color: colors.surface,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: colors.pillBorder,
                      width: OnsetTokens.hairlineWidth,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    Icon(socialIcon(social.name), size: 15, color: colors.body),
                    Flexible(
                      child: Text(
                        social.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The channel's social links in pills.
class ProfileSocials extends StatelessWidget {
  const ProfileSocials({
    super.key,
    required this.socials,
    required this.onOpenLink,
  });

  final List<SocialLink> socials;
  final ValueChanged<String> onOpenLink;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final social in socials)
        ProfileSocialPill(social: social, onOpenLink: onOpenLink),
    ],
  );
}
