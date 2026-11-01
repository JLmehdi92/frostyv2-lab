import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/constants.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';

class EmoteMenuSection extends StatefulWidget {
  final ChatStore chatStore;
  final List<Emote> emotes;
  final bool disabled;

  /// Names usable even in a [disabled] section (a follower or Bits emote
  /// of a channel the viewer is not subscribed to).
  final Set<String> usable;

  const EmoteMenuSection({
    super.key,
    required this.chatStore,
    required this.emotes,
    this.disabled = false,
    this.usable = const {},
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
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: GridView.builder(
        gridDelegate: emoteGridDelegate(context, panel: panel),
        padding: EdgeInsets.fromLTRB(panel ? 6 : 4, 4, panel ? 6 : 4, 10),
        itemBuilder: (context, index) {
          final off =
              widget.disabled &&
              !widget.usable.contains(widget.emotes[index].name);
          return EmoteCell(
            emote: widget.emotes[index],
            locked: off,
            onTap: off
                ? null
                : () => widget.chatStore.addEmote(widget.emotes[index]),
            onLongPress: () {
              HapticFeedback.lightImpact();

              IRCMessage.showEmoteDetailsBottomSheet(
                context,
                emote: widget.emotes[index],
                launchExternal: widget.chatStore.settings.launchUrlExternal,
              );
            },
          );
        },
        itemCount: widget.emotes.length,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
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
    return Semantics(
      label: locked ? context.l10n.emoteMenuLocked(name: emote.name) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Center(
            // Dimmed by the image's own colour, not an opacity layer per
            // cell: a channel's sub emotes can fill the grid.
            child: OnsetCachedNetworkImage(
              imageUrl: url ?? emote.url,
              height: emote.height?.toDouble() ?? defaultEmoteSize,
              width: emote.width?.toDouble(),
              color: locked ? const Color.fromRGBO(255, 255, 255, 0.42) : null,
              colorBlendMode: locked ? BlendMode.modulate : null,
              semanticLabel: locked ? null : emote.name,
            ),
          ),
        ),
      ),
    );
  }
}
