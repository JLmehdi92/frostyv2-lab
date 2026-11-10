/// Literals of `lib/` that read like UI text but stay as they are, by file:
/// `{path: {literal: why}}`. Interpolations are written `{}`. An entry that
/// no longer matches a literal fails the guard (no_hardcoded_strings_test).
///
/// Only what is never translated belongs here: brand names, Twitch's own
/// data, code that only looks like text.
const l10nAllowlist = <String, Map<String, String>>{
  'lib/apis/base_api_client.dart': {
    'No internet connection. Please check your network.': _apiLog,
    'Request was cancelled': _apiLog,
    'Security certificate error': _apiLog,
    'An unexpected error occurred': _apiLog,
    'Connection timeout. Please try again.': _apiLog,
    'Upload timeout. Please try again.': _apiLog,
    'Server response timeout. Please try again.': _apiLog,
    'Request timeout. Please try again.': _apiLog,
    'Invalid request data': _apiLog,
    'Please log in to continue': _apiLog,
    'Access denied. Insufficient permissions': _apiLog,
    'Resource not found': _apiLog,
    'Conflict with current state. Please refresh': _apiLog,
    'Invalid data provided': _apiLog,
    'Rate limit exceeded. Please wait before trying again': _apiLog,
    'Server error. Please try again later': _apiLog,
    'Service temporarily unavailable': _apiLog,
    'Service maintenance. Please try again later': _apiLog,
    'Server timeout. Please try again': _apiLog,
    'HTTP Error {} occurred': _apiLog,
  },
  'lib/apis/dio_client.dart': {
    'ONSET (Flutter Twitch Client)':
        'The HTTP User-Agent header sent to the APIs: the app\'s name, '
        'never shown.',
  },
  'lib/apis/integrity_retry_interceptor.dart': {
    'failed integrity check':
        'The exact error text Twitch\'s GQL answers when its anti-bot check '
        'refuses a request (IntegrityRetryInterceptor.refusalText), '
        'compared, never shown.',
  },
  'lib/apis/twitch_api.dart': {'Clip failed': _apiLog},
  'lib/apis/twitch_clip_service.dart': {'Clip playback is forbidden': _apiLog},
  'lib/apis/twitch_mod_api.dart': {
    'RESTRICTED': _helixValue,
    'ALLOW': _helixValue,
    'DENY': _helixValue,
    'RESOLVED': _helixValue,
    'CANCELED': _helixValue,
    'LOCKED': _helixValue,
    'FULFILLED': _helixValue,
  },
  'lib/apis/twitch_directory_service.dart': {
    'RELEVANCE': 'A GQL sort value sent to Twitch (StreamSort.gql): code.',
    'RECENT': 'A GQL sort value sent to Twitch (StreamSort.gql): code.',
  },
  'lib/apis/twitch_stream_service.dart': {
    '{}    value signature __typename{}':
        'A GraphQL query document sent to Twitch: code.',
  },
  'lib/apis/twitch_vod_service.dart': {'Video playback is forbidden': _apiLog},
  'lib/constants.dart': {
    'blue': _chatColorId,
    'chocolate': _chatColorId,
    'coral': _chatColorId,
    'firebrick': _chatColorId,
    'green': _chatColorId,
    'red': _chatColorId,
  },
  'lib/models/clip.dart': {
    'TRENDING': 'A GQL sort value sent to Twitch (ClipSort.gqlName): code.',
  },
  'lib/models/community_highlight_event.dart': {
    'polls':
        'A Hermes topic name sent to Twitch (HighlightTopic.prefix): code.',
    'raid': 'A Hermes topic name sent to Twitch (HighlightTopic.prefix): code.',
  },
  'lib/models/community_points.dart': {
    'ACTIVE':
        'A prediction\'s status code from Twitch (the default when it '
        'sends none), compared, never shown.',
  },
  'lib/models/irc.dart': {
    'GIF':
        'A GIF\'s title when it has none, and the format\'s name in its '
        'details: GIF in every language.',
    'Deleted user':
        'kDeletedUserDisplayName: the display name a line from an unknown '
        'sender carries as data, as the chat always had it (a reply quotes '
        'it); shown worded in the language on screen (chatDeletedUser).',
  },
  'lib/models/profile_edit.dart': {
    'PNG': _imageFormat,
    'JPG': _imageFormat,
    'GIF': _imageFormat,
  },
  'lib/models/vod.dart': {
    'ARCHIVE':
        'A GQL value sent to Twitch (VodType / WatchedVideoType.gqlName): code.',
    'HIGHLIGHT':
        'A GQL value sent to Twitch (VodType / WatchedVideoType.gqlName): code.',
    'UPLOAD':
        'A GQL value sent to Twitch (VodType / WatchedVideoType.gqlName): code.',
    'LIVE':
        'A GQL value sent to Twitch (VodType / WatchedVideoType.gqlName): code.',
    'VOD':
        'A GQL value sent to Twitch (VodType / WatchedVideoType.gqlName): code.',
  },
  'lib/screens/channel/chat/chat_commands.dart': {
    'me': _commandName,
    'color': _commandName,
    'block': _commandName,
    'unblock': _commandName,
    'user': _commandName,
    'disconnect': _commandName,
    'help': _commandName,
    'ban': _commandName,
    'unban': _commandName,
    'timeout': _commandName,
    'untimeout': _commandName,
    'warn': _commandName,
    'delete': _commandName,
    'clear': _commandName,
    'slow': _commandName,
    'slowoff': _commandName,
    'followers': _commandName,
    'followersoff': _commandName,
    'subscribers': _commandName,
    'subscribersoff': _commandName,
    'emoteonly': _commandName,
    'emoteonlyoff': _commandName,
    'uniquechat': _commandName,
    'uniquechatoff': _commandName,
    'announce': _commandName,
    'announceblue': _commandName,
    'announcegreen': _commandName,
    'announceorange': _commandName,
    'announcepurple': _commandName,
    'shoutout': _commandName,
    'shield': _commandName,
    'shieldoff': _commandName,
    'monitor': _commandName,
    'unmonitor': _commandName,
    'restrict': _commandName,
    'unrestrict': _commandName,
    'mods': _commandName,
    'vips': _commandName,
    'mod': _commandName,
    'unmod': _commandName,
    'vip': _commandName,
    'unvip': _commandName,
    'leadmod': _commandName,
    'unleadmod': _commandName,
    'marker': _commandName,
    'commercial': _commandName,
    'raid': _commandName,
    'unraid': _commandName,
  },
  'lib/screens/channel/chat/details/chat_details.dart': {
    'preview-message':
        'The id of the colour picker\'s fake preview message (an IRC tag), '
        'never shown.',
  },
  'lib/screens/channel/chat/mod_tools/mod_action_text.dart': {
    'timeoutUnknown':
        'A case of the chatModAction select (a timeout Twitch sent no '
        'length for), never shown.',
  },
  'lib/screens/channel/chat/moderation.dart': {
    'no user named {}':
        'The log message of the exception for a login nobody has (the '
        'failure\'s line words it: chatModNoUser), never shown.',
  },
  'lib/screens/channel/chat/stores/chat_assets_store.dart': {
    'Channel Emotes': _emoteSection,
    'Global Emotes': _emoteSection,
    'Unlocked Emotes': _emoteSection,
    'Other Channels': _emoteSection,
  },
  'lib/screens/channel/chat/stores/chat_store.dart': {
    'PONG :tmi.twitch.tv': _ircLine,
    'CAP REQ :twitch.tv/tags twitch.tv/commands': _ircLine,
    'PASS oauth:{}': _ircLine,
  },
  'lib/screens/channel/chat/widgets/first_frame_image.dart': {
    'Still image of':
        'The name of a diagnostics property in an image error report, for '
        'debugging, never shown.',
  },
  'lib/screens/channel/chat/widgets/user_card_info.dart': {
    'account date':
        'What a failed lookup was, for its debugPrint line only, never '
        'shown.',
    'follow date':
        'What a failed lookup was, for its debugPrint line only, never '
        'shown.',
  },
  'lib/screens/channel/hype_train/hype_train_reducer.dart': {
    'duplicate start': _ignoredEvent,
    'not applicable': _ignoredEvent,
    'level mismatch': _ignoredEvent,
  },
  'lib/screens/channel/hype_train/widgets/hype_train_palette.dart': {
    'Hype Train': _paletteName,
    'Treasure Train': _paletteName,
    'Community Train': _paletteName,
    'Mythic Train': _paletteName,
    'Golden Kappa Train': _paletteName,
  },
  'lib/screens/channel/video/stores/ivs_video_store.dart': {
    'Auto': _autoQuality,
  },
  'lib/screens/channel/video/stores/native_video_store.dart': {
    'Auto': _autoQuality,
  },
  'lib/screens/channel/video/stores/video_store.dart': {'Auto': _autoQuality},
  'lib/screens/home/live_feed/live_preview.dart': {
    'ONSET preview':
        'The preview player\'s internal media title (media_kit), never '
        'shown: the app\'s name and a word for logs.',
  },
  'lib/main.dart': {
    'ONSET': 'The app\'s name (MaterialApp.title, the task switcher): a brand.',
  },
  'lib/screens/home/shell/onset_shell.dart': {
    'ONSET': 'The header\'s default title: the app\'s name, a brand.',
  },
  'lib/screens/settings/other_settings.dart': {
    'ONSET': 'The app\'s name on the licences page (applicationName): a brand.',
  },
  'lib/screens/settings/profile_tab.dart': {
    'ONSET v{} ({})':
        'The app\'s name, its version and build number: a brand and figures.',
  },
  'lib/screens/settings/stores/auth_store.dart': {
    'Twitch refuses it':
        'Why the token proxy\'s app token is refused: only printed for '
        'debugging (debugPrint), never shown.',
    "it is the login application's (check the Worker's credentials)":
        'Same: a debug log, never shown.',
    "it is a user's token": 'Same: a debug log, never shown.',
    'it is not the application the proxy named':
        'Same: a debug log, never shown.',
  },
  'lib/screens/settings/widgets/settings_twitch_web_token.dart': {
    'auth-token':
        'The name of the twitch.tv cookie the field asks for, shown as its '
        'label while no token is set: a cookie name, the same in every '
        'language.',
  },
  'lib/screens/settings/widgets/settings_page.dart': {
    'ONSET v{} ({})':
        'The app\'s name, its version and build number: a brand and figures.',
  },
  'lib/services/go_live/go_live.dart': {
    'Log in again to get go-live notifications.':
        'What an older version stored as the go-live problem, read to map '
        'it to its code (kGoLiveLoggedOut); never shown.',
  },
  'lib/services/realtime/twitch_realtime_client.dart': {
    'subscribe failed':
        'Why a realtime topic is unavailable (RealtimeUnavailable.reason): '
        'for logs, never shown.',
  },
  'lib/utils/irc_privmsg_builder.dart': {
    '@{} :{}!{}@{}.tmi.twitch.tv PRIVMSG #{} :{}': _ircLine,
  },
  'lib/utils/stream_languages.dart': {
    'English':
        'A language\'s own name (an endonym), the same in every language.',
    'Français':
        'A language\'s own name (an endonym), the same in every language.',
    'Español':
        'A language\'s own name (an endonym), the same in every language.',
    'Deutsch':
        'A language\'s own name (an endonym), the same in every language.',
    'Português':
        'A language\'s own name (an endonym), the same in every language.',
    'Italiano':
        'A language\'s own name (an endonym), the same in every language.',
    'Русский':
        'A language\'s own name (an endonym), the same in every language.',
    '日本語': 'A language\'s own name (an endonym), the same in every language.',
    '한국어': 'A language\'s own name (an endonym), the same in every language.',
    '中文': 'A language\'s own name (an endonym), the same in every language.',
    'العربية':
        'A language\'s own name (an endonym), the same in every language.',
    'Türkçe':
        'A language\'s own name (an endonym), the same in every language.',
    'Polski':
        'A language\'s own name (an endonym), the same in every language.',
    'Nederlands':
        'A language\'s own name (an endonym), the same in every language.',
    'Svenska':
        'A language\'s own name (an endonym), the same in every language.',
  },
  'lib/widgets/launch/onset_mark.dart': {
    'ONSET': 'The wordmark\'s screen-reader label: the app\'s name, a brand.',
  },
};

