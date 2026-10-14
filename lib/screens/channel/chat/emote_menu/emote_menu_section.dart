import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/emotes.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/screens/channel/chat/stores/chat_store.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';

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

/// The emote grid of the emote menu and the recent emotes. A large screen
/// fits as many cells as it can at up to [kLargeScreenEmoteCell] dp, instead
/// of stretching a phone's column count to 130 dp cells.
SliverGridDelegate emoteGridDelegate({
  required bool largeScreen,
  required bool portrait,
  required bool showVideo,
}) {
  if (largeScreen) {
    return const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: kLargeScreenEmoteCell,
    );
  }
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: portrait
        ? 8
        : showVideo
        ? 6
        : 16,
  );
}

/// Widest emote cell on a large screen, in dp.
const kLargeScreenEmoteCell = 64.0;

class _EmoteMenuSectionState extends State<EmoteMenuSection>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: GridView.builder(
        gridDelegate: emoteGridDelegate(
          largeScreen: context.isLargeScreen,
          portrait: context.isPortrait,
          showVideo: context.settingsStore.showVideo,
        ),
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          final off =
              widget.disabled &&
              !widget.usable.contains(widget.emotes[index].name);
          return InkWell(
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
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: Center(
                child: FrostyCachedNetworkImage(
                  imageUrl: widget.emotes[index].url,
                  height:
                      widget.emotes[index].height?.toDouble() ??
                      defaultEmoteSize,
                  width: widget.emotes[index].width?.toDouble(),
                  color: off ? const Color.fromRGBO(255, 255, 255, 0.5) : null,
                  colorBlendMode: off ? BlendMode.modulate : null,
                ),
              ),
            ),
          );
        },
        itemCount: widget.emotes.length,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
