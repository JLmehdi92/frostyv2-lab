import 'dart:async';
import 'dart:convert';

import 'package:advanced_in_app_review/advanced_in_app_review.dart';
import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/bttv_api.dart';
import 'package:onset/apis/dio_client.dart';
import 'package:onset/apis/ffz_api.dart';
import 'package:onset/apis/seventv_api.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_auth_interceptor.dart';
import 'package:onset/apis/twitch_channel_profile_service.dart';
import 'package:onset/apis/twitch_chat_history_service.dart';
import 'package:onset/apis/twitch_chat_rules_service.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/apis/twitch_community_highlights_service.dart';
import 'package:onset/apis/twitch_community_service.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/apis/twitch_followed_categories_service.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/apis/twitch_watch_streak_service.dart';
import 'package:onset/apis/unauthorized_interceptor.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/activity/stores/activity_store.dart';
import 'package:onset/screens/channel/channel.dart';
import 'package:onset/screens/channel/stream_end.dart';
import 'package:onset/screens/channel_profile/channel_profile_screen.dart';
import 'package:onset/screens/clips/clip_screen.dart';
import 'package:onset/screens/home/home.dart';
import 'package:onset/screens/home/shell/onset_shell.dart';
import 'package:onset/screens/home/stores/home_store.dart';
import 'package:onset/screens/home/top/categories/category_streams.dart';
import 'package:onset/screens/onboarding/onboarding_flow.dart';
import 'package:onset/screens/settings/settings.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/screens/vod/channel_videos.dart';
import 'package:onset/screens/vod/vod_screen.dart';
import 'package:onset/services/background_audio.dart';
import 'package:onset/services/cache_manager.dart';
import 'package:onset/services/font_licenses.dart';
import 'package:onset/services/go_live/go_live.dart';
import 'package:onset/services/go_live/go_live_poller.dart';
import 'package:onset/services/go_live/go_live_worker.dart';
import 'package:onset/services/launch_info.dart';
import 'package:onset/services/locale_bridge.dart';
import 'package:onset/services/notification_settings_link.dart';
import 'package:onset/services/notifications/activity_log.dart';
import 'package:onset/services/notifications/mention_alerts.dart';
import 'package:onset/services/notifications/schedule_reminders.dart';
import 'package:onset/services/onset_updater.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';
import 'package:onset/services/realtime/twitch_realtime_client.dart';
import 'package:onset/services/settings_persistence.dart';
import 'package:onset/services/telemetry.dart';
import 'package:onset/services/telemetry_consent.dart';
import 'package:onset/stores/global_assets_store.dart';
import 'package:onset/stores/mini_player_store.dart';
import 'package:onset/stores/whisper_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/utils/link_router.dart';
import 'package:onset/utils/twitch_links.dart';
import 'package:onset/widgets/alert_message.dart';
import 'package:onset/widgets/external_link_dialog.dart';
import 'package:onset/widgets/global_mini_player.dart';
import 'package:onset/widgets/launch/launch_intro.dart';
import 'package:onset/widgets/launch/onset_mark.dart';
import 'package:onset/widgets/twitch_web_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();

  // Whether this is a cold start (the launch intro plays only then). Asked
  // now so the answer is in by the time the app is built.
  final launchInfo = LaunchInfo.load();
  // The first frames show the mark (the intro's tile where the splash drew
  // it, or the header's): decoded meanwhile, so they have the image
  // (bounded, never holds the launch).
  final view = WidgetsBinding.instance.platformDispatcher.implicitView;
  final markReady = view == null
      ? Future<void>.value()
      : OnsetMark.precacheFor(view);

  // Initialize the native media_kit player (low-latency video engine).
  MediaKit.ensureInitialized();

  CustomCacheManager.removeOrphanedCacheFiles();

  // Firebase only when the build carries its config (see Telemetry); it
  // then reports uncaught framework and platform errors as fatal, once the
  // setting below lets it collect (nothing is handed to it before).
  await Telemetry.initialize();

  final prefs = await SharedPreferences.getInstance();

  final firstRun = prefs.getBool('first_run') ?? true;

  // Workaround for clearing stored tokens on uninstall.
  // If first time running app, will clear all tokens in the secure storage.
  // Run non-blocking to avoid ANR on slow Android devices (especially Android 14).
  if (firstRun) {
    debugPrint('Clearing secure storage...');
    const storage = FlutterSecureStorage();

    // Don't block - run in background after app starts.
    // This is safe because first run means no active session depends on this data.
    unawaited(
      storage.deleteAll().catchError((e) {
        debugPrint('Error clearing secure storage: $e');
      }),
    );
  }

  await initUtils();

  // With the shared preferences instance, obtain the existing user settings if it exists.
  // If default settings don't exist, use an empty JSON string to use the default values.
  final userSettings = prefs.getString('settings') ?? '{}';

  // Initialize a settings store from the settings JSON string.
  final settingsStore = SettingsStore.fromJson(jsonDecode(userSettings));

  // Firebase collects as the setting says, now and whenever it changes (the
  // switch, the onboarding, a reset); never in a debug build. Kept for the
  // app's lifetime.
  syncFirebaseCollection(settingsStore);

  // Save the settings on disk when they change (gathered, not once per
  // frame of a drag), and at once when the app leaves the screen. Kept for
  // the app's lifetime.
  persistSettings(
    settingsStore,
    (json) => unawaited(prefs.setString('settings', json)),
  );

  // Android 13+'s per-app language and the app's stay the same, both ways:
  // one picked in the system meanwhile is adopted now and on each resume,
  // one picked in the app is told to the system. Kept for the app's
  // lifetime.
  final adoptSystemLanguage = await syncSystemLanguage(
    settingsStore,
    LocaleBridge.shared,
  );
  reaction(
    (_) => settingsStore.appLanguage,
    (AppLanguage language) => unawaited(LocaleBridge.shared.push(language)),
  );
  AppLifecycleListener(onResume: () => unawaited(adoptSystemLanguage()));

  /// Initialize API services with a common Dio client.
  /// This will prevent every request from creating a new client instance.
  final dioClient = DioClient.createClient();

  // Create API services
  final twitchApiService = TwitchApi(dioClient);
  final bttvApiService = BTTVApi(dioClient);
  final ffzApiService = FFZApi(dioClient);
  final sevenTVApiService = SevenTVApi(dioClient);
  // Anonymous GQL for VODs and hype trains: own Dio with timeouts and no
  // Twitch auth interceptor (it must never carry the user's Helix token).
  // Only the VOD playback token and the viewer's watch positions add the
  // viewer's twitch.tv web token, per request (wired below, once the auth
  // store exists).
  final anonymousGqlDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );
  final twitchVodService = TwitchVodService(anonymousGqlDio);
  final twitchHypeTrainService = TwitchHypeTrainService(anonymousGqlDio);
  final twitchClipService = TwitchClipService(anonymousGqlDio);
  final twitchCommunityHighlightsService = TwitchCommunityHighlightsService(
    anonymousGqlDio,
  );
  final twitchChannelProfileService = TwitchChannelProfileService(
    anonymousGqlDio,
  );
  final twitchDirectoryService = TwitchDirectoryService(anonymousGqlDio);
  final twitchChatRulesService = TwitchChatRulesService(anonymousGqlDio);
  // Chat history on joining: the web token is added per request, to GQL
  // only.
  final twitchChatHistoryService = TwitchChatHistoryService(anonymousGqlDio);
  // Followed categories: the web token is added per request, to GQL only.
  final twitchFollowedCategoriesService = TwitchFollowedCategoriesService(
    anonymousGqlDio,
  );
  // Watch streaks: the web token is added per request, to GQL only.
  final twitchWatchStreakService = TwitchWatchStreakService(anonymousGqlDio);
  final twitchViewerActionsService = TwitchViewerActionsService(
    anonymousGqlDio,
  );
  final twitchCommunityService = TwitchCommunityService(anonymousGqlDio);

  // One anonymous realtime connection (Hermes) for public Twitch topics such
  // as the hype train. It connects only when something subscribes and
  // sleeps after a minute in the background.
  final realtimeClient = TwitchRealtimeClient();
  AppLifecycleListener(
    onPause: realtimeClient.onAppPaused,
    onResume: realtimeClient.onAppResumed,
  );

  // Create global assets store (shared cache for global emotes/badges)
  final globalAssetsStore = GlobalAssetsStore(
    twitchApi: twitchApiService,
    bttvApi: bttvApiService,
    ffzApi: ffzApiService,
    sevenTVApi: sevenTVApiService,
  );

  // Create and initialize the authentication store
  final authStore = AuthStore(twitchApi: twitchApiService);

  // Add the auth interceptor to the Dio client after AuthStore creation
  dioClient.interceptors.add(TwitchAuthInterceptor(authStore));

  // Add the unauthorized interceptor to catch 401 errors
  dioClient.interceptors.add(UnauthorizedInterceptor(authStore));

  // VODs restricted to subscribers play for subscribers, like live 2K, and
  // watch positions are kept on the viewer's Twitch account.
  twitchVodService
    ..webToken = (() => authStore.twitchWebToken)
    ..onWebTokenRejected = authStore.renewTwitchWebToken
    ..viewerId = (() =>
        authStore.isLoggedIn ? authStore.user.details?.id : null);

  await authStore.init();

  // The logged-in user's events (whispers) over one EventSub websocket,
  // subscribed through Helix. Connects only while something listens and
  // sleeps after a minute in the background.
  final eventSubClient = TwitchEventSubClient(
    create: (topic, sessionId) => twitchApiService.createEventSubSubscription(
      type: topic.type,
      version: topic.version,
      condition: topic.condition,
      sessionId: sessionId,
    ),
    delete: twitchApiService.deleteEventSubSubscription,
  );
  AppLifecycleListener(
    onPause: eventSubClient.onAppPaused,
    onResume: eventSubClient.onAppResumed,
  );
  // The background go-live check follows the logged-in viewer. A launch
  // that is not logged in yet (offline, Twitch hiccup) keeps the last one:
  // a real logout removes the token, which stops the check by itself.
  reaction(
    (_) => authStore.isLoggedIn ? authStore.user.details?.id : null,
    (String? id) async {
      if (id == null) return;
      final prefs = await GoLivePrefs.load();
      await prefs.setUserId(id);
    },
    fireImmediately: true,
  );
  // The notifications ONSET posts, listed on the Activity screen. The
  // background go-live task adds to the same list: read again on resume.
  final activityStore = ActivityStore(log: await ActivityLog.load());
  // "Remind Me" on schedules: local notifications at the segment start;
  // those that went off are listed in Activity.
  final reminders = ScheduleReminders(
    prefs: prefs,
    platform: const LocalReminderPlatform(),
  );
  ScheduleReminders.shared = reminders;
  Future<void> refreshActivity() async {
    try {
      await activityStore.addAll(await reminders.takeDue());
    } catch (e) {
      debugPrint('Reminders unavailable: $e');
    }
    await activityStore.refresh();
  }

  unawaited(refreshActivity());
  AppLifecycleListener(onResume: () => unawaited(refreshActivity()));

  // Mentions in a connected chat while the app is not in front.
  MentionAlerts.shared = MentionAlerts(
    post: (notice) async {
      await MentionNotifications.show(notice, L10n.current);
      await activityStore.addAll([mentionEntry(notice, DateTime.now())]);
    },
    inFront: appInFront,
  );

  // Faster go-live notices while the app is alive (in front, in
  // picture-in-picture, or playing in the background); the background
  // task covers the rest. Both share the same state, so nothing is
  // announced twice.
  final goLivePoller = GoLivePoller(
    check: () async {
      // Nothing can show before the plugin is set up (just after launch).
      await GoLiveNotifications.ready.timeout(const Duration(seconds: 20));
      await checkGoLiveInApp(
        api: twitchApiService,
        prefs: await GoLivePrefs.load(),
        loggedIn: authStore.isLoggedIn,
        notify: (notices, more) async {
          await GoLiveNotifications.show(notices, more, L10n.current);
          final now = DateTime.now();
          await activityStore.addAll([
            for (final notice in notices) goLiveEntry(notice, now),
          ]);
        },
      );
    },
    playingInBackground: () => BackgroundAudio.shared.playing,
  );
  AppLifecycleListener(onStateChange: goLivePoller.onLifecycle);
  goLivePoller.start();

  final whisperStore = WhisperStore(
    twitchApi: twitchApiService,
    listen: eventSubClient.listen,
    currentUserId: () =>
        authStore.isLoggedIn ? authStore.user.details?.id : null,
    // Logging in again (new scopes) listens anew.
    credentials: () => authStore.token,
    mutedUserIds: settingsStore.mutedWhisperUserIds.toSet(),
    archivedUserIds: settingsStore.archivedWhisperUserIds.toSet(),
    onPreferencesChanged: (muted, archived) => runInAction(() {
      settingsStore
        ..mutedWhisperUserIds = muted.toList()
        ..archivedWhisperUserIds = archived.toList();
    }),
  );

  // Whether, never who: crash reports carry no user id.
  Telemetry.setCustomKey('is_logged_in', authStore.isLoggedIn);

  await markReady;
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthStore>.value(value: authStore),
        Provider<SettingsStore>.value(value: settingsStore),
        Provider<TwitchApi>.value(value: twitchApiService),
        Provider<BTTVApi>.value(value: bttvApiService),
        Provider<FFZApi>.value(value: ffzApiService),
        Provider<SevenTVApi>.value(value: sevenTVApiService),
        Provider<TwitchVodService>.value(value: twitchVodService),
        Provider<TwitchHypeTrainService>.value(value: twitchHypeTrainService),
        Provider<TwitchClipService>.value(value: twitchClipService),
        Provider<TwitchCommunityHighlightsService>.value(
          value: twitchCommunityHighlightsService,
        ),
        Provider<TwitchChannelProfileService>.value(
          value: twitchChannelProfileService,
        ),
        Provider<TwitchDirectoryService>.value(value: twitchDirectoryService),
        Provider<TwitchChatRulesService>.value(value: twitchChatRulesService),
        Provider<TwitchChatHistoryService>.value(
          value: twitchChatHistoryService,
        ),
        Provider<TwitchFollowedCategoriesService>.value(
          value: twitchFollowedCategoriesService,
        ),
        Provider<TwitchWatchStreakService>.value(
          value: twitchWatchStreakService,
        ),
        Provider<TwitchViewerActionsService>.value(
          value: twitchViewerActionsService,
        ),
        Provider<TwitchCommunityService>.value(value: twitchCommunityService),
        Provider<TwitchRealtimeClient>.value(value: realtimeClient),
        Provider<GlobalAssetsStore>.value(value: globalAssetsStore),
        Provider<TwitchEventSubClient>.value(value: eventSubClient),
        Provider<WhisperStore>.value(value: whisperStore),
        Provider<ActivityStore>.value(value: activityStore),
        Provider<MiniPlayerStore>(create: (_) => MiniPlayerStore()),
        // In-app updates; silent in builds without UPDATE_REPO.
        Provider<OnsetUpdater>(create: (_) => OnsetUpdater()),
      ],
      child: MyApp(firstRun: firstRun, launchInfo: await launchInfo),
    ),
  );
}

