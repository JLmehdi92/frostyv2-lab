// Screenshots of the real app for the README, drawn by the real widgets.
//
// Not part of the test suite (it lives outside test/). To rewrite the PNGs
// in .github/assets/screenshots/ and shrink them, in one command:
//
//   python3 tool/readme_shots/render.py
//
// (`flutter test tool/readme_shots/readme_shots_test.dart` alone writes them
// full-colour.)
//
// Every screen is pumped the way the app builds it, with fake stores and
// services standing in for Twitch. The content is invented and neutral: no
// real channel, no Twitch artwork, no third-party emotes. Stream previews
// and avatars are abstract frames painted here (see `_Art`), served through
// the image cache in place of the network.
//
// It is a test that lives outside test/, so the analyzer does not know it
// may call the members made visible for tests.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show Observable, ObservableList, ObservableMap;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/apis/twitch_followed_categories_service.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/apis/twitch_watch_streak_service.dart';
import 'package:onset/models/cheermote.dart';
import 'package:onset/models/followed_category.dart';
import 'package:onset/models/followed_channel.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/user.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/activity/stores/activity_store.dart';
import 'package:onset/screens/channel/chat/chat.dart';
import 'package:onset/screens/channel/chat/details/stores/chat_details_store.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/screens/channel/video/latency_pill.dart';
import 'package:onset/screens/channel/video/video_overlay.dart';
import 'package:onset/screens/home/home.dart';
import 'package:onset/screens/settings/profile_tab.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/screens/vod/vod_resume.dart';
import 'package:onset/services/cache_manager.dart';
import 'package:onset/services/notifications/activity_log.dart';
import 'package:onset/services/onset_updater.dart';
import 'package:onset/stores/mini_player_store.dart';
import 'package:onset/stores/whisper_store.dart';
import 'package:onset/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/helpers/chat_store_harness.dart' show FakeSocket;
import '../../test/helpers/fake_player.dart';

/// Where the PNGs go, from the repository root.
const _outDir = '.github/assets/screenshots';

/// A phone (dp) and its pixel ratio in the PNG.
const _phone = Size(412, 915);
const _phoneRatio = 2.0;

/// A landscape tablet (dp) and its pixel ratio in the PNG.
const _tablet = Size(1280, 800);
const _tabletRatio = 1.5;

/// Room for the system bars, in dp (left empty, as under real bars).
const _phonePadding = EdgeInsets.only(top: 28, bottom: 16);
const _tabletPadding = EdgeInsets.only(top: 24, bottom: 12);

// ------------------------------------------------------------- binding --

/// The test binding, with an image cache that answers network images with
/// the frames painted by [_Art] instead of going to the network.
class _ShotBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ImageCache createImageCache() => _ArtImageCache();
}

class _ArtImageCache extends ImageCache {
  final _order = <Object, int>{};

  @override
  void clear() {
    _order.clear();
    super.clear();
  }

  @override
  ImageStreamCompleter? putIfAbsent(
    Object key,
    ImageStreamCompleter Function() loader, {
    ImageErrorListener? onError,
  }) {
    ImageStreamCompleter art(Object which) => OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: _Art.pick(which).clone())),
    );
    return switch (key) {
      // Avatars (no decode size): the URL says whose.
      CachedNetworkImageProvider(:final url) => super.putIfAbsent(
        key,
        () => art(url),
        onError: onError,
      ),
      // Decoded at a size: a network image (previews, box art) or an
      // asset. Only the network image's own loader is a
      // [MultiImageStreamCompleter]; it is dropped, quietly, before it
      // reaches the network. The key does not say which preview it is:
      // the first one asked gets the first frame, and so on, the same on
      // every run.
      ResizeImageKey() => super.putIfAbsent(key, () {
        final real = loader();
        if (real is! MultiImageStreamCompleter) return real;
        real.addListener(ImageStreamListener((_, _) {}, onError: (_, _) {}));
        return art(_order.putIfAbsent(key, () => _order.length));
      }, onError: onError),
      _ => super.putIfAbsent(key, loader, onError: onError),
    };
  }
}

