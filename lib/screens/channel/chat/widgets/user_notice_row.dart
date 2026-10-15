import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:frosty/cache_manager.dart';
import 'package:frosty/models/user_notice_presentation.dart';
import 'package:frosty/models/user_notice_text.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';

/// A sub, gift or other `USERNOTICE`, drawn as Twitch's Android app draws its
/// notice rows, in green where Twitch uses purple.
///
/// A full-width row, 2dp clear of its neighbours, with a 4dp accent bar down
/// its left edge, an optional 18dp icon, the notice's sentence and, below it,
/// the viewer's own message (a resub message, for instance) rendered as an
/// ordinary chat line. The special and sub goal layouts sit on a green tint;
/// the generic and raid layouts have no tint and an accent in the text colour.
///
/// In the chat drawn over the video ([overlay]) the tint gives way to a
/// translucent black and the row is rounded, its accent bar too.
///
/// Knows nothing of the chat: the caller words the notice, picks its
/// presentation and builds the user message.
class UserNoticeRow extends StatelessWidget {
  /// The notice's sentence, as worded by `userNoticeText`. Empty when Twitch
  /// sent none, in which case only [userMessage] is shown.
  final List<NoticeSegment> segments;

  final NoticePresentation presentation;

  /// The viewer's own message, under the sentence.
  final Widget? userMessage;

  /// The avatar in the icon slot: the source channel of a shared-chat sub, or
  /// the raiding channel.
  final String? avatarUrl;

  /// Replaces the accent, for a notice branded by its sponsor.
  final Color? accentColor;

  /// The sub goal's progress, for [NoticeLayout.subGoal].
  final int? goalCurrent;
  final int? goalTarget;

  /// Whether the row sits in the chat drawn over the video.
  final bool overlay;

  const UserNoticeRow({
    super.key,
    required this.segments,
    required this.presentation,
    this.userMessage,
    this.avatarUrl,
    this.accentColor,
    this.goalCurrent,
    this.goalTarget,
    this.overlay = false,
  });

  /// The tinted body, inside the row's 2dp margins.
  static const bodyKey = ValueKey('user-notice-row-body');

  /// The sentence.
  static const systemLineKey = ValueKey('user-notice-row-system-line');

  static const _accentWidth = 4.0;
  static const _iconSize = 18.0;
  static const _avatarSlot = 24.0;
  static const _avatarSize = 16.0;
  static const _gap = 8.0;

  /// The row's background over the video: black at 16%.
  static const overlayBackground = Color(0x29000000);
  static const _overlayRadius = 6.0;

  bool get _tinted =>
      presentation.layout == NoticeLayout.special ||
      presentation.layout == NoticeLayout.subGoal;

