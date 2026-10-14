import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/settings/account/account_options.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

void main() {
  testWidgets('offers Twitch\'s security and connections pages', (
    tester,
  ) async {
    final auth = MockAuthStore();
    final user = MockUserStore();
    when(() => auth.user).thenReturn(user);
    when(() => user.details).thenReturn(const UserTwitch('7', 'me', 'Me', ''));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AccountOptions(authStore: auth)),
      ),
    );

    expect(find.text('Security and privacy'), findsOneWidget);
    expect(find.text('Connections'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });
}
