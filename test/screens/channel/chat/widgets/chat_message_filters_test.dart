import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/chat_filters.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/widgets/frosty_cached_network_image.dart';

import '../../../../helpers/chat_message_harness.dart';

String _line(String tags, String text) =>
    '@badge-info=;badges=;color=#00FF00;display-name=Viewer;emotes=;'
    'id=msg-1;room-id=12345;user-id=55555;$tags '
    ':viewer!viewer@viewer.tmi.twitch.tv PRIVMSG #channel :$text';

String _lineText(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((text) => text.text.toPlainText(includeSemanticsLabels: false))
    .join('\n');

/// Taps the span showing [text], like a finger on that word.
void _tapSpan(WidgetTester tester, String text) {
  TapGestureRecognizer? found;
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span.recognizer as TapGestureRecognizer?;
      }
      return found == null;
    });
  }
  expect(found, isNotNull, reason: 'no tappable "$text"');
  found!.onTap!();
}

SettingsStore _filtersOn() =>
    SettingsStore.fromJson({})..chatFiltersEnabled = true;

void main() {
  test('a message knows whether the filters hide part of it', () {
    final msg = IRCMessage.fromString(_line('flags=0-3:P.3', 'damn fine'));
    const on = ChatFilterSettings(
      enabled: true,
      discrimination: true,
      sexual: true,
      harassment: true,
      profanity: true,
    );

    expect(msg.isFiltered(on), isTrue);
    expect(msg.isFiltered(on.copyWith(profanity: false)), isFalse);
    expect(msg.isFiltered(on.copyWith(enabled: false)), isFalse);
    // Copy, search and mentions keep the whole text.
    expect(msg.message, 'damn fine');
  });

  testWidgets('a hidden word is drawn as stars', (tester) async {
    final store = fakeChatStore(settings: _filtersOn());
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(_line('flags=0-3:P.3', 'damn fine')),
      store,
    );

    final text = _lineText(tester);
    expect(text, contains('**** fine'));
    expect(text, isNot(contains('damn')));
  });

  testWidgets("tapping it asks Twitch's question and Show Message reveals it", (
    tester,
  ) async {
    final store = fakeChatStore(settings: _filtersOn());
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(_line('flags=0-3:P.3', 'damn fine')),
      store,
    );

    _tapSpan(tester, '****');
    await tester.pumpAndSettle();

    expect(find.text('Message Blocked'), findsOneWidget);
    expect(
      find.text(
        'Would you like to see this message? It has been hidden for you '
        'based on your NSFW Chat Filter settings.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Show Message'));
    await tester.pumpAndSettle();

    expect(find.text('Message Blocked'), findsNothing);
    expect(_lineText(tester), contains('damn fine'));
  });

  testWidgets('nothing is hidden with the filters off', (tester) async {
    final store = fakeChatStore();
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(_line('flags=0-3:P.3', 'damn fine')),
      store,
    );

    expect(_lineText(tester), contains('damn fine'));
  });

  testWidgets('a moderator still sees every message', (tester) async {
    final store = fakeChatStore(settings: _filtersOn());
    when(() => store.canModerate).thenReturn(true);
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(_line('flags=0-3:P.3', 'damn fine')),
      store,
    );

    expect(_lineText(tester), contains('damn fine'));
  });

  testWidgets('a Twitch emote inside a hidden range stays an emote', (
    tester,
  ) async {
    final store = fakeChatStore(settings: _filtersOn());
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(_line('emotes=25:0-4;flags=0-9:P.3', 'Kappa damn')),
      store,
    );

    final text = _lineText(tester);
    expect(text, contains('****'));
    expect(text, isNot(contains('damn')));
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is FrostyCachedNetworkImage &&
            w.imageUrl.contains('/emoticons/v2/25/'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the text around a GIF is filtered too', (tester) async {
    final store = fakeChatStore(settings: _filtersOn());
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(
        _line(
          'gifs=5-9|id|https://media.giphy.com/g.gif;flags=11-14:P.3',
          'look [YAY] damn',
        ),
      ),
      store,
    );

    final text = _lineText(tester);
    expect(text, contains('****'));
    expect(text, isNot(contains('damn')));
  });

  testWidgets('a /me message counts from after its ACTION prefix', (
    tester,
  ) async {
    final store = fakeChatStore(settings: _filtersOn());
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(_line('flags=0-3:P.3', '\x01ACTION damn it\x01')),
      store,
    );

    final text = _lineText(tester);
    expect(text, contains('**** it'));
  });

  test('a hidden link is not previewed; the rest of the text still is', () {
    const on = ChatFilterSettings(
      enabled: true,
      discrimination: true,
      sexual: true,
      harassment: true,
      profanity: true,
    );
    final msg = IRCMessage.fromString(
      _line(
        'flags=0-3:P.3',
        'damn https://clips.twitch.tv/Abc twitch.tv/videos/1x',
      ),
    );
    expect(msg.shownText(null), msg.message);
    expect(
      msg.shownText(on),
      'https://clips.twitch.tv/Abc twitch.tv/videos/1x',
    );

    final hidden = IRCMessage.fromString(
      _line('flags=0-26:P.3', 'https://clips.twitch.tv/Abc ok'),
    );
    expect(hidden.shownText(on), 'ok');
  });

  group('a private-use character a chatter sends', () {
    // Nerd Font and icon users send U+E000-U+F8FF: it is their text.
    const icon = '\u{E000}';

    bool hasFilteredSpan(WidgetTester tester) {
      var found = false;
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        rich.text.visitChildren((span) {
          if (span is TextSpan && span.semanticsLabel == 'Filtered word') {
            found = true;
          }
          return !found;
        });
      }
      return found;
    }

    testWidgets('shows as itself with the filters off', (tester) async {
      final store = fakeChatStore();
      await pumpChatMessage(
        tester,
        IRCMessage.fromString(_line('flags=', 'hi ${icon}x there')),
        store,
      );

      expect(_lineText(tester), contains('hi ${icon}x there'));
      expect(hasFilteredSpan(tester), isFalse);
    });

    testWidgets('shows as itself next to a hidden word', (tester) async {
      final store = fakeChatStore(settings: _filtersOn());
      await pumpChatMessage(
        tester,
        IRCMessage.fromString(_line('flags=0-3:P.3', 'damn ${icon}x ok')),
        store,
      );

      final text = _lineText(tester);
      expect(text, contains('**** ${icon}x ok'));
      expect(text, isNot(contains('damn')));
    });

    test('is kept by the text a link preview reads', () {
      const on = ChatFilterSettings(
        enabled: true,
        discrimination: true,
        sexual: true,
        harassment: true,
        profanity: true,
      );
      final msg = IRCMessage.fromString(
        _line('flags=0-3:P.3', 'damn ${icon}x ok'),
      );
      expect(msg.shownText(on), '${icon}x ok');
    });

    testWidgets('inside a hidden range is hidden too', (tester) async {
      final store = fakeChatStore(settings: _filtersOn());
      await pumpChatMessage(
        tester,
        IRCMessage.fromString(_line('flags=0-4:P.3', 'da${icon}mn ok')),
        store,
      );

      expect(_lineText(tester), contains('***** ok'));
    });
  });
}
