import 'package:onset/models/stream.dart';

sealed class StreamPush {
  const StreamPush();
}

class ViewerCountPush extends StreamPush {
  final int viewers;

  const ViewerCountPush(this.viewers);
}

class StreamUpPush extends StreamPush {
  const StreamUpPush();
}

class StreamDownPush extends StreamPush {
  const StreamDownPush();
}

class BroadcastSettingsPush extends StreamPush {
  final String? title;
  final String? gameName;
  final String? gameId;

  const BroadcastSettingsPush({this.title, this.gameName, this.gameId});
}

abstract interface class StreamPushTarget {
  void applyStreamPush(StreamPush push);
}

StreamPush? parseStreamPush(String type, Map<String, dynamic> data) {
  switch (type) {
    case 'viewcount':
      final viewers = data['viewers'];
      if (viewers is! num || viewers < 0) return null;
      return ViewerCountPush(viewers.toInt());
    case 'stream-up':
      return const StreamUpPush();
    case 'stream-down':
      return const StreamDownPush();
    case 'broadcast_settings_update':
      final title = _text(data['status']);
      final gameName = _text(data['game']);
      final gameId = _text(data['game_id']);
      if (title == null && gameName == null && gameId == null) return null;
      return BroadcastSettingsPush(
        title: title,
        gameName: gameName,
        gameId: gameId,
      );
  }
  return null;
}

String? _text(Object? value) => switch (value) {
  final String text when text.isNotEmpty => text,
  final num number => number.toString(),
  _ => null,
};

StreamTwitch? patchStream(StreamTwitch? stream, StreamPush push) {
  if (stream == null) return null;
  return switch (push) {
    ViewerCountPush(:final viewers) => _copy(stream, viewerCount: viewers),
    BroadcastSettingsPush(:final title, :final gameName, :final gameId) =>
      _copy(stream, title: title, gameName: gameName, gameId: gameId),
    StreamUpPush() || StreamDownPush() => stream,
  };
}

StreamTwitch _copy(
  StreamTwitch stream, {
  int? viewerCount,
  String? title,
  String? gameName,
  String? gameId,
}) => StreamTwitch(
  stream.userId,
  stream.userLogin,
  stream.userName,
  gameId ?? stream.gameId,
  gameName ?? stream.gameName,
  title ?? stream.title,
  viewerCount ?? stream.viewerCount,
  stream.startedAt,
  stream.thumbnailUrl,
  tags: stream.tags,
  language: stream.language,
  id: stream.id,
);
