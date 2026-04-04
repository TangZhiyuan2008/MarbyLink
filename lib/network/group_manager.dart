import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:marbylink/crypto/encryption.dart';
import 'package:marbylink/models/group.dart';
import 'package:marbylink/models/group_message.dart';
import 'package:marbylink/network/tcp_client.dart';
class GroupManager {
  final String _deviceId;
  final Encryption _encryption;
  final TcpClient _tcpClient;
  final Map<String, Group> _groups = {};
  final StreamController<Group> _groupUpdateController = StreamController<Group>.broadcast();
  final StreamController<GroupMessage> _groupMessageController = StreamController<GroupMessage>.broadcast();
  Stream<Group> get onGroupUpdate => _groupUpdateController.stream;
  Stream<GroupMessage> get onGroupMessage => _groupMessageController.stream;
  GroupManager(this._deviceId, this._encryption, this._tcpClient) {
    _listenForGroupMessages();
  }
  Future<Group> createGroup(String name, String password) async {
    final groupId = 'group_${Random().nextInt(1000000)}';
    final groupKey = _generateGroupKey();
    final group = Group(
      id: groupId,
      name: name,
      password: password,
      creatorId: _deviceId,
      memberIds: [_deviceId],
      groupKey: groupKey,
    );
    _groups[groupId] = group;
    _groupUpdateController.add(group);
    return group;
  }
  Future<Group?> joinGroup(String groupId, String password, Map<String, String> memberIps) async {
    // 尝试连接到群创建者，验证密码并获取群信息
    for (final memberId in memberIps.keys) {
      try {
        final ipAddress = memberIps[memberId];
        if (ipAddress != null) {
          // 发送加入请求
          final request = json.encode({
            'type': 'join_group',
            'groupId': groupId,
            'password': password,
            'requesterId': _deviceId,
          });
          final response = await _tcpClient.sendRequest(request, ipAddress);
          if (response != null) {
            final responseData = json.decode(response);
            if (responseData['success'] == true) {
              // 密码验证成功，创建群组对象
              final group = Group(
                id: groupId,
                name: responseData['groupName'],
                password: password, // 实际使用的是密码哈希
                creatorId: responseData['creatorId'],
                memberIds: List<String>.from(responseData['memberIds']),
                groupKey: responseData['groupKey'],
                createdAt: DateTime.parse(responseData['createdAt']),
              );
              _groups[groupId] = group;
              _groupUpdateController.add(group);
              return group;
            }
          }
        }
      } catch (e) {
        print('Error joining group: $e');
        continue;
      }
    }
    return null;
  }
  void sendGroupMessage(GroupMessage message, Map<String, String> memberIps) {
    // 遍历所有在线成员，通过TCP连接发送消息
    for (final memberId in _groups[message.groupId]?.memberIds ?? []) {
      if (memberId != _deviceId) {
        final ipAddress = memberIps[memberId];
        if (ipAddress != null) {
          _tcpClient.sendMessage(message, ipAddress);
        }
      }
    }
  }
  void leaveGroup(String groupId) {
    final group = _groups[groupId];
    if (group != null) {
      group.removeMember(_deviceId);
      if (group.memberIds.isEmpty) {
        _groups.remove(groupId);
      } else {
        _groupUpdateController.add(group);
      }
    }
  }
  void removeMember(String groupId, String memberId) {
    final group = _groups[groupId];
    if (group != null && group.isCreator(_deviceId)) {
      group.removeMember(memberId);
      _groupUpdateController.add(group);
    }
  }
  void updateGroupPassword(String groupId, String newPassword) {
    final group = _groups[groupId];
    if (group != null && group.isCreator(_deviceId)) {
      group.updatePassword(newPassword);
      _groupUpdateController.add(group);
    }
  }
  void _listenForGroupMessages() {
    _tcpClient.onMessage.listen((message) {
      if (message is GroupMessage) {
        _groupMessageController.add(message);
      }
    });
  }
  String _generateGroupKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64.encode(bytes);
  }
  List<Group> getGroups() {
    return _groups.values.toList();
  }
  Group? getGroup(String groupId) {
    return _groups[groupId];
  }
  void dispose() {
    _groupUpdateController.close();
    _groupMessageController.close();
  }
}