import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:marbylink/models/device.dart';
class DeviceDiscovery {
  static const int PORT = 8877;
  static const Duration HEARTBEAT_INTERVAL = Duration(seconds: 30);
  static const Duration OFFLINE_THRESHOLD = Duration(seconds: 90);
  final StreamController<Device> _deviceFoundController = StreamController<Device>.broadcast();
  final StreamController<String> _deviceLostController = StreamController<String>.broadcast();
  late RawDatagramSocket _socket;
  final Map<String, Device> _devices = {};
  late Timer _heartbeatTimer;
  late Timer _cleanupTimer;
  final String _deviceId;
  final String _deviceName;
  final DeviceType _deviceType;
  Stream<Device> get onDeviceFound => _deviceFoundController.stream;
  Stream<String> get onDeviceLost => _deviceLostController.stream;
  String get deviceId => _deviceId;
  DeviceDiscovery()
      : _deviceId = _generateDeviceId(),
        _deviceName = _getDeviceName(),
        _deviceType = _getDeviceType();
  Future<void> start() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, PORT, reuseAddress: true, reusePort: true);
      _socket.broadcastEnabled = true;
      _socket.listen(_handleDatagram);
      _sendBroadcast();
      _heartbeatTimer = Timer.periodic(HEARTBEAT_INTERVAL, (_) => _sendBroadcast());
      _cleanupTimer = Timer.periodic(Duration(seconds: 10), (_) => _cleanupOfflineDevices());
    } catch (e) {
      print('Error starting device discovery: $e');
    }
  }
  void stop() {
    _heartbeatTimer.cancel();
    _cleanupTimer.cancel();
    _socket.close();
    _deviceFoundController.close();
    _deviceLostController.close();
  }
  void _handleDatagram(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket.receive();
      if (datagram != null) {
        try {
          final message = utf8.decode(datagram.data);
          final data = json.decode(message);
          if (data['type'] == 'discovery' || data['type'] == 'heartbeat') {
            final deviceId = data['id'];
            if (deviceId != _deviceId) {
              final device = Device(
                id: deviceId,
                name: data['name'],
                ipAddress: datagram.address.address,
                port: data['port'],
                type: data['deviceType'] == 'mobile' ? DeviceType.mobile : DeviceType.computer,
              );
              _updateDevice(device);
            }
          }
        } catch (e) {
          print('Error handling datagram: $e');
        }
      }
    }
  }
  void _sendBroadcast() {
    final message = json.encode({
      'type': 'discovery',
      'id': _deviceId,
      'name': _deviceName,
      'port': PORT,
      'deviceType': _deviceType == DeviceType.mobile ? 'mobile' : 'computer',
      'publicKey': '', // 占位符，实际使用时从加密模块获取
      'signingPublicKey': '', // 占位符，实际使用时从加密模块获取
    });
    final data = utf8.encode(message);
    _socket.send(data, InternetAddress('255.255.255.255'), PORT);
    _socket.send(data, InternetAddress('239.0.0.1'), PORT);
  }
  void _updateDevice(Device device) {
    final existingDevice = _devices[device.id];
    if (existingDevice == null) {
      _devices[device.id] = device;
      _deviceFoundController.add(device);
    } else {
      existingDevice.updateLastSeen();
    }
  }
  void _cleanupOfflineDevices() {
    final now = DateTime.now();
    final toRemove = <String>[];
    for (final entry in _devices.entries) {
      final device = entry.value;
      if (now.difference(device.lastSeen) > OFFLINE_THRESHOLD) {
        device.markOffline();
        toRemove.add(device.id);
        _deviceLostController.add(device.id);
      }
    }
    for (final id in toRemove) {
      _devices.remove(id);
    }
  }
  static String _generateDeviceId() {
    // 使用时间戳和随机数生成设备 ID，避免依赖 NetworkInterface
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 1000000;
    return 'device-$timestamp-$random';
  }
  static String _getMacAddress() {
    // 简化实现，直接返回时间戳
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  static String _getDeviceName() {
    try {
      return Platform.localHostname;
    } catch (e) {
      return 'Device-${DateTime.now().millisecondsSinceEpoch}';
    }
  }
  static DeviceType _getDeviceType() {
    final os = Platform.operatingSystem;
    if (os == 'android' || os == 'ios') {
      return DeviceType.mobile;
    } else {
      return DeviceType.computer;
    }
  }
}