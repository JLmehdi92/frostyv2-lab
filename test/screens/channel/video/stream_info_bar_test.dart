import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/screens/channel/video/stream_info_bar.dart';
import 'package:onset/screens/home/top/categories/category_streams.dart';

class _Pushes extends NavigatorObserver {
  final names = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.add(route.settings.name);
}

void main() {
  testWidgets('a screen reader opens the category as a link', (tester) async {
    final semantics = tester.ensureSemantics();
    final pushes = _Pushes();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [pushes],
        home: const Scaffold(
          body: StreamInfoBar(
            displayName: 'Streamer',
            isOffline: true,
            offlineChannelInfo: Channel(
              broadcasterId: '42',
              broadcasterLogin: 'streamer',
              broadcasterName: 'Streamer',
              broadcasterLanguage: 'en',
              title: 'Endgames',
              gameId: '743',
              gameName: 'Chess',
            ),
          ),
        ),
      ),
    );
    pushes.names.clear();

    final link = find.semantics.byLabel('Chess');
    expect(
      tester.getSemantics(find.text('Chess')),
      matchesSemantics(label: 'Chess', isLink: true, hasTapAction: true),
    );
    tester.semantics.tap(link);
    expect(pushes.names, [CategoryStreams.routeName]);
    semantics.dispose();
  });
}
