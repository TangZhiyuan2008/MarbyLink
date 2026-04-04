import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:marbylink/crypto/encryption.dart';
import 'package:marbylink/models/file_transfer.dart';
class FileTransferManager {
  static const int PORT = 8879;
  static const int CHUNK_SIZE = 1024 * 1024; // 1MB
  final String _deviceId;
  final Encryption _encryption;
  final Map<String, FileTransfer> _transfers = {};
  final StreamController<FileTransfer> _transferUpdateController = StreamController<FileTransfer>.broadcast();
  final Map<String, Socket> _connections = {};
  Stream<FileTransfer> get onTransferUpdate => _transferUpdateController.stream;
  FileTransferManager(this._deviceId, this._encryption);
  Future<void> startServer() async {
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, PORT);
      server.listen((socket) {
        _handleIncomingConnection(socket);
      });
    } catch (e) {
      print('Error starting file transfer server: $e');
    }
  }
  Future<void> sendFile(String filePath, String receiverId, String ipAddress) async {
    final file = File(filePath);
    if (file.existsSync()) {
      // 发送单个文件
      await _sendSingleFile(file, receiverId, ipAddress);
    } else {
      final directory = Directory(filePath);
      if (directory.existsSync()) {
        // 发送整个文件夹
        await _sendDirectory(directory, receiverId, ipAddress);
      } else {
        throw Exception('File or directory not found: $filePath');
      }
    }
  }
  Future<void> _sendSingleFile(File file, String receiverId, String ipAddress) async {
    final fileSize = file.lengthSync();
    final transfer = FileTransfer(
      id: 'transfer_${Random().nextInt(1000000)}',
      fileName: file.path.split(Platform.pathSeparator).last,
      filePath: file.path,
      receiverId: receiverId,
      senderId: _deviceId,
      fileSize: fileSize,
    );
    _transfers[transfer.id] = transfer;
    _transferUpdateController.add(transfer);
    try {
      final socket = await connect(ipAddress);
      transfer.start();
      _transferUpdateController.add(transfer);
      await _sendFileMetadata(socket, transfer);
      await _sendFileChunks(socket, file, transfer);
      transfer.complete();
      _transferUpdateController.add(transfer);
    } catch (e) {
      transfer.fail();
      _transferUpdateController.add(transfer);
      print('Error sending file: $e');
    }
  }
  Future<void> _sendDirectory(Directory directory, String receiverId, String ipAddress) async {
    final directoryName = directory.path.split(Platform.pathSeparator).last;
    // 递归获取所有文件
    final files = _getAllFiles(directory);
    for (final file in files) {
      // 计算相对路径，保持目录结构
      final relativePath = file.path.substring(directory.parent.path.length + 1);
      final transfer = FileTransfer(
        id: 'transfer_${Random().nextInt(1000000)}',
        fileName: relativePath,
        filePath: file.path,
        receiverId: receiverId,
        senderId: _deviceId,
        fileSize: file.lengthSync(),
      );
      _transfers[transfer.id] = transfer;
      _transferUpdateController.add(transfer);
      try {
        final socket = await connect(ipAddress);
        transfer.start();
        _transferUpdateController.add(transfer);
        await _sendFileMetadata(socket, transfer);
        await _sendFileChunks(socket, file, transfer);
        transfer.complete();
        _transferUpdateController.add(transfer);
      } catch (e) {
        transfer.fail();
        _transferUpdateController.add(transfer);
        print('Error sending file: $e');
      }
    }
  }
  List<File> _getAllFiles(Directory directory) {
    final files = <File>[];
    final entries = directory.listSync(recursive: true);
    for (final entry in entries) {
      if (entry is File) {
        files.add(entry);
      }
    }
    return files;
  }
  Future<Socket> connect(String ipAddress) async {
    try {
      Socket? socket = _connections[ipAddress];
      if (socket == null) {
        socket = await Socket.connect(ipAddress, PORT);
        _connections[ipAddress] = socket;
        _setupSocketListeners(socket);
      }
      return socket;
    } catch (e) {
      print('Error connecting to $ipAddress: $e');
      throw e;
    }
  }
  Future<void> _sendFileMetadata(Socket socket, FileTransfer transfer) async {
    final metadata = json.encode({
      'type': 'file_metadata',
      'transferId': transfer.id,
      'fileName': transfer.fileName,
      'fileSize': transfer.fileSize,
      'senderId': _deviceId,
    });
    final length = metadata.length;
    final lengthBytes = length.toRadixString(16).padLeft(8, '0');
    socket.write('$lengthBytes$metadata');
  }
  Future<void> _sendFileChunks(Socket socket, File file, FileTransfer transfer) async {
    // 从已传输的位置开始读取文件
    final startOffset = transfer.transferredSize;
    final fileStream = file.openRead(startOffset);
    int bytesSent = startOffset;
    await for (final chunk in fileStream) {
      final chunkData = json.encode({
        'type': 'file_chunk',
        'transferId': transfer.id,
        'offset': bytesSent,
        'data': base64.encode(chunk),
      });
      // 加密文件块数据
      final encryptedData = await _encryption.encrypt(chunkData, transfer.receiverId);
      final encryptedChunkData = json.encode({
        'type': 'file_chunk',
        'transferId': transfer.id,
        'content': base64.encode(encryptedData),
      });
      final length = encryptedChunkData.length;
      final lengthBytes = length.toRadixString(16).padLeft(8, '0');
      socket.write('$lengthBytes$encryptedChunkData');
      bytesSent += chunk.length;
      transfer.updateProgress(chunk.length);
      _transferUpdateController.add(transfer);
    }
    // 发送完成信号
    final finishData = json.encode({
      'type': 'file_finish',
      'transferId': transfer.id,
    });
    final encryptedFinishData = await _encryption.encrypt(finishData, transfer.receiverId);
    final encryptedFinishChunkData = json.encode({
      'type': 'file_finish',
      'transferId': transfer.id,
      'content': base64.encode(encryptedFinishData),
    });
    final length = encryptedFinishChunkData.length;
    final lengthBytes = length.toRadixString(16).padLeft(8, '0');
    socket.write('$lengthBytes$encryptedFinishChunkData');
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
  void _handleIncomingMessage(String data, Socket socket) {
    try {
      final messageData = json.decode(data);
      switch (messageData['type']) {
        case 'file_metadata':
          _handleFileMetadata(messageData, socket);
          break;
        case 'file_chunk':
          _handleFileChunk(messageData, socket);
          break;
        case 'file_finish':
          _handleFileFinish(messageData, socket);
          break;
      }
    } catch (e) {
      print('Error handling incoming file message: $e');
    }
  }
  void _handleFileMetadata(Map<String, dynamic> data, Socket socket) {
    final transferId = data['transferId'];
    final fileName = data['fileName'];
    final fileSize = data['fileSize'];
    final senderId = data['senderId'];
    // 处理相对路径，确保目录结构存在
    final savePath = '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName';
    final saveDir = Directory(savePath).parent;
    if (!saveDir.existsSync()) {
      saveDir.createSync(recursive: true);
    }
    final transfer = FileTransfer(
      id: transferId,
      fileName: fileName,
      filePath: savePath,
      receiverId: _deviceId,
      senderId: senderId,
      fileSize: fileSize,
      status: FileTransferStatus.in_progress,
    );
    transfer.startTime = DateTime.now();
    _transfers[transferId] = transfer;
    _transferUpdateController.add(transfer);
  }
  void _handleFileChunk(Map<String, dynamic> data, Socket socket) {
    final transferId = data['transferId'];
    final content = data['content'];
    final transfer = _transfers[transferId];
    if (transfer != null) {
      try {
        // 解密文件块数据
        final encryptedData = base64.decode(content);
        final decryptedData = _encryption.decrypt(encryptedData, transfer.senderId ?? '').toString();
        final chunkData = json.decode(decryptedData);
        final offset = chunkData['offset'];
        final fileData = base64.decode(chunkData['data']);
        final file = File(transfer.filePath);
        // 确保文件存在
        if (!file.existsSync()) {
          file.createSync(recursive: true);
        }
        // 使用随机访问模式，从指定偏移量写入
        final raf = file.openSync(mode: FileMode.writeOnlyAppend);
        raf.setPositionSync(offset);
        raf.writeFromSync(fileData);
        raf.closeSync();
        transfer.updateProgress(fileData.length);
        _transferUpdateController.add(transfer);
      } catch (e) {
        print('Error handling file chunk: $e');
        transfer.fail();
        _transferUpdateController.add(transfer);
      }
    }
  }
  void _handleFileFinish(Map<String, dynamic> data, Socket socket) {
    final transferId = data['transferId'];
    final transfer = _transfers[transferId];
    if (transfer != null) {
      transfer.complete();
      _transferUpdateController.add(transfer);
    }
  }
  void _cleanupSocket(Socket socket) {
    final ipAddress = socket.remoteAddress.address;
    _connections.remove(ipAddress);
    socket.close();
  }
  void pauseTransfer(String transferId) {
    final transfer = _transfers[transferId];
    if (transfer != null) {
      transfer.pause();
      _transferUpdateController.add(transfer);
    }
  }
  void resumeTransfer(String transferId, String ipAddress) {
    final transfer = _transfers[transferId];
    if (transfer != null) {
      sendFile(transfer.filePath, transfer.receiverId, ipAddress);
    }
  }
  void cancelTransfer(String transferId) {
    _transfers.remove(transferId);
  }
  void dispose() {
    for (final socket in _connections.values) {
      socket.close();
    }
    _connections.clear();
    _transfers.clear();
    _transferUpdateController.close();
  }
}