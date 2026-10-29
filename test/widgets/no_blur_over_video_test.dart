import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/frosty_notification.dart';
import 'package:onset/widgets/frosty_photo_view_dialog.dart';

/// The pictures and notices the chat opens: the chat sits beside, under or
/// over the live video, so none of them may blur it.
void main() {
  bool blurring(WidgetTester tester) => tester
      .widgetList<BackdropFilter>(find.byType(BackdropFilter))
      .any((filter) => filter.enabled);

  testWidgets("a chat emote's picture opens over a plain dark scrim", (
    tester,
  ) async {
    final themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
    await tester.pumpWidget(
      MaterialApp(
        theme: themes.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => IRCMessage.showEmoteDetailsBottomSheet(
                context,
                emote: const Emote(
                  name: 'Kappa',
                  zeroWidth: false,
                  url: 'https://static-cdn.jtvnw.net/emoticons/v2/25/1.0',
                  type: EmoteType.twitchGlobal,
                ),
                launchExternal: false,
              ),
              child: const Text('emote'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('emote'));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(of: find.byType(InkWell), matching: find.byType(Center))
          .first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FrostyPhotoViewDialog), findsOneWidget);
    expect(blurring(tester), isFalse);
  });

  testWidgets('elsewhere the picture keeps its soft blur', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FrostyPhotoViewDialog(imageUrl: 'https://example.com/a.png'),
      ),
    );
    expect(blurring(tester), isTrue);
  });

  testWidgets('a chat notice over the video is opaque, never blurred', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FrostyNotification(message: 'Slow mode', overVideo: true),
        ),
      ),
    );
    expect(find.text('Slow mode'), findsOneWidget);
    expect(blurring(tester), isFalse);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FrostyNotification(message: 'Slow mode')),
      ),
    );
    expect(blurring(tester), isTrue);
  });
}
