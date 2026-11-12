import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/cheermote.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/stores/vod_chat_replay_store.dart';
import 'package:onset/screens/vod/widgets/video_kit.dart';
import 'package:onset/screens/vod/widgets/vod_chat_message.dart';
import 'package:onset/screens/vod/widgets/vod_chat_replay.dart';
import 'package:onset/widgets/skeleton_loader.dart';

class MockReplayStore extends Mock implements VodChatReplayStore {}

class MockChatAssetsStore extends Mock implements ChatAssetsStore {}

void main() {
  late MockReplayStore store;

  setUp(() {
    store = MockReplayStore();
    final assets = MockChatAssetsStore();
    when(() => assets.cheermotes).thenReturn(Cheermotes.empty);
    when(() => assets.emoteToObject).thenReturn({});
    when(() => assets.twitchBadgesToObject).thenReturn({});
    when(() => assets.userToFFZBadges).thenReturn({});
    when(() => assets.userTo7TVBadges).thenReturn({});
    when(() => assets.userToBTTVBadges).thenReturn({});
    when(() => assets.ffzRoomInfo).thenReturn(null);
    when(() => store.assetsStore).thenReturn(assets);
    when(() => store.settings).thenReturn(SettingsStore.fromJson({}));
    when(() => store.messages).thenReturn(ObservableList<IRCMessage>());
    when(() => store.autoScroll).thenReturn(true);
    when(() => store.scrollController).thenReturn(ScrollController());
    when(() => store.vod).thenReturn(
      Vod(
        id: '1',
        title: 't',
        lengthSeconds: 10,
        createdAt: DateTime.utc(2026),
        viewCount: 0,
        ownerId: '42',
        ownerLogin: 'streamer',
        ownerDisplayName: 'Streamer',
      ),
    );
  });

  Future<void> pump(WidgetTester tester, ReplayStatus status) {
    when(() => store.status).thenReturn(status);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VodChatReplay(store: store)),
      ),
    );
  }

  testWidgets('the header fits a 180 dp phone side chat', (tester) async {
    when(() => store.status).thenReturn(ReplayStatus.active);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 180,
              height: 400,
              child: VodChatReplay(store: store),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('loading shows message skeletons with a caption', (tester) async {
    await pump(tester, ReplayStatus.loading);

    expect(find.byType(ReplayLoading), findsOneWidget);
    expect(find.byType(SkeletonLoader), findsNWidgets(3));
    expect(find.text('Loading chat replay…'), findsOneWidget);
  });

  testWidgets('an active replay without messages says so', (tester) async {
    await pump(tester, ReplayStatus.active);

    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('unavailable offers a retry', (tester) async {
    await pump(tester, ReplayStatus.unavailable);

    expect(
      find.text('Chat replay is unavailable for this video'),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    verify(() => store.retry()).called(1);
  });

  testWidgets('uploads explain there is no chat', (tester) async {
    await pump(tester, ReplayStatus.notApplicable);

    expect(find.byType(VideoPaneNotice), findsOneWidget);
    expect(find.text('Uploads have no chat replay'), findsOneWidget);
    expect(find.text('synced to video'), findsNothing);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
  });

  testWidgets('the resume pill calls resumeScroll', (tester) async {
    when(() => store.messages).thenReturn(
      ObservableList.of([
        IRCMessage.fromString(
          '@display-name=A;id=1 :a!a@a.tmi.twitch.tv PRIVMSG #streamer :hi',
        ),
      ]),
    );
    when(() => store.autoScroll).thenReturn(false);
    await pump(tester, ReplayStatus.active);

    expect(find.textContaining('hi', findRichText: true), findsWidgets);
    await tester.tap(find.text('Resume scroll'));
    verify(() => store.resumeScroll()).called(1);
  });

  testWidgets('a new message leaves the rows already shown as they are', (
    tester,
  ) async {
    final messages = ObservableList.of([
      IRCMessage.fromString(
        '@display-name=A;id=1 :a!a@a.tmi.twitch.tv PRIVMSG #streamer :hi',
      ),
    ]);
    when(() => store.messages).thenReturn(messages);
    await pump(tester, ReplayStatus.active);
    final first = tester.widget(find.byType(VodChatMessage));

    messages.add(
      IRCMessage.fromString(
        '@display-name=B;id=2 :b!b@b.tmi.twitch.tv PRIVMSG #streamer :yo',
      ),
    );
    await tester.pump();

    expect(find.byType(VodChatMessage), findsNWidgets(2));
    expect(
      tester.widgetList(find.byType(VodChatMessage)),
      contains(same(first)),
    );
  });

  testWidgets('a setting changed mid-replay redraws the rows already shown', (
    tester,
  ) async {
    final settings = SettingsStore.fromJson({})..messageSpacing = 4;
    when(() => store.settings).thenReturn(settings);
    when(() => store.messages).thenReturn(
      ObservableList.of([
        IRCMessage.fromString(
          '@display-name=A;id=1 :a!a@a.tmi.twitch.tv PRIVMSG #streamer :hi',
        ),
      ]),
    );
    await pump(tester, ReplayStatus.active);
    final before = tester.getSize(find.byType(VodChatMessage)).height;

    settings.messageSpacing = 20;
    await tester.pump();

    expect(tester.getSize(find.byType(VodChatMessage)).height, before + 16);
  });

  group('header room', () {
    bool cut(WidgetTester tester, String text) =>
        tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

    Future<void> pumpWidth(
      WidgetTester tester,
      double width, {
      String syncLabel = 'synced to video',
    }) async {
      when(() => store.status).thenReturn(ReplayStatus.active);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: 400,
                child: VodChatReplay(store: store, syncLabel: syncLabel),
              ),
            ),
          ),
        ),
      );
    }

    // Measured in the app's own font, not the test font's square letters.
    setUpAll(() async {
      final inter = FontLoader('Inter');
      for (final weight in ['Regular', 'SemiBold', 'Bold']) {
        inter.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
      }
      await inter.load();
    });

    testWidgets('a phone shows the title and the pill whole', (tester) async {
      for (final label in ['synced to video', 'synced to the clip']) {
        await pumpWidth(tester, 390, syncLabel: label);
        expect(cut(tester, 'Chat replay'), isFalse);
        expect(cut(tester, label), isFalse, reason: label);
      }
    });

    testWidgets('a narrow side chat keeps the whole title', (tester) async {
      await pumpWidth(tester, 230);
      expect(tester.takeException(), isNull);
      expect(cut(tester, 'Chat replay'), isFalse);
    });
  });
}
