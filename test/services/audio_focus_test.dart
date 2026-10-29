import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/audio_focus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('frosty/audio-focus-test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late AudioFocus focus;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    focus = AudioFocus(channel: channel, supported: true);
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> change(String state) => messenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall('change', {'state': state})),
    (_) {},
  );

  test('asks for the focus once and lets it go', () async {
    final owner = Object();
    await focus.request(owner, (_) {});
    await focus.request(owner, (_) {});
    await focus.abandon(owner);
    await focus.abandon(owner);

    expect(calls.map((c) => c.method), ['request', 'abandon']);
  });

  test('changes reach the player holding the focus', () async {
    final changes = <AudioFocusChange>[];
    await focus.request(Object(), changes.add);

    await change('lossTransient');
    await change('gain');
    await change('loss');
    await change('noisy');
    await change('duck');

    expect(changes, [
      AudioFocusChange.lossTransient,
      AudioFocusChange.gain,
      AudioFocusChange.loss,
      AudioFocusChange.noisy,
    ]);
  });

  test('a newer player takes the focus over', () async {
    final first = Object();
    final firstChanges = <AudioFocusChange>[];
    await focus.request(first, firstChanges.add);
    await focus.request(Object(), (_) {});
    calls.clear();

    await focus.abandon(first);
    await change('loss');

    expect(calls, isEmpty);
    expect(firstChanges, isEmpty);
  });

  test('a platform without it, or a failing one, is left alone', () async {
    final owner = Object();
    await AudioFocus(channel: channel, supported: false).request(owner, (_) {});
    expect(calls, isEmpty);

    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'x'),
    );
    await focus.request(owner, (_) {});
    await focus.abandon(owner);
  });
}
