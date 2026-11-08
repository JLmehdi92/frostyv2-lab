import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/notification_settings_link.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('onset/notification-settings-test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> systemOpens() => messenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(const MethodCall('open')),
    (_) {},
  );

  test('opens once when the system launched the app for it', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => true);
    var opened = 0;
    await NotificationSettingsLink(
      channel: channel,
      supported: true,
    ).listen(() => opened++);
    expect(opened, 1);
  });

  test('opens each time the system asks while running', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => false);
    var opened = 0;
    await NotificationSettingsLink(
      channel: channel,
      supported: true,
    ).listen(() => opened++);
    expect(opened, 0);
    await systemOpens();
    await systemOpens();
    expect(opened, 2);
  });

  test('nothing elsewhere, and a failing platform is left alone', () async {
    var asked = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      asked++;
      throw PlatformException(code: 'x');
    });
    var opened = 0;
    await NotificationSettingsLink(
      channel: channel,
      supported: false,
    ).listen(() => opened++);
    expect(asked, 0);
    await NotificationSettingsLink(
      channel: channel,
      supported: true,
    ).listen(() => opened++);
    expect(opened, 0);
  });
}
