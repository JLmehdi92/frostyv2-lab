import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/services/network_metering.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('frosty/network-test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  void answer(Object? Function() reply) {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply();
    });
  }

  test('asks Android whether the network is metered', () async {
    answer(() => true);
    final metering = NetworkMetering(channel: channel, supported: true);

    expect(await metering.isMetered(), isTrue);
    expect(calls.single.method, 'isMetered');
  });

  test('an unmetered network (Wi-Fi) is false', () async {
    answer(() => false);
    final metering = NetworkMetering(channel: channel, supported: true);

    expect(await metering.isMetered(), isFalse);
  });

  test('no answer or a failure is unknown', () async {
    answer(() => null);
    expect(
      await NetworkMetering(channel: channel, supported: true).isMetered(),
      isNull,
    );
    answer(() => throw PlatformException(code: 'boom'));
    expect(
      await NetworkMetering(channel: channel, supported: true).isMetered(),
      isNull,
    );
  });

  test('elsewhere than Android it is unknown, without asking', () async {
    answer(() => true);
    final metering = NetworkMetering(channel: channel, supported: false);

    expect(await metering.isMetered(), isNull);
    expect(calls, isEmpty);
  });
}
