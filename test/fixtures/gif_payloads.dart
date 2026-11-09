Map<String, Object?> gifPickerConfigResponse({
  bool enabled = true,
  bool allowlisted = true,
  String apiKey = 'abcDEF123456',
  String contentRating = 'PG_13',
}) => {
  'data': {
    'gifPickerConfig': {
      'isEnabled': enabled,
      'isAllowlisted': allowlisted,
      'apiKey': apiKey,
      'contentRating': contentRating,
    },
  },
};

Map<String, Object?> sendGifResponse({
  Object? error,
  num? secondsUntilCanSend,
  String? messageId = 'm1',
}) => {
  'data': {
    'sendGifMessage': {
      'error': error,
      'secondsUntilCanSend': secondsUntilCanSend,
      'message': messageId == null ? null : {'id': messageId},
    },
  },
};

Map<String, Object?> giphyGif(String id, {String title = 'Wave'}) => {
  'type': 'gif',
  'id': id,
  'title': title,
  'images': {
    'original': {
      'url': 'https://media1.giphy.com/media/$id/giphy.gif',
      'width': '480',
      'height': '270',
    },
    'fixed_height': {
      'url': 'https://media1.giphy.com/media/$id/200.gif',
      'width': '356',
      'height': '200',
    },
  },
};

Map<String, Object?> giphyResponse(List<Map<String, Object?>> gifs) => {
  'data': gifs,
  'pagination': {'total_count': gifs.length, 'count': gifs.length},
  'meta': {'status': 200, 'msg': 'OK'},
};
