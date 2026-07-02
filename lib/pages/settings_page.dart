import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../services/api_service.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _backendController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _healthStatus;

  @override
  void initState() {
    super.initState();
    _loadBackendUrl();
  }

  @override
  void dispose() {
    _backendController.dispose();
    super.dispose();
  }

  Future<void> _loadBackendUrl() async {
    final backendUrl = await _apiService.getBackendUrl();
    if (!mounted) return;
    setState(() {
      _backendController.text = backendUrl;
      _isLoading = false;
    });
  }

  Future<void> _saveBackendUrl() async {
    final backendUrl = _backendController.text.trim();
    if (backendUrl.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);
    await _apiService.saveBackendUrl(backendUrl);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('后端地址已保存')));
  }

  Future<void> _testConnection() async {
    if (_isTesting) return;
    setState(() {
      _isTesting = true;
      _healthStatus = null;
    });
    await _apiService.saveBackendUrl(_backendController.text.trim());
    final status = await _apiService.checkHealth();
    if (!mounted) return;
    setState(() {
      _healthStatus = status;
      _isTesting = false;
    });
  }

  Future<void> _logout() async {
    await _apiService.logout();
    if (!mounted) return;
    context.read<ChatProvider>().newChat();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('后端连接', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _backendController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: '后端地址',
                    hintText: ApiService.defaultBackendUrl,
                    prefixIcon: Icon(Icons.dns_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveBackendUrl,
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('保存'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check_outlined),
                      label: const Text('测试连接'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_healthStatus != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _statusColor(colors).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _statusColor(colors)),
                    ),
                    child: Row(
                      children: [
                        Icon(_statusIcon(), color: _statusColor(colors)),
                        const SizedBox(width: 10),
                        Text(
                          '连接状态：$_healthStatus',
                          style: TextStyle(
                            color: _statusColor(colors),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 28),
                Text('账号', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('退出登录'),
                ),
              ],
            ),
    );
  }

  Color _statusColor(ColorScheme colors) {
    return switch (_healthStatus) {
      'ok' => colors.primary,
      'degraded' => colors.tertiary,
      _ => colors.error,
    };
  }

  IconData _statusIcon() {
    return switch (_healthStatus) {
      'ok' => Icons.check_circle_outline,
      'degraded' => Icons.warning_amber_outlined,
      _ => Icons.error_outline,
    };
  }
}
