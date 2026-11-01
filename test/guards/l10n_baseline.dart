/// The ratchet of no_hardcoded_strings_test: how many hard-coded UI strings
/// each file of `lib/` still has, before its texts move to the ARB files.
///
/// Counts may only go down, and must match exactly: the guard fails when a
/// file has more (or a new file has any), and when it has fewer until its
/// count here is lowered. The map is empty once every text is translated.
const l10nBaseline = <String, int>{
  'lib/apis/dio_client.dart': 1,
  'lib/apis/twitch_api.dart': 1,
  'lib/apis/twitch_clip_service.dart': 1,
  'lib/apis/twitch_stream_service.dart': 1,
  'lib/apis/twitch_vod_service.dart': 1,
  'lib/apis/unauthorized_interceptor.dart': 6,
  'lib/constants.dart': 6,
  'lib/screens/vod/player_media.dart': 4,
  'lib/screens/vod/vod_screen.dart': 2,
  'lib/screens/vod/widgets/up_next_overlay.dart': 7,
  'lib/screens/vod/widgets/vod_chat_message.dart': 3,
  'lib/screens/vod/widgets/vod_chat_replay.dart': 9,
  'lib/screens/vod/widgets/vod_details_panel.dart': 16,
  'lib/screens/vod/widgets/vod_seek_bar.dart': 2,
  'lib/services/go_live/go_live.dart': 2,
  'lib/services/go_live/go_live_worker.dart': 4,
  'lib/services/notifications/mention_alerts.dart': 3,
  'lib/services/notifications/schedule_reminders.dart': 4,
  'lib/services/realtime/twitch_realtime_client.dart': 1,
  'lib/stores/whisper_store.dart': 6,
  'lib/utils/share_link.dart': 1,
};
