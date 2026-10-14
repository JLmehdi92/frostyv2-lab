import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/utils/share_link.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class FakeSharePlatform extends Fake implements SharePlatform {
  FakeSharePlatform(this.answer);

  final ShareResult Function() answer;
  final shared = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    shared.add(params);
    return answer();
  }
}

void main() {
  String? copied;

  setUp(() {
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });

  Future<void> tapShare(WidgetTester tester, SharePlatform platform) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => shareLink(
                context,
                'https://www.twitch.tv/streamer',
                sharer: SharePlus.custom(platform),
              ),
              child: const Text('Share'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens the share sheet anchored to the button', (tester) async {
    final platform = FakeSharePlatform(
      () => const ShareResult('x', ShareResultStatus.success),
    );
    await tapShare(tester, platform);

    expect(platform.shared.single.text, 'https://www.twitch.tv/streamer');
    expect(platform.shared.single.sharePositionOrigin, isNotNull);
    expect(copied, isNull);
  });

  testWidgets('no share sheet: the link is copied', (tester) async {
    await tapShare(
      tester,
      FakeSharePlatform(
        () => const ShareResult('', ShareResultStatus.unavailable),
      ),
    );
    expect(copied, 'https://www.twitch.tv/streamer');
    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('a failing share sheet: the link is copied', (tester) async {
    await tapShare(
      tester,
      FakeSharePlatform(() => throw PlatformException(code: 'x')),
    );
    expect(copied, 'https://www.twitch.tv/streamer');
  });

  testWidgets('a second tap while the sheet opens is ignored', (tester) async {
    final platform = FakeSharePlatform(
      () => const ShareResult('x', ShareResultStatus.success),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                shareLink(context, 'a', sharer: SharePlus.custom(platform));
                shareLink(context, 'a', sharer: SharePlus.custom(platform));
              },
              child: const Text('Share'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(platform.shared, hasLength(1));
    expect(copied, isNull);
  });
}
