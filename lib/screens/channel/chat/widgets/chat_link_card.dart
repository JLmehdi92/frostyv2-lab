import 'package:flutter/material.dart';
import 'package:frosty/apis/twitch_clip_service.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/screens/vod/vod_time.dart';
import 'package:frosty/utils/link_router.dart';
import 'package:frosty/utils/twitch_links.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/skeleton_loader.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// The first clip or video link of a chat message, with the text it was
/// written as; null when there is none.
({TwitchLink link, String url})? chatPreviewLink(String? message) {
  if (message == null || !message.contains('twitch.tv')) return null;
  for (final word in message.split(' ').take(50)) {
    if (!word.contains('twitch.tv/')) continue;
    final link = TwitchLink.parseText(word);
    if (link is ClipLink || link is VodLink) return (link: link, url: word);
  }
  return null;
}

/// What a preview card shows.
class ChatLinkPreview {
  const ChatLinkPreview({
    required this.title,
    required this.channel,
    required this.detail,
    this.thumbnailUrl,
  });

  final String title;
  final String channel;
  final String detail;
  final String? thumbnailUrl;
}

/// [url] when it is an https image on a Twitch host, or null.
String? _twitchImage(String? url) {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      !(uri.host.endsWith('.jtvnw.net') || uri.host.endsWith('.twitch.tv')) ||
      url!.contains('404_processing')) {
    return null;
  }
  return url;
}

String _views(int count) =>
    '${NumberFormat.compact().format(count)} ${count == 1 ? 'view' : 'views'}';

/// Previews shared by every chat, newest kept: the same clip posted many
/// times is asked for once.
abstract final class ChatLinkPreviews {
  static const _size = 64;
  static final _cache = <TwitchLink, Future<ChatLinkPreview?>>{};

  /// The preview of [link], or null when it cannot be read (gone, refused,
  /// offline). Never throws.
  static Future<ChatLinkPreview?> load(
    TwitchLink link, {
    required TwitchClipService clips,
    required TwitchVodService vods,
  }) {
    final cached = _cache.remove(link);
    if (cached != null) return _cache[link] = cached;
    late final Future<ChatLinkPreview?> future;
    future = _fetch(link, clips, vods).catchError((Object e) {
      debugPrint('Chat link preview failed: $e');
      // Not kept: a later message may try again.
      if (identical(_cache[link], future)) _cache.remove(link);
      return null;
    });
    _cache[link] = future;
    while (_cache.length > _size) {
      _cache.remove(_cache.keys.first);
    }
    return future;
  }

  @visibleForTesting
  static void clear() => _cache.clear();

  static Future<ChatLinkPreview?> _fetch(
    TwitchLink link,
    TwitchClipService clips,
    TwitchVodService vods,
  ) async {
    switch (link) {
      case ClipLink(:final slug):
        final clip = await clips.getClip(slug);
        if (clip == null) return null;
        return ChatLinkPreview(
          title: clip.title.trim().isEmpty ? 'Untitled clip' : clip.title,
          channel: clip.broadcasterDisplayName,
          detail:
              'Clip · ${formatVodTime(clip.duration)} · '
              '${_views(clip.viewCount)}',
          thumbnailUrl: _twitchImage(clip.thumbnailUrl),
        );
      case VodLink(:final vodId):
        final vod = await vods.getVideo(vodId);
        if (vod == null) return null;
        return ChatLinkPreview(
          title: vod.title.trim().isEmpty ? 'Untitled' : vod.title,
          channel: vod.ownerDisplayName,
          detail:
              'Video · ${formatVodTime(vod.duration)} · '
              '${_views(vod.viewCount)}',
          thumbnailUrl: _twitchImage(vod.previewThumbnailUrl),
        );
      default:
        return null;
    }
  }
}

/// A clip or video posted in chat: thumbnail, title, channel, length and
/// views. Its height is fixed so the chat does not jump when it loads.
class ChatLinkCard extends StatefulWidget {
  const ChatLinkCard({super.key, required this.link, required this.url});

  final TwitchLink link;
  final String url;

  static const height = 64.0;

  @override
  State<ChatLinkCard> createState() => _ChatLinkCardState();
}

class _ChatLinkCardState extends State<ChatLinkCard> {
  late Future<ChatLinkPreview?> _preview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ChatLinkCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link != widget.link) _load();
  }

  void _load() => _preview = ChatLinkPreviews.load(
    widget.link,
    clips: context.read<TwitchClipService>(),
    vods: context.read<TwitchVodService>(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: SizedBox(
        height: ChatLinkCard.height,
        child: FutureBuilder<ChatLinkPreview?>(
          future: _preview,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SkeletonLoader(borderRadius: kCardBorderRadius);
            }
            final preview = snapshot.data;
            if (preview == null) return const SizedBox.shrink();
            return Material(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: kCardBorderRadius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => LinkRouter.open(widget.url, launchExternal: false),
                child: Row(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: preview.thumbnailUrl == null
                          ? ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                widget.link is ClipLink
                                    ? Icons.movie_outlined
                                    : Icons.video_library_outlined,
                              ),
                            )
                          : FrostyCachedNetworkImage(
                              imageUrl: preview.thumbnailUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 240,
                            ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              preview.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              preview.channel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              preview.detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
