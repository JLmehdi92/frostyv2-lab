import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/link_router.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  late List<Uri> launched;

  setUp(() {
    launched = [];
    LinkRouter.launcher = (url, {mode = LaunchMode.platformDefault}) async {
      launched.add(url);
      return true;
    };
  });

  Future<void> openInBrowser(WidgetTester tester, String url) async {
    final themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
    await tester.pumpWidget(
      MaterialApp(
        theme: themes.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => IRCMessage.showEmoteDetailsBottomSheet(
                context,
                emote: Emote(
                  name: 'Kappa',
                  zeroWidth: false,
                  url: url,
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
    await tester.tap(find.text('Open in browser'));
    await tester.pumpAndSettle();
  }

  testWidgets("an emote's picture opens in the browser", (tester) async {
    await openInBrowser(
      tester,
      'https://static-cdn.jtvnw.net/emoticons/v2/25/default/dark/3.0',
    );
    expect(launched, [
      Uri.parse(
        'https://static-cdn.jtvnw.net/emoticons/v2/25/default/dark/3.0',
      ),
    ]);
  });

  testWidgets('a picture address that is not a web link is never launched', (
    tester,
  ) async {
    await openInBrowser(tester, 'file:///sdcard/secret.png');
    expect(launched, isEmpty);
  });
}
