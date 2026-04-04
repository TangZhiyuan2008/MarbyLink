import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:marbylink/crypto/encryption.dart';
class QuickShareManager {
  static const int PORT = 8881;
  static const int TEMP_CODE_LENGTH = 4;
  final String _deviceId;
  final Encryption _encryption;
  final Map<String, QuickShareSession> _sessions = {};
  late RawDatagramSocket _socket;
  QuickShareSession? _currentSession;
  QuickShareManager(this._deviceId, this._encryption) {
    _init();
  }
  Future<void> _init() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, PORT, reuseAddress: true, reusePort: true);
      _socket.broadcastEnabled = true;
      _socket.listen(_handleDatagram);
    } catch (e) {
      print('Error initializing quick share manager: $e');
    }
  }
  QuickShareSession createSession(List<String> filePaths) {
    final sessionId = 'session_${Random().nextInt(1000000)}';
    final tempCode = _generateTempCode();
    final session = QuickShareSession(
      id: sessionId,
      tempCode: tempCode,
      filePaths: filePaths,
      createdAt: DateTime.now(),
    );
    _sessions[sessionId] = session;
    _currentSession = session;
    return session;
  }
  Future<QuickShareSession?> findSession(String tempCode) async {
    // 发送广播查找临时码对应的会话
    final message = json.encode({
      'type': 'find_session',
      'tempCode': tempCode,
      'receiverId': _deviceId,
    });
    final data = utf8.encode(message);
    _socket.send(data, InternetAddress('255.255.255.255'), PORT);
    // 等待响应
    final Completer<QuickShareSession?> completer = Completer();
    final timer = Timer(Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
    _socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket.receive();
        if (datagram != null) {
          try {
            final message = utf8.decode(datagram.data);
            final data = json.decode(message);
            if (data['type'] == 'session_found' && data['tempCode'] == tempCode) {
              final session = QuickShareSession(
                id: data['sessionId'],
                tempCode: data['tempCode'],
                filePaths: List<String>.from(data['filePaths']),
                senderId: data['senderId'],
                senderIp: datagram.address.address,
                createdAt: DateTime.parse(data['createdAt']),
              );
              if (!completer.isCompleted) {
                completer.complete(session);
                timer.cancel();
              }
            }
          } catch (e) {
            print('Error handling quick share datagram: $e');
          }
        }
      }
    });
    return completer.future;
  }
  Future<void> sendFiles(QuickShareSession session, String receiverIp) async {
    // 这里使用文件传输管理器的功能
    // 暂时模拟文件发送
    print('Sending files to $receiverIp: ${session.filePaths}');
  }
  void _handleDatagram(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket.receive();
      if (datagram != null) {
        try {
          final message = utf8.decode(datagram.data);
          final data = json.decode(message);
          switch (data['type']) {
            case 'find_session':
              _handleFindSession(data, datagram.address.address);
              break;
          }
        } catch (e) {
          print('Error handling quick share datagram: $e');
        }
      }
    }
  }
  void _handleFindSession(Map<String, dynamic> data, String senderIp) {
    final tempCode = data['tempCode'];
    final session = _sessions.values.firstWhere(
      (s) => s.tempCode == tempCode,
      orElse: () => QuickShareSession.empty(),
    );
    if (session.id.isNotEmpty) {
      final response = json.encode({
        'type': 'session_found',
        'sessionId': session.id,
        'tempCode': session.tempCode,
        'filePaths': session.filePaths,
        'senderId': _deviceId,
        'createdAt': session.createdAt.toIso8601String(),
      });
      final responseData = utf8.encode(response);
      _socket.send(responseData, InternetAddress(senderIp), PORT);
    }
  }
  String _generateTempCode() {
    final random = Random.secure();
    return String.fromCharCodes(
      List.generate(TEMP_CODE_LENGTH, (_) => '0123456789'.codeUnitAt(random.nextInt(10))),
    );
  }
  void dispose() {
    _socket.close();
    _sessions.clear();
  }
}
class QuickShareSession {
  final String id;
  final String tempCode;
  final List<String> filePaths;
  final String senderId;
  final String senderIp;
  final DateTime createdAt;
  QuickShareSession({
    required this.id,
    required this.tempCode,
    required this.filePaths,
    this.senderId = '',
    this.senderIp = '',
    required this.createdAt,
  });
  QuickShareSession.empty()
      : id = '',
        tempCode = '',
        filePaths = [],
        senderId = '',
        senderIp = '',
        createdAt = DateTime.now();
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tempCode': tempCode,
      'filePaths': filePaths,
      'senderId': senderId,
      'senderIp': senderIp,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  factory QuickShareSession.fromMap(Map<String, dynamic> map) {
    return QuickShareSession(
      id: map['id'],
      tempCode: map['tempCode'],
      filePaths: List<String>.from(map['filePaths']),
      senderId: map['senderId'] ?? '',
      senderIp: map['senderIp'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
  String toJson() => json.encode(toMap());
  factory QuickShareSession.fromJson(String source) => QuickShareSession.fromMap(json.decode(source));
}