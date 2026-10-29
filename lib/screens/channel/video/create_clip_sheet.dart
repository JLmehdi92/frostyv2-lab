import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/channel/stores/create_clip_store.dart';
import 'package:frosty/screens/onboarding/login_webview.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/vod/widgets/video_glyph.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/share_link.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/press_scale.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';
import 'package:frosty/widgets/twitch_web_page.dart';
import 'package:provider/provider.dart';

/// What to tell the viewer when Twitch would not make the clip.
String clipFailureMessage(ClipCreateFailure failure) => switch (failure) {
  ClipCreateFailure.missingScope =>
    'Your Twitch login does not allow creating clips.',
  ClipCreateFailure.restricted =>
    "You can't clip this channel right now: clips may be off, only for "
        'followers or subscribers, or you are banned or timed out here.',
  ClipCreateFailure.offline => 'Only live streams can be clipped.',
  ClipCreateFailure.notClippable =>
    'This channel does not permit clips of this category.',
  ClipCreateFailure.rateLimited =>
    'Too many clips at once. Try again in a moment.',
  ClipCreateFailure.unknown => 'Hmm... Something went wrong',
};

/// The live frame of [login]'s stream behind the clip being made (null
/// for a login that is not Twitch's).
String? clipFramePreviewUrl(String? login) {
  if (login == null || !_login.hasMatch(login)) return null;
  return 'https://static-cdn.jtvnw.net/previews-ttv/live_user_'
      '${login.toLowerCase()}-640x360.jpg';
}

final _login = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

/// The official app's Create Clip panel (board CreerClip): the clip is made
/// as soon as it opens, over the live frame while Twitch works; once Twitch
/// has it, its picture, Edit (twitch.tv's clip editor, where the title and
/// the moment are set before publishing), Share Clip and Copy link.
class CreateClipSheet extends StatelessWidget {
  const CreateClipSheet({
    super.key,
    required this.store,
    required this.onLogIn,
    required this.onOpenEditor,
    required this.onShare,
    this.framePreviewUrl,
    this.channelLogin,
    this.channelName,
    this.gameName,
  });

  final CreateClipStore store;

  /// Logs in again (with the clip permission).
  final VoidCallback onLogIn;
  final void Function(Uri editUrl) onOpenEditor;
  final void Function(String link) onShare;

  /// The live frame behind the work (null: a plain dark card).
  final String? framePreviewUrl;

  /// The channel and its category, on the finished clip's picture.
  final String? channelLogin;
  final String? channelName;
  final String? gameName;

  /// Opens the panel and clips [broadcasterId]'s stream right away.
  static Future<void> show(
    BuildContext context, {
    required String broadcasterId,
    String? channelLogin,
    String? channelName,
    String? gameName,
  }) async {
    final authStore = context.read<AuthStore>();
    final store = CreateClipStore(
      twitchApi: context.read<TwitchApi>(),
      broadcasterId: broadcasterId,
      isLoggedIn: () => authStore.isLoggedIn,
    );
    unawaited(store.start());
    final navigator = Navigator.of(context);
    try {
      await showOnsetSheet<void>(
        context: context,
        builder: (sheetContext) => CreateClipSheet(
          store: store,
          framePreviewUrl: clipFramePreviewUrl(channelLogin),
          channelLogin: channelLogin,
          channelName: channelName,
          gameName: gameName,
          onLogIn: () {
            Navigator.of(sheetContext).pop();
            navigator.push(
              MaterialPageRoute(
                builder: (context) => Provider<AuthStore>.value(
                  value: authStore,
                  child: const LoginWebView(),
                ),
              ),
            );
          },
          onOpenEditor: (url) =>
              TwitchWebPage.open(sheetContext, title: 'Edit Clip', url: url),
          onShare: (link) => shareLink(sheetContext, link),
        ),
      );
    } finally {
      store.dispose();
    }
  }

