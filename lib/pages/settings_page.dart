import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import '../theme/app_theme.dart';

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('设置'),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                  children: [
                    _SettingsCard(
                      title: '后端连接',
                      children: [
                        const Text(
                          '仅连接你信任的企业服务地址。远程服务建议使用 HTTPS，保存前先测试连接。',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _backendController,
                          keyboardType: TextInputType.url,
                          style: const TextStyle(fontSize: 15),
                          decoration: _inputDecoration(
                            label: '后端地址',
                            hint: ApiService.defaultBackendUrl,
                            icon: Icons.dns_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _isSaving ? null : _saveBackendUrl,
                              icon: _isSaving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.network_check_outlined),
                              label: const Text('测试连接'),
                            ),
                          ],
                        ),
                        if (_healthStatus != null) ...[
                          const SizedBox(height: 12),
                          _StatusBox(
                            status: _healthStatus!,
                            color: _statusColor(),
                            icon: _statusIcon(),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SettingsCard(
                      title: '账号',
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.text,
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('退出登录'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Color _statusColor() {
    return switch (_healthStatus) {
      'ok' => AppColors.success,
      'degraded' => AppColors.textMuted,
      _ => AppColors.error,
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppColors.border),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({
    required this.status,
    required this.color,
    required this.icon,
  });

  final String status;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Text(
            '连接状态：$status',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
