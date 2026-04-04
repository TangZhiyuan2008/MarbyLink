import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:marbylink/models/group.dart';
import 'package:marbylink/models/group_message.dart';
import 'package:marbylink/models/message.dart';
import 'package:marbylink/network/group_manager.dart';
class GroupChatPage extends StatefulWidget {
  final Group group;
  final GroupManager groupManager;
  final String currentDeviceId;
  final Map<String, String> memberIps;
  const GroupChatPage({
    super.key,
    required this.group,
    required this.groupManager,
    required this.currentDeviceId,
    required this.memberIps,
  });
  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}
class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _textController = TextEditingController();
  final List<GroupMessage> _messages = [];
  late StreamSubscription<GroupMessage> _messageSubscription;
  @override
  void initState() {
    super.initState();
    _messageSubscription = widget.groupManager.onGroupMessage.listen((message) {
      if (message.groupId == widget.group.id) {
        setState(() {
          _messages.add(message);
        });
      }
    });
  }
  @override
  void dispose() {
    _messageSubscription.cancel();
    _textController.dispose();
    super.dispose();
  }
  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      final message = GroupMessage(
        id: 'msg_${Random().nextInt(1000000)}',
        content: text,
        type: MessageType.text,
        senderId: widget.currentDeviceId,
        receiverId: widget.group.id,
        groupId: widget.group.id,
      );
      setState(() {
        _messages.add(message);
      });
      widget.groupManager.sendGroupMessage(message, widget.memberIps);
      _textController.clear();
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            onPressed: () {
              // 显示群成员列表和管理选项
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('群成员'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.group.memberIds.map((memberId) {
                      return ListTile(
                        title: Text(memberId),
                        trailing: widget.group.isCreator(widget.currentDeviceId) && memberId != widget.currentDeviceId
                            ? IconButton(
                                onPressed: () {
                                  widget.groupManager.removeMember(widget.group.id, memberId);
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.remove_circle),
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.group),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isSent = message.senderId == widget.currentDeviceId;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSent ? Colors.blue[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(message.content),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              if (isSent) ...[
                                const SizedBox(width: 4),
                                message.isDelivered
                                    ? const Icon(Icons.done_all, size: 14, color: Colors.blue)
                                    : const Icon(Icons.done, size: 14, color: Colors.grey),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}