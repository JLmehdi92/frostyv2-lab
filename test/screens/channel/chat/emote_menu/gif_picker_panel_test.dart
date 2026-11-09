import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/giphy_service.dart';
import 'package:onset/models/gif_picker.dart';
import 'package:onset/screens/channel/chat/emote_menu/gif_picker_panel.dart';

import '../../../../fixtures/gif_payloads.dart';
import '../../../../helpers/l10n.dart';

class _MockGiphy extends Mock implements GiphyService {}

const _config = GifPickerConfig(
  enabled: true,
  allowlisted: true,
  apiKey: 'abcDEF123456',
  rating: 'pg',
);

void main() {
  late _MockGiphy giphy;
  late List<(String, String)> sent;
  late GifSendResult result;
  late int closed;

  setUpAll(() => registerFallbackValue(_config));

  setUp(() {
    giphy = _MockGiphy();
    sent = [];
    result = const GifSendResult(GifSendStatus.sent);
    closed = 0;
    when(
      () => giphy.search(
        config: any(named: 'config'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async => [GiphyGif.fromJson(giphyGif('a1'))!]);
  });

  Future<void> pump(WidgetTester tester, {GifPickerConfig? config}) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: SizedBox(
          height: 360,
          child: GifPickerPanel(
            channelLogin: 'streamer',
            channelName: 'Streamer',
            loadConfig: () async => config,
            giphy: giphy,
            send: (gif, term) async {
              sent.add((gif.id, term));
              return result;
            },
            onSent: () => closed++,
          ),
        ),
      ),
      locale: en,
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a confirmed GIF is sent and the menu closes', (tester) async {
    await pump(tester, config: _config);
    expect(find.text('Powered by GIPHY'), findsOneWidget);

    await tester.tap(find.byKey(GifPickerPanel.tileKey('a1')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Send this GIF?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(sent, isEmpty);

    await tester.tap(find.byKey(GifPickerPanel.tileKey('a1')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(GifPickerPanel.sendKey));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(sent, [('a1', '')]);
    expect(closed, 1);
  });

  testWidgets('typing searches GIPHY after a pause', (tester) async {
    await pump(tester, config: _config);
    await tester.enterText(find.byKey(GifPickerPanel.searchKey), 'cat');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    verify(() => giphy.search(config: _config, query: 'cat')).called(1);
  });

  testWidgets('a new search shows that it loads over the old GIFs', (
    tester,
  ) async {
    await pump(tester, config: _config);
    final pending = Completer<List<GiphyGif>?>();
    when(
      () => giphy.search(config: _config, query: 'cat'),
    ).thenAnswer((_) => pending.future);
    await tester.enterText(find.byKey(GifPickerPanel.searchKey), 'cat');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(GifPickerPanel.loadingKey), findsOneWidget);
    expect(find.byKey(GifPickerPanel.tileKey('a1')), findsOneWidget);
    pending.complete(const []);
    await tester.pump();
    expect(find.byKey(GifPickerPanel.loadingKey), findsNothing);
  });

  testWidgets('a cooldown says how long to wait', (tester) async {
    result = const GifSendResult(
      GifSendStatus.cooldown,
      secondsUntilCanSend: 12,
    );
    await pump(tester, config: _config);
    await tester.tap(find.byKey(GifPickerPanel.tileKey('a1')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(GifPickerPanel.sendKey));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('You can send another GIF in 12 seconds.'),
      findsOneWidget,
    );
    expect(closed, 0);
  });

  testWidgets('a viewer who may not send sees why and Subscribe', (
    tester,
  ) async {
    await pump(
      tester,
      config: const GifPickerConfig(
        enabled: true,
        allowlisted: false,
        apiKey: 'abcDEF123456',
        rating: 'pg',
      ),
    );
    expect(find.textContaining('subscriber benefit'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
    verifyNever(
      () => giphy.search(
        config: any(named: 'config'),
        query: any(named: 'query'),
      ),
    );
  });

  testWidgets('no config hides the picker behind a message', (tester) async {
    await pump(tester);
    expect(find.text('GIFs aren’t available in this chat.'), findsOneWidget);
  });

  testWidgets('a GIPHY failure says so', (tester) async {
    when(
      () => giphy.search(
        config: any(named: 'config'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async => null);
    await pump(tester, config: _config);
    expect(
      find.text('Couldn’t load GIFs. Try again in a moment.'),
      findsOneWidget,
    );
  });
}
