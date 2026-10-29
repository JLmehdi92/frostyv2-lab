import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/constants.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/services/telemetry.dart';
import 'package:onset/utils/link_router.dart';
import 'package:onset/utils/twitch_links.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/skeleton_loader.dart';
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

/// Previews shared by every chat.
///
/// A busy chat can post many links: the same link is asked for once at a
/// time, at most [_maxRunning] requests run together (the oldest waiting
/// one is dropped when too many wait), finished answers are kept for the
/// newest [_size] links, and an empty or failed answer is kept for
/// [_retryAfter] before it is asked for again.
abstract final class ChatLinkPreviews {
  static const _size = 64;
  static const _maxRunning = 3;
  static const _maxWaiting = 8;
  static const _retryAfter = Duration(seconds: 60);

  static final _known = <TwitchLink, _Known>{};
  static final _pending = <TwitchLink, Future<ChatLinkPreview?>>{};
  static final _waiting = <_Job>[];
  static var _running = 0;

  /// One entry per video, whatever its start time.
  static TwitchLink _key(TwitchLink link) =>
      link is VodLink ? VodLink(link.vodId) : link;

  /// The answer for [link] when there is a current one, without waiting:
  /// a card shown again (the chat moves every flush) draws at once.
  static ({ChatLinkPreview? preview})? peek(TwitchLink link) {
    final key = _key(link);
    final known = _known[key];
    if (known == null) return null;
    if (known.expiresAt != null && !clock.now().isBefore(known.expiresAt!)) {
      _known.remove(key);
      return null;
    }
    // Most recently used last.
    _known
      ..remove(key)
      ..[key] = known;
    return (preview: known.preview);
  }

  /// The preview of [link], or null when it cannot be read (gone, refused,
  /// offline, or dropped from a full queue). Never throws.
  static Future<ChatLinkPreview?> load(
    TwitchLink link, {
    required TwitchClipService clips,
    required TwitchVodService vods,
  }) {
    final known = peek(link);
    if (known != null) return Future.value(known.preview);
    final key = _key(link);
    final pending = _pending[key];
    if (pending != null) return pending;

    final job = _Job(key, clips, vods);
    final future = job.done.future;
    _pending[key] = future;
    _waiting.add(job);
    if (_waiting.length > _maxWaiting) {
      // Probably scrolled away already; asked for again if shown again.
      final dropped = _waiting.removeAt(0);
      _pending.remove(dropped.key);
      dropped.done.complete(null);
    }
    _next();
    return future;
  }

  @visibleForTesting
  static void clear() {
    _known.clear();
    _pending.clear();
    _waiting.clear();
    _running = 0;
  }

  static void _next() {
    while (_running < _maxRunning && _waiting.isNotEmpty) {
      final job = _waiting.removeAt(0);
      _running++;
      _run(job).whenComplete(() {
        _running--;
        _next();
      });
    }
  }

  static Future<void> _run(_Job job) async {
    ChatLinkPreview? preview;
    var failed = false;
    try {
      preview = await _fetch(job.key, job.clips, job.vods);
    } catch (e, stack) {
      failed = true;
      debugPrint('Chat link preview failed: $e');
      // An API refusal is expected now and then; anything else is a bug.
      if (e is! ApiException) {
        Telemetry.recordError(e, stack, reason: 'chat link preview');
      }
    }
    // A gone, failed or thumbnail-less answer may change soon (a new clip).
    final short = failed || preview == null || preview.thumbnailUrl == null;
    _known[job.key] = _Known(
      preview,
      short ? clock.now().add(_retryAfter) : null,
    );
    while (_known.length > _size) {
      _known.remove(_known.keys.first);
    }
    _pending.remove(job.key);
    job.done.complete(preview);
  }

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

class _Known {
  const _Known(this.preview, this.expiresAt);

  final ChatLinkPreview? preview;

  /// Null keeps it until newer links push it out.
  final DateTime? expiresAt;
}

class _Job {
  _Job(this.key, this.clips, this.vods);

  final TwitchLink key;
  final TwitchClipService clips;
  final TwitchVodService vods;
  final done = Completer<ChatLinkPreview?>();
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
  /// Set when the answer is already known: drawn without a loading frame.
  ({ChatLinkPreview? preview})? _known;
  Future<ChatLinkPreview?>? _preview;

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

  void _load() {
    _known = ChatLinkPreviews.peek(widget.link);
    _preview = _known != null
        ? null
        : ChatLinkPreviews.load(
            widget.link,
            clips: context.read<TwitchClipService>(),
            vods: context.read<TwitchVodService>(),
          );
  }

  @override
  Widget build(BuildContext context) {
    final known = _known;
    if (known != null) return _card(context, known.preview);
    return FutureBuilder<ChatLinkPreview?>(
      future: _preview,
      builder: (context, snapshot) => _card(
        context,
        snapshot.data,
        loading: snapshot.connectionState != ConnectionState.done,
      ),
    );
  }

  /// Nothing to show collapses the row (one jump, once).
  Widget _card(
    BuildContext context,
    ChatLinkPreview? preview, {
    bool loading = false,
  }) {
    if (!loading && preview == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: SizedBox(
        height: ChatLinkCard.height,
        child: Builder(
          builder: (context) {
            if (preview == null) {
              return const SkeletonLoader(borderRadius: kCardBorderRadius);
            }
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
                          : OnsetCachedNetworkImage(
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
