Map<String, Object?> chatUiSettingsResponse({
  bool readableColors = true,
  bool emoteAnimations = true,
  bool gifs = true,
  bool gifAnimations = false,
}) => {
  'data': {
    'currentUser': {
      'id': '77',
      'chatUISettings': {
        'isReadableChatColorsEnabled': readableColors,
        'isEmoteAnimationsEnabled': emoteAnimations,
        'isGifsEnabled': gifs,
        'isGifAnimationsEnabled': gifAnimations,
      },
    },
  },
};

Map<String, Object?> setChatUiSettingResponse(String mutation, Object? value) =>
    {
      'data': {
        mutation: {
          'isEmoteAnimationsEnabled': value,
          'isGifsEnabled': value,
          'isGifAnimationsEnabled': value,
          'isReadableChatColorsEnabled': value,
        },
      },
    };
