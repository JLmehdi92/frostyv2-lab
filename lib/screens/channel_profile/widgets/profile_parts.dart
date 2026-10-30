import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/haptics.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

// The shared pieces of the channel profile (boards Profil and
// ProfilTablette).

/// A 44 dp round button over the banner (back, share, more): a dark disc
/// with a light glyph, readable on any picture. [onBar] draws it on the
/// collapsed bar instead: no disc, the theme's text colour.
class ProfileRoundButton extends StatelessWidget {
  const ProfileRoundButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
    this.disc = 0.45,
    this.onBar = 0,
  });

  final SheetGlyphKind glyph;
  final String tooltip;
  final VoidCallback onPressed;

  /// The disc's opacity (boards: 45 % on a phone, 50 % on a tablet).
  final double disc;

  /// From 0 (over the banner) to 1 (on the collapsed bar).
  final double onBar;

  @override
  Widget build(BuildContext context) {
    final t = onBar.clamp(0.0, 1.0);
    final color = Color.lerp(
      OnsetTokens.textPrimaryDark,
      FeedColors.of(context).text,
      t,
    )!;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        onTap: onPressed,
        excludeSemantics: true,
        child: PressScale(
          child: Material(
            color: Colors.black.withValues(alpha: disc * (1 - t)),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: SheetGlyph(
                    glyph,
                    color: color,
                    strokeWidth: glyph == SheetGlyphKind.chevronLeft ? 2 : 1.8,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The channel's picture in a [border] of the signal colour while it is
/// live, the ring pulsing outwards like the boards' (1.6 s, out to
/// [pulse] dp). The pulse runs in its own layer, stops in the background,
/// off-screen ([TickerMode]) and under reduce motion.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.login,
    required this.size,
    this.imageUrl,
    this.live = false,
    this.border = 3,
    this.pulse = 14,
  });

  final String login;

  /// The profile's own picture; without it, the Helix lookup.
  final String? imageUrl;
  final double size;
  final bool live;
  final double border;
  final double pulse;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  var _reduced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  var _shown = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = reduceMotionOf(context);
    _shown = ProfileAvatarShown.of(context);
    _sync();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live != widget.live) _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

  void _sync() {
    final state = WidgetsBinding.instance.lifecycleState;
    final inFront = state == null || state == AppLifecycleState.resumed;
    if (!widget.live || _reduced || !inFront || !_shown) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final url = widget.imageUrl;
    final ground = Theme.of(context).scaffoldBackgroundColor;
    final live = context.onsetColors.live;
    final inner = size - widget.border * 2;
    final picture = ClipOval(
      child: url != null
          ? OnsetCachedNetworkImage(
              imageUrl: url,
              width: inner,
              height: inner,
              fit: BoxFit.cover,
              memCacheWidth: (inner * MediaQuery.devicePixelRatioOf(context))
                  .round(),
            )
          : ProfilePicture(userLogin: widget.login, radius: inner / 2),
    );
    // The border (live) or as much of the ground (offline) around the
    // picture: the decoration's border counts as its padding.
    final avatar = Container(
      width: size,
      height: size,
      padding: widget.live ? null : EdgeInsets.all(widget.border),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ground,
        border: widget.live
            ? Border.all(color: live, width: widget.border)
            : null,
      ),
      child: picture,
    );
    // The pulse repaints in its own layer, never the picture.
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: widget.live
              ? _PulsePainter(_controller, live, widget.pulse)
              : null,
          child: RepaintBoundary(child: avatar),
        ),
      ),
    );
  }
}

/// Whether the [ProfileAvatar]s under it can be seen: a phone's header says
/// when its avatar has slid under the bar, and the pulse stops.
class ProfileAvatarShown extends InheritedWidget {
  const ProfileAvatarShown({
    super.key,
    required this.shown,
    required super.child,
  });

  final bool shown;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfileAvatarShown>()?.shown ??
      true;

  @override
  bool updateShouldNotify(ProfileAvatarShown oldWidget) =>
      shown != oldWidget.shown;
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.progress, this.color, this.reach)
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final double reach;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    // The board's box-shadow: spread 0 → reach, 55 % → 0.
    final eased = const Cubic(0.2, 0, 0, 1).transform(t);
    final radius = size.shortestSide / 2;
    final spread = reach * eased;
    canvas.drawCircle(
      size.center(Offset.zero),
      radius + spread / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = spread
        ..color = color.withValues(alpha: 0.55 * (1 - eased)),
    );
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.progress != progress || old.color != color || old.reach != reach;
}