  double get _iconSlotWidth => switch (presentation.icon) {
    null => 0,
    NoticeGlyph.sharedChat || NoticeGlyph.raider => _avatarSlot,
    _ => _iconSize,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.frostyColors;
    final accent =
        accentColor ??
        (_tinted ? colors.subNoticeAccent : context.colorScheme.onSurface);

    final icon = _icon(context);
    final iconSlot = icon == null ? 0.0 : _gap + _iconSlotWidth;

    final content = Padding(
      padding: EdgeInsets.only(left: iconSlot),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (segments.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                left: _gap,
                top: _gap,
                bottom: userMessage == null ? _gap : 0,
              ),
              child: presentation.layout == NoticeLayout.subGoal
                  ? _withGoal(context, accent)
                  : Padding(
                      padding: const EdgeInsets.only(right: _gap * 2),
                      child: _systemLine(context),
                    ),
            ),
          if (userMessage != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                _gap,
                segments.isEmpty ? _gap : 2,
                _gap,
                _gap,
              ),
              child: userMessage,
            ),
        ],
      ),
    );

    final background = !_tinted
        ? null
        : overlay
        ? overlayBackground
        : _tint(context);

    final body = Container(
      key: bodyKey,
      width: double.infinity,
      decoration: BoxDecoration(
        color: background,
        border: Border(
          left: BorderSide(color: accent, width: _accentWidth),
        ),
      ),
      child: icon == null
          ? content
          : Stack(
              children: [
                content,
                Positioned(
                  left: _gap,
                  top: 0,
                  bottom: 0,
                  width: _iconSlotWidth,
                  child: Align(
                    alignment: Alignment(0, presentation.iconBias * 2 - 1),
                    child: icon,
                  ),
                ),
              ],
            ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: overlay
          ? ClipRRect(
              borderRadius: BorderRadius.circular(_overlayRadius),
              child: body,
            )
          : body,
    );
  }

  /// The row's tint: the green one, or a sponsor's [accentColor] mixed into
  /// the theme's background the same way (10% in the dark theme, 8% in the
  /// light one).
  Color _tint(BuildContext context) {
    final sponsor = accentColor;
    if (sponsor == null) return context.frostyColors.subNoticeBackground;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Color.alphaBlend(
      sponsor.withValues(alpha: dark ? 0.10 : 0.08),
      dark ? FrostyTokens.backgroundDark : FrostyTokens.backgroundLight,
    );
  }

  Widget _systemLine(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    final fontSize = base.fontSize ?? 14;
    // Twitch adds 2dp between lines on top of the font's own line height.
    final lineHeight = ((base.height ?? 1.2) * fontSize + 2) / fontSize;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 24,
        minWidth: double.infinity,
      ),
      child: Text.rich(
        key: systemLineKey,
        TextSpan(
          style: base.copyWith(fontWeight: FontWeight.w600, height: lineHeight),
          children: [
            for (final segment in segments)
              TextSpan(
                text: segment.text,
                style: segment.bold
                    ? const TextStyle(fontWeight: FontWeight.w700)
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  /// The sentence beside the goal's static progress: three parts text to one
  /// part progress, the progress at most 75dp wide.
  Widget _withGoal(BuildContext context, Color accent) {
    final current = goalCurrent;
    final target = goalTarget;
    if (current == null || target == null || target <= 0) {
      return Padding(
        padding: const EdgeInsets.only(right: _gap * 2),
        child: _systemLine(context),
      );
    }

    return Row(
      children: [
        Expanded(flex: 3, child: _systemLine(context)),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 75),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Text(
                    '$current/$target',
                    style: DefaultTextStyle.of(
                      context,
                    ).style.copyWith(fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                  LinearProgressIndicator(
                    value: (current / target).clamp(0.0, 1.0),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    color: accent,
                    backgroundColor: accent.withValues(alpha: 0.2),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: _gap * 2),
      ],
    );
  }

  Widget? _icon(BuildContext context) {
    final tint = context.frostyColors.metadata;
    Icon glyph(IconData data) => Icon(data, size: _iconSize, color: tint);

    return switch (presentation.icon) {
      null => null,
      NoticeGlyph.anonymousGift ||
      NoticeGlyph.gift => glyph(Icons.card_giftcard_rounded),
      NoticeGlyph.megaphone => glyph(Icons.campaign_rounded),
      NoticeGlyph.charity => glyph(Icons.favorite_rounded),
      NoticeGlyph.milestone => glyph(Icons.emoji_events_rounded),
      NoticeGlyph.raider =>
        avatarUrl == null
            ? glyph(Icons.people_rounded)
            : _avatar(avatarUrl!, _avatarSlot, tint),
      NoticeGlyph.sharedChat => _sharedChatBadge(context, tint),
    };
  }

  /// The source channel's avatar with a star badge over its lower right.
  Widget _sharedChatBadge(BuildContext context, Color tint) {
    final background = !_tinted
        ? Theme.of(context).scaffoldBackgroundColor
        : overlay
        ? Colors.black
        : _tint(context);

    return SizedBox.square(
      dimension: _avatarSlot,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: avatarUrl == null
                ? _placeholder(_avatarSize, tint)
                : _avatar(avatarUrl!, _avatarSize, tint),
          ),
          Positioned(
            left: _gap,
            top: _gap,
            child: Container(
              width: _avatarSize,
              height: _avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: background,
                border: Border.all(color: background),
              ),
              child: Icon(
                Icons.star_rounded,
                size: _avatarSize - 4,
                color: context.frostyColors.subNoticeAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _avatar(String url, double size, Color tint) =>
      CachedNetworkImage(
        cacheManager: CustomCacheManager.instance,
        imageUrl: url,
        width: size,
        height: size,
        imageBuilder: (context, image) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(image: image, fit: BoxFit.cover),
          ),
        ),
        placeholder: (context, url) => _placeholder(size, tint),
        errorWidget: (context, url, error) => _placeholder(size, tint),
      );

  static Widget _placeholder(double size, Color tint) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: tint.withValues(alpha: 0.3),
    ),
  );
}
