import 'package:flutter/material.dart';
import 'package:frosty/apis/twitch_directory_service.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/screens/home/stream_list/stream_list_store.dart';
import 'package:frosty/screens/home/stream_list/stream_sort_button.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/widgets/blurred_container.dart';

/// The live streams with a tag, in any of Twitch's orders.
class TagStreams extends StatefulWidget {
  static const routeName = 'TagStreams';

  const TagStreams({super.key, required this.tag});

  final String tag;

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
    final padding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: StreamsList(
              listType: ListType.tag,
              tag: widget.tag,
              sort: _sort,
              showJumpButton: true,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BlurredContainer(
              gradientDirection: GradientDirection.up,
              padding: EdgeInsets.only(
                top: padding.top,
                left: padding.left,
                right: padding.right,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: kToolbarHeight,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          icon: Icon(Icons.adaptive.arrow_back_rounded),
                          onPressed: Navigator.of(context).pop,
                        ),
                        const Icon(Icons.sell_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.tag,
                            style: theme.textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: kCategorySectionsHeight,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      children: [
                        StreamSortButton(
                          sort: _sort,
                          onSort: (sort) => setState(() => _sort = sort),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
