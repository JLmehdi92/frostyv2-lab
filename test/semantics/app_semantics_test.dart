import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show Observable, ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/user.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/widgets/chat_bottom_bar.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/screens/channel/video/content_warning_gate.dart';
import 'package:onset/screens/channel_profile/widgets/profile_header.dart';
import 'package:onset/screens/channel_profile/widgets/profile_parts.dart';
import 'package:onset/screens/clips/clips_feed_screen.dart';
import 'package:onset/screens/clips/stores/clips_feed_store.dart';
import 'package:onset/screens/home/home_store.dart';
import 'package:onset/screens/home/live_feed/live_feed.dart';
import 'package:onset/screens/home/live_feed/live_preview.dart';
import 'package:onset/screens/home/live_feed/stores/live_feed_store.dart';
import 'package:onset/screens/home/shell/onset_shell.dart';
import 'package:onset/screens/onboarding/onboarding_flow.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/screens/vod/player_media.dart';
import 'package:onset/screens/vod/vod_overlay.dart';
import 'package:onset/stores/mini_player_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/channel_points_button.dart';
import 'package:onset/widgets/launch/launch_intro.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/chat_message_harness.dart';
import '../helpers/fake_vod_controller.dart';
import '../helpers/semantics_audit.dart';

/// A screen reader presses a control through its semantics node. A node
/// flagged as a button with no tap action reads "button" and does nothing:
/// that is what `Semantics(button: true, excludeSemantics: true)` around a
/// gesture detector gives when the Semantics does not carry the tap itself.
///
/// The main surfaces, at phone and tablet sizes, must have none; and the
/// source inventory below finds the pattern anywhere in lib/.

class _MockTwitchApi extends Mock implements TwitchApi {}

class _MockAuthStore extends Mock implements AuthStore {}

class _MockUserStore extends Mock implements UserStore {}

class _MockClipService extends Mock implements TwitchClipService {}

class _MockMiniPlayerStore extends Mock implements MiniPlayerStore {}

class _MockChannelEventsStore extends Mock implements ChannelEventsStore {}

class _OnboardingAuth extends Mock implements AuthStore {
  _OnboardingAuth() {
    when(
      () => _user.details,
    ).thenReturn(const UserTwitch('1', 'viewer', 'Viewer', ''));
    when(() => _user.blockedUsers).thenReturn(ObservableList());
  }

  final Observable<bool> _loggedIn = Observable(false);
  final _user = _MockUserStore();

  @override
  bool get isLoggedIn => _loggedIn.value;

  @override
  UserStore get user => _user;
}

class _Preview implements LivePreviewBackend {
  @override
  final ValueNotifier<bool> showing = ValueNotifier(false);

  @override
  Future<void> open(String url) async => showing.value = true;

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Widget buildVideo() => const ColoredBox(color: Color(0xFF00FF00));

  @override
  Future<void> dispose() async {}
}

const _phone = Size(390, 844);
const _tablet = Size(1280, 854);
const _sizes = {'phone': _phone, 'tablet': _tablet};

final _themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);

StreamTwitch _stream(int i) => StreamTwitch(
  '$i',
  'login$i',
  'Name $i',
  '10',
  'Just Chatting',
  'Title $i',
  1000 * (20 - i),
  '2026-10-28T10:00:00Z',
  'https://static-cdn.jtvnw.net/previews-ttv/live_user_login$i-{width}x{height}.jpg',
  tags: const ['Français'],
  language: 'fr',
);

Clip _clip(String slug) => Clip(
  id: slug,
  slug: slug,
  title: 'Clip $slug',
  viewCount: 1234,
  createdAt: DateTime.utc(2026, 10, 2),
  durationSeconds: 30,
  broadcasterId: '42',
  broadcasterLogin: 'streamer',
  broadcasterDisplayName: 'Streamer',
  gameName: 'Just Chatting',
);

void useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home, {ThemeMode mode = ThemeMode.dark}) => MaterialApp(
  theme: _themes.light,
  darkTheme: _themes.dark,
  themeMode: mode,
  home: home,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'ONSET',
      packageName: 'onset',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    group(name, () {
      testWidgets('the shell: header, whispers, search and navigation', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        useSize(tester, size);
        final picked = <ShellSection>[];
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: OnsetShell(
                section: ShellSection.home,
                onSection: picked.add,
                header: ShellHeader(
                  tabs: const ['Following', 'Live', 'Clips'],
                  onTab: (_) {},
                ),
                body: const SizedBox.expand(),
                onSearch: () {},
                whispers: ShellWhispers(
                  unread: 2,
                  refused: false,
                  onOpen: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expectNoSilentButtons(tester, reason: 'shell');

        // Pressed through its node, a section is picked exactly once (the
        // node's tap and the detector's never both fire).
        tester.semantics.tap(find.semantics.byLabel(RegExp('^Browse')));
        await tester.pumpAndSettle();
        expect(picked, [ShellSection.browse]);
        semantics.dispose();
      });

      testWidgets('the chat bottom bar with its autocomplete rows', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        useSize(tester, size);
        final text = TextEditingController();
        final focus = FocusNode();
        addTearDown(text.dispose);
        addTearDown(focus.dispose);
        final chat = fakeChatStore();
        final auth = _MockAuthStore();
        when(() => auth.isLoggedIn).thenReturn(true);
        when(() => chat.auth).thenReturn(auth);
        final assets = chat.assetsStore;
        when(() => assets.userEmoteToObject).thenReturn({});
        when(() => chat.matchingEmotes).thenReturn(const []);
        when(() => chat.matchingChatters).thenReturn(const ['viewer']);
        when(
          () => chat.matchingCommands,
        ).thenReturn(kChatCommands.take(2).toList());
        when(() => chat.showEmoteAutocomplete).thenReturn(false);
        when(() => chat.showMentionAutocomplete).thenReturn(true);
        when(() => chat.expandChat).thenReturn(false);
        when(() => chat.restriction).thenReturn(null);
        when(() => chat.replyingToMessage).thenReturn(null);
        when(() => chat.isWaitingForAck).thenReturn(false);
        when(() => chat.isConnected).thenReturn(true);
        when(() => chat.hasConnected).thenReturn(true);
        when(() => chat.textFieldFocusNode).thenReturn(focus);
        when(() => chat.textController).thenReturn(text);
        when(() => chat.showSendButton).thenReturn(false);
        await tester.pumpWidget(
          Provider<ChannelEventsStore?>.value(
            value: null,
            child: _app(
              Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: ChatBottomBar(chatStore: chat, onAddChat: () {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('@viewer'), findsOneWidget);
        expectNoSilentButtons(tester, reason: 'chat bottom bar');

        tester.semantics.tap(find.semantics.byLabel('@viewer'));
        await tester.pump();
        expect(text.text, '@viewer ');
        semantics.dispose();
      });

      testWidgets('the VOD overlay controls', (tester) async {
        final semantics = tester.ensureSemantics();
        useSize(tester, size);
        final vod = Vod(
          id: '1000000001',
          title: 'Morning stream',
          lengthSeconds: 3600,
          createdAt: DateTime.utc(2026, 10, 12),
          viewCount: 5,
          ownerId: '42',
          ownerLogin: 'streamer',
          ownerDisplayName: 'Streamer',
        );
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: VodOverlay(
                controller: FakeVodController(),
                media: PlayerMedia.vod(vod),
                settings: SettingsStore.fromJson({}),
                onCycleChatMode: () {},
                isLandscape: size.width > size.height,
              ),
            ),
          ),
        );
        await tester.pump();
        expectNoSilentButtons(tester, reason: 'VOD overlay');
        semantics.dispose();
      });

      testWidgets('the clips feed', (tester) async {
        final semantics = tester.ensureSemantics();
        useSize(tester, size);
        final service = _MockClipService();
        final mini = _MockMiniPlayerStore();
        when(() => mini.close()).thenReturn(null);
        when(() => mini.visible).thenReturn(false);
        when(
          () => service.getTopClips(language: any(named: 'language')),
        ).thenAnswer(
          (_) async =>
              ClipFeedPage(items: [_clip('a'), _clip('b'), _clip('c')]),
        );
        final settings = SettingsStore.fromJson({})..keepScreenAwake = false;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<SettingsStore>.value(value: settings),
              Provider<MiniPlayerStore>.value(value: mini),
              Provider<TwitchClipService>.value(value: service),
            ],
            child: _app(
              ClipsFeedScreen(
                store: ClipsFeedStore(clipService: service),
                disableAutoPip: () {},
                playerFactory: (clip, {required focused}) =>
                    FakeVodController(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expectNoSilentButtons(tester, reason: 'clips feed');
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        semantics.dispose();
      });

      testWidgets('the channel profile header and its round buttons', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        useSize(tester, size);
        const profile = ChannelProfile(
          id: '42',
          login: 'streamer',
          displayName: 'Streamer',
          profileImageUrl: 'https://static-cdn.jtvnw.net/p.png',
          followers: 1200,
          socials: [
            SocialLink(
              name: 'twitter',
              title: 'Twitter',
              url: 'https://twitter.com/streamer',
            ),
          ],
        );
        final opened = <String>[];
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      ProfileHeader(
                        login: profile.login,
                        displayName: profile.displayName,
                        profile: profile,
                        onOpenChannel: () {},
                      ),
                      ProfileSocials(
                        socials: profile.socials,
                        onOpenLink: opened.add,
                      ),
                      ProfileRoundButton(
                        glyph: SheetGlyphKind.share,
                        tooltip: 'Share',
                        onPressed: () => opened.add('share'),
                      ),
                      if (size == _tablet)
                        SizedBox(
                          width: 330,
                          child: ProfileRail(
                            login: profile.login,
                            displayName: profile.displayName,
                            profile: profile,
                            onOpenChannel: () {},
                            onOpenLink: opened.add,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expectNoSilentButtons(tester, reason: 'profile header');
        tester.semantics.tap(find.semantics.byLabel(RegExp('Twitter')).first);
        await tester.pump();
        expect(opened, ['https://twitter.com/streamer']);
        semantics.dispose();
      });

      testWidgets('the live feed, with a content warning', (tester) async {
        final semantics = tester.ensureSemantics();
        useSize(tester, size);
        final api = _MockTwitchApi();
        final auth = _MockAuthStore();
        final user = _MockUserStore();
        final settings = SettingsStore.fromJson({});
        final mini = MiniPlayerStore();
        when(() => auth.user).thenReturn(user);
        when(() => auth.isLoggedIn).thenReturn(true);
        when(() => auth.twitchWebToken).thenReturn(null);
        when(
          () => user.details,
        ).thenReturn(const UserTwitch('7', 'me', 'Me', ''));
        when(() => user.blockedUsers).thenReturn(ObservableList());
        when(
          () => api.getTopStreams(
            cursor: any(named: 'cursor'),
            language: any(named: 'language'),
          ),
        ).thenAnswer(
          (_) async => StreamsTwitch([
            for (var i = 1; i <= 4; i++) _stream(i),
          ], const {}),
        );
        when(
          () => api.getUser(userLogin: any(named: 'userLogin')),
        ).thenAnswer((_) => Future.error(Exception('offline')));
        when(() => api.getChannelsByIds(any())).thenAnswer(
          (invocation) async => {
            for (final id in invocation.positionalArguments.first as List)
              id as String: Channel(
                broadcasterId: id,
                broadcasterLogin: 'login$id',
                broadcasterName: 'Name $id',
                broadcasterLanguage: 'fr',
                title: 'Title $id',
                gameId: '',
                gameName: '',
                contentClassificationLabels: const ['MatureGame'],
              ),
          },
        );
        AcceptedContentWarnings.reset();
        addTearDown(AcceptedContentWarnings.reset);
        final store = LiveFeedStore(
          authStore: auth,
          settingsStore: settings,
          twitchApi: api,
        );
        final controller = PageController();
        final preview = LivePreviewController(
          resolveUrl: (login, CancelToken cancel) async =>
              'https://usher/$login',
          createBackend: _Preview.new,
        );
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AuthStore>.value(value: auth),
              Provider<SettingsStore>.value(value: settings),
              Provider<TwitchApi>.value(value: api),
              Provider<MiniPlayerStore>.value(value: mini),
            ],
            child: _app(
              Scaffold(
                body: LiveFeed(
                  store: store,
                  controller: controller,
                  active: true,
                  preview: preview,
                  isMetered: () async => true,
                  meteredChanges: const Stream.empty(),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expectNoSilentButtons(tester, reason: 'live feed');
        await tester.pumpWidget(const SizedBox());
        preview.dispose();
        store.dispose();
        controller.dispose();
        await tester.pump();
        semantics.dispose();
      });

      testWidgets('the onboarding setup', (tester) async {
        final semantics = tester.ensureSemantics();
        useSize(tester, size);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final settings = SettingsStore.fromJson({});
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AuthStore>.value(value: _OnboardingAuth()),
              Provider<SettingsStore>.value(value: settings),
            ],
            child: MaterialApp(
              navigatorObservers: [LaunchIntro.navigatorObserver],
              builder: (context, child) => LaunchIntro(child: child!),
              home: OnboardingFlow(
                loadLiveStreams: () async => const [],
                loginPanelBuilder: (context, onSignedIn, onTokenCaptured) =>
                    const SizedBox.expand(),
                onShareCrashLogsChanged: (_) {},
                homeBuilder: (_) => const Scaffold(body: Text('home')),
              ),
            ),
          ),
        );
        Future<void> settle() async {
          for (var i = 0; i < 18; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await settle();
        await tester.tap(find.text('Next').hitTestable());
        await settle();
        await tester.tap(find.text('Skip').hitTestable());
        await settle();
        expect(find.textContaining('Not logged in'), findsOneWidget);
        expectNoSilentButtons(tester, reason: 'onboarding setup');
        semantics.dispose();
      });

      testWidgets('the channel points button', (tester) async {
        final semantics = tester.ensureSemantics();
        useSize(tester, size);
        final store = _MockChannelEventsStore();
        when(() => store.channelId).thenReturn('watched');
        when(
          () => store.points,
        ).thenReturn(const CommunityPointsContext(balance: 1250));
        when(() => store.refreshWatchStreak()).thenAnswer((_) async {});
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: Center(
                child: Provider<ChannelEventsStore?>.value(
                  value: store,
                  child: const ChannelPointsButton(channelId: 'watched'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expectNoSilentButtons(tester, reason: 'channel points');
        semantics.dispose();
      });
    });
  }

  test('no button node in lib/ hides the tap of what it wraps', () {
    final findings = <String>[];
    var audited = 0;
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File ||
          !file.path.endsWith('.dart') ||
          file.path.endsWith('.g.dart')) {
        continue;
      }
      final source = file.readAsStringSync();
      for (final finding in hiddenTapsIn(source)) {
        findings.add('${file.path}:${finding.line} (${finding.missing})');
      }
      audited += buttonSemanticsIn(source);
    }
    // The inventory must have seen the pattern it guards.
    expect(audited, greaterThan(20));
    expect(findings, isEmpty);
  });

  test('the inventory finds what it looks for', () {
    const hidden = '''
Semantics(
  button: true,
  label: 'Go',
  excludeSemantics: true,
  child: GestureDetector(onTap: go, onLongPress: more, child: x),
)''';
    expect(hiddenTapsIn(hidden).single.missing, 'onTap, onLongPress');
    const nested = '''
Semantics(
  button: true,
  child: ExcludeSemantics(child: InkWell(onTap: go, child: x)),
)''';
    expect(hiddenTapsIn(nested).single.missing, 'onTap');
    const carried = '''
Semantics(
  button: true,
  label: 'Go (now)',
  onTap: go,
  excludeSemantics: true,
  child: GestureDetector(onTap: go, child: x),
)''';
    expect(hiddenTapsIn(carried), isEmpty);
    // The detector is outside what is excluded: its tap reaches the node.
    const outside = '''
Semantics(
  button: true,
  child: InkWell(onTap: go, child: ExcludeSemantics(child: Icon(x))),
)''';
    expect(hiddenTapsIn(outside), isEmpty);
    // A slider seeks where it is tapped: not a button.
    const slider = '''
Semantics(
  slider: true,
  excludeSemantics: true,
  child: GestureDetector(onTapUp: seek, child: x),
)''';
    expect(hiddenTapsIn(slider), isEmpty);
    // Strings and comments do not count.
    const text = '''
// Semantics(button: true, excludeSemantics: true, child: X(onTap: a))
final s = 'Semantics(button: true, excludeSemantics: true, child: X(onTap: a))';
''';
    expect(hiddenTapsIn(text), isEmpty);
  });
}

/// A button node that hides a handler it does not carry.
typedef HiddenTap = ({int line, String missing});

const _tapHandlers = ['onTap', 'onPressed', 'onTapUp', 'onTapDown'];

/// [source] with its comments and string contents blanked (same length, so
/// offsets and lines stay true).
String _blank(String source) {
  final out = source.split('');
  var i = 0;
  final n = source.length;
  void clear(int from, int to) {
    for (var k = from; k < to && k < n; k++) {
      if (out[k] != '\n') out[k] = ' ';
    }
  }

  while (i < n) {
    if (source.startsWith('//', i)) {
      var end = source.indexOf('\n', i);
      if (end < 0) end = n;
      clear(i, end);
      i = end;
    } else if (source.startsWith('/*', i)) {
      var end = source.indexOf('*/', i);
      end = end < 0 ? n : end + 2;
      clear(i, end);
      i = end;
    } else if (source[i] == "'" || source[i] == '"') {
      final triple = i + 2 < n && source.substring(i, i + 3) == source[i] * 3;
      final quote = triple ? source.substring(i, i + 3) : source[i];
      final raw = i > 0 && source[i - 1] == 'r';
      var j = i + quote.length;
      while (j < n && !source.startsWith(quote, j)) {
        if (!raw && source[j] == r'\') j++;
        j++;
      }
      clear(i + quote.length, j);
      i = j + quote.length;
    } else {
      i++;
    }
  }
  return out.join();
}

int _closing(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    final c = s[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return s.length;
}

/// The named arguments written directly in s[start, end).
Map<String, String> _arguments(String s, int start, int end) {
  final arguments = <String, String>{};
  var depth = 0;
  var from = start;
  void take(int to) {
    final segment = s.substring(from, to);
    final name = RegExp(r'^\s*(\w+)\s*:').firstMatch(segment);
    if (name != null) {
      arguments[name.group(1)!] = segment.substring(name.end);
    }
  }

  for (var i = start; i < end; i++) {
    final c = s[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (c == ',' && depth == 0) {
      take(i);
      from = i + 1;
    }
  }
  take(end);
  return arguments;
}

bool _has(String code, String handler) =>
    RegExp('\\b$handler\\s*:').hasMatch(code);

/// Every `Semantics(button: true, …)` in [source] whose excluded subtree
/// (its own `excludeSemantics: true`, or an `ExcludeSemantics` inside it)
/// holds a tap or long press handler the node itself does not carry.
List<HiddenTap> hiddenTapsIn(String source) {
  final code = _blank(source);
  final found = <HiddenTap>[];
  for (final match in RegExp(r'\bSemantics\s*\(').allMatches(code)) {
    if (match.start > 0 && RegExp(r'\w').hasMatch(code[match.start - 1])) {
      continue;
    }
    final open = match.end - 1;
    final arguments = _arguments(code, open + 1, _closing(code, open));
    final child = arguments['child'];
    if (child == null || !(arguments['button']?.contains('true') ?? false)) {
      continue;
    }
    String hidden;
    if (arguments['excludeSemantics']?.contains('true') ?? false) {
      hidden = child;
    } else {
      final parts = <String>[];
      for (final inner in RegExp(
        r'\bExcludeSemantics\s*\(',
      ).allMatches(child)) {
        final innerOpen = inner.end - 1;
        final innerClose = _closing(child, innerOpen);
        final excluding = _arguments(
          child,
          innerOpen + 1,
          innerClose,
        )['excluding'];
        if (excluding != null && !excluding.contains('true')) continue;
        parts.add(child.substring(innerOpen, innerClose));
      }
      hidden = parts.join(' ');
    }
    final missing = [
      if (_tapHandlers.any((h) => _has(hidden, h)) &&
          !arguments.containsKey('onTap'))
        'onTap',
      if (_has(hidden, 'onLongPress') && !arguments.containsKey('onLongPress'))
        'onLongPress',
    ];
    if (missing.isNotEmpty) {
      found.add((
        line: '\n'.allMatches(source.substring(0, match.start)).length + 1,
        missing: missing.join(', '),
      ));
    }
  }
  return found;
}

/// How many `Semantics(button: true, …)` [source] has.
int buttonSemanticsIn(String source) {
  final code = _blank(source);
  var count = 0;
  for (final match in RegExp(r'\bSemantics\s*\(').allMatches(code)) {
    final open = match.end - 1;
    final button = _arguments(code, open + 1, _closing(code, open))['button'];
    if (button?.contains('true') ?? false) count++;
  }
  return count;
}
