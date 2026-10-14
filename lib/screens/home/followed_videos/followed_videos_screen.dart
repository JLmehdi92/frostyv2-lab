import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/home/followed_videos/stores/followed_videos_store.dart';
import 'package:frosty/screens/vod/vod_screen.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/alert_message.dart';

/// The newest videos of the channels the viewer follows.
class FollowedVideosScreen extends StatefulWidget {
  const FollowedVideosScreen({super.key, required this.store});

  static const routeName = '/followed-videos';

  final FollowedVideosStore store;

  /// Opens the list for the logged-in viewer [userId].
  static Future<void> open(BuildContext context, {required String userId}) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: routeName),
          builder: (context) => FollowedVideosScreen(
            store: FollowedVideosStore(
              twitchApi: context.twitchApi,
              vodService: context.twitchVodService,
              userId: userId,
            ),
          ),
        ),
      );

  @override
  State<FollowedVideosScreen> createState() => _FollowedVideosScreenState();
}

class _FollowedVideosScreenState extends State<FollowedVideosScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.store.load());
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(title: const Text('Followed videos')),
      body: Observer(
        builder: (context) {
          final videos = store.videos;
          if (videos.isEmpty) {
            if (store.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AlertMessage(
                    message: store.error ?? 'No recent videos',
                    vertical: true,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: store.load,
                    child: Text(store.error == null ? 'Refresh' : 'Retry'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: store.load,
            child: ListView.builder(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 8,
              ),
              itemCount: videos.length + (store.error == null ? 0 : 1),
              itemBuilder: (context, index) {
                if (index == 0 && store.error != null) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: AlertMessage(message: store.error!),
                  );
                }
                final vod = videos[index - (store.error == null ? 0 : 1)];
                return VodCard(
                  vod: vod,
                  showChannel: true,
                  onTap: () => unawaited(
                    VodScreen.open(context, vodId: vod.id, vod: vod),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