/// Why an [ApiException]'s English message is allowed: it is for logs and
/// crash reports only; screens word its kind (lib/l10n/api_errors.dart).
const _apiLog =
    'ApiException.message, English for logs and crash reports; screens '
    'show apiErrorText (lib/l10n/api_errors.dart) instead.';

/// Why a Twitch chat colour's id is allowed.
const _chatColorId =
    'A chat colour\'s id sent to Twitch (chatColorNames, /color); the '
    'colour picker words it with chatColorName.';

const _imageFormat =
    'A UserImageUploadFormat value sent to Twitch with a profile image '
    '(ProfileImageFormat.gqlName): code.';

const _helixValue =
    'A value Twitch\'s Helix API reads (a status or an action): code.';

const _commandName =
    'A chat command\'s name: what is typed after the slash, as Twitch reads '
    'it, never translated (only its usage words and description are).';

const _emoteSection =
    'A key of the viewer\'s Twitch emote sections (UserEmoteSection), '
    'compared, never shown: the emote menu names it in the language on '
    'screen.';

const _ircLine =
    'A line of the IRC protocol sent to Twitch\'s chat server: code.';

const _autoQuality =
    'The adaptive rendition\'s name, a quality value compared and saved '
    'as is (streamQuality, the quality list); the quality menu words it '
    'with qualityLabel (playerConfigAuto, « Auto » in French too).';

const _ignoredEvent =
    'Why the hype train reducer ignored an event (HtApplyResult.reason): '
    'for logs and tests, never shown.';

const _paletteName =
    'HtPalette.a11yName: tells the palettes apart in tests, never shown '
    '(screen readers hear the train\'s name from the ARB files).';
