import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/screens/home/search/search.dart';
import 'package:onset/screens/home/search/stores/search_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'search_history': ['xqc', 'lirik', 'chess'],
    });
  });

  test('one past search can be removed and stays removed', () async {
    final store = SearchStore(
      authStore: MockAuthStore(),
      twitchApi: MockTwitchApi(),
    );
    // The constructor loads the history.
    await pumpEventQueue();

    store.removeFromHistory('lirik');

    expect(store.searchHistory, ['xqc', 'chess']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('search_history'), ['xqc', 'chess']);
    store.dispose();
  });

  testWidgets('each past search has its own remove button', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: MockAuthStore()),
          Provider<TwitchApi>.value(value: MockTwitchApi()),
        ],
        child: MaterialApp(
          home: Scaffold(body: Search(scrollController: controller)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('lirik'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove lirik from history'));
    await tester.pump();

    expect(find.text('lirik'), findsNothing);
    expect(find.text('xqc'), findsOneWidget);
    expect(find.text('chess'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
