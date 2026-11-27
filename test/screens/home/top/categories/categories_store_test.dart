import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/category.dart';
import 'package:onset/screens/home/top/categories/stores/categories_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

CategoryTwitch category(String id) => CategoryTwitch('', id, 'Game $id');

void main() {
  test('a category a later page repeats is listed once', () async {
    final api = MockTwitchApi();
    when(() => api.getTopCategories()).thenAnswer(
      (_) async => CategoriesTwitch(
        [category('a'), category('b')],
        const {'cursor': 'next'},
      ),
    );
    when(() => api.getTopCategories(cursor: 'next')).thenAnswer(
      (_) async => CategoriesTwitch([category('b'), category('c')], const {}),
    );
    final store = CategoriesStore(authStore: MockAuthStore(), twitchApi: api);
    await Future<void>.delayed(Duration.zero);

    await store.getCategories();

    expect(store.categories.map((c) => c.id), ['a', 'b', 'c']);
    expect(store.hasMore, isFalse);
  });
}
