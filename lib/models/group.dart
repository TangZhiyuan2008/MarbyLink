import 'dart:convert';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:marbylink/models/device.dart';
class Group {
  final String id;
  String name;
  final String passwordHash;
  final String creatorId;
  final List<String> memberIds;
  final String groupKey;
  DateTime createdAt;
  Group({
    required this.id,
    required this.name,
    required String password,
    required this.creatorId,
    required this.memberIds,
    required this.groupKey,
    DateTime? createdAt,
  }) : passwordHash = _hashPassword(password),
       createdAt = createdAt ?? DateTime.now();
  bool isCreator(String deviceId) => deviceId == creatorId;
  bool isMember(String deviceId) => memberIds.contains(deviceId);
  bool verifyPassword(String password) {
    return _hashPassword(password) == passwordHash;
  }
  void addMember(String deviceId) {
    if (!memberIds.contains(deviceId)) {
      memberIds.add(deviceId);
    }
  }
  void removeMember(String deviceId) {
    memberIds.remove(deviceId);
  }
  void updatePassword(String newPassword) {
    // 这里需要更新密码并重新生成群密钥
  }
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'passwordHash': passwordHash,
      'creatorId': creatorId,
      'memberIds': memberIds,
      'groupKey': groupKey,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'],
      name: map['name'],
      password: map['passwordHash'] ?? '', // 为了兼容性，实际使用 passwordHash
      creatorId: map['creatorId'],
      memberIds: List<String>.from(map['memberIds'] ?? []),
      groupKey: map['groupKey'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
  String toJson() => json.encode(toMap());
  factory Group.fromJson(String source) => Group.fromMap(json.decode(source));
}