// ---------------------------------------------------------------- art --

/// Abstract frames standing in for stream previews and avatars: deep
/// gradients, soft light and the logo's halftone, nothing recognisable.
abstract final class _Art {
  static final _previews = <ui.Image>[];
  static final _avatars = <ui.Image>[];

  /// Gradient pairs (top left, bottom right) and a light colour.
  static const _palettes = [
    (Color(0xFF0E2A3B), Color(0xFF061018), Color(0xFF3FA7C9)),
    (Color(0xFF2B1240), Color(0xFF0B0612), Color(0xFFB46CE8)),
    (Color(0xFF3A230C), Color(0xFF120A04), Color(0xFFF0A23C)),
    (Color(0xFF1C3A12), Color(0xFF070F05), Color(0xFFC8FF3D)),
    (Color(0xFF3B1020), Color(0xFF12050A), Color(0xFFFF6B81)),
    (Color(0xFF10303A), Color(0xFF050E12), Color(0xFF5FE0C0)),
    (Color(0xFF1E1E2E), Color(0xFF09090F), Color(0xFF8C9BFF)),
    (Color(0xFF34300E), Color(0xFF100E04), Color(0xFFE8D45A)),
  ];

  static Future<void> paint() async {
    if (_previews.isNotEmpty) return;
    for (var i = 0; i < _palettes.length; i++) {
      _previews.add(await _frame(i, 960, 540));
      _avatars.add(await _frame(i, 160, 160, avatar: true));
    }
  }

  static ui.Image pick(Object key) {
    if (key is String) {
      // An avatar URL ends with the login.
      final h = key.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0xFFFF);
      return _avatars[h % _avatars.length];
    }
    return _previews[(key as int) % _previews.length];
  }

  static Future<ui.Image> _frame(
    int seed,
    int w,
    int h, {
    bool avatar = false,
  }) async {
    final (from, to, light) = _palettes[seed];
    final random = math.Random(seed * 7 + (avatar ? 1 : 0));
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(w.toDouble(), h.toDouble());
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          [from, to],
        ),
    );
    // Soft light, two or three blooms.
    for (var i = 0; i < (avatar ? 1 : 3); i++) {
      final c = Offset(
        size.width * (0.2 + random.nextDouble() * 0.6),
        size.height * (0.2 + random.nextDouble() * 0.6),
      );
      final r = size.shortestSide * (0.35 + random.nextDouble() * 0.4);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(c, r, [
            light.withValues(alpha: 0.55 - i * 0.12),
            light.withValues(alpha: 0),
          ]),
      );
    }
    // The halftone of the ONSET logo, faint, growing towards a corner.
    final pitch = size.shortestSide / (avatar ? 9 : 16);
    final origin = Offset(size.width * 0.85, size.height * 0.15);
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.10);
    for (var y = pitch / 2; y < size.height; y += pitch) {
      for (var x = pitch / 2; x < size.width; x += pitch) {
        final d = (Offset(x, y) - origin).distance / size.longestSide;
        final r = pitch * 0.42 * (1 - d).clamp(0.0, 1.0);
        if (r > 0.4) canvas.drawCircle(Offset(x, y), r, dot);
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    picture.dispose();
    return image;
  }
}

// -------------------------------------------------------------- fonts --

