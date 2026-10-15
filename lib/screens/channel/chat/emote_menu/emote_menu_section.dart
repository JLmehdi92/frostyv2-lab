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

class _EmoteMenuSectionState extends State<EmoteMenuSection>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: context.isPortrait
              ? 8
              : context.settingsStore.showVideo
              ? 6
              : 16,
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
                  semanticLabel: widget.emotes[index].name,
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
