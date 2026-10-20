import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/channel/video/create_clip_sheet.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

void main() {
  testWidgets('the Clip button opens the panel for this channel', (
    tester,
  ) async {
    final auth = MockAuthStore();
    when(() => auth.isLoggedIn).thenReturn(false);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: auth),
          Provider<TwitchApi>.value(value: MockTwitchApi()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CreateClipButton(broadcasterId: '42', color: Colors.white),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Clip'));
    await tester.pumpAndSettle();

    expect(find.text('Create Clip'), findsOneWidget);
    expect(find.text('Log in to create clips.'), findsOneWidget);
  });
}
