import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel_profile/widgets/channel_restricted_banner.dart';

import '../../../helpers/l10n.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Future<bool> Function(String) check, {
    String channelId = '1000',
  }) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: ChannelRestrictedBanner(
          channelId: channelId,
          name: 'Streamer',
          check: check,
        ),
      ),
      locale: en,
    );
    await tester.pumpAndSettle();
  }

  const text =
      'Streamer’s account is temporarily restricted for breaking Twitch’s '
      'community guidelines.';

  testWidgets('a restricted channel shows the banner', (tester) async {
    final asked = <String>[];
    await pump(tester, (id) async {
      asked.add(id);
      return true;
    });
    expect(find.text(text), findsOneWidget);
    expect(asked, ['1000']);
  });

  testWidgets('a channel in good standing shows nothing', (tester) async {
    await pump(tester, (_) async => false);
    expect(find.text(text), findsNothing);
  });

  testWidgets('a failure hides the banner', (tester) async {
    await pump(tester, (_) async => throw Exception('gql'));
    expect(find.text(text), findsNothing);
  });

  testWidgets('another channel is asked again and starts hidden', (
    tester,
  ) async {
    await pump(tester, (id) async => id == '1000');
    expect(find.text(text), findsOneWidget);
    await pump(tester, (id) async => id == '1000', channelId: '2000');
    expect(find.text(text), findsNothing);
  });
}
