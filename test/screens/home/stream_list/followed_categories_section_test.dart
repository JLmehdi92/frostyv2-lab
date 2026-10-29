import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/followed_category.dart';
import 'package:onset/screens/home/stream_list/followed_categories_section.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';

Widget _host(List<FollowedCategory> categories) => MaterialApp(
  theme: ThemeData(extensions: const [OnsetColors.light]),
  home: Scaffold(
    body: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: FollowedCategoriesSection(categories: categories),
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('shows each followed category with its viewers', (tester) async {
    await tester.pumpWidget(
      _host(const [
        FollowedCategory(
          id: '1',
          name: 'Just Chatting',
          displayName: 'Just Chatting',
          viewers: 412300,
        ),
        FollowedCategory(id: '2', name: 'Chess', viewers: 1),
      ]),
    );

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Just Chatting'), findsOneWidget);
    expect(find.text('412K viewers'), findsOneWidget);
    expect(find.text('Chess'), findsOneWidget);
    expect(find.text('1 viewer'), findsOneWidget);
  });

  testWidgets('box art is decoded at the size it is drawn', (tester) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.reset);
    const category = FollowedCategory(
      id: '1',
      name: 'Chess',
      boxArtUrl: 'https://static-cdn.jtvnw.net/ttv-boxart/chess.jpg',
      viewers: 3,
    );
    int? decodedWidth() => tester
        .widget<OnsetCachedNetworkImage>(find.byType(OnsetCachedNetworkImage))
        .memCacheWidth;

    // The phone's 104 dp tile.
    await tester.pumpWidget(_host(const [category]));
    expect(decodedWidth(), 312);

    // The tablet's 18 dp chip.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [OnsetColors.light]),
        home: const Scaffold(
          body: FollowedCategoryChips(categories: [category]),
        ),
      ),
    );
    expect(decodedWidth(), 54);
  });

  testWidgets('no followed categories, no section', (tester) async {
    await tester.pumpWidget(_host(const []));

    expect(find.text('Categories'), findsNothing);
  });
}
