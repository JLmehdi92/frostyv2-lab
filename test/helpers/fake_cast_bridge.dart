import 'package:onset/services/cast_bridge.dart';

class FakeCastBridge extends CastBridge {
  FakeCastBridge() : super(supported: true);

  late void Function(List<CastDevice>) devices;
  late void Function(CastStatus) pushStatus;
  var available = true;
  var connectAccepted = true;
  var loadAccepted = true;
  final loaded = <CastMedia>[];
  final connected = <CastDevice>[];
  var disconnects = 0;
  CastStatus current = CastStatus.disconnected;

  @override
  void listen({
    required void Function(List<CastDevice> devices) onDevices,
    required void Function(CastStatus status) onStatus,
  }) {
    devices = onDevices;
    pushStatus = onStatus;
  }

  @override
  Future<bool> startDiscovery() async => available;

  @override
  Future<void> stopDiscovery() async {}

  @override
  @override
  Future<CastStatus> status() async => current;

  @override
  Future<bool> connect(CastDevice device) async {
    connected.add(device);
    return connectAccepted;
  }

  @override
  Future<void> disconnect() async => disconnects++;

  @override
  Future<bool> load(CastMedia media) async {
    loaded.add(media);
    return loadAccepted;
  }
}
