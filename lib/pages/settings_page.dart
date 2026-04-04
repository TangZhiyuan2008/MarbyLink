import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _deviceNameController;
  bool _autoStart = false;
  bool _autoDiscover = true;
  bool _enableEncryption = true;
  @override
  void initState() {
    super.initState();
    _loadSettings();
    _deviceNameController = TextEditingController();
  }
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceNameController.text = prefs.getString('deviceName') ?? 'My Device';
      _autoStart = prefs.getBool('autoStart') ?? false;
      _autoDiscover = prefs.getBool('autoDiscover') ?? true;
      _enableEncryption = prefs.getBool('enableEncryption') ?? true;
    });
  }
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deviceName', _deviceNameController.text);
    await prefs.setBool('autoStart', _autoStart);
    await prefs.setBool('autoDiscover', _autoDiscover);
    await prefs.setBool('enableEncryption', _enableEncryption);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存')),
    );
  }
  @override
  void dispose() {
    _deviceNameController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('设备名称'),
            subtitle: TextField(
              controller: _deviceNameController,
              decoration: const InputDecoration(
                hintText: '输入设备名称',
              ),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('网络设置'),
            subtitle: Column(
              children: [
                SwitchListTile(
                  title: const Text('自动启动'),
                  value: _autoStart,
                  onChanged: (value) => setState(() => _autoStart = value),
                ),
                SwitchListTile(
                  title: const Text('自动发现设备'),
                  value: _autoDiscover,
                  onChanged: (value) => setState(() => _autoDiscover = value),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('安全设置'),
            subtitle: SwitchListTile(
              title: const Text('启用端到端加密'),
              value: _enableEncryption,
              onChanged: (value) => setState(() => _enableEncryption = value),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('关于'),
            subtitle: const Text('MarbyLink v1.0.0\n纯P2P局域网通信工具'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'MarbyLink',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 MarbyLink',
                children: [
                  const Text('纯P2P局域网通信工具，无需服务器，安全可靠。'),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('保存设置'),
            ),
          ),
        ],
      ),
    );
  }
}