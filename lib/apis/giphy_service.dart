import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/models/gif_picker.dart';

class GiphyService extends BaseApiClient {
  GiphyService(Dio dio) : super(dio, 'https://api.giphy.com/v1/gifs');

  static const pageSize = 24;
  static const maxQueryLength = 50;

  Future<List<GiphyGif>?> search({
    required GifPickerConfig config,
    required String query,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return trending(config: config);
    return _gifs('/search', config, {
      'q': trimmed.length > maxQueryLength
          ? trimmed.substring(0, maxQueryLength)
          : trimmed,
    });
  }

  Future<List<GiphyGif>?> trending({required GifPickerConfig config}) =>
      _gifs('/trending', config, const {});

  Future<List<GiphyGif>?> _gifs(
    String path,
    GifPickerConfig config,
    Map<String, String> extra,
  ) async {
    if (!config.canSend) return null;
    try {
      final body = await get<dynamic>(
        path,
        queryParameters: {
          'api_key': config.apiKey,
          'limit': pageSize,
          'offset': 0,
          'rating': config.rating,
          ...extra,
        },
      );
      final data = body is Map ? body['data'] : null;
      if (data is! List) return null;
      return List.unmodifiable(data.map(GiphyGif.fromJson).nonNulls);
    } catch (e) {
      if (kDebugMode) debugPrint('GIPHY $path failed: $e');
      return null;
    }
  }
}
