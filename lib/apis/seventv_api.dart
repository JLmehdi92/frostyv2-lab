import 'package:dio/dio.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/third_party_cosmetics.dart';

/// The 7TV service for making API calls.
class SevenTVApi extends BaseApiClient {
  SevenTVApi(Dio dio) : super(dio, 'https://7tv.io/v3');

  /// Returns a map of global 7TV emotes to their URL.
  Future<List<Emote>> getEmotesGlobal() async {
    final data = await get<JsonMap>('/emote-sets/global');

    final decoded = data['emotes'] as JsonList;
    final emotes = decoded.map((emote) => Emote7TV.fromJson(emote));

    return emotes
        .map((emote) => Emote.from7TV(emote, EmoteType.sevenTVGlobal))
        .toList();
  }

  /// Returns a tuple containing the emote set ID and a map of a channel's 7TV
  /// emotes to their URL.
  Future<(String, List<Emote>)> getEmotesChannel({required String id}) async {
    final channel = await getChannel(id: id);
    return (channel.setId, channel.emotes);
  }

  Future<SevenTvChannel> getChannel({required String id}) async {
    final data = await get<JsonMap>('/users/twitch/$id');

    final emoteSetId = data['emote_set']['id'] as String;
    final user = data['user'];

    return SevenTvChannel(
      setId: emoteSetId,
      userId: user is Map ? user['id'] as String? : null,
      emotes: _activeEmotes(
        data['emote_set']['emotes'] as JsonList,
        EmoteType.sevenTVChannel,
      ),
    );
  }

  Future<List<Emote>> getEmoteSet({
    required String id,
    required EmoteType type,
  }) async {
    final data = await get<JsonMap>('/emote-sets/${Uri.encodeComponent(id)}');
    return _activeEmotes((data['emotes'] as JsonList?) ?? const [], type);
  }

  Future<Map<String, SevenTvUserCosmetics>> getUsersCosmetics(
    List<String> twitchIds,
  ) async {
    final ids = [
      for (final id in twitchIds.toSet())
        if (RegExp(r'^[0-9]{1,20}$').hasMatch(id)) id,
    ];
    if (ids.isEmpty) return const {};
    final lookups = [
      for (final (index, id) in ids.indexed)
        'u$index: userByConnection(platform: TWITCH, platformId: "$id") '
            '{ ...Cosmetics }',
    ].join(' ');
    final data = await post<JsonMap>(
      'https://7tv.io/v4/gql',
      data: {'query': 'query { users { $lookups } } $_cosmeticsFragment'},
    );
    final users = data['data'] is Map ? data['data']['users'] : null;
    if (users is! Map) {
      throw const FormatException('7TV cosmetics answer without users');
    }
    return {
      for (final (index, id) in ids.indexed)
        id: SevenTvUserCosmetics.fromGql(
          users['u$index'] is Map
              ? Map<String, dynamic>.from(users['u$index'] as Map)
              : null,
        ),
    };
  }

  static List<Emote> _activeEmotes(JsonList emotes, EmoteType type) => emotes
      .map((emote) => Emote.from7TV(Emote7TV.fromJson(emote), type))
      .where((emote) => emote.url.isNotEmpty)
      .toList();

  static final _imageFields = [
    'url',
    'mime',
    'scale',
    'width',
    'height',
    'frameCount',
  ].join(' ');

  static final _cosmeticsFragment =
      'fragment Cosmetics on User { '
      'style { '
      'activePaint { id name data { '
      'layers { opacity ty { __typename '
      '... on PaintLayerTypeSingleColor { color { hex } } '
      '... on PaintLayerTypeLinearGradient { angle repeating '
      'stops { at color { hex } } } '
      '... on PaintLayerTypeRadialGradient { repeating '
      'stops { at color { hex } } } '
      '... on PaintLayerTypeImage { images { $_imageFields } } } } '
      'shadows { color { hex } offsetX offsetY blur } } } '
      'activeBadge { id name description images { $_imageFields } } } '
      'personalEmoteSet { id emotes { items { alias flags { zeroWidth } '
      'emote { id defaultName flags { defaultZeroWidth } '
      'images { $_imageFields } } } } } }';
}

class SevenTvChannel {
  final String setId;
  final String? userId;
  final List<Emote> emotes;

  const SevenTvChannel({
    required this.setId,
    required this.userId,
    required this.emotes,
  });
}
