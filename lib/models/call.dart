enum CallType {
  voice,
  video,
}
enum CallStatus {
  pending,
  ringing,
  active,
  ended,
  missed,
  rejected,
}
class Call {
  final String id;
  final String callerId;
  final String receiverId;
  final CallType type;
  CallStatus status;
  DateTime startTime;
  DateTime? endTime;
  Call({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.type,
    this.status = CallStatus.pending,
    DateTime? startTime,
    this.endTime,
  }) : startTime = startTime ?? DateTime.now();
  void start() {
    status = CallStatus.active;
  }
  void end() {
    status = CallStatus.ended;
    endTime = DateTime.now();
  }
  void reject() {
    status = CallStatus.rejected;
    endTime = DateTime.now();
  }
  void miss() {
    status = CallStatus.missed;
    endTime = DateTime.now();
  }
  void ring() {
    status = CallStatus.ringing;
  }
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callerId': callerId,
      'receiverId': receiverId,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }
  factory Call.fromMap(Map<String, dynamic> map) {
    return Call(
      id: map['id'],
      callerId: map['callerId'],
      receiverId: map['receiverId'],
      type: CallType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => CallType.voice,
      ),
      status: CallStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => CallStatus.pending,
      ),
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
    );
  }
}