// Navigator key for sleep timer. Allows navigation popping without context.
final navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  final bool firstRun;

  /// How the app was launched; decides whether the launch intro plays.
  final LaunchInfo launchInfo;

  const MyApp({
    super.key,
    this.firstRun = false,
    this.launchInfo = LaunchInfo.none,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();

    AdvancedInAppReview()
        .setMinDaysBeforeRemind(7)
        .setMinDaysAfterInstall(1)
        .setMinLaunchTimes(5)
        .setMinSecondsBeforeShowDialog(3)
        .monitor();

    LinkRouter.inAppHandler = _openTwitchLinkInApp;
    LinkRouter.externalLinkGate = (url) {
      final settings = context.read<SettingsStore>();
      return confirmExternalLink(
        navigatorKey.currentContext,
        url,
        ask: settings.confirmExternalLinks,
        stopAsking: () => settings.confirmExternalLinks = false,
      );
    };
    _initDeepLinks();
    _initGoLive();
    unawaited(NotificationSettingsLink().listen(_openNotificationSettings));
  }

  void _openNotificationSettings() {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        final navigator = navigatorKey.currentState;
        if (!mounted || navigator == null) return;
        const page = SettingsPageId.notifications;
        unawaited(
          navigator.push(
            MaterialPageRoute(
              settings: RouteSettings(name: settingsRouteName(page)),
              builder: (context) => SettingsScaffold(
                title: page.title(context.l10n),
                body: buildSettingsPage(
                  page,
                  settingsStore: context.read<SettingsStore>(),
                  authStore: context.read<AuthStore>(),
                ),
              ),
            ),
          ),
        );
      })
      ..scheduleFrame();
  }

  /// A tapped go-live notice opens its channel, whether the app was running
  /// or started from it.
  Future<void> _initGoLive() async {
    // The channel deep link path: looks the channel up and opens it here.
    void openChannel(String login) => unawaited(_openGoLiveNotice(login));
    try {
      await GoLiveNotifications.init(
        onOpen: openChannel,
        onMention: _openMention,
      );
      final notice = await GoLiveNotifications.launchNotice();
      if (notice != null) {
        await WidgetsBinding.instance.endOfFrame;
        if (notice.mention) {
          _openMention(notice.login);
        } else {
          openChannel(notice.login);
        }
      }
      // Registered again at each launch: Android drops it after a force
      // stop, and an update may move the background entry point.
      final prefs = await GoLivePrefs.load();
      if (prefs.enabled) await GoLiveScheduler.start();
    } catch (e, stack) {
      debugPrint('Go-live notices unavailable: $e');
      Telemetry.recordError(e, stack, reason: 'go-live init');
    }
  }

  Future<void> _openGoLiveNotice(String login) async {
    final lookup = StreamEndLookup(
      api: context.read<TwitchApi>(),
      vods: context.read<TwitchVodService>(),
    );
    final latest = lookup.latestBroadcastIfOffline(login);
    await handleDeepLink(Uri.https('www.twitch.tv', '/$login'));
    final vod = await latest;
    if (!mounted || vod == null) return;
    final channel = VideoChat.routeOf(login);
    final navigator = navigatorKey.currentState;
    if (navigator == null || channel == null || !channel.isCurrent) return;
    navigator.replace(
      oldRoute: channel,
      newRoute: MaterialPageRoute<void>(
        settings: const RouteSettings(name: VodScreen.routeName),
        builder: (context) => VodScreen(vodId: vod.id, vod: vod),
      ),
    );
  }

  /// A tapped mention notice: its chat back on screen. The channel is
  /// usually still open (the app was only in the background) and simply
  /// comes back; under pages that may close (a profile, search, settings)
  /// those close; under a player or a conversation nothing closes and a
  /// notice says where the mention is; in the mini player it is restored;
  /// closed, it opens.
  void _openMention(String login) {
    if (!mounted) return;
    final mini = context.read<MiniPlayerStore>();
    final route = VideoChat.routeOf(login);
    final above = route == null
        ? const <Route<dynamic>>[]
        : OnsetShell.routeObserver.above(route);
    switch (mentionTapFor(
      login,
      open: route != null,
      shown: route?.isCurrent ?? false,
      closable: mentionMayClose([for (final page in above) page.settings.name]),
      miniLogin: mini.userLogin,
    )) {
      case MentionTap.bringToFront:
        return;
      case MentionTap.backToChannel:
        navigatorKey.currentState?.popUntil((page) => page == route);
      case MentionTap.notice:
        final navigatorContext = navigatorKey.currentContext;
        if (navigatorContext == null) return;
        ScaffoldMessenger.maybeOf(navigatorContext)
          ?..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(navigatorContext.l10n.mentionNotice(login: login)),
            ),
          );
      case MentionTap.restoreMini:
        GlobalMiniPlayer.restore(mini);
      case MentionTap.openChannel:
        unawaited(handleDeepLink(Uri.https('www.twitch.tv', '/$login')));
    }
  }

  /// The channel's display name, or [login] when it cannot be had.
  Future<String> _displayNameOf(String login) async {
    try {
      final user = await context.read<TwitchApi>().getUser(userLogin: login);
      return user.displayName;
    } catch (e) {
      debugPrint('Channel link: no user for $login: $e');
      return login;
    }
  }

  /// Opens a category link: its page when Twitch's search finds it, else
  /// the twitch.tv page in the app.
  Future<void> _openCategoryLink(
    CategoryLink link, {
    CategorySection section = CategorySection.live,
  }) async {
    String? id;
    try {
      id = await CategoryStreams.idOf(context.read<TwitchApi>(), link);
    } catch (e) {
      debugPrint('Category link: lookup failed: ${e.runtimeType}');
    }
    if (!mounted) return;
    if (id != null) {
      final categoryId = id;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => navigatorKey.currentState?.push(
          MaterialPageRoute(
            settings: const RouteSettings(name: CategoryStreams.routeName),
            builder: (context) => CategoryStreams(
              categoryId: categoryId,
              initialSection: section,
            ),
          ),
        ),
      );
      return;
    }
    final navigatorContext = navigatorKey.currentContext;
    if (navigatorContext == null || !navigatorContext.mounted) return;
    await TwitchWebPage.open(
      navigatorContext,
      title: link.name ?? navigatorContext.l10n.deepLinkCategoryFallback,
      url: twitchCategoryUrl(link),
    );
  }

  Future<bool> _openAppDestination(TwitchLink link) async {
    switch (link) {
      case BrowseLink():
        return _openShellPlace(ShellPlace.browse);
      case FollowingLink():
        return _openShellPlace(ShellPlace.following);
      case ActivityLink():
        return _openShellPlace(ShellPlace.activity);
      case SearchLink(:final term):
        return Home.openSearch(term);
      case CategoryVideosLink(:final category):
        await _openCategoryLink(category, section: CategorySection.videos);
        return true;
      case CollectionLink(:final collectionId):
        final vodId = await context
            .read<TwitchVodService>()
            .firstVideoOfCollection(collectionId);
        if (vodId == null) return false;
        return _openTwitchLinkInApp(VodLink(vodId, collectionId: collectionId));
      default:
        return false;
    }
  }

  bool _openShellPlace(ShellPlace place) {
    if (VideoChat.leaveForShell()) {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    return Home.openPlace(place);
  }

  /// Opens video and clip links in-app (from chat or deep links).
  Future<bool> _openTwitchLinkInApp(TwitchLink link) async {
    final Route<void> route;
    switch (link) {
      case VodLink(:final vodId, :final startAt, :final collectionId):
        route = MaterialPageRoute(
          settings: const RouteSettings(name: VodScreen.routeName),
          builder: (context) => VodScreen(
            vodId: vodId,
            startAt: startAt,
            collectionId: collectionId,
          ),
        );
      case ChannelVideosLink(:final login, :final type):
        final displayName = await _displayNameOf(login);
        route = MaterialPageRoute(
          settings: const RouteSettings(name: ChannelVideosScreen.routeName),
          builder: (context) => ChannelVideosScreen(
            userLogin: login,
            displayName: displayName,
            initialTab: type ?? VodType.archive,
          ),
        );
      case ClipLink(:final slug):
        route = MaterialPageRoute(
          settings: const RouteSettings(name: ClipScreen.routeName),
          builder: (context) => ClipScreen(slug: slug),
        );
      case ChannelClipsLink(:final login, :final period):
        final displayName = await _displayNameOf(login);
        route = MaterialPageRoute(
          settings: const RouteSettings(name: ChannelVideosScreen.routeName),
          builder: (context) => ChannelVideosScreen(
            userLogin: login,
            displayName: displayName,
            startOnClips: true,
            clipPeriod: period ?? ClipPeriod.lastWeek,
          ),
        );
      case ChannelProfileLink(:final login, :final section):
        route = MaterialPageRoute(
          settings: const RouteSettings(name: ChannelProfileScreen.routeName),
          builder: (context) => ChannelProfileScreen(
            login: login,
            initialTab: switch (section) {
              ProfileSection.about => ProfileTab.about,
              ProfileSection.schedule => ProfileTab.schedule,
            },
          ),
        );
      case ChannelLink() ||
          CategoryLink() ||
          CategoryVideosLink() ||
          ChannelChatLink() ||
          CollectionLink() ||
          SearchLink() ||
          BrowseLink() ||
          FollowingLink() ||
          ActivityLink() ||
          OtherLink():
        return false;
    }
    if (navigatorKey.currentState == null) return false;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => navigatorKey.currentState?.push(route),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final settingsStore = context.read<SettingsStore>();
        final themes = OnsetThemes(
          colorSchemeSeed: Color(settingsStore.accentColor),
        );

        return MaterialApp(
          title: 'ONSET',
          // The language picked, or the device's (resolveAppLocale).
          locale: settingsStore.appLanguage.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          localeListResolutionCallback: (device, _) =>
              resolveAppLocale(AppLanguage.system, device ?? const []),
          theme: themes.light,
          darkTheme: themes.dark,
          themeMode: settingsStore.themeType == ThemeType.system
              ? ThemeMode.system
              : settingsStore.themeType == ThemeType.light
              ? ThemeMode.light
              : ThemeMode.dark,
          navigatorObservers: [
            ...Telemetry.navigatorObservers(),
            // Any page opening ends the launch intro.
            LaunchIntro.navigatorObserver,
            OnsetShell.routeObserver,
          ],
          home: widget.firstRun ? const OnboardingFlow() : const Home(),
          navigatorKey: navigatorKey,
          // The launch intro covers the app on a cold start while it builds
          // and loads underneath.
          builder: (context, child) => LocaleSync(
            // The language shown, for what runs without the app's widgets:
            // the background check, the reminders the system keeps (worded
            // again only when the language changed), the media
            // notification.
            onLocale: [
              rememberUiLanguage(
                onChanged: () async {
                  await ScheduleReminders.shared?.reschedule();
                },
              ),
              (_) => unawaited(
                BackgroundAudio.shared.setLabels(mediaLabelsOf(L10n.current)),
              ),
            ],
            child: LaunchIntro(
              play: widget.launchInfo.playsIntro,
              fromTile: widget.launchInfo.nativeTile,
              // The first run stops on the name: the onboarding picks it up
              // from there.
              holdOnName: widget.firstRun,
              splashTile: LaunchInfo.splashTile,
              // The tile lands on the header's mark.
              slotKey: OnsetShell.markKey,
              child: Stack(
                children: [
                  ?child,
                  const Positioned.fill(child: GlobalMiniPlayer()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _initDeepLinks() async {
    try {
      // Handle links when app is already open
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
        handleDeepLink(uri);
      });

      // Handle the initial link if app was opened from a link.
      // Add timeout to prevent indefinite blocking on certain Android lifecycle states.
      final initialLink = await _appLinks.getInitialLink().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (initialLink != null) {
        handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Failed to initialize deep links: $e');
    }
  }

  Future<void> handleDeepLink(Uri uri) async {
    // A link or a go-live notice opens its page straight away.
    LaunchIntro.skipAll();
    // Videos open in-app; every other link keeps the handling below.
    final link = TwitchLink.parse(uri);
    if (link.opensInApp && await _openTwitchLinkInApp(link)) {
      return;
    }
    if (!mounted) return;
    // A category: its page, never a channel named "directory".
    if (link is CategoryLink) {
      await _openCategoryLink(link);
      return;
    }
    if (await _openAppDestination(link)) return;
    if (!mounted) return;

    // In the language of the screen the snackbar shows over.
    final l = (navigatorKey.currentContext ?? context).l10n;
    final failureSnackbar = SnackBar(
      content: AlertMessage(
        message: l.deepLinkFailed(uri: '$uri'),
        centered: false,
        trailingIcon: Icons.open_in_browser_rounded,
        trailingTooltip: l.deepLinkOpenInBrowser,
        // Fallback, allow user to open URL outside app
        onTrailingIconPressed: () async {
          await launchUrl(
            TwitchLink.webUri(uri) ?? uri,
            mode: LaunchMode.inAppWebView, // Force browser
          );
        },
      ),
    );

    final channelName = switch (link) {
      ChannelLink(:final login) || ChannelChatLink(:final login) => login,
      _ when TwitchLink.webUri(uri) == uri && uri.pathSegments.isNotEmpty =>
        uri.pathSegments.first,
      _ => null,
    };
    if (channelName != null) {
      try {
        final twitchApi = context.read<TwitchApi>();

        final user = await twitchApi.getUser(userLogin: channelName);

        final route = MaterialPageRoute(
          settings: const RouteSettings(name: VideoChat.routeName),
          builder: (context) => VideoChat(
            userId: user.id,
            userName: user.displayName,
            userLogin: user.login,
            startChatOnly: link is ChannelChatLink,
          ),
        );

        if (navigatorKey.currentState == null) return;

        WidgetsBinding.instance.addPostFrameCallback(
          (_) => navigatorKey.currentState?.push(route),
        );
      } catch (e) {
        // If we get here, there was most likely an error with the Twitch API call and/or this isn't really a channel link
        debugPrint('Failed to open link $uri due to error: $e');

        if (navigatorKey.currentContext == null) return;
        ScaffoldMessenger.of(
          navigatorKey.currentContext!,
        ).showSnackBar(failureSnackbar);
      }
    }
    // TODO: Here we can implement handlers for other types of links
    else {
      // If we get here, it's a link format that we're unable to handle
      if (navigatorKey.currentContext == null) return;
      ScaffoldMessenger.of(
        navigatorKey.currentContext!,
      ).showSnackBar(failureSnackbar);
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }
}
