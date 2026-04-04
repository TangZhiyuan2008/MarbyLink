import 'dart:convert';
import 'package:marbylink/models/message.dart';
class GroupMessage extends Message {
  final String groupId;
  GroupMessage({
    required super.id,
    required super.content,
    required super.type,
    required super.senderId,
    required super.receiverId,
    required this.groupId,
    super.timestamp,
    super.isSent = false,
    super.isDelivered = false,
  });
  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'groupId': groupId,
      'type': 'group_message',
    };
  }
  factory GroupMessage.fromMap(Map<String, dynamic> map) {
    return GroupMessage(
      id: map['id'],
      content: map['content'],
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => MessageType.text,
      ),
      senderId: map['senderId'],
      receiverId: map['receiverId'],
      groupId: map['groupId'],
      timestamp: DateTime.parse(map['timestamp']),
      isSent: map['isSent'] ?? false,
      isDelivered: map['isDelivered'] ?? false,
    );
  }
  @override
  String toJson() => json.encode(toMap());
  factory GroupMessage.fromJson(String source) => GroupMessage.fromMap(json.decode(source));
}