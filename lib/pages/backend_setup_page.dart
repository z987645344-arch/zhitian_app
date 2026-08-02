import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_shell.dart';

/// 首次启动服务地址引导。
///
/// 地址保存到SharedPreferences；完成后后续启动直接进入登录或工作台。
/// 远程服务只接受HTTPS，本机联调可使用localhost/127.0.0.1的HTTP地址。
class BackendSetupPage extends StatefulWidget {
  const BackendSetupPage({super.key, required this.nextPage, this.apiService});

  final Widget nextPage;
  final ApiService? apiService;

  @override
  State<BackendSetupPage> createState() => _BackendSetupPageState();
}

class _BackendSetupPageState extends State<BackendSetupPage> {
  late final ApiService _apiService = widget.apiService ?? ApiService();
  final TextEditingController _controller = TextEditingController();

  bool _isSaving = false;
  bool _isTesting = false;
  String? _errorText;
  BackendConnectionResult? _connectionResult;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await _apiService.saveBackendUrl(_controller.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => widget.nextPage),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _errorText = ApiService.userMessageFor(error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testConnection() async {
    if (_isTesting) return;
    setState(() {
      _isTesting = true;
      _errorText = null;
      _connectionResult = null;
    });
    final result = await _apiService.checkBackendUrl(_controller.text);
    if (!mounted) return;
    setState(() {
      _connectionResult = result;
      _isTesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: '连接企业服务',
      subtitle: '首次使用需要设置后端地址，保存后可随时在“设置”中修改。',
      footer: const Text(
        '远程服务必须使用 HTTPS；本机联调可使用 localhost 或 127.0.0.1。',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
      ),
      children: [
        const Text(
          '服务地址',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          key: const Key('backend_setup_url'),
          controller: _controller,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'https://api.example.com',
            prefixIcon: const Icon(Icons.dns_outlined),
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
          ),
          onSubmitted: (_) => _saveAndContinue(),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          _InlineMessage(
            icon: Icons.error_outline,
            color: AppColors.error,
            message: _errorText!,
          ),
        ],
        if (_connectionResult != null) ...[
          const SizedBox(height: 12),
          _InlineMessage(
            icon: _connectionResult!.status == 'ok'
                ? Icons.check_circle_outline
                : _connectionResult!.status == 'certificate_error'
                ? Icons.gpp_bad_outlined
                : Icons.warning_amber_outlined,
            color: _connectionResult!.status == 'ok'
                ? AppColors.success
                : _connectionResult!.status == 'degraded'
                ? AppColors.textMuted
                : AppColors.error,
            message: _connectionResult!.message,
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 44,
          child: FilledButton(
            key: const Key('backend_setup_continue'),
            onPressed: _isSaving ? null : _saveAndContinue,
            child: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('保存并继续'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            key: const Key('backend_setup_test'),
            onPressed: _isTesting ? null : _testConnection,
            icon: _isTesting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check_outlined, size: 18),
            label: const Text('测试连接'),
          ),
        ),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