/// Loads every font the app bundles (Inter, the icon fonts), so text is not
/// drawn in the test font, and Roboto from the Flutter SDK for the text the
/// app leaves to the platform's font (see [_usePlatformFont]).
Future<void> _loadFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final family = entry['family'] as String;
    final loader = FontLoader(family.split('/').last);
    for (final font in (entry['fonts'] as List<dynamic>).cast<Map>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  final roboto = FontLoader('Roboto');
  for (final file in _sdkFonts().listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (name.startsWith('Roboto-') && name.endsWith('.ttf')) {
      roboto.addFont(
        file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    }
  }
  await roboto.load();
}

/// The Flutter SDK's Material fonts, found from the test runner's own path
/// (it lives in the SDK's cache).
Directory _sdkFonts() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    final fonts = Directory('${dir.path}/artifacts/material_fonts');
    if (fonts.existsSync()) return fonts;
    dir = dir.parent;
  }
  throw StateError('Flutter SDK fonts not found');
}

/// Names the platform's font on every paragraph on screen that leaves its
/// family to the platform: Android draws those in Roboto, the test engine in
/// boxes. Families the app names are kept (the outer span only fills in
/// what its children leave unset).
void _usePlatformFont(WidgetTester tester) {
  const platform = TextStyle(fontFamily: 'Roboto');
  void visit(RenderObject object) {
    if (object is RenderParagraph) {
      final text = object.text;
      final style = text.style;
      if (style == null || style.inherit) {
        object.text = TextSpan(style: platform, children: [text]);
      } else if (style.fontFamily == null && text is TextSpan) {
        object.text = TextSpan(
          style: style.copyWith(fontFamily: 'Roboto'),
          text: text.text,
          children: text.children,
        );
      }
    }
    object.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
}

// ------------------------------------------------------ image manager --

/// Builds the app's image cache manager once, in a zone that drops its
/// start-up errors: it opens a folder and an SQLite index through plugins
/// a test does not have. It is never asked for an image (the image cache
/// answers first); the network images only hand it to their provider.
void _startImageManager() {
  runZonedGuarded(() => CustomCacheManager.instance, (error, stack) {});
}

// -------------------------------------------------------------- fakes --

class _MockTwitchApi extends Mock implements TwitchApi {}

class _MockHypeTrainService extends Mock implements TwitchHypeTrainService {}

class _MockUserStore extends Mock implements UserStore {}

class _MockVodService extends Mock implements TwitchVodService {}

class _MockFollowedCategories extends Mock
    implements TwitchFollowedCategoriesService {}

/// The viewer, signed in.
const _viewer = UserTwitch('1000', 'viewer', 'Viewer', _avatarBase);

const _avatarBase = 'https://onset.invalid/avatar/';

class _FakeAuthStore extends Mock implements AuthStore {
  _FakeAuthStore() {
    when(() => _user.details).thenReturn(_viewer);
    when(() => _user.blockedUsers).thenReturn(ObservableList());
    when(() => _user.refreshBlockedUsers()).thenAnswer((_) async {});
  }

  final _user = _MockUserStore();
  final _loggedIn = Observable(true);

  @override
  bool get isLoggedIn => _loggedIn.value;

  @override
  UserStore get user => _user;

  @override
  String? get error => null;

  /// A web session, so the followed categories load.
  @override
  String? get twitchWebToken => 'web-session';

  @override
  bool get webSessionExpired => false;

  @override
  String? get tokenNotice => null;

  @override
  String? get token => null;

  @override
  Map<String, String> get headersTwitch => const {};
}

/// A followed channel live now.
typedef _Live = ({
  String login,
  String name,
  String category,
  String title,
  int viewers,
  Duration since,
  List<String> tags,
});

const List<_Live> _live = [
  (
    login: 'harborlights',
    name: 'HarborLights',
    category: 'Music',
    title: 'Late night synth session, building a track from scratch',
    viewers: 18240,
    since: Duration(hours: 2, minutes: 14),
    tags: ['English', 'Synthwave'],
  ),
  (
    login: 'pixelgarden',
    name: 'PixelGarden',
    category: 'Art',
    title: 'Painting a city at dusk, one layer at a time',
    viewers: 6315,
    since: Duration(hours: 1, minutes: 3),
    tags: ['English', 'DigitalArt'],
  ),
  (
    login: 'fieldnotes',
    name: 'FieldNotes',
    category: 'Science & Technology',
    title: 'Soldering a tiny weather station, questions welcome',
    viewers: 2870,
    since: Duration(hours: 3, minutes: 40),
    tags: ['English', 'Electronics'],
  ),
  (
    login: 'slowcraft',
    name: 'SlowCraft',
    category: 'Makers & Crafting',
    title: 'Hand-cutting dovetails for a walnut box',
    viewers: 1468,
    since: Duration(minutes: 47),
    tags: ['English', 'Woodworking'],
  ),
  (
    login: 'nightshiftradio',
    name: 'NightShiftRadio',
    category: 'Just Chatting',
    title: 'Coffee, music requests and your week',
    viewers: 984,
    since: Duration(hours: 5, minutes: 2),
    tags: ['English', 'Chill'],
  ),
  (
    login: 'kilocourse',
    name: 'KiloCourse',
    category: 'Software and Game Development',
    title: 'Writing a tiny game engine in a weekend, day 2',
    viewers: 512,
    since: Duration(hours: 1, minutes: 25),
    tags: ['English', 'Programming'],
  ),
];

const _offline = [
  ('quietlake', 'QuietLake'),
  ('tidewatch', 'TideWatch'),
  ('emberstudio', 'EmberStudio'),
];

final _now = DateTime.now().toUtc();

List<StreamTwitch> _streams() => [
  for (final (i, s) in _live.indexed)
    StreamTwitch(
      '${2000 + i}',
      s.login,
      s.name,
      '${500 + i}',
      s.category,
      s.title,
      s.viewers,
      _now.subtract(s.since).toIso8601String(),
      'https://onset.invalid/preview/${s.login}-{width}x{height}.jpg',
      tags: s.tags,
      language: 'en',
      id: '${9000 + i}',
    ),
];

_MockTwitchApi _api() {
  final api = _MockTwitchApi();
  when(
    () => api.getFollowedStreams(
      id: any(named: 'id'),
      cursor: any(named: 'cursor'),
      first: any(named: 'first'),
      quiet: any(named: 'quiet'),
    ),
  ).thenAnswer((_) async => StreamsTwitch(_streams(), const {}));
  when(
    () => api.getFollowedChannels(
      userId: any(named: 'userId'),
      cursor: any(named: 'cursor'),
    ),
  ).thenAnswer(
    (_) async => FollowedChannels(
      data: [
        for (final (i, s) in _live.indexed)
          FollowedChannel(
            broadcasterId: '${2000 + i}',
            broadcasterLogin: s.login,
            broadcasterName: s.name,
            followedAt: DateTime.utc(2025, 1, 1 + i),
          ),
        for (final (i, (login, name)) in _offline.indexed)
          FollowedChannel(
            broadcasterId: '${3000 + i}',
            broadcasterLogin: login,
            broadcasterName: name,
            followedAt: DateTime.utc(2025, 2, 1 + i),
          ),
      ],
      pagination: const {},
      total: _live.length + _offline.length,
    ),
  );
  when(
    () => api.getStreamsByIds(userIds: any(named: 'userIds')),
  ).thenAnswer((_) async => const StreamsTwitch([], {}));
  when(
    () => api.getUser(
      userLogin: any(named: 'userLogin'),
      id: any(named: 'id'),
    ),
  ).thenAnswer((invocation) async {
    final login = invocation.namedArguments[#userLogin] as String? ?? 'viewer';
    return UserTwitch('1', login, login, '$_avatarBase$login.png');
  });
  return api;
}

_MockHypeTrainService _hypeTrains() {
  final service = _MockHypeTrainService();
  when(
    () => service.getActiveStatuses(any()),
  ).thenAnswer((_) async => {'2001': const HtCardStatus(level: 3)});
  return service;
}

_MockFollowedCategories _categories() {
  final service = _MockFollowedCategories();
  when(
    () => service.getFollowedCategories(authToken: any(named: 'authToken')),
  ).thenAnswer(
    (_) async => [
      for (final (i, (name, viewers)) in const [
        ('Music', 48200),
        ('Art', 21900),
        ('Science & Technology', 9400),
        ('Makers & Crafting', 6100),
      ].indexed)
        FollowedCategory(
          id: '${500 + i}',
          name: name,
          displayName: name,
          boxArtUrl: 'https://onset.invalid/category/$i-285x380.jpg',
          viewers: viewers,
        ),
    ],
  );
  return service;
}

/// Two past broadcasts the viewer left halfway: Continue watching.
_MockVodService _vods() {
  final service = _MockVodService();
  when(() => service.viewerId).thenReturn(() => _viewer.id);
  when(() => service.getResumeWatching(limit: any(named: 'limit'))).thenAnswer(
    (_) async => [
      for (final (i, (title, owner, length, at)) in const [
        ('Modular patching from zero', 'harborlights', 9240, 3100),
        ('Restoring an old hand plane', 'slowcraft', 7380, 5200),
      ].indexed)
        ResumeWatchingEntry(
          vod: Vod(
            id: '${7000 + i}',
            title: title,
            lengthSeconds: length,
            createdAt: _now.subtract(Duration(days: 2 + i)),
            viewCount: 1200 + i * 800,
            ownerId: '${2000 + i}',
            ownerLogin: owner,
            ownerDisplayName: _live.firstWhere((s) => s.login == owner).name,
            previewThumbnailUrl:
                'https://onset.invalid/vod/$i-%{width}x%{height}.jpg',
            gameName: i == 0 ? 'Music' : 'Makers & Crafting',
          ),
          history: ViewingHistory(
            positionSec: at,
            updatedAt: _now.subtract(Duration(hours: 5 + i * 20)),
          ),
        ),
    ],
  );
  return service;
}

class _MockChatAssets extends Mock implements ChatAssetsStore {}

class _MockChatStore extends Mock implements ChatStore {}

/// The chat of [_live]'s first channel, read from IRC lines through the
/// app's own parser: viewers talking, a /me, a mention of the viewer, a
/// message deleted by a moderator and a timeout.
const _chatLines = [
  ('pixelmoth', '#E8D45A', 'evening everyone'),
  ('lowtide', '#F0A23C', 'just got here, what did I miss?'),
  ('tinkerwave', '#B46CE8', 'a whole new patch from an empty rack'),
  ('quietfern', '#3FA7C9', 'the reverb on that lead is so wide'),
  ('mossbyte', '#5FE0C0', 'that bassline is unreal'),
  ('tinkerwave', '#B46CE8', 'what synth is that pad?'),
  ('harborlights', '#C8FF3D', 'a little analog poly, recorded dry'),
  ('lowtide', '#F0A23C', 'first time catching this live, the latency is tiny'),
  ('quietfern', '#3FA7C9', '\x01ACTION waves from the night shift\x01'),
  ('spamcan', '#FF6B81', 'buy followers at a totally real site'),
  ('mossbyte', '#5FE0C0', '@viewer you made it, it gets good at the drop'),
  ('pixelmoth', '#E8D45A', 'can you loop the arp for a bit?'),
  ('harborlights', '#C8FF3D', 'looping it now, then we add drums'),
  ('tinkerwave', '#B46CE8', 'this is my focus music for the week'),
];

List<String> _ircLines() {
  final lines = <String>[];
  for (final (i, (login, color, text)) in _chatLines.indexed) {
    final broadcaster = login == 'harborlights';
    final ts = _now.millisecondsSinceEpoch - (_chatLines.length - i) * 9000;
    lines.add(
      '@badge-info=;badges=${broadcaster ? 'broadcaster/1' : ''};'
      'color=$color;display-name=$login;emotes=;id=line-$i;mod=0;'
      'room-id=2000;subscriber=0;tmi-sent-ts=$ts;turbo=0;'
      'user-id=${broadcaster ? 2000 : 4000 + i};user-type= '
      ':$login!$login@$login.tmi.twitch.tv PRIVMSG #harborlights :$text',
    );
    if (login == 'spamcan') {
      // Deleted by a moderator, then the sender timed out.
      lines
        ..add(
          '@login=spamcan;room-id=2000;target-msg-id=line-$i;tmi-sent-ts=$ts '
          ':tmi.twitch.tv CLEARMSG #harborlights :$text',
        )
        ..add(
          '@ban-duration=600;room-id=2000;target-user-id=${4000 + i};'
          'tmi-sent-ts=$ts :tmi.twitch.tv CLEARCHAT #harborlights :spamcan',
        );
    }
  }
  return lines;
}

/// A chat store of the first channel, signed in, on a fake socket that
/// [sockets] receives.
ChatStore _chatStore(
  SettingsStore settings,
  _FakeAuthStore auth,
  TwitchApi api,
  List<FakeSocket> sockets,
) {
  final assets = _MockChatAssets();
  when(() => assets.init()).thenAnswer((_) async {});
  when(() => assets.showEmoteMenu).thenReturn(false);
  when(() => assets.sevenTvEmoteSetId).thenReturn(null);
  when(() => assets.cheermotes).thenReturn(Cheermotes.empty);
  when(() => assets.emoteToObject).thenReturn({});
  when(() => assets.userEmoteToObject).thenReturn({});
  when(() => assets.twitchBadgesToObject).thenReturn({});
  when(() => assets.userToFFZBadges).thenReturn({});
  when(() => assets.userTo7TVBadges).thenReturn({});
  when(() => assets.userToBTTVBadges).thenReturn({});
  when(() => assets.ffzRoomInfo).thenReturn(null);
  when(() => assets.channelIdToUserTwitch).thenReturn(ObservableMap());
  when(
    () => assets.assetsFuture(
      channelId: any(named: 'channelId'),
      headers: any(named: 'headers'),
      onEmoteError: any(named: 'onEmoteError'),
      onBadgeError: any(named: 'onBadgeError'),
      showTwitchEmotes: any(named: 'showTwitchEmotes'),
      showTwitchBadges: any(named: 'showTwitchBadges'),
      show7TVEmotes: any(named: 'show7TVEmotes'),
      showBTTVEmotes: any(named: 'showBTTVEmotes'),
      showBTTVBadges: any(named: 'showBTTVBadges'),
      showFFZEmotes: any(named: 'showFFZEmotes'),
      showFFZBadges: any(named: 'showFFZBadges'),
    ),
  ).thenAnswer((_) async {});
  return ChatStore(
    twitchApi: api,
    auth: auth,
    chatDetailsStore: ChatDetailsStore(
      twitchApi: api,
      channelName: 'harborlights',
    ),
    assetsStore: assets,
    settings: settings,
    channelName: 'harborlights',
    channelId: '2000',
    displayName: 'HarborLights',
    connectSocket: (uri) {
      final socket = FakeSocket(uri);
      sockets.add(socket);
      return socket;
    },
  );
}

// -------------------------------------------------------------- shots --

final _themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);

final _shotKey = GlobalKey();

/// What a shot leaves running (stores with timers), stopped once it is
/// taken.
final _afterShot = <VoidCallback>[];

/// Sizes the window like a [size] dp screen at [ratio], with [padding]
/// for the system bars.
void _useScreen(
  WidgetTester tester,
  Size size,
  double ratio,
  EdgeInsets padding,
) {
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  tester.view.padding = FakeViewPadding(
    top: padding.top * ratio,
    bottom: padding.bottom * ratio,
  );
  tester.view.viewPadding = FakeViewPadding(
    top: padding.top * ratio,
    bottom: padding.bottom * ratio,
  );
  addTearDown(tester.view.reset);
}

/// The app's frame around [home], dark, with [providers].
Widget _app(Widget home, List<Provider<Object?>> providers) => MultiProvider(
  providers: providers,
  child: RepaintBoundary(
    key: _shotKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _themes.light,
      darkTheme: _themes.dark,
      themeMode: ThemeMode.dark,
      home: home,
    ),
  ),
);

