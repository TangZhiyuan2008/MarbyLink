import 'dart:io';
enum FileTransferStatus {
  pending,
  in_progress,
  completed,
  failed,
  paused,
}
class FileTransfer {
  final String id;
  final String fileName;
  final String filePath;
  final String receiverId;
  final String senderId;
  final int fileSize;
  int transferredSize;
  FileTransferStatus status;
  double progress;
  double speed; // MB/s
  DateTime? startTime;
  DateTime? endTime;
  FileTransfer({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.receiverId,
    required this.senderId,
    required this.fileSize,
    this.transferredSize = 0,
    this.status = FileTransferStatus.pending,
    this.progress = 0.0,
    this.speed = 0.0,
  });
  void updateProgress(int bytesTransferred) {
    transferredSize += bytesTransferred;
    progress = fileSize > 0 ? transferredSize / fileSize : 0.0;
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime!).inSeconds;
      if (duration > 0) {
        speed = (transferredSize / (1024 * 1024)) / duration;
      }
    }
  }
  void start() {
    status = FileTransferStatus.in_progress;
    startTime = DateTime.now();
  }
  void complete() {
    status = FileTransferStatus.completed;
    endTime = DateTime.now();
    progress = 1.0;
  }
  void fail() {
    status = FileTransferStatus.failed;
  }
  void pause() {
    status = FileTransferStatus.paused;
  }
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'receiverId': receiverId,
      'senderId': senderId,
      'fileSize': fileSize,
      'transferredSize': transferredSize,
      'status': status.toString().split('.').last,
      'progress': progress,
      'speed': speed,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }
  factory FileTransfer.fromMap(Map<String, dynamic> map) {
    return FileTransfer(
      id: map['id'],
      fileName: map['fileName'],
      filePath: map['filePath'],
      receiverId: map['receiverId'],
      senderId: map['senderId'] ?? '',
      fileSize: map['fileSize'],
      transferredSize: map['transferredSize'] ?? 0,
      status: FileTransferStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => FileTransferStatus.pending,
      ),
      progress: map['progress'] ?? 0.0,
      speed: map['speed'] ?? 0.0,
    )..startTime = map['startTime'] != null ? DateTime.parse(map['startTime']) : null
     ..endTime = map['endTime'] != null ? DateTime.parse(map['endTime']) : null;
  }
}