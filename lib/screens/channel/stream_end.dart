import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/vod.dart';

const _broadcastStartSlack = Duration(minutes: 10);

class StreamEndLookup {
  const StreamEndLookup({required this.api, required this.vods});

  final TwitchApi api;
  final TwitchVodService vods;

  Future<bool?> isLive(String login) async {
    try {
      await api.getStream(userLogin: login);
      return true;
    } on ApiException catch (e) {
      return e.statusCode == 404 ? false : null;
    } catch (e) {
      debugPrint('Stream end: live check failed: ${e.runtimeType}');
      return null;
    }
  }

  Future<Vod?> latestBroadcast(String login) async {
    try {
      final page = await vods.getChannelVideos(
        login: login,
        type: VodType.archive,
      );
      Vod? latest;
      for (final vod in page.items) {
        if (latest == null || vod.createdAt.isAfter(latest.createdAt)) {
          latest = vod;
        }
      }
      return latest;
    } catch (e) {
      debugPrint('Stream end: no latest broadcast: ${e.runtimeType}');
      return null;
    }
  }

  Future<Vod?> latestBroadcastIfOffline(String login) async {
    if (await isLive(login) != false) return null;
    return latestBroadcast(login);
  }
}

bool isVodOfBroadcast(Vod vod, StreamTwitch stream) {
  final broadcastId = vod.broadcastId;
  if (broadcastId != null && stream.id.isNotEmpty) {
    return broadcastId == stream.id;
  }
  final started = DateTime.tryParse(stream.startedAt);
  if (started == null || vod.type != VodType.archive) return false;
  return !vod.createdAt.isBefore(started.subtract(_broadcastStartSlack));
}
