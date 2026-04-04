import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:marbylink/network/quick_share_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
class QuickSharePage extends StatefulWidget {
  final QuickShareManager quickShareManager;
  const QuickSharePage({super.key, required this.quickShareManager});
  @override
  State<QuickSharePage> createState() => _QuickSharePageState();
}
class _QuickSharePageState extends State<QuickSharePage> {
  bool _isSender = true;
  List<String> _selectedFiles = [];
  String _tempCode = '';
  QuickShareSession? _session;
  @override
  void initState() {
    super.initState();
  }
  Future<void> _selectFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null) {
        setState(() {
          _selectedFiles = result.files.map((file) => file.path!).toList();
        });
      }
    } catch (e) {
      print('Error picking files: $e');
    }
  }
  void _generateSession() {
    if (_selectedFiles.isNotEmpty) {
      final session = widget.quickShareManager.createSession(_selectedFiles);
      setState(() {
        _session = session;
        _tempCode = session.tempCode;
      });
    }
  }
  Future<void> _joinSession(String tempCode) async {
    final session = await widget.quickShareManager.findSession(tempCode);
    if (session != null) {
      await widget.quickShareManager.sendFiles(session, session.senderIp);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件传输开始')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到临时码对应的会话')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('面对面快传'),
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isSender = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _isSender ? Colors.blue[100] : Colors.grey[100],
                    ),
                    child: const Center(child: Text('发送文件')),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isSender = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: !_isSender ? Colors.blue[100] : Colors.grey[100],
                    ),
                    child: const Center(child: Text('接收文件')),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: _isSender ? _buildSenderUI() : _buildReceiverUI(),
          ),
        ],
      ),
    );
  }
  Widget _buildSenderUI() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_session == null) ...[
            ElevatedButton(
              onPressed: _selectFiles,
              child: const Text('选择文件'),
            ),
            const SizedBox(height: 16),
            Text('已选择 ${_selectedFiles.length} 个文件'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _selectedFiles.isNotEmpty ? _generateSession : null,
              child: const Text('生成临时码'),
            ),
          ] else ...[
            const Text('临时码:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Text(_tempCode, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            QrImageView(
              data: _session!.toJson(),
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 32),
            const Text('请对方扫描二维码或输入临时码'),
          ],
        ],
      ),
    );
  }
  Widget _buildReceiverUI() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('选择接收方式:', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QRScannerPage(),
                ),
              );
              if (result is QuickShareSession) {
                // 处理扫描结果，开始文件传输
                await widget.quickShareManager.sendFiles(result, result.senderIp);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('文件传输开始')),
                );
              }
            },
            child: const Text('扫描二维码'),
          ),
          const SizedBox(height: 16),
          TextField(
            onSubmitted: _joinSession,
            decoration: InputDecoration(
              labelText: '输入4位临时码',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => _joinSession(_tempCode),
                icon: const Icon(Icons.send),
              ),
            ),
            onChanged: (value) => setState(() => _tempCode = value),
            maxLength: 4,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}
class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});
  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}
class _QRScannerPageState extends State<QRScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  Future<void> _handleScanResult(String code) async {
    try {
      // 解析二维码中的会话信息
      final session = QuickShareSession.fromJson(code);
      // 加入会话并开始传输
      // 这里需要获取 QuickShareManager 实例
      // 暂时先返回，后续需要通过构造函数传入
      Navigator.pop(context, session);
    } catch (e) {
      print('Error parsing QR code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('二维码格式错误')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          final String? code = capture.barcodes.first.rawValue;
          if (code != null) {
            _handleScanResult(code);
          }
        },
      ),
    );
  }
}