  Future<void> _copy(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: AlertMessage(message: 'Clip link copied', centered: false),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final creation = store.creation;
    final colors = SheetColors.of(context);
    switch (store.status) {
      case CreateClipStatus.idle:
      case CreateClipStatus.checking:
      case CreateClipStatus.creating:
        return _Working(
          key: const ValueKey('working'),
          label: 'Generating Clipperino...',
          frameUrl: framePreviewUrl,
          frameOpacity: 0.28,
        );
      case CreateClipStatus.rendering:
        return _Working(
          key: const ValueKey('working'),
          label: 'Rendering Clip',
          frameUrl: framePreviewUrl,
          frameOpacity: 0.55,
        );
      case CreateClipStatus.needsLogin:
        return _Prompt(
          key: const ValueKey('login'),
          message: 'Log in to create clips.',
          action: 'Log in',
          onPressed: onLogIn,
        );
      case CreateClipStatus.missingScope:
        return _Prompt(
          key: const ValueKey('scope'),
          message:
              'Creating clips needs a permission your Twitch login does not '
              'have yet. Reconnect to Twitch to allow it.',
          action: 'Reconnect to Twitch',
          onPressed: onLogIn,
        );
      case CreateClipStatus.failed:
        return Padding(
          key: const ValueKey('failed'),
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 4),
          child: Column(
            spacing: 12,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.raised,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: VideoGlyph(
                    VideoGlyphKind.alert,
                    color: colors.text,
                    size: 22,
                    strokeWidth: 2,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  clipFailureMessage(
                    store.failure ?? ClipCreateFailure.unknown,
                  ),
                  textAlign: TextAlign.center,
                  style: SheetText.body.copyWith(
                    fontSize: 14.5,
                    color: colors.body,
                  ),
                ),
              ),
              _QuietPill(label: 'Retry', onPressed: store.start),
            ],
          ),
        );
      case CreateClipStatus.ready:
        if (creation == null) return const SizedBox.shrink();
        final editUrl = creation.editUrl;
        final thumbnail = store.thumbnailUrl;
        return Column(
          key: const ValueKey('ready'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            _Reveal(
              child: _ClipPicture(
                url: thumbnail,
                channelLogin: channelLogin,
                caption: [channelName, gameName]
                    .whereType<String>()
                    .where((part) => part.isNotEmpty)
                    .join(' · '),
              ),
            ),
            if (editUrl != null) _EditRow(onTap: () => onOpenEditor(editUrl)),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: SheetButton(
                    label: 'Share Clip',
                    large: true,
                    expand: true,
                    icon: VideoGlyph(
                      VideoGlyphKind.share,
                      color: SheetColors.onAccentOf(context),
                      size: 17,
                      strokeWidth: 2.1,
                    ),
                    onPressed: () => onShare(creation.link),
                  ),
                ),
                Expanded(
                  child: _QuietPill(
                    label: 'Copy link',
                    glyph: VideoGlyphKind.link,
                    large: true,
                    onPressed: () => _copy(context, creation.link),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            spacing: 10,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: SheetColors.accentTintOf(context, alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: VideoGlyph(
                    VideoGlyphKind.clip,
                    color: accent,
                    size: 17,
                    strokeWidth: 2,
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Create Clip',
                    style: SheetText.subtitle.copyWith(color: colors.text),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(10, 0),
                child: Tooltip(
                  message: 'Close',
                  child: IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: VideoGlyph(
                      VideoGlyphKind.close,
                      color: colors.secondary,
                      size: 16,
                      strokeWidth: 2.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Observer(
            builder: (context) => AnimatedSwitcher(
              duration: motionDuration(
                context,
                const Duration(milliseconds: 300),
              ),
              switchInCurve: FrostyMotion.standard,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: reduceMotionOf(context)
                    ? child
                    : SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              child: _content(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Twitch at work: the live frame dimmed in a 16:9 card, the spinner and
/// what is happening, a running line along the bottom, and the two
/// buttons' places.
class _Working extends StatelessWidget {
  const _Working({
    super.key,
    required this.label,
    required this.frameUrl,
    required this.frameOpacity,
  });

  final String label;
  final String? frameUrl;
  final double frameOpacity;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    final frameUrl = this.frameUrl;
    final radius = BorderRadius.circular(14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                if (frameUrl != null)
                  AnimatedOpacity(
                    opacity: frameOpacity,
                    duration: motionDuration(
                      context,
                      const Duration(milliseconds: 600),
                    ),
                    child: FrostyCachedNetworkImage(
                      imageUrl: frameUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 12,
                    children: [
                      SizedBox.square(
                        dimension: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: accent,
                          backgroundColor: const Color(0x24FFFFFF),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          label,
                          style: SheetText.row.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: FrostyTokens.textPrimaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: accent,
                    backgroundColor: const Color(0x14FFFFFF),
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: colors.ring,
                        width: FrostyTokens.hairlineWidth,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ExcludeSemantics(
          child: Row(
            spacing: 8,
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: ShapeDecoration(
                      color: colors.well,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The finished clip's picture with the channel and category over it.
class _ClipPicture extends StatelessWidget {
  const _ClipPicture({
    required this.url,
    required this.channelLogin,
    required this.caption,
  });

  final String? url;
  final String? channelLogin;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final url = this.url;
    final login = channelLogin;
    final radius = BorderRadius.circular(14);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            if (url != null)
              Semantics(
                image: true,
                label: 'Clip thumbnail',
                child: FrostyCachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x99000000)],
                  stops: [0.55, 1],
                ),
              ),
            ),
            if (caption.isNotEmpty)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Row(
                  spacing: 8,
                  children: [
                    if (login != null && login.isNotEmpty)
                      ProfilePicture(userLogin: login, radius: 10),
                    Flexible(
                      child: Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: FrostyTokens.bodyFamily,
                          fontSize: 12,
                          color: FrostyTokens.textBodyDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: colors.ring,
                    width: FrostyTokens.hairlineWidth,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picture brightens and settles in once Twitch has the clip (420 ms;
/// a plain fade under reduce motion).
class _Reveal extends StatelessWidget {
  const _Reveal({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motionDuration(context, const Duration(milliseconds: 420)),
      curve: FrostyMotion.standard,
      builder: (context, t, child) {
        // brightness(.45) → none: a black veil that lifts.
        final veil = 0.55 * (1 - t);
        return Transform.scale(
          scale: reduce ? 1 : 0.985 + 0.015 * t,
          child: Stack(
            children: [
              child!,
              if (veil > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: veil),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: child,
    );
  }
}

/// "Edit · Title and moment, in the twitch.tv clip editor".
class _EditRow extends StatelessWidget {
  const _EditRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Semantics(
      button: true,
      label: 'Edit, Title and moment, in the twitch.tv clip editor',
      excludeSemantics: true,
      child: PressScale(
        child: Material(
          color: colors.well,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colors.hairline,
              width: FrostyTokens.hairlineWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 12, 8),
                child: Row(
                  spacing: 12,
                  children: [
                    VideoGlyph(VideoGlyphKind.pencil, color: colors.text),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: 1,
                        children: [
                          Text(
                            'Edit',
                            style: SheetText.row.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                          Text(
                            'Title and moment, in the twitch.tv clip editor',
                            style: SheetText.rowDetail.copyWith(
                              fontSize: 12,
                              color: colors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    VideoGlyph(
                      VideoGlyphKind.chevronRight,
                      color: colors.secondary,
                      size: 18,
                      strokeWidth: 2,
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

/// What the viewer must do first (log in, reconnect), with the button.
class _Prompt extends StatelessWidget {
  const _Prompt({
    super.key,
    required this.message,
    required this.action,
    required this.onPressed,
  });

  final String message;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(
            message,
            style: SheetText.body.copyWith(fontSize: 14.5, color: colors.body),
          ),
          SheetButton(
            label: action,
            large: true,
            expand: true,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

/// A raised pill with a hairline (Retry, Copy link).
class _QuietPill extends StatelessWidget {
  const _QuietPill({
    required this.label,
    required this.onPressed,
    this.glyph,
    this.large = false,
  });

  final String label;
  final VoidCallback onPressed;
  final VideoGlyphKind? glyph;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final glyph = this.glyph;
    return PressScale(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: colors.text,
          backgroundColor: colors.raised,
          minimumSize: Size(large ? double.infinity : 0, large ? 48 : 44),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: StadiumBorder(
            side: BorderSide(
              color: colors.ringStrong,
              width: FrostyTokens.hairlineWidth,
            ),
          ),
          textStyle: const TextStyle(
            fontFamily: FrostyTokens.bodyFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            if (glyph != null)
              VideoGlyph(glyph, color: colors.text, size: 17, strokeWidth: 1.9),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// The live player's Clip button (top right, like the official app): it
/// stays lit while its panel is open (board CreerClip).
class CreateClipButton extends StatefulWidget {
  const CreateClipButton({
    super.key,
    required this.broadcasterId,
    required this.color,
    this.shadows,
    this.icon,
    this.activeIcon,
    this.channelLogin,
    this.channelName,
    this.gameName,
  });

  final String broadcasterId;
  final Color color;
  final List<Shadow>? shadows;

  /// Replaces the default icon (the player draws its own glyphs).
  final Widget? icon;

  /// The icon while the panel is open (in the signal colour).
  final Widget? activeIcon;

  /// The channel and its category, for the panel's pictures.
  final String? channelLogin;
  final String? channelName;
  final String? gameName;

  @override
  State<CreateClipButton> createState() => _CreateClipButtonState();
}

class _CreateClipButtonState extends State<CreateClipButton> {
  var _open = false;

  Future<void> _create() async {
    setState(() => _open = true);
    try {
      await CreateClipSheet.show(
        context,
        broadcasterId: widget.broadcasterId,
        channelLogin: widget.channelLogin,
        channelName: widget.channelName,
        gameName: widget.gameName,
      );
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.icon;
    final accent = context.frostyColors.live;
    final shown = _open ? (widget.activeIcon ?? icon) : icon;
    return Semantics(
      selected: _open,
      child: IconButton(
        tooltip: 'Clip',
        padding: icon == null ? null : EdgeInsets.zero,
        constraints: icon == null
            ? null
            : const BoxConstraints.tightFor(width: 44, height: 44),
        style: icon == null
            ? null
            : IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: _open
                    ? accent.withValues(alpha: 0.16)
                    : Colors.transparent,
              ),
        icon:
            shown ??
            Icon(
              Icons.movie_creation_outlined,
              color: _open ? accent : widget.color,
              shadows: widget.shadows,
            ),
        onPressed: _open ? null : () => unawaited(_create()),
      ),
    );
  }
}
