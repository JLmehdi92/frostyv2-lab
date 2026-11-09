class GifPickerConfig {
  const GifPickerConfig({
    required this.enabled,
    required this.allowlisted,
    required this.apiKey,
    required this.rating,
  });

  final bool enabled;
  final bool allowlisted;
  final String apiKey;
  final String rating;

  bool get canSend => enabled && allowlisted && apiKey.isNotEmpty;

  static final _apiKey = RegExp(r'^[A-Za-z0-9]{8,64}$');

  static GifPickerConfig? fromConfig(Object? config) {
    if (config is! Map) return null;
    final enabled = config['isEnabled'];
    final allowlisted = config['isAllowlisted'];
    if (enabled is! bool || allowlisted is! bool) return null;
    final apiKey = config['apiKey'];
    return GifPickerConfig(
      enabled: enabled,
      allowlisted: allowlisted,
      apiKey: apiKey is String && _apiKey.hasMatch(apiKey) ? apiKey : '',
      rating: giphyRating(config['contentRating']),
    );
  }

  static String giphyRating(Object? contentRating) =>
      contentRating is String && contentRating.trim().toUpperCase() == 'PG_13'
      ? 'pg-13'
      : 'pg';
}

class GiphyGif {
  const GiphyGif({
    required this.id,
    required this.title,
    required this.url,
    required this.previewUrl,
    required this.width,
    required this.height,
  });

  final String id;
  final String title;
  final String url;
  final String previewUrl;
  final int width;
  final int height;

  static final _id = RegExp(r'^[A-Za-z0-9]{1,64}$');

  static GiphyGif? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final images = json['images'];
    if (id is! String || !_id.hasMatch(id) || images is! Map) return null;
    final original = images['original'];
    final fixed = images['fixed_height'];
    if (original is! Map || fixed is! Map) return null;
    final url = _giphyUrl(original['url']);
    final preview = _giphyUrl(fixed['url']);
    final width = int.tryParse('${fixed['width']}');
    final height = int.tryParse('${fixed['height']}');
    if (url == null || preview == null || width == null || height == null) {
      return null;
    }
    if (width <= 0 || height <= 0) return null;
    final title = json['title'];
    return GiphyGif(
      id: id,
      title: title is String ? title : '',
      url: url,
      previewUrl: preview,
      width: width,
      height: height,
    );
  }

  static String? _giphyUrl(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https') return null;
    final host = uri.host;
    return host == 'giphy.com' || host.endsWith('.giphy.com') ? value : null;
  }
}

enum GifSendStatus {
  sent,
  cooldown,
  refused,
  integrityRefused,
  signedOut,
  failed,
}

class GifSendResult {
  const GifSendResult(this.status, {this.secondsUntilCanSend = 0});

  final GifSendStatus status;
  final int secondsUntilCanSend;

  static GifSendResult fromBody(Object? body) {
    if (body is! Map) return const GifSendResult(GifSendStatus.failed);
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final text = errors
          .map((e) => e is Map ? '${e['message']}' : '$e')
          .join(' ')
          .toLowerCase();
      return GifSendResult(
        text.contains('integrity')
            ? GifSendStatus.integrityRefused
            : GifSendStatus.failed,
      );
    }
    final data = body['data'];
    final payload = data is Map ? data['sendGifMessage'] : null;
    if (payload is! Map) return const GifSendResult(GifSendStatus.failed);
    final wait = payload['secondsUntilCanSend'];
    final seconds = wait is num && wait > 0 ? wait.ceil() : 0;
    final error = payload['error'];
    if (error != null) {
      return seconds > 0
          ? GifSendResult(GifSendStatus.cooldown, secondsUntilCanSend: seconds)
          : const GifSendResult(GifSendStatus.refused);
    }
    final message = payload['message'];
    return message is Map && message['id'] is String
        ? const GifSendResult(GifSendStatus.sent)
        : const GifSendResult(GifSendStatus.failed);
  }
}