/// Lets [tester] run [frames] frames of [step].
Future<void> _settle(
  WidgetTester tester, {
  int frames = 30,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// The [Image]s on screen still waiting for their first frame.
List<Image> _undecoded(WidgetTester tester) => [
  for (final element in find.byType(Image).evaluate())
    if (find
        .descendant(
          of: find.byWidget(element.widget),
          matching: find.byType(RawImage),
        )
        .evaluate()
        .any((raw) => (raw.widget as RawImage).image == null))
      element.widget as Image,
];

/// Waits until every image on screen has a frame. An asset is read from
/// disk and decoded by the engine, real work that the test's fake clock
/// does not wait for: give it real time, then let the fake clock deliver
/// the result, until nothing is left (or a few seconds have passed).
Future<void> _decodeImages(WidgetTester tester) async {
  for (var i = 0; i < 50 && _undecoded(tester).isNotEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  final left = _undecoded(tester);
  expect(left, isEmpty, reason: 'images never decoded: $left');
}

/// Writes what is on screen to `<_outDir>/<name>.png`.
Future<void> _shoot(WidgetTester tester, String name) async {
  await _decodeImages(tester);
  _usePlatformFont(tester);
  await tester.pump();
  final boundary =
      _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ratio = tester.view.devicePixelRatio;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$_outDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  _ShotBinding();

  setUpAll(() async {
    _startImageManager();
    await _loadFonts();
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'ONSET',
      packageName: 'app.onset',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  /// A screenshot test: the art painted, the platform answered, the
  /// window sized, and the shadows on (tests draw none by default) while
  /// [body] runs.
  void shot(
    String name,
    Size size,
    double ratio,
    EdgeInsets padding,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(name, (tester) async {
      // The saved positions queue on a future of the previous screen's
      // clock: start it again on this one's.
      VodResumeRepository.shared.resetQueue();
      await tester.runAsync(_Art.paint);
      _useScreen(tester, size, ratio, padding);
      debugDisableShadows = false;
      try {
        await body(tester);
        await _shoot(tester, name);
        // Unmount, so the screen's timers stop inside the test.
        await tester.pumpWidget(const SizedBox());
        for (final dispose in _afterShot) {
          dispose();
        }
        _afterShot.clear();
        await _settle(tester, frames: 5);
      } finally {
        debugDisableShadows = true;
      }
    });
  }

  for (final (name, size, ratio, padding) in [
    ('home-phone', _phone, _phoneRatio, _phonePadding),
    ('home-tablet', _tablet, _tabletRatio, _tabletPadding),
  ]) {
    shot(name, size, ratio, padding, (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final auth = _FakeAuthStore();
      final settings = SettingsStore.fromJson({});
      final api = _api();
      final whispers = WhisperStore(
        twitchApi: api,
        listen: (_) => throw UnsupportedError('no whispers here'),
        currentUserId: () => null,
      );
      await tester.pumpWidget(
        _app(const Home(), [
          Provider<AuthStore>.value(value: auth),
          Provider<SettingsStore>.value(value: settings),
          Provider<TwitchApi>.value(value: api),
          Provider<WhisperStore>.value(value: whispers),
          Provider<ActivityStore>.value(
            value: ActivityStore(log: ActivityLog(prefs)),
          ),
          Provider<MiniPlayerStore>.value(value: MiniPlayerStore()),
          Provider<TwitchHypeTrainService>.value(value: _hypeTrains()),
          Provider<TwitchDirectoryService?>.value(value: null),
          Provider<TwitchFollowedCategoriesService?>.value(
            value: _categories(),
          ),
          Provider<TwitchWatchStreakService?>.value(value: null),
          Provider<TwitchVodService?>.value(value: _vods()),
          Provider<OnsetUpdater?>.value(value: null),
        ]),
      );
      await _settle(tester);
      // The shelf loads after the list: wait for it.
      await _settle(tester, frames: 10);
      expect(find.text('Continue watching'), findsOneWidget);
    });
  }

  for (final (name, size, ratio, padding) in [
    ('settings-phone', _phone, _phoneRatio, _phonePadding),
    ('settings-tablet', _tablet, _tabletRatio, _tabletPadding),
  ]) {
    shot(name, size, ratio, padding, (tester) async {
      final auth = _FakeAuthStore();
      final settings = SettingsStore.fromJson({});
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ProfileTab(settingsStore: settings, authStore: auth),
          ),
          [
            Provider<AuthStore>.value(value: auth),
            Provider<SettingsStore>.value(value: settings),
            Provider<TwitchApi>.value(value: _api()),
          ],
        ),
      );
      // The tablet opens on General. Video is left out: its page reads
      // the platform (Android shows the player engine), which a test on
      // a desktop host cannot pass for Android.
      await _settle(tester);
    });
  }

  shot('chat-phone', const Size(412, 520), _phoneRatio, EdgeInsets.zero, (
    tester,
  ) async {
    final auth = _FakeAuthStore();
    final settings = SettingsStore.fromJson({})
      ..autoSyncChatDelay = false
      ..chatDelay = 0;
    final api = _api();
    final sockets = <FakeSocket>[];
    final chat = _chatStore(settings, auth, api, sockets);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Chat(chatStore: chat, onAddChat: () {}),
        ),
        [
          Provider<AuthStore>.value(value: auth),
          Provider<SettingsStore>.value(value: settings),
          Provider<TwitchApi>.value(value: api),
          Provider<ChannelEventsStore?>.value(value: null),
        ],
      ),
    );
    await _settle(tester, frames: 5);
    // Twitch's welcome starts the chat's message flow.
    sockets.last.receive(':tmi.twitch.tv 001 viewer :Welcome, GLHF!');
    for (final line in _ircLines()) {
      sockets.last.receive(line);
    }
    await _settle(tester);
    expect(
      find.textContaining('looping it now', findRichText: true),
      findsOneWidget,
    );
    _afterShot.add(chat.dispose);
  });

  shot('player-phone', const Size(412, 232), _phoneRatio, EdgeInsets.zero, (
    tester,
  ) async {
    final settings = SettingsStore.fromJson({});
    final first = _streams().first;
    final player = FakePlayer(
      settings: settings,
      stream: first,
      latency: '1.8s',
    );
    final chat = _MockChatStore();
    when(() => chat.displayName).thenReturn(first.userName);
    when(() => chat.channelName).thenReturn(first.userLogin);
    when(() => chat.isInSharedChatMode).thenReturn(false);
    await tester.pumpWidget(
      _app(
        Scaffold(
          backgroundColor: Colors.black,
          // The channel screen's video stack: the picture, the controls,
          // and the latency over them where their top row leaves it room.
          body: Builder(
            builder: (context) {
              final metrics = PlayerChromeMetrics.of(context);
              return Stack(
                fit: StackFit.expand,
                children: [
                  RawImage(image: _Art.pick(0), fit: BoxFit.cover),
                  VideoOverlay(
                    videoStore: player,
                    chatStore: chat,
                    settingsStore: settings,
                  ),
                  Positioned(
                    top: metrics.pillTop,
                    right: metrics.pillEdge,
                    child: LatencyPill(store: player),
                  ),
                ],
              );
            },
          ),
        ),
        [Provider<TwitchApi>.value(value: _api())],
      ),
    );
    await _settle(tester, frames: 5);
  });
}
