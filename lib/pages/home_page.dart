import 'package:flutter/material.dart';
import 'package:marbylink/network/discovery.dart';
import 'package:marbylink/network/tcp_client.dart';
import 'package:marbylink/network/file_transfer_manager.dart';
import 'package:marbylink/network/group_manager.dart';
import 'package:marbylink/network/call_manager.dart';
import 'package:marbylink/network/quick_share_manager.dart';
import 'package:marbylink/crypto/encryption.dart';
import 'package:marbylink/models/device.dart';
import 'package:marbylink/models/group.dart';
import 'package:marbylink/models/call.dart';
import 'package:marbylink/pages/chat_page.dart';
import 'package:marbylink/pages/group_chat_page.dart';
import 'package:marbylink/pages/call_page.dart';
import 'package:marbylink/pages/quick_share_page.dart';
import 'package:marbylink/pages/settings_page.dart';
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  late DeviceDiscovery _discovery;
  late Encryption _encryption;
  late TcpClient _tcpClient;
  late FileTransferManager _fileTransferManager;
  late GroupManager _groupManager;
  late CallManager _callManager;
  late QuickShareManager _quickShareManager;
  List<Device> _devices = [];
  List<Group> _groups = [];
  String _currentDeviceId = '';
  final Map<String, String> _memberIps = {};
  @override
  void initState() {
    super.initState();
    _init();
  }
  Future<void> _init() async {
    _discovery = DeviceDiscovery();
    _currentDeviceId = _discovery.deviceId;
    _encryption = Encryption();
    await _encryption.initialize(_currentDeviceId);
    _tcpClient = TcpClient(_currentDeviceId, _encryption);
    await _tcpClient.startServer();
    _fileTransferManager = FileTransferManager(_currentDeviceId, _encryption);
    await _fileTransferManager.startServer();
    _groupManager = GroupManager(_currentDeviceId, _encryption, _tcpClient);
    _callManager = CallManager(_currentDeviceId);
    _quickShareManager = QuickShareManager(_currentDeviceId, _encryption);
    _groupManager.onGroupUpdate.listen((group) {
      setState(() {
        final existingIndex = _groups.indexWhere((g) => g.id == group.id);
        if (existingIndex >= 0) {
          _groups[existingIndex] = group;
        } else {
          _groups.add(group);
        }
      });
    });
    _callManager.onCallUpdate.listen((call) {
      if (call.status == CallStatus.ringing) {
        // 显示来电界面
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallPage(
              call: call,
              callManager: _callManager,
              isIncoming: true,
            ),
          ),
        );
      }
    });
    _discovery.start();
    _discovery.onDeviceFound.listen((device) {
      setState(() {
        if (!_devices.any((d) => d.id == device.id)) {
          // 这里需要从设备信息中获取公钥和签名公钥
          // 由于当前 Device 模型还没有这些字段，暂时使用空字符串
          // 实际实现时需要在 Device 模型中添加这些字段
          _encryption.addDevicePublicKey(device.id, '', '');
          _memberIps[device.id] = device.ipAddress;
          _devices.add(device);
        }
      });
    });
    _discovery.onDeviceLost.listen((deviceId) {
      setState(() {
        _devices.removeWhere((d) => d.id == deviceId);
        _memberIps.remove(deviceId);
      });
    });
  }
  @override
  void dispose() {
    _discovery.stop();
    _tcpClient.dispose();
    _fileTransferManager.dispose();
    _groupManager.dispose();
    _callManager.dispose();
    _quickShareManager.dispose();
    super.dispose();
  }
  void _openQuickShare() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuickSharePage(
          quickShareManager: _quickShareManager,
        ),
      ),
    );
  }
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
  }
  void _makeCall(Device device, CallType type) async {
    final call = await _callManager.makeCall(device.id, device.ipAddress, type);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallPage(
          call: call,
          callManager: _callManager,
          isIncoming: false,
        ),
      ),
    );
  }
  void _createGroup() {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建群组'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '群组名称'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: '加入密码'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final group = await _groupManager.createGroup(
                nameController.text,
                passwordController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
  void _joinGroup() {
    final groupIdController = TextEditingController();
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加入群组'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: groupIdController,
              decoration: const InputDecoration(labelText: '群组ID'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: '加入密码'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final group = await _groupManager.joinGroup(
                groupIdController.text,
                passwordController.text,
                _memberIps,
              );
              Navigator.pop(context);
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MarbyLink'),
        actions: [
          IconButton(
            onPressed: _openQuickShare,
            icon: const Icon(Icons.near_me),
            tooltip: '面对面快传',
          ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            tooltip: '设置',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'create', child: Text('创建群组')),
              const PopupMenuItem(value: 'join', child: Text('加入群组')),
            ],
            onSelected: (value) {
              if (value == 'create') {
                _createGroup();
              } else if (value == 'join') {
                _joinGroup();
              }
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: '设备'),
                Tab(text: '群组'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return ListTile(
                        leading: Icon(
                          device.type == DeviceType.mobile ? Icons.phone_android : Icons.computer,
                          color: device.isOnline ? Colors.green : Colors.grey,
                        ),
                        title: Text(device.name),
                        subtitle: Text('${device.ipAddress}:${device.port}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (device.isOnline) ...[
                              IconButton(
                                onPressed: () => _makeCall(device, CallType.voice),
                                icon: const Icon(Icons.phone),
                              ),
                              IconButton(
                                onPressed: () => _makeCall(device, CallType.video),
                                icon: const Icon(Icons.video_call),
                              ),
                            ],
                            Text(device.isOnline ? '在线' : '离线'),
                          ],
                        ),
                        onTap: device.isOnline
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatPage(
                                      device: device,
                                      tcpClient: _tcpClient,
                                      fileTransferManager: _fileTransferManager,
                                      currentDeviceId: _currentDeviceId,
                                    ),
                                  ),
                                )
                            : null,
                      );
                    },
                  ),
                  ListView.builder(
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      return ListTile(
                        leading: const Icon(Icons.group),
                        title: Text(group.name),
                        subtitle: Text('成员: ${group.memberIds.length}'),
                        trailing: group.isCreator(_currentDeviceId) ? const Text('创建者') : null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupChatPage(
                              group: group,
                              groupManager: _groupManager,
                              currentDeviceId: _currentDeviceId,
                              memberIps: _memberIps,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}