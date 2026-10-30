import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/widgets/chat_gif_image.dart';
import 'package:onset/screens/channel/chat/widgets/chat_message.dart';
import 'package:onset/screens/channel/chat/widgets/first_frame_image.dart';
import 'package:onset/screens/channel/chat/widgets/overlay_chat_scope.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';

import '../../../../fixtures/irc_messages.dart';
import '../../../../helpers/chat_message_harness.dart';

const _title = '[Y A Y Yes GIF by Djemilah Birnie]';

/// The text of the chat line, a GIF counting as one object character.
String _lineText(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((text) => text.text.toPlainText())
    .join('\n');

OnsetCachedNetworkImage _gifImage(WidgetTester tester) =>
    tester.widget<OnsetCachedNetworkImage>(
      find.descendant(
        of: find.byType(ChatGifImage),
        matching: find.byType(OnsetCachedNetworkImage),
      ),
    );

String _line(String tags, String text) =>
    '@badge-info=;badges=;color=#00FF00;display-name=Viewer;emotes=;'
    'id=gif-1;room-id=12345;user-id=55555;$tags '
    ':viewer!viewer@viewer.tmi.twitch.tv PRIVMSG #channel :$text';

/// A phone held upright: the default test view (800x600) is landscape.
void _portrait(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('a GIF replaces its title, below the name, with the exact url', (
    tester,
  ) async {
    _portrait(tester);
    final semantics = tester.ensureSemantics();
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(gifMessage),
      fakeChatStore(),
    );

    expect(find.byType(ChatGifImage), findsOneWidget);
    final image = _gifImage(tester);
    expect(image.imageUrl, gifMessageUrl);
    expect(image.height, 128);
    expect(image.semanticLabel, _title);
    // The bracketed title is not drawn as text; the GIF starts a new line.
    expect(_lineText(tester), isNot(contains('[Y A Y')));
    expect(_lineText(tester), contains('TwitchDev:\n'));
    expect(find.bySemanticsLabel(_title), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the decode is bounded to the drawn height', (tester) async {
    _portrait(tester);
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(gifMessage),
      fakeChatStore(),
    );

    final ratio = tester.view.devicePixelRatio;
    expect(_gifImage(tester).memCacheHeight, (128 * ratio).round());
  });

  testWidgets('the text around a GIF is still drawn', (tester) async {
    _portrait(tester);
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(
        _line('gifs=5-9|id|https://media.giphy.com/g.gif', 'look [YAY] wow'),
      ),
      fakeChatStore(),
    );

    final text = _lineText(tester);
    expect(text, contains('look'));
    expect(text, contains('wow'));
    expect(text, isNot(contains('[YAY]')));
    expect(find.byType(ChatGifImage), findsOneWidget);
  });

  testWidgets('a reply keeps hiding the @name and still draws its GIF', (
    tester,
  ) async {
    _portrait(tester);
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(
        _line(
          'reply-parent-display-name=Other;reply-parent-msg-body=hi;'
              'reply-parent-msg-id=p-1;reply-parent-user-login=other;'
              'gifs=7-11|id|https://media.giphy.com/g.gif',
          '@Other [YAY]',
        ),
      ),
      fakeChatStore(),
    );

    expect(find.byType(ChatGifImage), findsOneWidget);
    expect(_lineText(tester), isNot(contains('@Other')));
  });

  testWidgets('a GIF is shorter in landscape', (tester) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpChatMessage(
      tester,
      IRCMessage.fromString(gifMessage),
      fakeChatStore(),
    );

    expect(_gifImage(tester).height, 72);
  });

  testWidgets('a GIF is shorter in the chat over the video', (tester) async {
    _portrait(tester);
    const themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      MaterialApp(
        theme: themes.dark,
        home: Scaffold(
          body: OverlayChatScope(
            child: ListView(
              children: [
                ChatMessage(
                  ircMessage: IRCMessage.fromString(gifMessage),
                  chatStore: fakeChatStore(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(_gifImage(tester).height, 72);
  });

  testWidgets('a deleted GIF message still shows its GIF', (tester) async {
    _portrait(tester);
    final message = IRCMessage.fromString(gifMessage)
      ..command = Command.clearMessage;
    await pumpChatMessage(tester, message, fakeChatStore());

    expect(find.text('Message deleted'), findsOneWidget);
    expect(find.byType(ChatGifImage), findsOneWidget);
  });

  testWidgets('a hidden deleted GIF message shows the placeholder', (
    tester,
  ) async {
    _portrait(tester);
    final message = IRCMessage.fromString(gifMessage)
      ..command = Command.clearMessage;
    await pumpChatMessage(
      tester,
      message,
      fakeChatStore(
        settings: SettingsStore.fromJson({'revealDeletedMessages': false}),
      ),
    );

    expect(find.byType(ChatGifImage), findsNothing);
    expect(_lineText(tester), contains('<message deleted>'));
  });

  testWidgets('with GIFs turned off the title is shown as text', (
    tester,
  ) async {
    _portrait(tester);
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(gifMessage),
      fakeChatStore(settings: SettingsStore.fromJson({'showGifs': false})),
    );

    expect(find.byType(ChatGifImage), findsNothing);
    expect(_lineText(tester), contains('TwitchDev: $_title'));
  });

  testWidgets('with animation turned off only the first frame is drawn', (
    tester,
  ) async {
    _portrait(tester);
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(gifMessage),
      fakeChatStore(settings: SettingsStore.fromJson({'animateGifs': false})),
    );

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(ChatGifImage),
        matching: find.byType(Image),
      ),
    );
    expect(image.image, isA<FirstFrameImage>());
    expect(image.height, 128);
    expect(image.semanticLabel, _title);
    final resized = (image.image as FirstFrameImage).inner as ResizeImage;
    expect(resized.height, (128 * tester.view.devicePixelRatio).round());
    final network = resized.imageProvider as CachedNetworkImageProvider;
    expect(network.url, gifMessageUrl);
  });

  testWidgets('an http url is not loaded: the title is shown as text', (
    tester,
  ) async {
    _portrait(tester);
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(
        _line('gifs=0-4|id|http://media.giphy.com/g.gif', '[YAY]'),
      ),
      fakeChatStore(),
    );

    expect(find.byType(ChatGifImage), findsNothing);
    expect(_lineText(tester), contains('Viewer: [YAY]'));
  });

  testWidgets('a GIF that fails to load shows its title', (tester) async {
    _portrait(tester);
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(gifMessage),
      fakeChatStore(),
    );

    final image = _gifImage(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              image.errorWidget!(context, image.imageUrl, Exception('404')),
        ),
      ),
    );

    expect(find.text(_title), findsOneWidget);
  });

  testWidgets('the loading placeholder is an empty square', (tester) async {
    _portrait(tester);
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(gifMessage),
      fakeChatStore(),
    );

    final image = _gifImage(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Builder(
            builder: (context) => image.placeholder!(context, image.imageUrl),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(SizedBox).last), const Size(128, 128));
  });

  testWidgets('tapping a GIF opens its details', (tester) async {
    _portrait(tester);
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(gifMessage),
      fakeChatStore(),
    );

    await tester.tap(find.byType(ChatGifImage));
    await tester.pumpAndSettle();

    expect(find.text(_title), findsOneWidget);
    expect(find.text('GIF'), findsOneWidget);
    expect(find.text('Copy image URL'), findsOneWidget);
  });

  testWidgets('a failed GIF keeps its height while showing its title', (
    tester,
  ) async {
    _portrait(tester);
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(gifMessage),
      fakeChatStore(),
    );

    final image = _gifImage(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Builder(
            builder: (context) =>
                image.errorWidget!(context, image.imageUrl, Exception('404')),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(SizedBox).first).height, 128);
  });

  testWidgets('Copy name copies the whole title of a GIF', (tester) async {
    _portrait(tester);
    final copied = captureClipboard(tester);
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(
        _line('gifs=0-14|id|https://media.giphy.com/g.gif', 'dance (remix) x'),
      ),
      fakeChatStore(),
    );

    await tester.tap(find.byType(ChatGifImage));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy name'));
    await tester.pumpAndSettle();

    expect(copied, ['dance (remix) x']);
  });

  testWidgets('a GIF whose title is blank is called GIF', (tester) async {
    _portrait(tester);
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(
        _line('gifs=0-0|id|https://media.giphy.com/g.gif', ' x'),
      ),
      fakeChatStore(),
    );

    expect(_gifImage(tester).semanticLabel, 'GIF');
  });
}
