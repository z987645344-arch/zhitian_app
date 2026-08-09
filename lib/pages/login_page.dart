import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_shell.dart';
import 'backend_setup_page.dart';
import 'chat_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.apiService});

  final ApiService? apiService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final ApiService _apiService = widget.apiService ?? ApiService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText;
  String? _backendUrl;

  @override
  void initState() {
    super.initState();
    _loadBackendUrl();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (_isLoading || username.isEmpty || password.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await _apiService.login(username: username, password: password);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ChatPage()),
      );
    } on SocketException {
      _showError(ApiService.connectionErrorMessage);
    } on TimeoutException {
      _showError(ApiService.timeoutErrorMessage);
    } catch (e) {
      _showError(ApiService.userMessageFor(e));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorText = message;
    });
  }

  Future<void> _openRegister() async {
    final registered = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const RegisterPage()));
    if (!mounted) return;
    if (registered == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('注册成功，请登录')));
    }
  }

  Future<void> _loadBackendUrl() async {
    try {
      final backendUrl = await _apiService.getBackendUrl();
      if (mounted) setState(() => _backendUrl = backendUrl);
    } catch (error) {
      debugPrint('读取登录页服务器地址失败: ${error.runtimeType}');
      if (mounted) {
        setState(() => _backendUrl = ApiService.defaultBackendUrl);
      }
    }
  }

  Future<void> _openBackendSettings() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BackendSetupPage(
          apiService: _apiService,
          initialUrl: _backendUrl ?? ApiService.defaultBackendUrl,
          returnToPrevious: true,
        ),
      ),
    );
    if (saved == true) await _loadBackendUrl();
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: '安全登录',
      subtitle: '使用已获准的企业邮箱账号进入工作台。',
      footer: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '还没有个人账号？',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              TextButton(
                onPressed: _isLoading ? null : _openRegister,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('立即注册'),
              ),
            ],
          ),
          AuthServerSettingsLink(
            backendUrl: _backendUrl,
            onPressed: _openBackendSettings,
            buttonKey: const Key('login_server_settings'),
            showComposeMigrationHint: ApiService.isLegacyLocalDebugUrl(
              _backendUrl,
            ),
          ),
        ],
      ),
      children: [
        AuthField(
          label: '邮箱',
          child: TextField(
            key: const Key('login_email'),
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14),
            decoration: authInputDecoration(
              hintText: 'name@company.com',
              icon: Icons.mail_outline,
            ),
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
        ),
        const SizedBox(height: 16),
        AuthField(
          label: '密码',
          child: TextField(
            key: const Key('login_password'),
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 14),
            decoration: authInputDecoration(
              hintText: '请输入密码',
              icon: Icons.lock_outline,
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                iconSize: 18,
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            onSubmitted: (_) => _login(),
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 16),
          AuthMessage(text: _errorText!, isError: true),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 44,
          child: FilledButton(
            onPressed: _isLoading ? null : _login,
            child: _isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('登录'),
          ),
        ),
      ],
    );
  }
}
