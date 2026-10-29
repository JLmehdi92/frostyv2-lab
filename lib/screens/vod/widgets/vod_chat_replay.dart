import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/home/stream_list/stream_card_parts.dart';
import 'package:frosty/screens/vod/stores/vod_chat_replay_store.dart';
import 'package:frosty/screens/vod/widgets/video_glyph.dart';
import 'package:frosty/screens/vod/widgets/video_kit.dart';
import 'package:frosty/screens/vod/widgets/vod_chat_message.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/press_scale.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';
import 'package:frosty/widgets/skeleton_loader.dart';

/// Why the replay's emotes may differ from the broadcast's.
const kReplayEmotesNote =
    "7TV, BTTV and FFZ emotes are the channel's current sets, which may "
    'differ from the ones used during the broadcast.';

/// The chat replay pane under (or beside) the VOD player (boards Rediff,
/// RediffTablette, Clips): "Chat replay" with its "synced to video" pill
/// and the note about emotes, then the messages as the live chat draws
/// them.
class VodChatReplay extends StatefulWidget {
  const VodChatReplay({
    super.key,
    required this.store,
    this.showHeader = true,
    this.large = false,
    this.syncLabel = 'synced to video',
  });

  final VodChatReplayStore store;

  /// The "Chat replay" title (hidden when the pane is an overlay).
  final bool showHeader;

  /// A tablet's side column: the 56 dp header with its hairline.
  final bool large;

  /// The pill's words ("synced to the clip" under a clip).
  final String syncLabel;

  @override
  State<VodChatReplay> createState() => _VodChatReplayState();
}

class _VodChatReplayState extends State<VodChatReplay> {
  /// The note about emotes, over the top of the messages.
  var _noteShown = false;

  VodChatReplayStore get _store => widget.store;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The header follows the status only, not each message.
        if (widget.showHeader)
          Observer(
            builder: (context) {
              final status = _store.status;
              return _ReplayHeader(
                large: widget.large,
                syncLabel:
                    status == ReplayStatus.unavailable ||
                        status == ReplayStatus.notApplicable
                    ? null
                    : widget.syncLabel,
                noteShown: _noteShown,
                onNote: () => setState(() => _noteShown = !_noteShown),
              );
            },
          ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: Observer(builder: _body)),
              if (_noteShown)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 4,
                  child: _EmotesNote(
                    onClose: () => setState(() => _noteShown = false),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final store = _store;
    final settings = store.settings;
    switch (store.status) {
      case ReplayStatus.notApplicable:
        return const VideoPaneNotice(message: 'Uploads have no chat replay');
      case ReplayStatus.unavailable:
        return VideoPaneNotice(
          message: 'Chat replay is unavailable for this video',
          onRetry: store.retry,
        );
      case ReplayStatus.loading when store.messages.isEmpty:
        return const ReplayLoading();
      case ReplayStatus.active when store.messages.isEmpty:
        return const VideoPaneNotice(message: 'No messages yet');
      case ReplayStatus.loading || ReplayStatus.active:
        break;
    }
    final messages = store.messages;
    return Stack(
      alignment: AlignmentDirectional.bottomCenter,
      children: [
        MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: settings.messageScale.textScaler),
          child: DefaultTextStyle(
            style: context.defaultTextStyle.copyWith(
              fontSize: settings.fontSize,
            ),
            child: FrostyScrollbar(
              controller: store.scrollController,
              child: ListView.builder(
                reverse: true,
                addAutomaticKeepAlives: false,
                controller: store.scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) => VodChatMessage(
                  ircMessage: messages[messages.length - 1 - index],
                  assetsStore: store.assetsStore,
                  settings: settings,
                  vodCreatedAt: store.vod.createdAt,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AnimatedSwitcher(
            duration: motionDuration(
              context,
              const Duration(milliseconds: 280),
            ),
            switchInCurve: FrostyMotion.standard,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: reduceMotionOf(context)
                  ? child
                  : SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
            ),
            child: store.autoScroll
                ? const SizedBox.shrink()
                : ResumeScrollPill(onPressed: store.resumeScroll),
          ),
        ),
      ],
    );
  }
}

