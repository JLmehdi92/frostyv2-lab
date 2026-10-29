import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/widgets/twitch_web_page.dart';
import 'package:onset/widgets/user_actions_modal.dart';

class MockAuthStore extends Mock implements AuthStore {}

void main() {
  Future<void> pump(WidgetTester tester, {required bool loggedIn}) {
    final auth = MockAuthStore();
    when(() => auth.isLoggedIn).thenReturn(loggedIn);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserActionsModal(
            authStore: auth,
            name: 'Streamer',
            userLogin: 'streamer',
            userId: '1',
          ),
        ),
      ),
    );
  }

  testWidgets('a logged-in viewer can follow on twitch.tv', (tester) async {
    await pump(tester, loggedIn: true);
    expect(find.text('Follow Streamer on Twitch'), findsOneWidget);
    expect(find.text('Report Streamer'), findsOneWidget);
  });

  testWidgets('logged out, there is nothing to follow with', (tester) async {
    await pump(tester, loggedIn: false);
    expect(find.text('Follow Streamer on Twitch'), findsNothing);
  });

  testWidgets('only twitch.tv pages open', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => TwitchWebPage.open(
              context,
              title: 'x',
              url: Uri.parse('https://evil.example/twitch.tv'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.byType(TwitchWebPage), findsNothing);
  });
}
