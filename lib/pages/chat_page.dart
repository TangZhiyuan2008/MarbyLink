import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:marbylink/models/device.dart';
import 'package:marbylink/models/message.dart';
import 'package:marbylink/models/file_transfer.dart';
import 'package:marbylink/network/tcp_client.dart';
import 'package:marbylink/network/file_transfer_manager.dart';
class ChatPage extends StatefulWidget {
  final Device device;
  final TcpClient tcpClient;
  final FileTransferManager fileTransferManager;
  final String currentDeviceId;
  const ChatPage({
    super.key,
    required this.device,
    required this.tcpClient,
    required this.fileTransferManager,
    required this.currentDeviceId,
  });
  @override
  State<ChatPage> createState() => _ChatPageState();
}
class _ChatPageState extends State<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final List<Message> _messages = [];
  final List<FileTransfer> _transfers = [];
  late StreamSubscription<Message> _messageSubscription;
  late StreamSubscription<FileTransfer> _transferSubscription;
  @override
  void initState() {
    super.initState();
    _messageSubscription = widget.tcpClient.onMessage.listen((message) {
      if (message.senderId == widget.device.id || message.receiverId == widget.device.id) {
        setState(() {
          _messages.add(message);
        });
      }
    });
    _transferSubscription = widget.fileTransferManager.onTransferUpdate.listen((transfer) {
      setState(() {
        final existingIndex = _transfers.indexWhere((t) => t.id == transfer.id);
        if (existingIndex >= 0) {
          _transfers[existingIndex] = transfer;
        } else {
          _transfers.add(transfer);
        }
      });
    });
  }
  @override
  void dispose() {
    _messageSubscription.cancel();
    _transferSubscription.cancel();
    _textController.dispose();
    super.dispose();
  }
  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      final message = Message(
        id: 'msg_${Random().nextInt(1000000)}',
        content: text,
        type: MessageType.text,
        senderId: widget.currentDeviceId,
        receiverId: widget.device.id,
      );
      setState(() {
        _messages.add(message);
      });
      widget.tcpClient.sendMessage(message, widget.device.ipAddress);
      _textController.clear();
    }
  }
  Future<void> _sendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null) {
        for (final file in result.files) {
          await widget.fileTransferManager.sendFile(
            file.path!,
            widget.device.id,
            widget.device.ipAddress,
          );
        }
      }
    } catch (e) {
      print('Error picking file: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length + _transfers.length,
              itemBuilder: (context, index) {
                if (index < _messages.length) {
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
                } else {
                  final transfer = _transfers[index - _messages.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(transfer.fileName),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: transfer.progress,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${(transfer.progress * 100).toStringAsFixed(1)}%'),
                              Text('${transfer.speed.toStringAsFixed(2)} MB/s'),
                              Text(transfer.status.toString().split('.').last),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  onPressed: _sendFile,
                  icon: const Icon(Icons.attach_file),
                ),
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