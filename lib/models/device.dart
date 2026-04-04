enum DeviceType {
  mobile,
  computer,
}
class Device {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final DeviceType type;
  bool isOnline;
  DateTime lastSeen;
  Device({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.type,
    this.isOnline = true,
  }) : lastSeen = DateTime.now();
  void updateLastSeen() {
    lastSeen = DateTime.now();
    isOnline = true;
  }
  void markOffline() {
    isOnline = false;
  }
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Device && other.id == id;
  }
  @override
  int get hashCode => id.hashCode;
}