import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class CastDevice {
  const CastDevice({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is CastDevice && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

enum CastConnection { disconnected, connecting, connected }

@immutable
class CastMedia {
  const CastMedia({
    required this.url,
    required this.title,
    required this.live,
    this.subtitle,
    this.imageUrl,
    this.start = Duration.zero,
  });

  final String url;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final bool live;
  final Duration start;

  Map<String, Object?> toArguments() => {
    'url': url,
    'title': title,
    'subtitle': subtitle,
    'imageUrl': imageUrl,
    'live': live,
    'startMs': start.inMilliseconds,
  };
}

@immutable
class CastStatus {
  const CastStatus(this.connection, {this.deviceName, this.deviceId});

  static const disconnected = CastStatus(CastConnection.disconnected);

  final CastConnection connection;
  final String? deviceName;
  final String? deviceId;

  static CastStatus fromMap(Object? raw) {
    if (raw is! Map) return disconnected;
    final connection = switch (raw['state']) {
      'connected' => CastConnection.connected,
      'connecting' => CastConnection.connecting,
      _ => CastConnection.disconnected,
    };
    final device = raw['device'];
    final id = raw['deviceId'];
    return CastStatus(
      connection,
      deviceName: device is String ? device : null,
      deviceId: id is String ? id : null,
    );
  }
}

class CastBridge {
  CastBridge({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel('onset/cast'),
      supported = supported ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool supported;

  void listen({
    required void Function(List<CastDevice> devices) onDevices,
    required void Function(CastStatus status) onStatus,
  }) {
    if (!supported) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'devices':
          onDevices(_devices(call.arguments));
        case 'state':
          onStatus(CastStatus.fromMap(call.arguments));
      }
    });
  }

  static List<CastDevice> _devices(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map && item['id'] is String && item['name'] is String)
          CastDevice(id: item['id'] as String, name: item['name'] as String),
    ];
  }

  Future<bool> startDiscovery() async => await _ask<bool>('start') ?? false;

  Future<void> stopDiscovery() => _ask<Object?>('stop');

  Future<CastStatus> status() async =>
      CastStatus.fromMap(await _ask<Object?>('state'));

  Future<bool> connect(CastDevice device) async =>
      await _ask<bool>('connect', {'id': device.id}) ?? false;

  Future<void> disconnect() => _ask<Object?>('disconnect');

  Future<bool> load(CastMedia media) async =>
      await _ask<bool>('load', media.toArguments()) ?? false;

  Future<T?> _ask<T>(String method, [Object? arguments]) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } catch (e) {
      debugPrint('Cast $method failed: ${e.runtimeType}');
      return null;
    }
  }
}
