import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/widgets/add_chat_dialog.dart';
import 'package:provider/provider.dart';

import '../../../../helpers/l10n.dart';

class _MockTwitchApi extends Mock implements TwitchApi {}

ChannelQuery _channel(String login) => ChannelQuery(
  broadcasterLogin: login,
  displayName: login,
  id: login,
  isLive: false,
  startedAt: '',
);

void main() {
  late _MockTwitchApi api;
  late Map<String, Completer<List<ChannelQuery>>> searches;

  setUp(() {
    api = _MockTwitchApi();
    searches = {};
    when(() => api.searchChannels(query: any(named: 'query'))).thenAnswer(
      (invocation) =>
          (searches[invocation.namedArguments[#query] as String] =
                  Completer())
              .future,
    );
    when(
      () => api.getUser(userLogin: any(named: 'userLogin')),
    ).thenAnswer((_) => Completer<UserTwitch>().future);
  });

  Future<void> pump(WidgetTester tester) => pumpLocalized(
    tester,
    Scaffold(body: AddChatSheet(twitchApi: api)),
    locale: en,
    wrap: (app) => Provider<TwitchApi>.value(value: api, child: app),
  );

  testWidgets('a slower answer to an older search does not replace the newer '
      'results', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'xq');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'xqc');
    await tester.pump(const Duration(milliseconds: 300));

    searches['xqc']!.complete([_channel('xqcfresh')]);
    await tester.pump();
    searches['xq']!.complete([_channel('xqstale')]);
    await tester.pump();

    expect(find.text('xqcfresh'), findsOneWidget);
    expect(find.text('xqstale'), findsNothing);
  });

  testWidgets('a search answered after the field was cleared and typed in '
      'again shows nothing', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'xqc');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 100));

    searches['xqc']!.complete([_channel('xqcfresh')]);
    await tester.pump();

    expect(find.text('xqcfresh'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    searches['a']!.complete([]);
    await tester.pump();
  });
}
