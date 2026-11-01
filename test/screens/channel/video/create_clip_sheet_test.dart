import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/stores/create_clip_store.dart';
import 'package:onset/screens/channel/video/create_clip_sheet.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

void main() {
  late MockTwitchApi api;
  late bool loggedIn;
  late List<String> actions;
  late List<Uri> edited;

  setUp(() {
    api = MockTwitchApi();
    loggedIn = true;
    actions = [];
    edited = [];
    when(() => api.getTokenScopes()).thenAnswer((_) async => {'clips:edit'});
    when(() => api.createClip(broadcasterId: '42')).thenAnswer(
      (_) async => ClipCreation(
        id: 'Slug-abc',
        editUrl: Uri.parse('https://www.twitch.tv/streamer/clip/Slug-abc'),
      ),
    );
    when(
      () => api.getCreatedClip('Slug-abc'),
    ).thenAnswer((_) async => const CreatedClip(id: 'Slug-abc'));
  });

  Future<CreateClipStore> pump(WidgetTester tester) async {
    final store = CreateClipStore(
      twitchApi: api,
      broadcasterId: '42',
      isLoggedIn: () => loggedIn,
      pollInterval: const Duration(seconds: 1),
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateClipSheet(
            store: store,
            onLogIn: () => actions.add('log in'),
            onOpenEditor: edited.add,
            onShare: (link) => actions.add('share $link'),
          ),
        ),
      ),
    );
    return store;
  }

  testWidgets('clips at once, renders, then offers edit, share and copy', (
    tester,
  ) async {
    final store = await pump(tester);
    expect(find.text('Create clip'), findsOneWidget);

    store.start();
    await tester.pump();
    expect(find.text('Rendering clip…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    // The work cross-fades into the finished clip.
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Rendering clip…'), findsNothing);
    await tester.tap(find.text('Edit'));
    expect(edited, [Uri.parse('https://www.twitch.tv/streamer/clip/Slug-abc')]);

    await tester.tap(find.text('Share clip'));
    expect(actions, ['share https://clips.twitch.tv/Slug-abc']);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await tester.tap(find.text('Copy link'));
    await tester.pump();
    expect(copied, 'https://clips.twitch.tv/Slug-abc');
    expect(find.text('Clip link copied'), findsOneWidget);
  });

  testWidgets('a login from before clips offers to reconnect', (tester) async {
    when(() => api.getTokenScopes()).thenAnswer((_) async => {'chat:read'});
    final store = await pump(tester);

    store.start();
    await tester.pump();

    expect(find.textContaining('permission'), findsOneWidget);
    await tester.tap(find.text('Reconnect to Twitch'));
    expect(actions, ['log in']);
    verifyNever(
      () => api.createClip(broadcasterId: any(named: 'broadcasterId')),
    );
  });

  testWidgets('logged out asks to log in', (tester) async {
    loggedIn = false;
    final store = await pump(tester);

    store.start();
    await tester.pump();

    expect(find.text('Log in to create clips.'), findsOneWidget);
    await tester.tap(find.text('Log in'));
    expect(actions, ['log in']);
  });

  testWidgets('a refusal says why and offers to retry', (tester) async {
    var calls = 0;
    when(() => api.createClip(broadcasterId: '42')).thenAnswer((_) async {
      if (calls++ == 0) {
        throw const ClipCreateException(ClipCreateFailure.offline);
      }
      return const ClipCreation(id: 'Slug-abc');
    });
    final store = await pump(tester);

    store.start();
    await tester.pump();

    expect(find.textContaining('live'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Rendering clip…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('Edit'), findsNothing, reason: 'no edit link given');
  });

  test('each refusal has its own wording', () {
    final messages = {
      for (final failure in ClipCreateFailure.values)
        failure: clipFailureMessage(failure, L10n.english),
    };
    expect(messages.values.toSet(), hasLength(messages.length));
    expect(
      messages[ClipCreateFailure.notClippable],
      'This channel doesn’t allow clips of this category.',
    );
    expect(messages[ClipCreateFailure.unknown], 'Hmm… something went wrong.');
  });

  test('the live frame is only asked for a Twitch login', () {
    expect(
      clipFramePreviewUrl('Streamer_1'),
      'https://static-cdn.jtvnw.net/previews-ttv/live_user_streamer_1-640x360.jpg',
    );
    expect(clipFramePreviewUrl(null), isNull);
    expect(clipFramePreviewUrl(''), isNull);
    expect(clipFramePreviewUrl('a/../b'), isNull);
    expect(clipFramePreviewUrl('x' * 26), isNull);
  });

  testWidgets('the work shows over the frame, the finished clip names its '
      'channel', (tester) async {
    final store = CreateClipStore(
      twitchApi: api,
      broadcasterId: '42',
      isLoggedIn: () => loggedIn,
      pollInterval: const Duration(seconds: 1),
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateClipSheet(
            store: store,
            framePreviewUrl: clipFramePreviewUrl('streamer'),
            channelName: 'Streamer',
            gameName: 'Dota 2',
            onLogIn: () {},
            onOpenEditor: (_) {},
            onShare: (_) {},
          ),
        ),
      ),
    );
    store.start();
    await tester.pump();
    expect(find.text('Rendering clip…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Streamer · Dota 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
