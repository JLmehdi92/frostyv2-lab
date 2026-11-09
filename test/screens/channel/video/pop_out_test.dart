import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/pop_out.dart';
import 'package:onset/services/floating_player.dart';

import '../../../helpers/l10n.dart';

class _FakeFloating extends FloatingPlayer {
  _FakeFloating({this.allowed = false}) : super(supported: true);

  bool allowed;
  bool grantInSettings = false;
  bool startAccepted = true;
  var settingsOpened = 0;
  final started = <String>[];
  String? channelLabel;

  void Function(bool returned)? closedListener;

  @override
  set onClosed(void Function(bool returned)? listener) =>
      closedListener = listener;

  @override
  Future<bool> canDrawOverlays() async => allowed;

  @override
  Future<bool> openPermissionSettings() async {
    settingsOpened++;
    if (grantInSettings) allowed = true;
    return true;
  }

  @override
  Future<bool> start({
    required String url,
    required String title,
    required String channelLabel,
    required String closeLabel,
  }) async {
    started.add(url);
    this.channelLabel = channelLabel;
    return startAccepted;
  }
}

Future<PopOutResult> _run(
  WidgetTester tester,
  _FakeFloating floating, {
  String? url = 'https://usher/a.m3u8',
  required List<String> log,
  Future<void> Function(WidgetTester)? answer,
}) async {
  late BuildContext context;
  await pumpLocalized(
    tester,
    Scaffold(
      body: Builder(
        builder: (c) {
          context = c;
          return const SizedBox.expand();
        },
      ),
    ),
    locale: en,
  );
  final result = popOut(
    context,
    floating: floating,
    url: url,
    title: 'Live',
    pictureInPicture: () => log.add('pip'),
    beforeStart: () => log.add('paused'),
    afterClose: ({required returned}) => log.add('closed $returned'),
    waitForResume: () async => log.add('waited'),
  );
  await tester.pump();
  await tester.pump();
  if (answer != null) {
    await answer(tester);
    await tester.pumpAndSettle();
  }
  return result;
}

void main() {
  testWidgets('starts at once when the permission is granted', (tester) async {
    final floating = _FakeFloating(allowed: true);
    final log = <String>[];

    expect(await _run(tester, floating, log: log), PopOutResult.floating);

    expect(floating.started, ['https://usher/a.m3u8']);
    expect(floating.channelLabel, 'Floating player');
    expect(log, ['paused']);

    floating.closedListener!(true);
    expect(log, ['paused', 'closed true']);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('explains the permission before asking for it', (tester) async {
    final floating = _FakeFloating()..grantInSettings = true;
    final log = <String>[];

    final result = _run(
      tester,
      floating,
      log: log,
      answer: (tester) async {
        expect(find.text('Float the stream over other apps?'), findsOne);
        expect(floating.settingsOpened, 0);
        await tester.tap(find.text('Continue'));
      },
    );

    expect(await result, PopOutResult.floating);
    expect(floating.settingsOpened, 1);
    expect(log, ['waited', 'paused']);
  });

  testWidgets('falls back to picture-in-picture when refused', (tester) async {
    final floating = _FakeFloating();
    final log = <String>[];

    final result = _run(
      tester,
      floating,
      log: log,
      answer: (tester) => tester.tap(find.text('Continue')),
    );

    expect(await result, PopOutResult.pictureInPicture);
    expect(floating.started, isEmpty);
    expect(log, ['waited', 'pip']);
    expect(
      find.text(
        'Without the permission, the stream continues in picture-in-picture.',
      ),
      findsOne,
    );
  });

  testWidgets('not now asks nothing of the system', (tester) async {
    final floating = _FakeFloating();
    final log = <String>[];

    final result = _run(
      tester,
      floating,
      log: log,
      answer: (tester) => tester.tap(find.text('Not now')),
    );

    expect(await result, PopOutResult.cancelled);
    expect(floating.settingsOpened, 0);
    expect(log, isEmpty);
  });

  testWidgets('a window the system refuses falls back to picture-in-picture', (
    tester,
  ) async {
    final floating = _FakeFloating(allowed: true)..startAccepted = false;
    final log = <String>[];

    expect(
      await _run(tester, floating, log: log),
      PopOutResult.pictureInPicture,
    );
    expect(log, ['paused', 'closed true', 'pip']);
  });

  testWidgets('a stream not ready yet is not floated', (tester) async {
    final floating = _FakeFloating(allowed: true);
    final log = <String>[];

    expect(
      await _run(tester, floating, url: null, log: log),
      PopOutResult.notReady,
    );
    expect(floating.started, isEmpty);
  });

  test('the bridge reports a closed window and never throws', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('onset/floating-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'x'),
        );
    final bridge = FloatingPlayer(channel: channel, supported: true);
    expect(await bridge.canDrawOverlays(), isFalse);
    expect(
      await bridge.start(
        url: 'u',
        title: 't',
        channelLabel: 'c',
        closeLabel: 'x',
      ),
      isFalse,
    );
    final unsupported = FloatingPlayer(channel: channel, supported: false);
    expect(await unsupported.canDrawOverlays(), isFalse);
  });
}
