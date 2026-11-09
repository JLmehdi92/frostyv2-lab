enum ChatUiSetting {
  emoteAnimations(
    field: 'isEmoteAnimationsEnabled',
    operation: 'SyncedSettingsSetEmoteAnimations',
    mutation: 'setEmoteAnimationsEnabled',
    inputType: 'SetEmoteAnimationsEnabledInput',
  ),
  gifs(
    field: 'isGifsEnabled',
    operation: 'SyncedSettingsSetGifsEnabled',
    mutation: 'setGifsEnabled',
    inputType: 'SetGifsEnabledInput',
  ),
  gifAnimations(
    field: 'isGifAnimationsEnabled',
    operation: 'SyncedSettingsSetGifAnimationsEnabled',
    mutation: 'setGifAnimationsEnabled',
    inputType: 'SetGifAnimationsEnabledInput',
  ),
  readableColors(
    field: 'isReadableChatColorsEnabled',
    operation: 'SetReadableChatColorsPreference',
    mutation: 'setReadableChatColorsEnabled',
    inputType: 'SetReadableChatColorsEnabledInput',
  );

  const ChatUiSetting({
    required this.field,
    required this.operation,
    required this.mutation,
    required this.inputType,
  });

  final String field;
  final String operation;
  final String mutation;
  final String inputType;

  String get document =>
      'mutation $operation(\$input: $inputType!) { $mutation(input: '
      '\$input) { $field } }';
}

class ChatUiSettings {
  const ChatUiSettings(this.values);

  final Map<ChatUiSetting, bool> values;

  bool operator [](ChatUiSetting setting) => values[setting]!;

  static ChatUiSettings? fromSettings(Object? settings) {
    if (settings is! Map) return null;
    final values = <ChatUiSetting, bool>{};
    for (final setting in ChatUiSetting.values) {
      final value = settings[setting.field];
      if (value is! bool) return null;
      values[setting] = value;
    }
    return ChatUiSettings(Map.unmodifiable(values));
  }

  List<ChatUiSetting> differencesFrom(ChatUiSettings other) => [
    for (final setting in ChatUiSetting.values)
      if (this[setting] != other[setting]) setting,
  ];

  @override
  bool operator ==(Object other) =>
      other is ChatUiSettings && differencesFrom(other).isEmpty;

  @override
  int get hashCode =>
      Object.hashAll(ChatUiSetting.values.map((setting) => values[setting]));
}
