import 'package:flutter/material.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/home/top/categories/category_streams.dart';
import 'package:frosty/screens/vod/vod_time.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:intl/intl.dart';

/// Title and details of a VOD under the player (portrait).
class VodInfoStrip extends StatelessWidget {
  const VodInfoStrip({super.key, required this.vod});

  final Vod vod;

  @override
  Widget build(BuildContext context) {
    final muted = context.colorScheme.onSurfaceVariant;
    final details = [
      formatTimeAgo(vod.createdAt),
      '${NumberFormat().format(vod.viewCount)} '
          '${vod.viewCount == 1 ? 'view' : 'views'}',
    ].join(' · ');
    final gameId = vod.gameId;
    final gameName = vod.gameName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            vod.title.isEmpty ? 'Untitled broadcast' : vod.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              if (vod.isRecording)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.colorScheme.error,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    child: Text(
                      'Recording',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Text(details, style: TextStyle(color: muted, fontSize: 13)),
              if (gameId != null && gameName != null)
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(
                        name: CategoryStreams.routeName,
                      ),
                      builder: (context) => CategoryStreams(categoryId: gameId),
                    ),
                  ),
                  child: Text(
                    gameName,
                    style: TextStyle(
                      color: context.colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
