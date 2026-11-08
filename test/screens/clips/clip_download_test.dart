import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/screens/clips/clip_download.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class MockClipService extends Mock implements TwitchClipService {}

class FakeSharePlatform extends Fake implements SharePlatform {
  final shared = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    shared.add(params);
    return const ShareResult('', ShareResultStatus.success);
  }
}

void main() {
  late MockClipService service;
  late FakeSharePlatform platform;
  final folder = Directory.systemTemp;

  setUpAll(() => registerFallbackValue(folder));

  setUp(() {
    service = MockClipService();
    platform = FakeSharePlatform();
  });

  Future<void> tapDownload(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => downloadClip(
                context,
                service: service,
                slug: 'Clip-1',
                folder: () async => folder,
                sharer: SharePlus.custom(platform),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
  }

  testWidgets('downloads the clip, then offers the video to save', (
    tester,
  ) async {
    final saved = File('${folder.path}/onset-clip-Clip-1.mp4')
      ..writeAsStringSync('mp4');
    when(
      () => service.downloadClip('Clip-1', any()),
    ).thenAnswer((_) async => saved);

    await tapDownload(tester);
    await tester.pump();

    expect(platform.shared, hasLength(1));
    final file = platform.shared.single.files!.single;
    expect(file.path, endsWith('onset-clip-Clip-1.mp4'));
    expect(file.mimeType, 'video/mp4');
    expect(saved.existsSync(), isFalse);
  });

  testWidgets('a failure says so and shares nothing', (tester) async {
    when(
      () => service.downloadClip('Clip-1', any()),
    ).thenThrow(const NetworkException('down'));

    await tapDownload(tester);
    await tester.pump();

    expect(platform.shared, isEmpty);
    expect(find.text('Couldn’t download this clip.'), findsOneWidget);
  });
}
