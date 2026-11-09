import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_stream_service.dart';
import 'package:onset/models/playback_access_token.dart';
import 'package:onset/screens/channel/video/free_preview.dart';

import '../../../fixtures/free_preview_payloads.dart';
import '../../../helpers/l10n.dart';

void main() {
  group('the token tells a timed preview apart', () {
    test('an unlimited token has no preview', () {
      expect(PlaybackAccessToken.parsePreviewEnd(unlimitedTokenValue), isNull);
    });

    test('viewing that stops before the token expires is a preview', () {
      final end = PlaybackAccessToken.parsePreviewEnd(
        previewTokenValue(viewUntil: 1794200300, expires: 1794220976),
      );
      expect(
        end,
        DateTime.fromMillisecondsSinceEpoch(1794200300000, isUtc: true),
      );
    });

    test('an odd value has no preview', () {
      expect(PlaybackAccessToken.parsePreviewEnd('nope'), isNull);
      expect(
        PlaybackAccessToken.parsePreviewEnd('{"chansub":{"view_until":"x"}}'),
        isNull,
      );
    });
  });

  group('the stream service', () {
    late Dio dio;
    late DioAdapter adapter;
    late TwitchStreamService service;

    setUp(() {
      dio = Dio(BaseOptions());
      adapter = DioAdapter(dio: dio);
      service = TwitchStreamService(dio);
    });

    void reply(Object? body) => adapter.onPost(
      'https://gql.twitch.tv/gql',
      (server) => server.reply(200, body),
      data: Matchers.any,
    );

    test('remembers a preview end per channel from its token', () async {
      reply({
        'data': {
          'streamPlaybackAccessToken': {
            'value': previewTokenValue(
              viewUntil: 1794200300,
              expires: 1794220976,
            ),
            'signature': 'deadbeef',
          },
        },
      });
      adapter.onGet(
        'https://usher.ttvnw.net/api/channel/hls/streamer.m3u8',
        (server) => server.reply(200, '#EXTM3U'),
      );
      await service.getUsherUrl(userLogin: 'streamer');
      expect(service.freePreviewEndFor('streamer'), isNotNull);
      expect(service.freePreviewEndFor('other'), isNull);
    });

    test('reads the tier a restricted live needs', () async {
      reply(restrictedStreamResponse(['ALLOW_TIER_2_AND_3_ONLY']));
      expect(
        await service.streamRestrictionTier('streamer'),
        SubscriberTier.tier2,
      );
    });

    test('an unrestricted live needs any tier', () async {
      reply(unrestrictedStreamResponse);
      expect(
        await service.streamRestrictionTier('streamer'),
        SubscriberTier.any,
      );
    });

    test('an unreadable answer gives no tier', () async {
      reply({'errors': <Object>[]});
      expect(await service.streamRestrictionTier('streamer'), isNull);
    });
  });

  group('the preview controller', () {
    test('counts down and expires once', () {
      var now = DateTime(2026, 11, 9, 12);
      var expiries = 0;
      final controller = FreePreviewController(
        endsAt: DateTime(2026, 11, 9, 12, 2, 31),
        clock: () => now,
        onExpired: () => expiries++,
      );
      addTearDown(controller.dispose);
      expect(formatPreviewRemaining(controller.remaining), '2:31');
      now = DateTime(2026, 11, 9, 12, 3);
      controller.expire();
      controller.expire();
      expect(controller.expired, isTrue);
      expect(expiries, 1);
    });

    test('a preview already over is expired at once', () {
      final controller = FreePreviewController(
        endsAt: DateTime(2020),
        clock: () => DateTime(2026),
      );
      addTearDown(controller.dispose);
      expect(controller.expired, isTrue);
    });
  });

  group('the preview layer', () {
    Future<FreePreviewController> pump(
      WidgetTester tester, {
      required VoidCallback onWeb,
      SubscriberTier tier = SubscriberTier.any,
    }) async {
      final now = DateTime(2026, 11, 9, 12);
      final controller = FreePreviewController(
        endsAt: now.add(const Duration(minutes: 2, seconds: 5)),
        clock: () => now,
      )..tier = tier;
      await pumpLocalized(
        tester,
        Scaffold(
          body: SizedBox(
            width: 400,
            height: 225,
            child: FreePreviewLayer(
              controller: controller,
              name: 'Streamer',
              login: 'streamer',
              onUseWebPlayer: onWeb,
            ),
          ),
        ),
        locale: en,
      );
      return controller;
    }

    testWidgets('a banner names the tier and the time left', (tester) async {
      final controller = await pump(tester, onWeb: () {});
      expect(
        find.text('Streamer’s stream is for subscribers only'),
        findsOneWidget,
      );
      expect(find.text('Free preview: 2:05 left'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);

      controller.tier = SubscriberTier.tier3;
      await tester.pump();
      expect(
        find.text('Streamer’s stream is for Tier 3 subscribers only'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Hide'));
      await tester.pumpAndSettle();
      expect(find.byKey(FreePreviewLayer.bannerKey), findsNothing);
      controller.dispose();
    });

    testWidgets('when it ends, Subscribe and the web player are offered', (
      tester,
    ) async {
      var web = 0;
      final controller = await pump(tester, onWeb: () => web++);
      controller.expire();
      await tester.pumpAndSettle();

      expect(find.text('Your free preview has ended'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
      await tester.tap(find.byKey(FreePreviewLayer.webPlayerKey));
      expect(web, 1);
      controller.dispose();
    });
  });
}