/// "Recent broadcasts" and its "See all" (boards: 18/700, 19/700 on a
/// tablet; "See all" 13 sp in the secondary grey).
class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle({
    super.key,
    required this.title,
    this.onSeeAll,
    this.large = false,
  });

  final String title;
  final VoidCallback? onSeeAll;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final size = large ? 19.0 : 18.0;
    final onSeeAll = this.onSeeAll;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: OnsetTokens.displayFamily,
                fontSize: size,
                fontWeight: FontWeight.w700,
                letterSpacing: (large ? -0.02 : -0.015) * size,
                height: 1.25,
                color: colors.text,
              ),
            ),
          ),
        ),
        if (onSeeAll != null)
          // A 44 dp target around the small label.
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Align(
                  widthFactor: 1,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    'See all',
                    style: TextStyle(fontSize: 13, color: colors.secondary),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The small "COMING UP" label (11 / 600, tracked capitals).
class ProfileEyebrow extends StatelessWidget {
  const ProfileEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.14 * 11,
        height: 1.3,
        color: FeedColors.of(context).secondary,
      ),
    ),
  );
}

/// A day of the schedule in a tile: the weekday (signal for the next
/// stream) over the day of the month.
class ProfileDateTile extends StatelessWidget {
  const ProfileDateTile({
    super.key,
    required this.date,
    this.highlighted = false,
    this.large = false,
  });

  /// Local.
  final DateTime date;
  final bool highlighted;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return ExcludeSemantics(
      child: Container(
        width: large ? 52 : 48,
        height: large ? 56 : 52,
        decoration: BoxDecoration(
          color: colors.raised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat.E().format(date).toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1 * 10,
                  height: 1.3,
                  // The signal reads on the dark ground only.
                  color: !highlighted
                      ? colors.secondary
                      : Theme.of(context).brightness == Brightness.dark
                      ? context.onsetColors.live
                      : colors.text,
                ),
              ),
              Text(
                DateFormat.d().format(date),
                style: OnsetType.tabular(
                  TextStyle(
                    fontSize: large ? 20 : 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: colors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Twitch's reminder toggle in the boards' pill (36 dp): "Remind Me" with a
/// bell, outlined; "Reminder Set" with a check, tinted in the signal
/// colour.
class ProfileRemindButton extends StatelessWidget {
  const ProfileRemindButton({
    super.key,
    required this.set,
    required this.onPressed,
  });

  final bool set;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final accent = context.onsetColors.live;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The signal reads on the dark ground only; on white the set state
    // keeps the tint with the text colour.
    final foreground = set && dark ? accent : colors.text;
    return Semantics(
      button: true,
      toggled: set,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptics.light();
            onPressed();
          },
          // 36 dp drawn, a 44 dp target.
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: ShapeDecoration(
                color: set ? accent.withValues(alpha: 0.12) : null,
                shape: StadiumBorder(
                  side: set
                      ? BorderSide.none
                      : BorderSide(
                          color: colors.pillBorder,
                          width: OnsetTokens.hairlineWidth,
                        ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  SheetGlyph(
                    set ? SheetGlyphKind.check : SheetGlyphKind.bell,
                    size: 14,
                    color: foreground,
                    strokeWidth: set ? 2.2 : 2,
                  ),
                  Text(
                    set ? 'Reminder Set' : 'Remind Me',
                    style: TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: foreground,
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

/// A card of the profile (the next stream, a panel): the surface, 16 dp
/// corners, the inner hairline.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.hairline,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      child: child,
    );
  }
}

/// The system bars over the banner: light icons on the dark picture, the
/// theme's once the bar has collapsed ([collapsed]).
SystemUiOverlayStyle profileOverlayStyle(
  BuildContext context, {
  required bool collapsed,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final lightIcons = dark || !collapsed;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: lightIcons ? Brightness.light : Brightness.dark,
    statusBarBrightness: lightIcons ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
  );
}

/// The profile's tabs (boards: 15 / 700 selected, 600 in the tertiary grey
/// otherwise, 22 dp apart, a 2 dp signal line under the selected one and a
/// hairline under the row; 16 sp, 26 dp apart and a 2.5 dp line on a
/// tablet). They follow the [controller]'s swipes.
class ProfileTabBar extends StatelessWidget {
  const ProfileTabBar({
    super.key,
    required this.controller,
    required this.labels,
    this.large = false,
    this.padding = EdgeInsets.zero,
  });

  final TabController controller;
  final List<String> labels;
  final bool large;
  final EdgeInsetsGeometry padding;

  /// The row's height before text scaling.
  static double heightFor({required bool large}) => large ? 44 : 40;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final size = large ? 16.0 : 15.0;
    final gap = large ? 26.0 : 22.0;
    final scaler = MediaQuery.textScalerOf(context);
    final height = heightFor(large: large) - size + scaler.scale(size);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.hairline,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: padding,
        labelPadding: EdgeInsetsDirectional.only(end: gap),
        dividerHeight: 0,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: context.onsetColors.live,
            width: large ? 2.5 : 2,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        labelColor: colors.text,
        unselectedLabelColor: colors.tertiary,
        labelStyle: TextStyle(
          fontFamily: OnsetTokens.bodyFamily,
          fontSize: size,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: OnsetTokens.bodyFamily,
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        onTap: (_) => Haptics.selection(),
        tabs: [for (final label in labels) Tab(height: height, text: label)],
      ),
    );
  }
}
