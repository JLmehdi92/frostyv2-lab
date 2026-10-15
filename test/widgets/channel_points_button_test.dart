import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/community_points.dart';
import 'package:frosty/screens/channel/stores/channel_events_store.dart';
import 'package:frosty/widgets/channel_points_button.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockChannelEventsStore extends Mock implements ChannelEventsStore {}

void main() {
  late MockChannelEventsStore store;

  setUp(() {
    store = MockChannelEventsStore();
    when(() => store.channelId).thenReturn('watched');
    when(() => store.points).thenReturn(CommunityPointsContext.empty);
  });

  Future<void> pump(WidgetTester tester, {String? channelId}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<ChannelEventsStore?>.value(
              value: store,
              child: ChannelPointsButton(channelId: channelId),
            ),
          ),
        ),
      );

  testWidgets("another channel's chat tab never reads the store", (
    tester,
  ) async {
    await pump(tester, channelId: 'other');

    verifyNever(() => store.points);
  });

  testWidgets("the watched channel's chat reads it", (tester) async {
    await pump(tester, channelId: 'watched');

    verify(() => store.points).called(greaterThan(0));
  });
}
