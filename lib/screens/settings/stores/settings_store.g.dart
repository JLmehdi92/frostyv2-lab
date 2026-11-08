// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_store.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SettingsStore _$SettingsStoreFromJson(
  Map<String, dynamic> json,
) => SettingsStore()
  ..themeType =
      $enumDecodeNullable(
        _$ThemeTypeEnumMap,
        json['themeType'],
        unknownValue: ThemeType.system,
      ) ??
      ThemeType.system
  ..accentColor = (json['accentColor'] as num?)?.toInt() ?? 4291362621
  ..showThumbnails = json['showThumbnails'] as bool? ?? true
  ..largeStreamCard = json['largeStreamCard'] as bool? ?? false
  ..startTab =
      $enumDecodeNullable(
        _$HomeTabEnumMap,
        HomeTab.readStored(json, 'startTab'),
        unknownValue: HomeTab.following,
      ) ??
      HomeTab.following
  ..followedSort =
      $enumDecodeNullable(
        _$FollowedSortEnumMap,
        json['followedSort'],
        unknownValue: FollowedSort.viewers,
      ) ??
      FollowedSort.viewers
  ..streamLanguage = json['streamLanguage'] as String? ?? ''
  ..hiddenContentLabels =
      (json['hiddenContentLabels'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      []
  ..confirmExternalLinks = json['confirmExternalLinks'] as bool? ?? true
  ..launchUrlExternal = json['launchUrlExternal'] as bool? ?? false
  ..mentionNotifications = json['mentionNotifications'] as bool? ?? true
  ..appLanguage =
      $enumDecodeNullable(
        _$AppLanguageEnumMap,
        json['appLanguage'],
        unknownValue: AppLanguage.system,
      ) ??
      AppLanguage.system
  ..languagePromptVersion =
      (json['languagePromptVersion'] as num?)?.toInt() ?? 0
  ..showVideo = json['showVideo'] as bool? ?? true
  ..warnMatureContent = json['warnMatureContent'] as bool? ?? true
  ..showCaptions = json['showCaptions'] as bool? ?? false
  ..captionSize =
      $enumDecodeNullable(
        _$CaptionSizeEnumMap,
        json['captionSize'],
        unknownValue: CaptionSize.medium,
      ) ??
      CaptionSize.medium
  ..captionBackground =
      $enumDecodeNullable(
        _$CaptionBackgroundEnumMap,
        json['captionBackground'],
        unknownValue: CaptionBackground.black,
      ) ??
      CaptionBackground.black
  ..captionLanguage = json['captionLanguage'] as String? ?? ''
  ..portraitVideoScale = (json['portraitVideoScale'] as num?)?.toDouble() ?? 1.0
  ..portraitChatHeight =
      $enumDecodeNullable(
        _$PortraitChatHeightEnumMap,
        readPortraitChatHeight(json, 'portraitChatHeight'),
        unknownValue: PortraitChatHeight.low,
      ) ??
      PortraitChatHeight.low
  ..defaultToHighestQuality = json['defaultToHighestQuality'] as bool? ?? false
  ..useTextureRendering = json['useTextureRendering'] as bool? ?? true
  ..keepScreenAwake = json['keepScreenAwake'] as bool? ?? true
  ..backgroundAudio = json['backgroundAudio'] as bool? ?? false
  ..autoPictureInPicture = json['autoPictureInPicture'] as bool? ?? true
  ..playerEngine =
      $enumDecodeNullable(
        _$PlayerEngineEnumMap,
        json['playerEngine'],
        unknownValue: PlayerEngine.ivs,
      ) ??
      PlayerEngine.ivs
  ..liveCatchUpMode =
      $enumDecodeNullable(
        _$LiveCatchUpModeEnumMap,
        json['liveCatchUpMode'],
        unknownValue: LiveCatchUpMode.speedUp,
      ) ??
      LiveCatchUpMode.speedUp
  ..bufferProfile =
      $enumDecodeNullable(
        _$BufferProfileEnumMap,
        json['bufferProfile'],
        unknownValue: BufferProfile.standard,
      ) ??
      BufferProfile.ultra
  ..autoLatency = json['autoLatency'] as bool? ?? true
  ..vodAutoplay =
      $enumDecodeNullable(
        _$VodAutoplayEnumMap,
        json['vodAutoplay'],
        unknownValue: VodAutoplay.always,
      ) ??
      VodAutoplay.always
  ..showOverlay = json['showOverlay'] as bool? ?? true
  ..toggleableOverlay = json['toggleableOverlay'] as bool? ?? false
  ..showLatency = json['showLatency'] as bool? ?? true
  ..badgeScale = (json['badgeScale'] as num?)?.toDouble() ?? 1.0
  ..emoteScale = (json['emoteScale'] as num?)?.toDouble() ?? 1.0
  ..messageScale = (json['messageScale'] as num?)?.toDouble() ?? 1.0
  ..messageSpacing = (json['messageSpacing'] as num?)?.toDouble() ?? 8.0
  ..fontSize = (json['fontSize'] as num?)?.toDouble() ?? 12.0
  ..showDeletedMessages = json['revealDeletedMessages'] as bool? ?? true
  ..animateEmotes = json['animateEmotes'] as bool? ?? true
  ..showGifs = json['showGifs'] as bool? ?? true
  ..animateGifs = json['animateGifs'] as bool? ?? true
  ..showLinkPreviews = json['showLinkPreviews'] as bool? ?? true
  ..showModerationNotices = json['showModerationNotices'] as bool? ?? true
  ..showChatMessageDividers = json['showChatMessageDividers'] as bool? ?? false
  ..timestampType =
      $enumDecodeNullable(
        _$TimestampTypeEnumMap,
        json['timestampType'],
        unknownValue: TimestampType.disabled,
      ) ??
      TimestampType.disabled
  ..readableNameColors = json['readableNameColors'] as bool? ?? true
  ..increaseChatContrast = json['increaseChatContrast'] as bool? ?? false
  ..autoSyncChatDelay = json['autoSyncChatDelay'] as bool? ?? true
  ..chatDelay = (json['chatDelay'] as num?)?.toDouble() ?? 0.0
  ..chatSyncDefaultApplied = json['chatSyncDefaultApplied'] as bool? ?? false
  ..highlightFirstTimeChatter =
      json['highlightFirstTimeChatter'] as bool? ?? true
  ..showUserNotices = json['showUserNotices'] as bool? ?? true
  ..collapseGiftBombs = json['collapseGiftBombs'] as bool? ?? true
  ..hideGiftSubNotices = json['hideGiftSubNotices'] as bool? ?? false
  ..hideGiftCount = json['hideGiftCount'] as bool? ?? false
  ..showHypeTrain = json['showHypeTrain'] as bool? ?? true
  ..showCommunityHighlights = json['showCommunityHighlights'] as bool? ?? true
  ..showCelebrations = json['showCelebrations'] as bool? ?? true
  ..celebrationsOnVideo =
      $enumDecodeNullable(
        _$CelebrationsOnVideoEnumMap,
        json['celebrationsOnVideo'],
        unknownValue: CelebrationsOnVideo.full,
      ) ??
      CelebrationsOnVideo.full
  ..emoteMenuButtonOnLeft = json['emoteMenuButtonOnLeft'] as bool? ?? false
  ..landscapeChatLeftSide = json['landscapeChatLeftSide'] as bool? ?? false
  ..landscapeForceVerticalChat =
      json['landscapeForceVerticalChat'] as bool? ?? false
  ..landscapeCutout =
      $enumDecodeNullable(
        _$LandscapeCutoutTypeEnumMap,
        json['landscapeCutout'],
      ) ??
      LandscapeCutoutType.none
  ..chatWidth = (json['chatWidth'] as num?)?.toDouble() ?? 0.2
  ..fullScreenChatOverlayOpacity =
      (json['fullScreenChatOverlayOpacity'] as num?)?.toDouble() ?? 0.5
  ..tapToCloseOverlayChat = json['tapToCloseOverlayChat'] as bool? ?? false
  ..showModActionsInChat = json['showModActionsInChat'] as bool? ?? true
  ..landscapeChatModes = landscapeChatModesFromJson(
    json['landscapeChatModes'] as List?,
  )
  ..autocomplete = json['autocomplete'] as bool? ?? true
  ..showTwitchEmotes = json['showTwitchEmotes'] as bool? ?? true
  ..showTwitchBadges = json['showTwitchBadges'] as bool? ?? true
  ..show7TVEmotes = json['show7TVEmotes'] as bool? ?? true
  ..showBTTVEmotes = json['showBTTVEmotes'] as bool? ?? true
  ..showBTTVBadges = json['showBTTVBadges'] as bool? ?? true
  ..showFFZEmotes = json['showFFZEmotes'] as bool? ?? true
  ..showFFZBadges = json['showFFZBadges'] as bool? ?? true
  ..showRecentMessages = json['showRecentMessages'] as bool? ?? false
  ..persistChatTabs = json['persistChatTabs'] as bool? ?? true
  ..secondaryTabs =
      (json['secondaryTabs'] as List<dynamic>?)
          ?.map((e) => PersistedChatTab.fromJson(e as Map<String, dynamic>))
          .toList() ??
      []
  ..mutedWords =
      (json['mutedWords'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      []
  ..matchWholeWord = json['matchWholeWord'] as bool? ?? true
  ..chatFiltersEnabled = json['chatFiltersEnabled'] as bool? ?? false
  ..chatFilterDiscrimination = json['chatFilterDiscrimination'] as bool? ?? true
  ..chatFilterSexual = json['chatFilterSexual'] as bool? ?? true
  ..chatFilterHarassment = json['chatFilterHarassment'] as bool? ?? true
  ..chatFilterProfanity = json['chatFilterProfanity'] as bool? ?? true
  ..shareCrashLogsAndAnalytics =
      json['shareCrashLogsAndAnalytics'] as bool? ?? false
  ..telemetryConsentVersion =
      (json['telemetryConsentVersion'] as num?)?.toInt() ?? 0
  ..fullScreen = json['fullScreen'] as bool? ?? false
  ..fullScreenChatOverlay = json['fullScreenChatOverlay'] as bool? ?? false
  ..pinnedChannelIds =
      (json['pinnedChannelIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      []
  ..animatedEmotesCalloutShown =
      json['animatedEmotesCalloutShown'] as bool? ?? false
  ..hiddenPinnedChatIds =
      (json['hiddenPinnedChatIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [];

Map<String, dynamic> _$SettingsStoreToJson(
  SettingsStore instance,
) => <String, dynamic>{
  'themeType': _$ThemeTypeEnumMap[instance.themeType]!,
  'accentColor': instance.accentColor,
  'showThumbnails': instance.showThumbnails,
  'largeStreamCard': instance.largeStreamCard,
  'startTab': _$HomeTabEnumMap[instance.startTab]!,
  'followedSort': _$FollowedSortEnumMap[instance.followedSort]!,
  'streamLanguage': instance.streamLanguage,
  'hiddenContentLabels': instance.hiddenContentLabels,
  'confirmExternalLinks': instance.confirmExternalLinks,
  'launchUrlExternal': instance.launchUrlExternal,
  'mentionNotifications': instance.mentionNotifications,
  'appLanguage': _$AppLanguageEnumMap[instance.appLanguage]!,
  'languagePromptVersion': instance.languagePromptVersion,
  'showVideo': instance.showVideo,
  'warnMatureContent': instance.warnMatureContent,
  'showCaptions': instance.showCaptions,
  'captionSize': _$CaptionSizeEnumMap[instance.captionSize]!,
  'captionBackground': _$CaptionBackgroundEnumMap[instance.captionBackground]!,
  'captionLanguage': instance.captionLanguage,
  'portraitVideoScale': instance.portraitVideoScale,
  'portraitChatHeight':
      _$PortraitChatHeightEnumMap[instance.portraitChatHeight]!,
  'defaultToHighestQuality': instance.defaultToHighestQuality,
  'useTextureRendering': instance.useTextureRendering,
  'keepScreenAwake': instance.keepScreenAwake,
  'backgroundAudio': instance.backgroundAudio,
  'autoPictureInPicture': instance.autoPictureInPicture,
  'playerEngine': _$PlayerEngineEnumMap[instance.playerEngine]!,
  'liveCatchUpMode': _$LiveCatchUpModeEnumMap[instance.liveCatchUpMode]!,
  'bufferProfile': _$BufferProfileEnumMap[instance.bufferProfile]!,
  'autoLatency': instance.autoLatency,
  'vodAutoplay': _$VodAutoplayEnumMap[instance.vodAutoplay]!,
  'showOverlay': instance.showOverlay,
  'toggleableOverlay': instance.toggleableOverlay,
  'showLatency': instance.showLatency,
  'badgeScale': instance.badgeScale,
  'emoteScale': instance.emoteScale,
  'messageScale': instance.messageScale,
  'messageSpacing': instance.messageSpacing,
  'fontSize': instance.fontSize,
  'revealDeletedMessages': instance.showDeletedMessages,
  'animateEmotes': instance.animateEmotes,
  'showGifs': instance.showGifs,
  'animateGifs': instance.animateGifs,
  'showLinkPreviews': instance.showLinkPreviews,
  'showModerationNotices': instance.showModerationNotices,
  'showChatMessageDividers': instance.showChatMessageDividers,
  'timestampType': _$TimestampTypeEnumMap[instance.timestampType]!,
  'readableNameColors': instance.readableNameColors,
  'increaseChatContrast': instance.increaseChatContrast,
  'autoSyncChatDelay': instance.autoSyncChatDelay,
  'chatDelay': instance.chatDelay,
  'chatSyncDefaultApplied': instance.chatSyncDefaultApplied,
  'highlightFirstTimeChatter': instance.highlightFirstTimeChatter,
  'showUserNotices': instance.showUserNotices,
  'collapseGiftBombs': instance.collapseGiftBombs,
  'hideGiftSubNotices': instance.hideGiftSubNotices,
  'hideGiftCount': instance.hideGiftCount,
  'showHypeTrain': instance.showHypeTrain,
  'showCommunityHighlights': instance.showCommunityHighlights,
  'showCelebrations': instance.showCelebrations,
  'celebrationsOnVideo':
      _$CelebrationsOnVideoEnumMap[instance.celebrationsOnVideo]!,
  'emoteMenuButtonOnLeft': instance.emoteMenuButtonOnLeft,
  'landscapeChatLeftSide': instance.landscapeChatLeftSide,
  'landscapeForceVerticalChat': instance.landscapeForceVerticalChat,
  'landscapeCutout': _$LandscapeCutoutTypeEnumMap[instance.landscapeCutout]!,
  'chatWidth': instance.chatWidth,
  'fullScreenChatOverlayOpacity': instance.fullScreenChatOverlayOpacity,
  'tapToCloseOverlayChat': instance.tapToCloseOverlayChat,
  'showModActionsInChat': instance.showModActionsInChat,
  'landscapeChatModes': instance.landscapeChatModes
      .map((e) => _$LandscapeChatModeEnumMap[e]!)
      .toList(),
  'autocomplete': instance.autocomplete,
  'showTwitchEmotes': instance.showTwitchEmotes,
  'showTwitchBadges': instance.showTwitchBadges,
  'show7TVEmotes': instance.show7TVEmotes,
  'showBTTVEmotes': instance.showBTTVEmotes,
  'showBTTVBadges': instance.showBTTVBadges,
  'showFFZEmotes': instance.showFFZEmotes,
  'showFFZBadges': instance.showFFZBadges,
  'showRecentMessages': instance.showRecentMessages,
  'persistChatTabs': instance.persistChatTabs,
  'secondaryTabs': instance.secondaryTabs,
  'mutedWords': instance.mutedWords,
  'matchWholeWord': instance.matchWholeWord,
  'chatFiltersEnabled': instance.chatFiltersEnabled,
  'chatFilterDiscrimination': instance.chatFilterDiscrimination,
  'chatFilterSexual': instance.chatFilterSexual,
  'chatFilterHarassment': instance.chatFilterHarassment,
  'chatFilterProfanity': instance.chatFilterProfanity,
  'shareCrashLogsAndAnalytics': instance.shareCrashLogsAndAnalytics,
  'telemetryConsentVersion': instance.telemetryConsentVersion,
  'fullScreen': instance.fullScreen,
  'fullScreenChatOverlay': instance.fullScreenChatOverlay,
  'pinnedChannelIds': instance.pinnedChannelIds,
  'animatedEmotesCalloutShown': instance.animatedEmotesCalloutShown,
  'hiddenPinnedChatIds': instance.hiddenPinnedChatIds,
};

const _$ThemeTypeEnumMap = {
  ThemeType.system: 'system',
  ThemeType.light: 'light',
  ThemeType.dark: 'dark',
};

const _$HomeTabEnumMap = {
  HomeTab.following: 'following',
  HomeTab.live: 'live',
  HomeTab.clips: 'clips',
  HomeTab.browse: 'browse',
};

const _$FollowedSortEnumMap = {
  FollowedSort.viewers: 'viewers',
  FollowedSort.recent: 'recent',
  FollowedSort.name: 'name',
  FollowedSort.category: 'category',
};

const _$AppLanguageEnumMap = {
  AppLanguage.system: 'system',
  AppLanguage.en: 'en',
  AppLanguage.fr: 'fr',
};

const _$CaptionSizeEnumMap = {
  CaptionSize.small: 'small',
  CaptionSize.medium: 'medium',
  CaptionSize.large: 'large',
  CaptionSize.extraLarge: 'extraLarge',
};

const _$CaptionBackgroundEnumMap = {
  CaptionBackground.black: 'black',
  CaptionBackground.translucent: 'translucent',
  CaptionBackground.none: 'none',
};

const _$PortraitChatHeightEnumMap = {
  PortraitChatHeight.low: 'low',
  PortraitChatHeight.medium: 'medium',
  PortraitChatHeight.high: 'high',
  PortraitChatHeight.custom: 'custom',
};

const _$PlayerEngineEnumMap = {
  PlayerEngine.ivs: 'ivs',
  PlayerEngine.nativeLowLatency: 'nativeLowLatency',
  PlayerEngine.twitchWeb: 'twitchWeb',
};

const _$LiveCatchUpModeEnumMap = {
  LiveCatchUpMode.speedUp: 'speedUp',
  LiveCatchUpMode.jumpToLive: 'jumpToLive',
};

const _$BufferProfileEnumMap = {
  BufferProfile.standard: 'standard',
  BufferProfile.ultra: 'ultra',
};

const _$VodAutoplayEnumMap = {
  VodAutoplay.always: 'always',
  VodAutoplay.wifiOnly: 'wifiOnly',
  VodAutoplay.never: 'never',
};

const _$TimestampTypeEnumMap = {
  TimestampType.disabled: 'disabled',
  TimestampType.twelve: 'twelve',
  TimestampType.twentyFour: 'twentyFour',
};

const _$CelebrationsOnVideoEnumMap = {
  CelebrationsOnVideo.full: 'full',
  CelebrationsOnVideo.subtle: 'subtle',
};

const _$LandscapeCutoutTypeEnumMap = {
  LandscapeCutoutType.none: 'none',
  LandscapeCutoutType.left: 'left',
  LandscapeCutoutType.right: 'right',
  LandscapeCutoutType.both: 'both',
};

const _$LandscapeChatModeEnumMap = {
  LandscapeChatMode.overlay: 'overlay',
  LandscapeChatMode.column: 'column',
  LandscapeChatMode.hidden: 'hidden',
};

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$SettingsStore on _SettingsStoreBase, Store {
  Computed<double?>? _$nameColorContrastComputed;

  @override
  double? get nameColorContrast =>
      (_$nameColorContrastComputed ??= Computed<double?>(
        () => super.nameColorContrast,
        name: '_SettingsStoreBase.nameColorContrast',
      )).value;
  Computed<double>? _$effectiveChatDelayComputed;

  @override
  double get effectiveChatDelay =>
      (_$effectiveChatDelayComputed ??= Computed<double>(
        () => super.effectiveChatDelay,
        name: '_SettingsStoreBase.effectiveChatDelay',
      )).value;
  Computed<List<LandscapeChatMode>>? _$switchableLandscapeChatModesComputed;

  @override
  List<LandscapeChatMode> get switchableLandscapeChatModes =>
      (_$switchableLandscapeChatModesComputed ??=
              Computed<List<LandscapeChatMode>>(
                () => super.switchableLandscapeChatModes,
                name: '_SettingsStoreBase.switchableLandscapeChatModes',
              ))
          .value;

  late final _$themeTypeAtom = Atom(
    name: '_SettingsStoreBase.themeType',
    context: context,
  );

  @override
  ThemeType get themeType {
    _$themeTypeAtom.reportRead();
    return super.themeType;
  }

  @override
  set themeType(ThemeType value) {
    _$themeTypeAtom.reportWrite(value, super.themeType, () {
      super.themeType = value;
    });
  }

  late final _$accentColorAtom = Atom(
    name: '_SettingsStoreBase.accentColor',
    context: context,
  );

  @override
  int get accentColor {
    _$accentColorAtom.reportRead();
    return super.accentColor;
  }

  @override
  set accentColor(int value) {
    _$accentColorAtom.reportWrite(value, super.accentColor, () {
      super.accentColor = value;
    });
  }

  late final _$showThumbnailsAtom = Atom(
    name: '_SettingsStoreBase.showThumbnails',
    context: context,
  );

  @override
  bool get showThumbnails {
    _$showThumbnailsAtom.reportRead();
    return super.showThumbnails;
  }

  @override
  set showThumbnails(bool value) {
    _$showThumbnailsAtom.reportWrite(value, super.showThumbnails, () {
      super.showThumbnails = value;
    });
  }

  late final _$largeStreamCardAtom = Atom(
    name: '_SettingsStoreBase.largeStreamCard',
    context: context,
  );

  @override
  bool get largeStreamCard {
    _$largeStreamCardAtom.reportRead();
    return super.largeStreamCard;
  }

  @override
  set largeStreamCard(bool value) {
    _$largeStreamCardAtom.reportWrite(value, super.largeStreamCard, () {
      super.largeStreamCard = value;
    });
  }

  late final _$startTabAtom = Atom(
    name: '_SettingsStoreBase.startTab',
    context: context,
  );

  @override
  HomeTab get startTab {
    _$startTabAtom.reportRead();
    return super.startTab;
  }

  @override
  set startTab(HomeTab value) {
    _$startTabAtom.reportWrite(value, super.startTab, () {
      super.startTab = value;
    });
  }

  late final _$followedSortAtom = Atom(
    name: '_SettingsStoreBase.followedSort',
    context: context,
  );

  @override
  FollowedSort get followedSort {
    _$followedSortAtom.reportRead();
    return super.followedSort;
  }

  @override
  set followedSort(FollowedSort value) {
    _$followedSortAtom.reportWrite(value, super.followedSort, () {
      super.followedSort = value;
    });
  }

  late final _$streamLanguageAtom = Atom(
    name: '_SettingsStoreBase.streamLanguage',
    context: context,
  );

  @override
  String get streamLanguage {
    _$streamLanguageAtom.reportRead();
    return super.streamLanguage;
  }

  @override
  set streamLanguage(String value) {
    _$streamLanguageAtom.reportWrite(value, super.streamLanguage, () {
      super.streamLanguage = value;
    });
  }

  late final _$hiddenContentLabelsAtom = Atom(
    name: '_SettingsStoreBase.hiddenContentLabels',
    context: context,
  );

  @override
  List<String> get hiddenContentLabels {
    _$hiddenContentLabelsAtom.reportRead();
    return super.hiddenContentLabels;
  }

  @override
  set hiddenContentLabels(List<String> value) {
    _$hiddenContentLabelsAtom.reportWrite(value, super.hiddenContentLabels, () {
      super.hiddenContentLabels = value;
    });
  }

  late final _$confirmExternalLinksAtom = Atom(
    name: '_SettingsStoreBase.confirmExternalLinks',
    context: context,
  );

  @override
  bool get confirmExternalLinks {
    _$confirmExternalLinksAtom.reportRead();
    return super.confirmExternalLinks;
  }

  @override
  set confirmExternalLinks(bool value) {
    _$confirmExternalLinksAtom.reportWrite(
      value,
      super.confirmExternalLinks,
      () {
        super.confirmExternalLinks = value;
      },
    );
  }

  late final _$launchUrlExternalAtom = Atom(
    name: '_SettingsStoreBase.launchUrlExternal',
    context: context,
  );

  @override
  bool get launchUrlExternal {
    _$launchUrlExternalAtom.reportRead();
    return super.launchUrlExternal;
  }

  @override
  set launchUrlExternal(bool value) {
    _$launchUrlExternalAtom.reportWrite(value, super.launchUrlExternal, () {
      super.launchUrlExternal = value;
    });
  }

  late final _$mentionNotificationsAtom = Atom(
    name: '_SettingsStoreBase.mentionNotifications',
    context: context,
  );

  @override
  bool get mentionNotifications {
    _$mentionNotificationsAtom.reportRead();
    return super.mentionNotifications;
  }

  @override
  set mentionNotifications(bool value) {
    _$mentionNotificationsAtom.reportWrite(
      value,
      super.mentionNotifications,
      () {
        super.mentionNotifications = value;
      },
    );
  }

  late final _$appLanguageAtom = Atom(
    name: '_SettingsStoreBase.appLanguage',
    context: context,
  );

  @override
  AppLanguage get appLanguage {
    _$appLanguageAtom.reportRead();
    return super.appLanguage;
  }

  @override
  set appLanguage(AppLanguage value) {
    _$appLanguageAtom.reportWrite(value, super.appLanguage, () {
      super.appLanguage = value;
    });
  }

  late final _$languagePromptVersionAtom = Atom(
    name: '_SettingsStoreBase.languagePromptVersion',
    context: context,
  );

  @override
  int get languagePromptVersion {
    _$languagePromptVersionAtom.reportRead();
    return super.languagePromptVersion;
  }

  @override
  set languagePromptVersion(int value) {
    _$languagePromptVersionAtom.reportWrite(
      value,
      super.languagePromptVersion,
      () {
        super.languagePromptVersion = value;
      },
    );
  }

  late final _$showVideoAtom = Atom(
    name: '_SettingsStoreBase.showVideo',
    context: context,
  );

  @override
  bool get showVideo {
    _$showVideoAtom.reportRead();
    return super.showVideo;
  }

  @override
  set showVideo(bool value) {
    _$showVideoAtom.reportWrite(value, super.showVideo, () {
      super.showVideo = value;
    });
  }

  late final _$warnMatureContentAtom = Atom(
    name: '_SettingsStoreBase.warnMatureContent',
    context: context,
  );

  @override
  bool get warnMatureContent {
    _$warnMatureContentAtom.reportRead();
    return super.warnMatureContent;
  }

  @override
  set warnMatureContent(bool value) {
    _$warnMatureContentAtom.reportWrite(value, super.warnMatureContent, () {
      super.warnMatureContent = value;
    });
  }

  late final _$showCaptionsAtom = Atom(
    name: '_SettingsStoreBase.showCaptions',
    context: context,
  );

  @override
  bool get showCaptions {
    _$showCaptionsAtom.reportRead();
    return super.showCaptions;
  }

  @override
  set showCaptions(bool value) {
    _$showCaptionsAtom.reportWrite(value, super.showCaptions, () {
      super.showCaptions = value;
    });
  }

  late final _$captionSizeAtom = Atom(
    name: '_SettingsStoreBase.captionSize',
    context: context,
  );

  @override
  CaptionSize get captionSize {
    _$captionSizeAtom.reportRead();
    return super.captionSize;
  }

  @override
  set captionSize(CaptionSize value) {
    _$captionSizeAtom.reportWrite(value, super.captionSize, () {
      super.captionSize = value;
    });
  }

  late final _$captionBackgroundAtom = Atom(
    name: '_SettingsStoreBase.captionBackground',
    context: context,
  );

  @override
  CaptionBackground get captionBackground {
    _$captionBackgroundAtom.reportRead();
    return super.captionBackground;
  }

  @override
  set captionBackground(CaptionBackground value) {
    _$captionBackgroundAtom.reportWrite(value, super.captionBackground, () {
      super.captionBackground = value;
    });
  }

  late final _$captionLanguageAtom = Atom(
    name: '_SettingsStoreBase.captionLanguage',
    context: context,
  );

  @override
  String get captionLanguage {
    _$captionLanguageAtom.reportRead();
    return super.captionLanguage;
  }

  @override
  set captionLanguage(String value) {
    _$captionLanguageAtom.reportWrite(value, super.captionLanguage, () {
      super.captionLanguage = value;
    });
  }

  late final _$portraitVideoScaleAtom = Atom(
    name: '_SettingsStoreBase.portraitVideoScale',
    context: context,
  );

  @override
  double get portraitVideoScale {
    _$portraitVideoScaleAtom.reportRead();
    return super.portraitVideoScale;
  }

  @override
  set portraitVideoScale(double value) {
    _$portraitVideoScaleAtom.reportWrite(value, super.portraitVideoScale, () {
      super.portraitVideoScale = value;
    });
  }

  late final _$portraitChatHeightAtom = Atom(
    name: '_SettingsStoreBase.portraitChatHeight',
    context: context,
  );

  @override
  PortraitChatHeight get portraitChatHeight {
    _$portraitChatHeightAtom.reportRead();
    return super.portraitChatHeight;
  }

  @override
  set portraitChatHeight(PortraitChatHeight value) {
    _$portraitChatHeightAtom.reportWrite(value, super.portraitChatHeight, () {
      super.portraitChatHeight = value;
    });
  }

  late final _$defaultToHighestQualityAtom = Atom(
    name: '_SettingsStoreBase.defaultToHighestQuality',
    context: context,
  );

  @override
  bool get defaultToHighestQuality {
    _$defaultToHighestQualityAtom.reportRead();
    return super.defaultToHighestQuality;
  }

  @override
  set defaultToHighestQuality(bool value) {
    _$defaultToHighestQualityAtom.reportWrite(
      value,
      super.defaultToHighestQuality,
      () {
        super.defaultToHighestQuality = value;
      },
    );
  }

  late final _$useTextureRenderingAtom = Atom(
    name: '_SettingsStoreBase.useTextureRendering',
    context: context,
  );

  @override
  bool get useTextureRendering {
    _$useTextureRenderingAtom.reportRead();
    return super.useTextureRendering;
  }

  @override
  set useTextureRendering(bool value) {
    _$useTextureRenderingAtom.reportWrite(value, super.useTextureRendering, () {
      super.useTextureRendering = value;
    });
  }

  late final _$keepScreenAwakeAtom = Atom(
    name: '_SettingsStoreBase.keepScreenAwake',
    context: context,
  );

  @override
  bool get keepScreenAwake {
    _$keepScreenAwakeAtom.reportRead();
    return super.keepScreenAwake;
  }

  @override
  set keepScreenAwake(bool value) {
    _$keepScreenAwakeAtom.reportWrite(value, super.keepScreenAwake, () {
      super.keepScreenAwake = value;
    });
  }

  late final _$backgroundAudioAtom = Atom(
    name: '_SettingsStoreBase.backgroundAudio',
    context: context,
  );

  @override
  bool get backgroundAudio {
    _$backgroundAudioAtom.reportRead();
    return super.backgroundAudio;
  }

  @override
  set backgroundAudio(bool value) {
    _$backgroundAudioAtom.reportWrite(value, super.backgroundAudio, () {
      super.backgroundAudio = value;
    });
  }

  late final _$autoPictureInPictureAtom = Atom(
    name: '_SettingsStoreBase.autoPictureInPicture',
    context: context,
  );

  @override
  bool get autoPictureInPicture {
    _$autoPictureInPictureAtom.reportRead();
    return super.autoPictureInPicture;
  }

  @override
  set autoPictureInPicture(bool value) {
    _$autoPictureInPictureAtom.reportWrite(
      value,
      super.autoPictureInPicture,
      () {
        super.autoPictureInPicture = value;
      },
    );
  }

  late final _$playerEngineAtom = Atom(
    name: '_SettingsStoreBase.playerEngine',
    context: context,
  );

  @override
  PlayerEngine get playerEngine {
    _$playerEngineAtom.reportRead();
    return super.playerEngine;
  }

  @override
  set playerEngine(PlayerEngine value) {
    _$playerEngineAtom.reportWrite(value, super.playerEngine, () {
      super.playerEngine = value;
    });
  }

  late final _$liveCatchUpModeAtom = Atom(
    name: '_SettingsStoreBase.liveCatchUpMode',
    context: context,
  );

  @override
  LiveCatchUpMode get liveCatchUpMode {
    _$liveCatchUpModeAtom.reportRead();
    return super.liveCatchUpMode;
  }

  @override
  set liveCatchUpMode(LiveCatchUpMode value) {
    _$liveCatchUpModeAtom.reportWrite(value, super.liveCatchUpMode, () {
      super.liveCatchUpMode = value;
    });
  }

  late final _$bufferProfileAtom = Atom(
    name: '_SettingsStoreBase.bufferProfile',
    context: context,
  );

  @override
  BufferProfile get bufferProfile {
    _$bufferProfileAtom.reportRead();
    return super.bufferProfile;
  }

  @override
  set bufferProfile(BufferProfile value) {
    _$bufferProfileAtom.reportWrite(value, super.bufferProfile, () {
      super.bufferProfile = value;
    });
  }

  late final _$autoLatencyAtom = Atom(
    name: '_SettingsStoreBase.autoLatency',
    context: context,
  );

  @override
  bool get autoLatency {
    _$autoLatencyAtom.reportRead();
    return super.autoLatency;
  }

  @override
  set autoLatency(bool value) {
    _$autoLatencyAtom.reportWrite(value, super.autoLatency, () {
      super.autoLatency = value;
    });
  }

  late final _$vodAutoplayAtom = Atom(
    name: '_SettingsStoreBase.vodAutoplay',
    context: context,
  );

  @override
  VodAutoplay get vodAutoplay {
    _$vodAutoplayAtom.reportRead();
    return super.vodAutoplay;
  }

  @override
  set vodAutoplay(VodAutoplay value) {
    _$vodAutoplayAtom.reportWrite(value, super.vodAutoplay, () {
      super.vodAutoplay = value;
    });
  }

  late final _$showOverlayAtom = Atom(
    name: '_SettingsStoreBase.showOverlay',
    context: context,
  );

  @override
  bool get showOverlay {
    _$showOverlayAtom.reportRead();
    return super.showOverlay;
  }

  @override
  set showOverlay(bool value) {
    _$showOverlayAtom.reportWrite(value, super.showOverlay, () {
      super.showOverlay = value;
    });
  }

  late final _$toggleableOverlayAtom = Atom(
    name: '_SettingsStoreBase.toggleableOverlay',
    context: context,
  );

  @override
  bool get toggleableOverlay {
    _$toggleableOverlayAtom.reportRead();
    return super.toggleableOverlay;
  }

  @override
  set toggleableOverlay(bool value) {
    _$toggleableOverlayAtom.reportWrite(value, super.toggleableOverlay, () {
      super.toggleableOverlay = value;
    });
  }

  late final _$showLatencyAtom = Atom(
    name: '_SettingsStoreBase.showLatency',
    context: context,
  );

  @override
  bool get showLatency {
    _$showLatencyAtom.reportRead();
    return super.showLatency;
  }

  @override
  set showLatency(bool value) {
    _$showLatencyAtom.reportWrite(value, super.showLatency, () {
      super.showLatency = value;
    });
  }

  late final _$badgeScaleAtom = Atom(
    name: '_SettingsStoreBase.badgeScale',
    context: context,
  );

  @override
  double get badgeScale {
    _$badgeScaleAtom.reportRead();
    return super.badgeScale;
  }

  @override
  set badgeScale(double value) {
    _$badgeScaleAtom.reportWrite(value, super.badgeScale, () {
      super.badgeScale = value;
    });
  }

  late final _$emoteScaleAtom = Atom(
    name: '_SettingsStoreBase.emoteScale',
    context: context,
  );

  @override
  double get emoteScale {
    _$emoteScaleAtom.reportRead();
    return super.emoteScale;
  }

  @override
  set emoteScale(double value) {
    _$emoteScaleAtom.reportWrite(value, super.emoteScale, () {
      super.emoteScale = value;
    });
  }

  late final _$messageScaleAtom = Atom(
    name: '_SettingsStoreBase.messageScale',
    context: context,
  );

  @override
  double get messageScale {
    _$messageScaleAtom.reportRead();
    return super.messageScale;
  }

  @override
  set messageScale(double value) {
    _$messageScaleAtom.reportWrite(value, super.messageScale, () {
      super.messageScale = value;
    });
  }

  late final _$messageSpacingAtom = Atom(
    name: '_SettingsStoreBase.messageSpacing',
    context: context,
  );

  @override
  double get messageSpacing {
    _$messageSpacingAtom.reportRead();
    return super.messageSpacing;
  }

  @override
  set messageSpacing(double value) {
    _$messageSpacingAtom.reportWrite(value, super.messageSpacing, () {
      super.messageSpacing = value;
    });
  }

  late final _$fontSizeAtom = Atom(
    name: '_SettingsStoreBase.fontSize',
    context: context,
  );

  @override
  double get fontSize {
    _$fontSizeAtom.reportRead();
    return super.fontSize;
  }

  @override
  set fontSize(double value) {
    _$fontSizeAtom.reportWrite(value, super.fontSize, () {
      super.fontSize = value;
    });
  }

  late final _$showDeletedMessagesAtom = Atom(
    name: '_SettingsStoreBase.showDeletedMessages',
    context: context,
  );

  @override
  bool get showDeletedMessages {
    _$showDeletedMessagesAtom.reportRead();
    return super.showDeletedMessages;
  }

  @override
  set showDeletedMessages(bool value) {
    _$showDeletedMessagesAtom.reportWrite(value, super.showDeletedMessages, () {
      super.showDeletedMessages = value;
    });
  }

  late final _$animateEmotesAtom = Atom(
    name: '_SettingsStoreBase.animateEmotes',
    context: context,
  );

  @override
  bool get animateEmotes {
    _$animateEmotesAtom.reportRead();
    return super.animateEmotes;
  }

  @override
  set animateEmotes(bool value) {
    _$animateEmotesAtom.reportWrite(value, super.animateEmotes, () {
      super.animateEmotes = value;
    });
  }

  late final _$showGifsAtom = Atom(
    name: '_SettingsStoreBase.showGifs',
    context: context,
  );

  @override
  bool get showGifs {
    _$showGifsAtom.reportRead();
    return super.showGifs;
  }

  @override
  set showGifs(bool value) {
    _$showGifsAtom.reportWrite(value, super.showGifs, () {
      super.showGifs = value;
    });
  }

  late final _$animateGifsAtom = Atom(
    name: '_SettingsStoreBase.animateGifs',
    context: context,
  );

  @override
  bool get animateGifs {
    _$animateGifsAtom.reportRead();
    return super.animateGifs;
  }

  @override
  set animateGifs(bool value) {
    _$animateGifsAtom.reportWrite(value, super.animateGifs, () {
      super.animateGifs = value;
    });
  }

  late final _$showLinkPreviewsAtom = Atom(
    name: '_SettingsStoreBase.showLinkPreviews',
    context: context,
  );

  @override
  bool get showLinkPreviews {
    _$showLinkPreviewsAtom.reportRead();
    return super.showLinkPreviews;
  }

  @override
  set showLinkPreviews(bool value) {
    _$showLinkPreviewsAtom.reportWrite(value, super.showLinkPreviews, () {
      super.showLinkPreviews = value;
    });
  }

  late final _$showModerationNoticesAtom = Atom(
    name: '_SettingsStoreBase.showModerationNotices',
    context: context,
  );

  @override
  bool get showModerationNotices {
    _$showModerationNoticesAtom.reportRead();
    return super.showModerationNotices;
  }

  @override
  set showModerationNotices(bool value) {
    _$showModerationNoticesAtom.reportWrite(
      value,
      super.showModerationNotices,
      () {
        super.showModerationNotices = value;
      },
    );
  }

  late final _$showChatMessageDividersAtom = Atom(
    name: '_SettingsStoreBase.showChatMessageDividers',
    context: context,
  );

  @override
  bool get showChatMessageDividers {
    _$showChatMessageDividersAtom.reportRead();
    return super.showChatMessageDividers;
  }

  @override
  set showChatMessageDividers(bool value) {
    _$showChatMessageDividersAtom.reportWrite(
      value,
      super.showChatMessageDividers,
      () {
        super.showChatMessageDividers = value;
      },
    );
  }

  late final _$timestampTypeAtom = Atom(
    name: '_SettingsStoreBase.timestampType',
    context: context,
  );

  @override
  TimestampType get timestampType {
    _$timestampTypeAtom.reportRead();
    return super.timestampType;
  }

  @override
  set timestampType(TimestampType value) {
    _$timestampTypeAtom.reportWrite(value, super.timestampType, () {
      super.timestampType = value;
    });
  }

  late final _$readableNameColorsAtom = Atom(
    name: '_SettingsStoreBase.readableNameColors',
    context: context,
  );

  @override
  bool get readableNameColors {
    _$readableNameColorsAtom.reportRead();
    return super.readableNameColors;
  }

  @override
  set readableNameColors(bool value) {
    _$readableNameColorsAtom.reportWrite(value, super.readableNameColors, () {
      super.readableNameColors = value;
    });
  }

  late final _$increaseChatContrastAtom = Atom(
    name: '_SettingsStoreBase.increaseChatContrast',
    context: context,
  );

  @override
  bool get increaseChatContrast {
    _$increaseChatContrastAtom.reportRead();
    return super.increaseChatContrast;
  }

  @override
  set increaseChatContrast(bool value) {
    _$increaseChatContrastAtom.reportWrite(
      value,
      super.increaseChatContrast,
      () {
        super.increaseChatContrast = value;
      },
    );
  }

  late final _$autoSyncChatDelayAtom = Atom(
    name: '_SettingsStoreBase.autoSyncChatDelay',
    context: context,
  );

  @override
  bool get autoSyncChatDelay {
    _$autoSyncChatDelayAtom.reportRead();
    return super.autoSyncChatDelay;
  }

  @override
  set autoSyncChatDelay(bool value) {
    _$autoSyncChatDelayAtom.reportWrite(value, super.autoSyncChatDelay, () {
      super.autoSyncChatDelay = value;
    });
  }

  late final _$chatDelayAtom = Atom(
    name: '_SettingsStoreBase.chatDelay',
    context: context,
  );

  @override
  double get chatDelay {
    _$chatDelayAtom.reportRead();
    return super.chatDelay;
  }

  @override
  set chatDelay(double value) {
    _$chatDelayAtom.reportWrite(value, super.chatDelay, () {
      super.chatDelay = value;
    });
  }

  late final _$syncedChatDelayAtom = Atom(
    name: '_SettingsStoreBase.syncedChatDelay',
    context: context,
  );

  @override
  double get syncedChatDelay {
    _$syncedChatDelayAtom.reportRead();
    return super.syncedChatDelay;
  }

  @override
  set syncedChatDelay(double value) {
    _$syncedChatDelayAtom.reportWrite(value, super.syncedChatDelay, () {
      super.syncedChatDelay = value;
    });
  }

  late final _$highlightFirstTimeChatterAtom = Atom(
    name: '_SettingsStoreBase.highlightFirstTimeChatter',
    context: context,
  );

  @override
  bool get highlightFirstTimeChatter {
    _$highlightFirstTimeChatterAtom.reportRead();
    return super.highlightFirstTimeChatter;
  }

  @override
  set highlightFirstTimeChatter(bool value) {
    _$highlightFirstTimeChatterAtom.reportWrite(
      value,
      super.highlightFirstTimeChatter,
      () {
        super.highlightFirstTimeChatter = value;
      },
    );
  }

  late final _$showUserNoticesAtom = Atom(
    name: '_SettingsStoreBase.showUserNotices',
    context: context,
  );

  @override
  bool get showUserNotices {
    _$showUserNoticesAtom.reportRead();
    return super.showUserNotices;
  }

  @override
  set showUserNotices(bool value) {
    _$showUserNoticesAtom.reportWrite(value, super.showUserNotices, () {
      super.showUserNotices = value;
    });
  }

  late final _$collapseGiftBombsAtom = Atom(
    name: '_SettingsStoreBase.collapseGiftBombs',
    context: context,
  );

  @override
  bool get collapseGiftBombs {
    _$collapseGiftBombsAtom.reportRead();
    return super.collapseGiftBombs;
  }

  @override
  set collapseGiftBombs(bool value) {
    _$collapseGiftBombsAtom.reportWrite(value, super.collapseGiftBombs, () {
      super.collapseGiftBombs = value;
    });
  }

  late final _$hideGiftSubNoticesAtom = Atom(
    name: '_SettingsStoreBase.hideGiftSubNotices',
    context: context,
  );

  @override
  bool get hideGiftSubNotices {
    _$hideGiftSubNoticesAtom.reportRead();
    return super.hideGiftSubNotices;
  }

  @override
  set hideGiftSubNotices(bool value) {
    _$hideGiftSubNoticesAtom.reportWrite(value, super.hideGiftSubNotices, () {
      super.hideGiftSubNotices = value;
    });
  }

  late final _$hideGiftCountAtom = Atom(
    name: '_SettingsStoreBase.hideGiftCount',
    context: context,
  );

  @override
  bool get hideGiftCount {
    _$hideGiftCountAtom.reportRead();
    return super.hideGiftCount;
  }

  @override
  set hideGiftCount(bool value) {
    _$hideGiftCountAtom.reportWrite(value, super.hideGiftCount, () {
      super.hideGiftCount = value;
    });
  }

  late final _$showHypeTrainAtom = Atom(
    name: '_SettingsStoreBase.showHypeTrain',
    context: context,
  );

  @override
  bool get showHypeTrain {
    _$showHypeTrainAtom.reportRead();
    return super.showHypeTrain;
  }

  @override
  set showHypeTrain(bool value) {
    _$showHypeTrainAtom.reportWrite(value, super.showHypeTrain, () {
      super.showHypeTrain = value;
    });
  }

  late final _$showCommunityHighlightsAtom = Atom(
    name: '_SettingsStoreBase.showCommunityHighlights',
    context: context,
  );

  @override
  bool get showCommunityHighlights {
    _$showCommunityHighlightsAtom.reportRead();
    return super.showCommunityHighlights;
  }

  @override
  set showCommunityHighlights(bool value) {
    _$showCommunityHighlightsAtom.reportWrite(
      value,
      super.showCommunityHighlights,
      () {
        super.showCommunityHighlights = value;
      },
    );
  }

  late final _$showCelebrationsAtom = Atom(
    name: '_SettingsStoreBase.showCelebrations',
    context: context,
  );

  @override
  bool get showCelebrations {
    _$showCelebrationsAtom.reportRead();
    return super.showCelebrations;
  }

  @override
  set showCelebrations(bool value) {
    _$showCelebrationsAtom.reportWrite(value, super.showCelebrations, () {
      super.showCelebrations = value;
    });
  }

  late final _$celebrationsOnVideoAtom = Atom(
    name: '_SettingsStoreBase.celebrationsOnVideo',
    context: context,
  );

  @override
  CelebrationsOnVideo get celebrationsOnVideo {
    _$celebrationsOnVideoAtom.reportRead();
    return super.celebrationsOnVideo;
  }

  @override
  set celebrationsOnVideo(CelebrationsOnVideo value) {
    _$celebrationsOnVideoAtom.reportWrite(value, super.celebrationsOnVideo, () {
      super.celebrationsOnVideo = value;
    });
  }

  late final _$emoteMenuButtonOnLeftAtom = Atom(
    name: '_SettingsStoreBase.emoteMenuButtonOnLeft',
    context: context,
  );

  @override
  bool get emoteMenuButtonOnLeft {
    _$emoteMenuButtonOnLeftAtom.reportRead();
    return super.emoteMenuButtonOnLeft;
  }

  @override
  set emoteMenuButtonOnLeft(bool value) {
    _$emoteMenuButtonOnLeftAtom.reportWrite(
      value,
      super.emoteMenuButtonOnLeft,
      () {
        super.emoteMenuButtonOnLeft = value;
      },
    );
  }

  late final _$landscapeChatLeftSideAtom = Atom(
    name: '_SettingsStoreBase.landscapeChatLeftSide',
    context: context,
  );

  @override
  bool get landscapeChatLeftSide {
    _$landscapeChatLeftSideAtom.reportRead();
    return super.landscapeChatLeftSide;
  }

  @override
  set landscapeChatLeftSide(bool value) {
    _$landscapeChatLeftSideAtom.reportWrite(
      value,
      super.landscapeChatLeftSide,
      () {
        super.landscapeChatLeftSide = value;
      },
    );
  }

  late final _$landscapeForceVerticalChatAtom = Atom(
    name: '_SettingsStoreBase.landscapeForceVerticalChat',
    context: context,
  );

  @override
  bool get landscapeForceVerticalChat {
    _$landscapeForceVerticalChatAtom.reportRead();
    return super.landscapeForceVerticalChat;
  }

  @override
  set landscapeForceVerticalChat(bool value) {
    _$landscapeForceVerticalChatAtom.reportWrite(
      value,
      super.landscapeForceVerticalChat,
      () {
        super.landscapeForceVerticalChat = value;
      },
    );
  }

  late final _$landscapeCutoutAtom = Atom(
    name: '_SettingsStoreBase.landscapeCutout',
    context: context,
  );

  @override
  LandscapeCutoutType get landscapeCutout {
    _$landscapeCutoutAtom.reportRead();
    return super.landscapeCutout;
  }

  @override
  set landscapeCutout(LandscapeCutoutType value) {
    _$landscapeCutoutAtom.reportWrite(value, super.landscapeCutout, () {
      super.landscapeCutout = value;
    });
  }

  late final _$chatWidthAtom = Atom(
    name: '_SettingsStoreBase.chatWidth',
    context: context,
  );

  @override
  double get chatWidth {
    _$chatWidthAtom.reportRead();
    return super.chatWidth;
  }

  @override
  set chatWidth(double value) {
    _$chatWidthAtom.reportWrite(value, super.chatWidth, () {
      super.chatWidth = value;
    });
  }

  late final _$fullScreenChatOverlayOpacityAtom = Atom(
    name: '_SettingsStoreBase.fullScreenChatOverlayOpacity',
    context: context,
  );

  @override
  double get fullScreenChatOverlayOpacity {
    _$fullScreenChatOverlayOpacityAtom.reportRead();
    return super.fullScreenChatOverlayOpacity;
  }

  @override
  set fullScreenChatOverlayOpacity(double value) {
    _$fullScreenChatOverlayOpacityAtom.reportWrite(
      value,
      super.fullScreenChatOverlayOpacity,
      () {
        super.fullScreenChatOverlayOpacity = value;
      },
    );
  }

  late final _$tapToCloseOverlayChatAtom = Atom(
    name: '_SettingsStoreBase.tapToCloseOverlayChat',
    context: context,
  );

  @override
  bool get tapToCloseOverlayChat {
    _$tapToCloseOverlayChatAtom.reportRead();
    return super.tapToCloseOverlayChat;
  }

  @override
  set tapToCloseOverlayChat(bool value) {
    _$tapToCloseOverlayChatAtom.reportWrite(
      value,
      super.tapToCloseOverlayChat,
      () {
        super.tapToCloseOverlayChat = value;
      },
    );
  }

  late final _$showModActionsInChatAtom = Atom(
    name: '_SettingsStoreBase.showModActionsInChat',
    context: context,
  );

  @override
  bool get showModActionsInChat {
    _$showModActionsInChatAtom.reportRead();
    return super.showModActionsInChat;
  }

  @override
  set showModActionsInChat(bool value) {
    _$showModActionsInChatAtom.reportWrite(
      value,
      super.showModActionsInChat,
      () {
        super.showModActionsInChat = value;
      },
    );
  }

  late final _$landscapeChatModesAtom = Atom(
    name: '_SettingsStoreBase.landscapeChatModes',
    context: context,
  );

  @override
  List<LandscapeChatMode> get landscapeChatModes {
    _$landscapeChatModesAtom.reportRead();
    return super.landscapeChatModes;
  }

  @override
  set landscapeChatModes(List<LandscapeChatMode> value) {
    _$landscapeChatModesAtom.reportWrite(value, super.landscapeChatModes, () {
      super.landscapeChatModes = value;
    });
  }

  late final _$autocompleteAtom = Atom(
    name: '_SettingsStoreBase.autocomplete',
    context: context,
  );

  @override
  bool get autocomplete {
    _$autocompleteAtom.reportRead();
    return super.autocomplete;
  }

  @override
  set autocomplete(bool value) {
    _$autocompleteAtom.reportWrite(value, super.autocomplete, () {
      super.autocomplete = value;
    });
  }

  late final _$showTwitchEmotesAtom = Atom(
    name: '_SettingsStoreBase.showTwitchEmotes',
    context: context,
  );

  @override
  bool get showTwitchEmotes {
    _$showTwitchEmotesAtom.reportRead();
    return super.showTwitchEmotes;
  }

  @override
  set showTwitchEmotes(bool value) {
    _$showTwitchEmotesAtom.reportWrite(value, super.showTwitchEmotes, () {
      super.showTwitchEmotes = value;
    });
  }

  late final _$showTwitchBadgesAtom = Atom(
    name: '_SettingsStoreBase.showTwitchBadges',
    context: context,
  );

  @override
  bool get showTwitchBadges {
    _$showTwitchBadgesAtom.reportRead();
    return super.showTwitchBadges;
  }

  @override
  set showTwitchBadges(bool value) {
    _$showTwitchBadgesAtom.reportWrite(value, super.showTwitchBadges, () {
      super.showTwitchBadges = value;
    });
  }

  late final _$show7TVEmotesAtom = Atom(
    name: '_SettingsStoreBase.show7TVEmotes',
    context: context,
  );

  @override
  bool get show7TVEmotes {
    _$show7TVEmotesAtom.reportRead();
    return super.show7TVEmotes;
  }

  @override
  set show7TVEmotes(bool value) {
    _$show7TVEmotesAtom.reportWrite(value, super.show7TVEmotes, () {
      super.show7TVEmotes = value;
    });
  }

  late final _$showBTTVEmotesAtom = Atom(
    name: '_SettingsStoreBase.showBTTVEmotes',
    context: context,
  );

  @override
  bool get showBTTVEmotes {
    _$showBTTVEmotesAtom.reportRead();
    return super.showBTTVEmotes;
  }

  @override
  set showBTTVEmotes(bool value) {
    _$showBTTVEmotesAtom.reportWrite(value, super.showBTTVEmotes, () {
      super.showBTTVEmotes = value;
    });
  }

  late final _$showBTTVBadgesAtom = Atom(
    name: '_SettingsStoreBase.showBTTVBadges',
    context: context,
  );

  @override
  bool get showBTTVBadges {
    _$showBTTVBadgesAtom.reportRead();
    return super.showBTTVBadges;
  }

  @override
  set showBTTVBadges(bool value) {
    _$showBTTVBadgesAtom.reportWrite(value, super.showBTTVBadges, () {
      super.showBTTVBadges = value;
    });
  }

  late final _$showFFZEmotesAtom = Atom(
    name: '_SettingsStoreBase.showFFZEmotes',
    context: context,
  );

  @override
  bool get showFFZEmotes {
    _$showFFZEmotesAtom.reportRead();
    return super.showFFZEmotes;
  }

  @override
  set showFFZEmotes(bool value) {
    _$showFFZEmotesAtom.reportWrite(value, super.showFFZEmotes, () {
      super.showFFZEmotes = value;
    });
  }

  late final _$showFFZBadgesAtom = Atom(
    name: '_SettingsStoreBase.showFFZBadges',
    context: context,
  );

  @override
  bool get showFFZBadges {
    _$showFFZBadgesAtom.reportRead();
    return super.showFFZBadges;
  }

  @override
  set showFFZBadges(bool value) {
    _$showFFZBadgesAtom.reportWrite(value, super.showFFZBadges, () {
      super.showFFZBadges = value;
    });
  }

  late final _$showRecentMessagesAtom = Atom(
    name: '_SettingsStoreBase.showRecentMessages',
    context: context,
  );

  @override
  bool get showRecentMessages {
    _$showRecentMessagesAtom.reportRead();
    return super.showRecentMessages;
  }

  @override
  set showRecentMessages(bool value) {
    _$showRecentMessagesAtom.reportWrite(value, super.showRecentMessages, () {
      super.showRecentMessages = value;
    });
  }

  late final _$persistChatTabsAtom = Atom(
    name: '_SettingsStoreBase.persistChatTabs',
    context: context,
  );

  @override
  bool get persistChatTabs {
    _$persistChatTabsAtom.reportRead();
    return super.persistChatTabs;
  }

  @override
  set persistChatTabs(bool value) {
    _$persistChatTabsAtom.reportWrite(value, super.persistChatTabs, () {
      super.persistChatTabs = value;
    });
  }

  late final _$secondaryTabsAtom = Atom(
    name: '_SettingsStoreBase.secondaryTabs',
    context: context,
  );

  @override
  List<PersistedChatTab> get secondaryTabs {
    _$secondaryTabsAtom.reportRead();
    return super.secondaryTabs;
  }

  @override
  set secondaryTabs(List<PersistedChatTab> value) {
    _$secondaryTabsAtom.reportWrite(value, super.secondaryTabs, () {
      super.secondaryTabs = value;
    });
  }

  late final _$mutedWordsAtom = Atom(
    name: '_SettingsStoreBase.mutedWords',
    context: context,
  );

  @override
  List<String> get mutedWords {
    _$mutedWordsAtom.reportRead();
    return super.mutedWords;
  }

  @override
  set mutedWords(List<String> value) {
    _$mutedWordsAtom.reportWrite(value, super.mutedWords, () {
      super.mutedWords = value;
    });
  }

  late final _$matchWholeWordAtom = Atom(
    name: '_SettingsStoreBase.matchWholeWord',
    context: context,
  );

  @override
  bool get matchWholeWord {
    _$matchWholeWordAtom.reportRead();
    return super.matchWholeWord;
  }

  @override
  set matchWholeWord(bool value) {
    _$matchWholeWordAtom.reportWrite(value, super.matchWholeWord, () {
      super.matchWholeWord = value;
    });
  }

  late final _$chatFiltersEnabledAtom = Atom(
    name: '_SettingsStoreBase.chatFiltersEnabled',
    context: context,
  );

  @override
  bool get chatFiltersEnabled {
    _$chatFiltersEnabledAtom.reportRead();
    return super.chatFiltersEnabled;
  }

  @override
  set chatFiltersEnabled(bool value) {
    _$chatFiltersEnabledAtom.reportWrite(value, super.chatFiltersEnabled, () {
      super.chatFiltersEnabled = value;
    });
  }

  late final _$chatFilterDiscriminationAtom = Atom(
    name: '_SettingsStoreBase.chatFilterDiscrimination',
    context: context,
  );

  @override
  bool get chatFilterDiscrimination {
    _$chatFilterDiscriminationAtom.reportRead();
    return super.chatFilterDiscrimination;
  }

  @override
  set chatFilterDiscrimination(bool value) {
    _$chatFilterDiscriminationAtom.reportWrite(
      value,
      super.chatFilterDiscrimination,
      () {
        super.chatFilterDiscrimination = value;
      },
    );
  }

  late final _$chatFilterSexualAtom = Atom(
    name: '_SettingsStoreBase.chatFilterSexual',
    context: context,
  );

  @override
  bool get chatFilterSexual {
    _$chatFilterSexualAtom.reportRead();
    return super.chatFilterSexual;
  }

  @override
  set chatFilterSexual(bool value) {
    _$chatFilterSexualAtom.reportWrite(value, super.chatFilterSexual, () {
      super.chatFilterSexual = value;
    });
  }

  late final _$chatFilterHarassmentAtom = Atom(
    name: '_SettingsStoreBase.chatFilterHarassment',
    context: context,
  );

  @override
  bool get chatFilterHarassment {
    _$chatFilterHarassmentAtom.reportRead();
    return super.chatFilterHarassment;
  }

  @override
  set chatFilterHarassment(bool value) {
    _$chatFilterHarassmentAtom.reportWrite(
      value,
      super.chatFilterHarassment,
      () {
        super.chatFilterHarassment = value;
      },
    );
  }

  late final _$chatFilterProfanityAtom = Atom(
    name: '_SettingsStoreBase.chatFilterProfanity',
    context: context,
  );

  @override
  bool get chatFilterProfanity {
    _$chatFilterProfanityAtom.reportRead();
    return super.chatFilterProfanity;
  }

  @override
  set chatFilterProfanity(bool value) {
    _$chatFilterProfanityAtom.reportWrite(value, super.chatFilterProfanity, () {
      super.chatFilterProfanity = value;
    });
  }

  late final _$shareCrashLogsAndAnalyticsAtom = Atom(
    name: '_SettingsStoreBase.shareCrashLogsAndAnalytics',
    context: context,
  );

  @override
  bool get shareCrashLogsAndAnalytics {
    _$shareCrashLogsAndAnalyticsAtom.reportRead();
    return super.shareCrashLogsAndAnalytics;
  }

  @override
  set shareCrashLogsAndAnalytics(bool value) {
    _$shareCrashLogsAndAnalyticsAtom.reportWrite(
      value,
      super.shareCrashLogsAndAnalytics,
      () {
        super.shareCrashLogsAndAnalytics = value;
      },
    );
  }

  late final _$telemetryConsentVersionAtom = Atom(
    name: '_SettingsStoreBase.telemetryConsentVersion',
    context: context,
  );

  @override
  int get telemetryConsentVersion {
    _$telemetryConsentVersionAtom.reportRead();
    return super.telemetryConsentVersion;
  }

  @override
  set telemetryConsentVersion(int value) {
    _$telemetryConsentVersionAtom.reportWrite(
      value,
      super.telemetryConsentVersion,
      () {
        super.telemetryConsentVersion = value;
      },
    );
  }

  late final _$fullScreenAtom = Atom(
    name: '_SettingsStoreBase.fullScreen',
    context: context,
  );

  @override
  bool get fullScreen {
    _$fullScreenAtom.reportRead();
    return super.fullScreen;
  }

  @override
  set fullScreen(bool value) {
    _$fullScreenAtom.reportWrite(value, super.fullScreen, () {
      super.fullScreen = value;
    });
  }

  late final _$fullScreenChatOverlayAtom = Atom(
    name: '_SettingsStoreBase.fullScreenChatOverlay',
    context: context,
  );

  @override
  bool get fullScreenChatOverlay {
    _$fullScreenChatOverlayAtom.reportRead();
    return super.fullScreenChatOverlay;
  }

  @override
  set fullScreenChatOverlay(bool value) {
    _$fullScreenChatOverlayAtom.reportWrite(
      value,
      super.fullScreenChatOverlay,
      () {
        super.fullScreenChatOverlay = value;
      },
    );
  }

  late final _$pinnedChannelIdsAtom = Atom(
    name: '_SettingsStoreBase.pinnedChannelIds',
    context: context,
  );

  @override
  List<String> get pinnedChannelIds {
    _$pinnedChannelIdsAtom.reportRead();
    return super.pinnedChannelIds;
  }

  @override
  set pinnedChannelIds(List<String> value) {
    _$pinnedChannelIdsAtom.reportWrite(value, super.pinnedChannelIds, () {
      super.pinnedChannelIds = value;
    });
  }

  late final _$animatedEmotesCalloutShownAtom = Atom(
    name: '_SettingsStoreBase.animatedEmotesCalloutShown',
    context: context,
  );

  @override
  bool get animatedEmotesCalloutShown {
    _$animatedEmotesCalloutShownAtom.reportRead();
    return super.animatedEmotesCalloutShown;
  }

  @override
  set animatedEmotesCalloutShown(bool value) {
    _$animatedEmotesCalloutShownAtom.reportWrite(
      value,
      super.animatedEmotesCalloutShown,
      () {
        super.animatedEmotesCalloutShown = value;
      },
    );
  }

  late final _$hiddenPinnedChatIdsAtom = Atom(
    name: '_SettingsStoreBase.hiddenPinnedChatIds',
    context: context,
  );

  @override
  List<String> get hiddenPinnedChatIds {
    _$hiddenPinnedChatIdsAtom.reportRead();
    return super.hiddenPinnedChatIds;
  }

  @override
  set hiddenPinnedChatIds(List<String> value) {
    _$hiddenPinnedChatIdsAtom.reportWrite(value, super.hiddenPinnedChatIds, () {
      super.hiddenPinnedChatIds = value;
    });
  }

  late final _$_SettingsStoreBaseActionController = ActionController(
    name: '_SettingsStoreBase',
    context: context,
  );

  @override
  void chooseLanguage(AppLanguage language) {
    final _$actionInfo = _$_SettingsStoreBaseActionController.startAction(
      name: '_SettingsStoreBase.chooseLanguage',
    );
    try {
      return super.chooseLanguage(language);
    } finally {
      _$_SettingsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void resetGeneralSettings() {
    final _$actionInfo = _$_SettingsStoreBaseActionController.startAction(
      name: '_SettingsStoreBase.resetGeneralSettings',
    );
    try {
      return super.resetGeneralSettings();
    } finally {
      _$_SettingsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void resetVideoSettings() {
    final _$actionInfo = _$_SettingsStoreBaseActionController.startAction(
      name: '_SettingsStoreBase.resetVideoSettings',
    );
    try {
      return super.resetVideoSettings();
    } finally {
      _$_SettingsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setLandscapeChatMode(LandscapeChatMode mode, {required bool on}) {
    final _$actionInfo = _$_SettingsStoreBaseActionController.startAction(
      name: '_SettingsStoreBase.setLandscapeChatMode',
    );
    try {
      return super.setLandscapeChatMode(mode, on: on);
    } finally {
      _$_SettingsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void showLandscapeChatMode(LandscapeChatMode mode) {
    final _$actionInfo = _$_SettingsStoreBaseActionController.startAction(
      name: '_SettingsStoreBase.showLandscapeChatMode',
    );
    try {
      return super.showLandscapeChatMode(mode);
    } finally {
      _$_SettingsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void resetChatSettings() {
    final _$actionInfo = _$_SettingsStoreBaseActionController.startAction(
      name: '_SettingsStoreBase.resetChatSettings',
    );
    try {
      return super.resetChatSettings();
    } finally {
      _$_SettingsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void resetOtherSettings() {
    final _$actionInfo = _$_SettingsStoreBaseActionController.startAction(
      name: '_SettingsStoreBase.resetOtherSettings',
    );
    try {
      return super.resetOtherSettings();
    } finally {
      _$_SettingsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void hidePinnedChat(String pinId) {
    final _$actionInfo = _$_SettingsStoreBaseActionController.startAction(
      name: '_SettingsStoreBase.hidePinnedChat',
    );
    try {
      return super.hidePinnedChat(pinId);
    } finally {
      _$_SettingsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void resetGlobalConfigs() {
    final _$actionInfo = _$_SettingsStoreBaseActionController.startAction(
      name: '_SettingsStoreBase.resetGlobalConfigs',
    );
    try {
      return super.resetGlobalConfigs();
    } finally {
      _$_SettingsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void resetAllSettings() {
    final _$actionInfo = _$_SettingsStoreBaseActionController.startAction(
      name: '_SettingsStoreBase.resetAllSettings',
    );
    try {
      return super.resetAllSettings();
    } finally {
      _$_SettingsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
themeType: ${themeType},
accentColor: ${accentColor},
showThumbnails: ${showThumbnails},
largeStreamCard: ${largeStreamCard},
startTab: ${startTab},
followedSort: ${followedSort},
streamLanguage: ${streamLanguage},
hiddenContentLabels: ${hiddenContentLabels},
confirmExternalLinks: ${confirmExternalLinks},
launchUrlExternal: ${launchUrlExternal},
mentionNotifications: ${mentionNotifications},
appLanguage: ${appLanguage},
languagePromptVersion: ${languagePromptVersion},
showVideo: ${showVideo},
warnMatureContent: ${warnMatureContent},
showCaptions: ${showCaptions},
captionSize: ${captionSize},
captionBackground: ${captionBackground},
captionLanguage: ${captionLanguage},
portraitVideoScale: ${portraitVideoScale},
portraitChatHeight: ${portraitChatHeight},
defaultToHighestQuality: ${defaultToHighestQuality},
useTextureRendering: ${useTextureRendering},
keepScreenAwake: ${keepScreenAwake},
backgroundAudio: ${backgroundAudio},
autoPictureInPicture: ${autoPictureInPicture},
playerEngine: ${playerEngine},
liveCatchUpMode: ${liveCatchUpMode},
bufferProfile: ${bufferProfile},
autoLatency: ${autoLatency},
vodAutoplay: ${vodAutoplay},
showOverlay: ${showOverlay},
toggleableOverlay: ${toggleableOverlay},
showLatency: ${showLatency},
badgeScale: ${badgeScale},
emoteScale: ${emoteScale},
messageScale: ${messageScale},
messageSpacing: ${messageSpacing},
fontSize: ${fontSize},
showDeletedMessages: ${showDeletedMessages},
animateEmotes: ${animateEmotes},
showGifs: ${showGifs},
animateGifs: ${animateGifs},
showLinkPreviews: ${showLinkPreviews},
showModerationNotices: ${showModerationNotices},
showChatMessageDividers: ${showChatMessageDividers},
timestampType: ${timestampType},
readableNameColors: ${readableNameColors},
increaseChatContrast: ${increaseChatContrast},
autoSyncChatDelay: ${autoSyncChatDelay},
chatDelay: ${chatDelay},
syncedChatDelay: ${syncedChatDelay},
highlightFirstTimeChatter: ${highlightFirstTimeChatter},
showUserNotices: ${showUserNotices},
collapseGiftBombs: ${collapseGiftBombs},
hideGiftSubNotices: ${hideGiftSubNotices},
hideGiftCount: ${hideGiftCount},
showHypeTrain: ${showHypeTrain},
showCommunityHighlights: ${showCommunityHighlights},
showCelebrations: ${showCelebrations},
celebrationsOnVideo: ${celebrationsOnVideo},
emoteMenuButtonOnLeft: ${emoteMenuButtonOnLeft},
landscapeChatLeftSide: ${landscapeChatLeftSide},
landscapeForceVerticalChat: ${landscapeForceVerticalChat},
landscapeCutout: ${landscapeCutout},
chatWidth: ${chatWidth},
fullScreenChatOverlayOpacity: ${fullScreenChatOverlayOpacity},
tapToCloseOverlayChat: ${tapToCloseOverlayChat},
showModActionsInChat: ${showModActionsInChat},
landscapeChatModes: ${landscapeChatModes},
autocomplete: ${autocomplete},
showTwitchEmotes: ${showTwitchEmotes},
showTwitchBadges: ${showTwitchBadges},
show7TVEmotes: ${show7TVEmotes},
showBTTVEmotes: ${showBTTVEmotes},
showBTTVBadges: ${showBTTVBadges},
showFFZEmotes: ${showFFZEmotes},
showFFZBadges: ${showFFZBadges},
showRecentMessages: ${showRecentMessages},
persistChatTabs: ${persistChatTabs},
secondaryTabs: ${secondaryTabs},
mutedWords: ${mutedWords},
matchWholeWord: ${matchWholeWord},
chatFiltersEnabled: ${chatFiltersEnabled},
chatFilterDiscrimination: ${chatFilterDiscrimination},
chatFilterSexual: ${chatFilterSexual},
chatFilterHarassment: ${chatFilterHarassment},
chatFilterProfanity: ${chatFilterProfanity},
shareCrashLogsAndAnalytics: ${shareCrashLogsAndAnalytics},
telemetryConsentVersion: ${telemetryConsentVersion},
fullScreen: ${fullScreen},
fullScreenChatOverlay: ${fullScreenChatOverlay},
pinnedChannelIds: ${pinnedChannelIds},
animatedEmotesCalloutShown: ${animatedEmotesCalloutShown},
hiddenPinnedChatIds: ${hiddenPinnedChatIds},
nameColorContrast: ${nameColorContrast},
effectiveChatDelay: ${effectiveChatDelay},
switchableLandscapeChatModes: ${switchableLandscapeChatModes}
    ''';
  }
}
