import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/home/stream_list/stream_list_store.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

void main() {
  testWidgets('a closed list stops following settings and leaves the '
      'scroll controller to its owner', (tester) async {
    final api = MockTwitchApi();
    final settings = SettingsStore.fromJson({});
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) async => const StreamsTwitch([], {}));
    final controller = ScrollController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: MockAuthStore()),
          Provider<SettingsStore>.value(value: settings),
          Provider<TwitchApi>.value(value: api),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StreamsList(
              listType: ListType.top,
              scrollController: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    clearInteractions(api);

    settings.streamLanguage = 'fr';
    await tester.pump();

    verifyNever(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    );
    // Still usable: the list did not dispose it.
    controller.addListener(() {});
    controller.dispose();
  });
}
