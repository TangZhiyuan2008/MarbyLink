import 'dart:convert';
import 'package:marbylink/models/device.dart';
enum MessageType {
  text,
  image,
  audio,
}
class Message {
  final String id;
  final String content;
  final MessageType type;
  final String senderId;
  final String receiverId;
  final DateTime timestamp;
  bool isSent;
  bool isDelivered;
  Message({
    required this.id,
    required this.content,
    required this.type,
    required this.senderId,
    required this.receiverId,
    DateTime? timestamp,
    this.isSent = false,
    this.isDelivered = false,
  }) : timestamp = timestamp ?? DateTime.now();
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'type': type.toString().split('.').last,
      'senderId': senderId,
      'receiverId': receiverId,
      'timestamp': timestamp.toIso8601String(),
      'isSent': isSent,
      'isDelivered': isDelivered,
    };
  }
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      content: map['content'],
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => MessageType.text,
      ),
      senderId: map['senderId'],
      receiverId: map['receiverId'],
      timestamp: DateTime.parse(map['timestamp']),
      isSent: map['isSent'] ?? false,
      isDelivered: map['isDelivered'] ?? false,
    );
  }
  String toJson() => json.encode(toMap());
  factory Message.fromJson(String source) => Message.fromMap(json.decode(source));
}