/// "Chat replay", the synced pill and the note button: 44 dp, or 56 with a
/// hairline in a tablet's column.
class _ReplayHeader extends StatelessWidget {
  const _ReplayHeader({
    required this.large,
    required this.syncLabel,
    required this.noteShown,
    required this.onNote,
  });

  final bool large;
  final String? syncLabel;
  final bool noteShown;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final syncLabel = this.syncLabel;
    return Container(
      height: large ? 56 : 44,
      padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      decoration: large
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.hairline,
                  width: FrostyTokens.hairlineWidth,
                ),
              ),
            )
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A narrow side chat keeps the title and the note.
          final roomy = constraints.maxWidth >= 240;
          return Row(
            spacing: large ? 10 : 8,
            children: [
              Flexible(
                child: Text(
                  'Chat replay',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: FrostyTokens.bodyFamily,
                    fontSize: large ? 15 : 14,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
              if (syncLabel != null && roomy)
                Flexible(child: SyncedPill(label: syncLabel)),
              const Spacer(),
              Tooltip(
                message: 'About emotes in replays',
                child: Semantics(
                  selected: noteShown,
                  child: IconButton(
                    onPressed: onNote,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: VideoGlyph(
                      VideoGlyphKind.info,
                      color: colors.secondary,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The note about emotes, in a raised card over the messages; a tap closes
/// it.
class _EmotesNote extends StatelessWidget {
  const _EmotesNote({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motionDuration(context, const Duration(milliseconds: 220)),
      curve: FrostyMotion.standard,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, reduceMotionOf(context) ? 0 : 6 * (1 - t)),
          child: child,
        ),
      ),
      child: Semantics(
        liveRegion: true,
        child: GestureDetector(
          onTap: onClose,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: dark ? FrostyTokens.raisedDark : colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.pillBorder,
                width: FrostyTokens.hairlineWidth,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 30,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Text(
              kReplayEmotesNote,
              style: TextStyle(
                fontFamily: FrostyTokens.bodyFamily,
                fontSize: 13,
                height: 1.45,
                color: colors.body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The replay loading: three message lines under the global sheen and
/// "Loading chat replay".
class ReplayLoading extends StatelessWidget {
  const ReplayLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final radius = BorderRadius.circular(6);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                SkeletonLoader(
                  width: width * 0.72,
                  height: 12,
                  borderRadius: radius,
                ),
                SkeletonLoader(
                  width: width * 0.54,
                  height: 12,
                  borderRadius: radius,
                ),
                SkeletonLoader(
                  width: width * 0.64,
                  height: 12,
                  borderRadius: radius,
                ),
                Text(
                  'Loading chat replay',
                  style: TextStyle(
                    fontFamily: FrostyTokens.bodyFamily,
                    fontSize: 12,
                    color: colors.tertiary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Resume scroll": back to the newest messages.
class ResumeScrollPill extends StatelessWidget {
  const ResumeScrollPill({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PressScale(
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          shape: StadiumBorder(),
          shadows: [
            BoxShadow(
              color: Color(0x73000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: _pill(colors, dark),
      ),
    );
  }

  Widget _pill(FeedColors colors, bool dark) {
    return Material(
      color: dark ? FrostyTokens.raisedDark : colors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: dark ? FrostyTokens.hairlineStrongDark : colors.pillBorder,
          width: FrostyTokens.hairlineWidth,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 40,
          padding: const EdgeInsetsDirectional.only(start: 12, end: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              VideoGlyph(
                VideoGlyphKind.arrowDown,
                color: colors.text,
                size: 16,
                strokeWidth: 2,
              ),
              Text(
                'Resume scroll',
                style: TextStyle(
                  fontFamily: FrostyTokens.bodyFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
