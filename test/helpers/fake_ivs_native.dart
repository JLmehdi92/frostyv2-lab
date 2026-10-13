import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fakes the native side of the IVS texture player so `IvsVideoStore` can be
/// driven from unit tests.
///
/// - `frosty/ivs-texture-manager`: `create` returns [textureId] and records its
///   arguments, `dispose` is recorded.
/// - `frosty/ivs-texture/<id>`: every Dart → native call is recorded in
///   [playerCalls].
/// - [emit] delivers an `onEvent` call native → Dart, exactly like
///   `IvsPlayerCore.send` does on device.
class FakeIvsNative {
  FakeIvsNative({this.textureId = 7});

  final int textureId;

  final managerCalls = <MethodCall>[];

  /// When set, `create` waits for this gate before returning the id.
  Completer<void>? createGate;

  /// When true, `create` fails like a broken native side.
  bool createThrows = false;

  /// When true, the player's `load` fails like a broken native side.
  bool loadThrows = false;
  final playerCalls = <MethodCall>[];

  static const _manager = MethodChannel('frosty/ivs-texture-manager');

  String get playerChannelName => 'frosty/ivs-texture/$textureId';

  TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void install() {
    TestWidgetsFlutterBinding.ensureInitialized();
    _messenger.setMockMethodCallHandler(_manager, (call) async {
      managerCalls.add(call);
      if (call.method == 'create') {
        await createGate?.future;
        if (createThrows) {
          throw PlatformException(code: 'create_failed');
        }
        return textureId;
      }
      return null;
    });
    _messenger.setMockMethodCallHandler(MethodChannel(playerChannelName), (
      call,
    ) async {
      playerCalls.add(call);
      if (call.method == 'load' && loadThrows) {
        throw PlatformException(code: 'load_failed');
      }
      return null;
    });
  }

  void uninstall() {
    _messenger
      ..setMockMethodCallHandler(_manager, null)
      ..setMockMethodCallHandler(MethodChannel(playerChannelName), null);
  }

  /// Pushes a native player event to the Dart handler.
  Future<void> emit(Map<String, Object?> event) async {
    await _messenger.handlePlatformMessage(
      playerChannelName,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onEvent', event),
      ),
      (_) {},
    );
  }

  Iterable<MethodCall> callsNamed(String method) =>
      playerCalls.where((c) => c.method == method);
}
