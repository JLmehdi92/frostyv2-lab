import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/cheermote.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';

class MockChatAssetsStore extends Mock implements ChatAssetsStore {}

const _darkBlue = Color(0xFF0000AA);

double _luminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final hi = _luminance(a) > _luminance(b) ? a : b;
  final lo = identical(hi, a) ? b : a;
  return (_luminance(hi) + 0.05) / (_luminance(lo) + 0.05);
}

void main() {
  late MockChatAssetsStore assets;

  setUp(() {
    assets = MockChatAssetsStore();
    when(() => assets.cheermotes).thenReturn(Cheermotes.empty);
    when(() => assets.emoteToObject).thenReturn({});
    when(() => assets.twitchBadgesToObject).thenReturn({});
    when(() => assets.userToFFZBadges).thenReturn({});
    when(() => assets.userTo7TVBadges).thenReturn({});
    when(() => assets.userToBTTVBadges).thenReturn({});
    when(() => assets.ffzRoomInfo).thenReturn(null);
  });

  Future<(Color, Color)> nameColor(
    WidgetTester tester,
    double? contrast,
  ) async {
    late Color color;
    late Color background;
    await tester.pumpWidget(
      MaterialApp(
        theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
        home: Builder(
          builder: (context) {
            background = Theme.of(context).scaffoldBackgroundColor;
            final spans =
                IRCMessage.fromString(
                  '@color=#0000AA;display-name=Fan :fan!fan@fan.tmi.twitch.tv '
                  'PRIVMSG #c :hi',
                ).generateSpan(
                  context,
                  assetsStore: assets,
                  badgeScale: 1,
                  emoteScale: 1,
                  launchExternal: false,
                  nameContrast: contrast,
                );
            color = spans
                .whereType<TextSpan>()
                .firstWhere((span) => span.text == 'Fan')
                .style!
                .color!;
            return const SizedBox();
          },
        ),
      ),
    );
    return (color, background);
  }

  testWidgets('readable colors lift a dark name to 4.5:1', (tester) async {
    final (color, background) = await nameColor(
      tester,
      readableNameColorContrast,
    );
    expect(_contrast(color, background), greaterThanOrEqualTo(4.5));
    expect(_contrast(color, background), lessThan(7));
  });

  testWidgets('increased contrast lifts it to 7:1', (tester) async {
    final (color, background) = await nameColor(tester, highNameColorContrast);
    expect(_contrast(color, background), greaterThanOrEqualTo(7));
  });

  testWidgets('with readable colors off the name keeps its color', (
    tester,
  ) async {
    final (color, _) = await nameColor(tester, null);
    expect(color, _darkBlue);
  });
}
