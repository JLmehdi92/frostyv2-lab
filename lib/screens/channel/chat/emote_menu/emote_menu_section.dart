import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/constants.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/twitch_links.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/twitch_web_page.dart';

class EmoteMenuSection extends StatefulWidget {
  final ChatStore chatStore;
  final List<Emote> emotes;
  final bool disabled;

  /// Names usable even in a [disabled] section (a follower or Bits emote
  /// of a channel the viewer is not subscribed to).
  final Set<String> usable;

  final String? followerInfo;

  const EmoteMenuSection({
    super.key,
    required this.chatStore,
    required this.emotes,
    this.disabled = false,
    this.usable = const {},
    this.followerInfo,
  });

  @override
  State<EmoteMenuSection> createState() => _EmoteMenuSectionState();
}

class _EmoteMenuSectionState extends State<EmoteMenuSection>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final panel = SheetPresentation.isPanel(context);
    final emotes = widget.emotes;
    final followerInfo = widget.followerInfo;
    final showFollowerInfo =
        followerInfo != null &&
        emotes.any((emote) => emote.type == EmoteType.twitchFollower);
    final side = panel ? 6.0 : 4.0;
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: CustomScrollView(
        slivers: [
          if (showFollowerInfo)
            SliverToBoxAdapter(child: EmoteMenuNote(text: followerInfo)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(side, 4, side, 10),
            sliver: SliverGrid(
              gridDelegate: emoteGridDelegate(context, panel: panel),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _cell(context, emotes[index]),
                childCount: emotes.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, Emote emote) {
    final locked = widget.disabled && !widget.usable.contains(emote.name);
    void details() => showEmoteDetails(
      context,
      chatStore: widget.chatStore,
      emote: emote,
      locked: locked,
    );
    return EmoteCell(
      emote: emote,
      locked: locked,
      onTap: locked ? details : () => widget.chatStore.addEmote(emote),
      onLongPress: () {
        HapticFeedback.lightImpact();
        details();
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

void showEmoteDetails(
  BuildContext context, {
  required ChatStore chatStore,
  required Emote emote,
  bool locked = false,
  VoidCallback? onRemoveRecent,
}) {
  final subscribeUrl = locked && emote.type == EmoteType.twitchChannel
      ? twitchSubscribeUrl(chatStore.channelName)
      : null;
  IRCMessage.showEmoteDetailsBottomSheet(
    context,
    emote: emote,
    launchExternal: chatStore.settings.launchUrlExternal,
    onRemoveRecent: onRemoveRecent,
    onSubscribe: subscribeUrl == null
        ? null
        : () => TwitchWebPage.open(
            context,
            title: context.l10n.channelSubscribe,
            url: subscribeUrl,
          ),
  );
}

class EmoteMenuNote extends StatelessWidget {
  const EmoteMenuNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SheetGlyph(
              SheetGlyphKind.heart,
              size: 15,
              color: colors.secondary,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: SheetText.rowDetail.copyWith(color: colors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The grid of the emote menu: 8 columns on a phone in portrait, 6 beside
/// the video, 16 for a chat alone in landscape; 6 tall cells in a
/// tablet's panel.
SliverGridDelegate emoteGridDelegate(
  BuildContext context, {
  required bool panel,
}) {
  if (panel) {
    return const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 6,
      mainAxisExtent: 54,
    );
  }
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: context.isPortrait
        ? 8
        : context.settingsStore.showVideo
        ? 6
        : 16,
  );
}

/// One emote of the menu: a 12 dp rounded tap target, dimmed to 42 % when
/// it cannot be used (a sub emote of a channel one is not subscribed to).
class EmoteCell extends StatelessWidget {
  const EmoteCell({
    super.key,
    required this.emote,
    required this.locked,
    required this.onTap,
    required this.onLongPress,
    this.url,
  });

  final Emote emote;
  final bool locked;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  /// The picture to show, when not the emote's own.
  final String? url;

  @override
  Widget build(BuildContext context) {
    final label = locked
        ? context.l10n.emoteMenuLocked(name: emote.name)
        : emote.animated
        ? context.l10n.emoteMenuAnimated(name: emote.name)
        : null;
    return Semantics(
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Dimmed by the image's own colour, not an opacity layer per
                // cell: a channel's sub emotes can fill the grid.
                OnsetCachedNetworkImage(
                  imageUrl: url ?? emote.url,
                  height: emote.height?.toDouble() ?? defaultEmoteSize,
                  width: emote.width?.toDouble(),
                  memCacheHeight:
                      ((emote.height?.toDouble() ?? defaultEmoteSize) *
                              MediaQuery.devicePixelRatioOf(context))
                          .ceil(),
                  color: locked
                      ? const Color.fromRGBO(255, 255, 255, 0.42)
                      : null,
                  colorBlendMode: locked ? BlendMode.modulate : null,
                  semanticLabel: label == null ? emote.name : null,
                ),
                if (emote.animated)
                  const PositionedDirectional(
                    end: -6,
                    bottom: -4,
                    child: AnimatedEmoteMark(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedEmoteMark extends StatelessWidget {
  const AnimatedEmoteMark({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return ExcludeSemantics(
      child: Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          color: colors.raised,
          shape: BoxShape.circle,
          border: Border.all(
            color: colors.ring,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        alignment: Alignment.center,
        child: CustomPaint(
          size: const Size(5, 6),
          painter: _PlayMarkPainter(colors.secondary),
        ),
      ),
    );
  }
}

class _PlayMarkPainter extends CustomPainter {
  const _PlayMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PlayMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
