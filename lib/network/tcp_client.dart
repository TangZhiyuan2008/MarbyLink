import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:marbylink/crypto/encryption.dart';
import 'package:marbylink/models/message.dart';
import 'package:marbylink/models/group_message.dart';
class TcpClient {
  static const int PORT = 8878;
  final String _deviceId;
  final Encryption _encryption;
  final Map<String, Socket> _connections = {};
  final StreamController<Message> _messageController = StreamController<Message>.broadcast();
  Stream<Message> get onMessage => _messageController.stream;
  TcpClient(this._deviceId, this._encryption);
  Future<void> startServer() async {
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, PORT);
      server.listen((socket) {
        _handleIncomingConnection(socket);
      });
    } catch (e) {
      print('Error starting TCP server: $e');
    }
  }
  Future<Socket> connect(String ipAddress) async {
    try {
      // 使用安全的 TLS 连接
      final secureSocket = await SecureSocket.connect(
        ipAddress, 
        PORT,
        onBadCertificate: (cert) {
          // 在局域网环境下，我们可以接受自签名证书
          // 实际生产环境中应该验证证书指纹
          print('Accepting self-signed certificate from $ipAddress');
          return true;
        },
      );
      _connections[ipAddress] = secureSocket;
      _setupSocketListeners(secureSocket);
      return secureSocket;
    } catch (e) {
      print('Error connecting to $ipAddress: $e');
      // 回退到普通 Socket 连接
      try {
        final socket = await Socket.connect(ipAddress, PORT);
        _connections[ipAddress] = socket;
        _setupSocketListeners(socket);
        return socket;
      } catch (fallbackError) {
        print('Fallback connection failed: $fallbackError');
        throw fallbackError;
      }
    }
  }
  void sendMessage(Message message, String ipAddress) async {
    try {
      Socket? socket = _connections[ipAddress];
      if (socket == null) {
        socket = await connect(ipAddress);
      }
      final messageJson = message.toJson();
      final encryptedMessage = await _encryption.encrypt(messageJson, message.receiverId);
      final data = json.encode({
        'type': 'message',
        'content': base64.encode(encryptedMessage),
        'senderId': _deviceId,
      });
      final length = data.length;
      final lengthBytes = length.toRadixString(16).padLeft(8, '0');
      socket.write('$lengthBytes$data');
      message.isSent = true;
    } catch (e) {
      print('Error sending message: $e');
    }
  }
  Future<String?> sendRequest(String request, String ipAddress) async {
    try {
      Socket? socket = _connections[ipAddress];
      if (socket == null) {
        socket = await connect(ipAddress);
      }
      final requestData = json.encode({
        'type': 'request',
        'content': request,
        'senderId': _deviceId,
      });
      final length = requestData.length;
      final lengthBytes = length.toRadixString(16).padLeft(8, '0');
      socket.write('$lengthBytes$requestData');
      // 等待响应
      final Completer<String> completer = Completer();
      final subscription = socket.listen((data) {
        final response = utf8.decode(data);
        completer.complete(response);
      });
      final response = await completer.future.timeout(Duration(seconds: 10));
      subscription.cancel();
      return response;
    } catch (e) {
      print('Error sending request: $e');
      return null;
    }
  }
  void _handleIncomingConnection(Socket socket) {
    _setupSocketListeners(socket);
  }
  void _setupSocketListeners(Socket socket) {
    final buffer = StringBuffer();
    socket.listen(
      (data) {
        buffer.write(utf8.decode(data));
        _processBuffer(buffer, socket);
      },
      onError: (error) {
        print('Socket error: $error');
        _cleanupSocket(socket);
      },
      onDone: () {
        _cleanupSocket(socket);
      },
    );
  }
  void _processBuffer(StringBuffer buffer, Socket socket) {
    while (buffer.length >= 8) {
      final bufferString = buffer.toString();
      final lengthHex = bufferString.substring(0, 8);
      final length = int.parse(lengthHex, radix: 16);
      if (buffer.length >= 8 + length) {
        final data = bufferString.substring(8, 8 + length);
        final remaining = buffer.length > 8 + length ? bufferString.substring(8 + length) : '';
        buffer.clear();
        buffer.write(remaining);
        _handleIncomingMessage(data, socket);
      } else {
        break;
      }
    }
  }
  Future<void> _handleIncomingMessage(String data, Socket socket) async {
    try {
      final messageData = json.decode(data);
      if (messageData['type'] == 'message') {
        final encryptedContent = base64.decode(messageData['content']);
        final senderId = messageData['senderId'];
        final decryptedJson = await _encryption.decrypt(encryptedContent, senderId);
        final message = Message.fromJson(decryptedJson);
        message.isDelivered = true;
        _messageController.add(message);
        _sendDeliveryAck(socket, message.id);
      } else if (messageData['type'] == 'group_message') {
        final encryptedContent = base64.decode(messageData['content']);
        final senderId = messageData['senderId'];
        final decryptedJson = await _encryption.decrypt(encryptedContent, senderId);
        final message = GroupMessage.fromJson(decryptedJson);
        message.isDelivered = true;
        _messageController.add(message);
        _sendDeliveryAck(socket, message.id);
      } else if (messageData['type'] == 'delivery_ack') {
        // Handle delivery acknowledgment
      } else if (messageData['type'] == 'request') {
        final requestContent = messageData['content'];
        final requestData = json.decode(requestContent);
        if (requestData['type'] == 'join_group') {
          await _handleJoinGroupRequest(requestData, socket);
        }
      }
    } catch (e) {
      print('Error handling incoming message: $e');
    }
  }
  Future<void> _handleJoinGroupRequest(Map<String, dynamic> requestData, Socket socket) async {
    try {
      final groupId = requestData['groupId'];
      final password = requestData['password'];
      final requesterId = requestData['requesterId'];
      // 这里需要从 GroupManager 获取群组信息并验证密码
      // 暂时模拟验证成功，实际应该使用密码哈希进行验证
      final response = json.encode({
        'success': true,
        'groupName': 'Test Group',
        'creatorId': _deviceId,
        'memberIds': [_deviceId, requesterId],
        'groupKey': 'test_group_key_123',
        'createdAt': DateTime.now().toIso8601String(),
      });
      final responseData = json.encode({
        'type': 'response',
        'content': response,
        'senderId': _deviceId,
      });
      final length = responseData.length;
      final lengthBytes = length.toRadixString(16).padLeft(8, '0');
      socket.write('$lengthBytes$responseData');
    } catch (e) {
      print('Error handling join group request: $e');
      final errorResponse = json.encode({
        'success': false,
        'error': 'Failed to process join request',
      });
      final responseData = json.encode({
        'type': 'response',
        'content': errorResponse,
        'senderId': _deviceId,
      });
      final length = responseData.length;
      final lengthBytes = length.toRadixString(16).padLeft(8, '0');
      socket.write('$lengthBytes$responseData');
    }
  }
  void _sendDeliveryAck(Socket socket, String messageId) {
    final data = json.encode({
      'type': 'delivery_ack',
      'messageId': messageId,
    });
    final length = data.length;
    final lengthBytes = length.toRadixString(16).padLeft(8, '0');
    socket.write('$lengthBytes$data');
  }
  void _cleanupSocket(Socket socket) {
    final ipAddress = socket.remoteAddress.address;
    _connections.remove(ipAddress);
    socket.close();
  }
  void disconnect(String ipAddress) {
    final socket = _connections[ipAddress];
    if (socket != null) {
      _cleanupSocket(socket);
    }
  }
  void dispose() {
    for (final socket in _connections.values) {
      socket.close();
    }
    _connections.clear();
    _messageController.close();
  }
}