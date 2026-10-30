import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/home/stream_list/stream_sort_button.dart';
import 'package:onset/screens/home/stream_list/streams_list.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/settled_blur.dart';

/// The live streams with a tag, in any of Twitch's orders (board Categorie,
/// "tag" state): a glass header with the tag and the order over the list,
/// the tag lit on every card.
class TagStreams extends StatefulWidget {
  static const routeName = 'TagStreams';

  const TagStreams({super.key, required this.tag});

  final String tag;

  /// The header's title row and order row (board: 56 + 48, a hairline).
  static const headerHeight = 56.0 + 48.0 + OnsetTokens.hairlineWidth;

  /// Opens the page of [tag], when it is a Twitch tag.
  static void open(BuildContext context, String tag) {
    if (!TwitchDirectoryService.tagPattern.hasMatch(tag)) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: routeName),
        builder: (context) => TagStreams(tag: tag),
      ),
    );
  }

  @override
  State<TagStreams> createState() => _TagStreamsState();
}

class _TagStreamsState extends State<TagStreams> {
  var _sort = StreamSort.viewersHigh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FeedColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    final gutter = context.isLargeScreen
        ? OnsetSpacing.gutterTablet
        : OnsetSpacing.gutterPhone;
    final ground = theme.scaffoldBackgroundColor;

    // No app bar to set the system bars: the theme's, as on every page.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          theme.appBarTheme.systemOverlayStyle ??
          (theme.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark),
      child: Scaffold(
        backgroundColor: ground,
        body: Stack(
          children: [
            Positioned.fill(
              child: StreamsList(
                listType: ListType.tag,
                tag: widget.tag,
                sort: _sort,
                showJumpButton: true,
                topInset: TagStreams.headerHeight + 4,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // The glass of the shell's header, once the page is in place
              // (the Live feed's preview can be under it while it moves).
              child: ClipRect(
                child: SettledBlur(
                  filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ground.withValues(alpha: 0.74),
                      border: Border(
                        bottom: BorderSide(
                          color: colors.hairline,
                          width: OnsetTokens.hairlineWidth,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: padding.top,
                        left: padding.left,
                        right: padding.right,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 56,
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: gutter - 12,
                                right: gutter,
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Back',
                                    constraints: const BoxConstraints.tightFor(
                                      width: 44,
                                      height: 44,
                                    ),
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.chevron_left_rounded,
                                      size: 26,
                                      color: colors.text,
                                    ),
                                    onPressed: () =>
                                        Navigator.maybePop(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.sell_outlined,
                                    size: 18,
                                    color: colors.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Semantics(
                                      header: true,
                                      child: Text(
                                        widget.tag,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: OnsetTokens.displayFamily,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.03 * 20,
                                          color: colors.text,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(gutter, 0, 8, 4),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: StreamSortButton(
                                sort: _sort,
                                onSort: (sort) => setState(() => _sort = sort),
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
          ],
        ),
      ),
    );
  }
}
