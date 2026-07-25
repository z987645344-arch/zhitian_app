import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_shell.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.apiService});

  final ApiService? apiService;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // 后端 customer_register 用途的发送冷却为180秒，倒计时与之对齐
  static const int _codeCooldownSeconds = 180;

  late final ApiService _apiService = widget.apiService ?? ApiService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _sendingCode = false;
  bool _obscurePassword = true;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool _validEmail(String value) {
    final parts = value.trim().split('@');
    return parts.length == 2 &&
        parts.first.isNotEmpty &&
        parts.last.contains('.') &&
        !parts.last.startsWith('.') &&
        !parts.last.endsWith('.');
  }

  bool _strongPassword(String value) {
    return value.length >= 10 &&
        value.contains(RegExp(r'[A-Z]')) &&
        value.contains(RegExp(r'[a-z]')) &&
        value.contains(RegExp(r'[0-9]'));
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = _codeCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldownSeconds -= 1);
      if (_cooldownSeconds <= 0) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (_sendingCode || _cooldownSeconds > 0) return;
    final email = _emailController.text.trim();
    if (!_validEmail(email)) {
      setState(() {
        _error = '请输入有效的邮箱地址';
        _notice = null;
      });
      return;
    }
    setState(() {
      _sendingCode = true;
      _error = null;
      _notice = null;
    });
    try {
      await _apiService.sendCustomerRegisterCode(email: email);
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _notice = '验证码已发送，请查收邮箱';
      });
      _startCooldown();
    } on SocketException {
      _showSendError(ApiService.connectionErrorMessage);
    } on TimeoutException {
      _showSendError(ApiService.timeoutErrorMessage);
    } catch (error) {
      _showSendError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showSendError(String message) {
    if (!mounted) return;
    setState(() {
      _sendingCode = false;
      _error = message;
    });
  }

  Future<void> _submit() async {
    if (_loading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmation = _confirmController.text;
    if (!_validEmail(email)) {
      setState(() => _error = '请输入有效的邮箱地址');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = '请输入密码');
      return;
    }
    if (password != confirmation) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }
    // 前端预检减少无效请求，后端 validate_password_strength 才是唯一权威判断
    if (!_strongPassword(password)) {
      setState(() => _error = '密码需至少10位，且包含大小写字母和数字');
      return;
    }
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = '请输入邮箱验证码');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      await _apiService.registerCustomer(
        email: email,
        password: password,
        verificationCode: code,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on SocketException {
      _showError(ApiService.connectionErrorMessage);
    } on TimeoutException {
      _showError(ApiService.timeoutErrorMessage);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  String get _sendCodeLabel {
    if (_cooldownSeconds > 0) return '${_cooldownSeconds}s';
    return '发送验证码';
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: '创建个人账号',
      subtitle: '个人账号用于日常对话与文件工作台；企业角色需由管理员审批开通。',
      onBack: () => Navigator.of(context).pop(),
      footer: const Text(
        '注册即表示同意在企业内部合规使用本工作台。',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
      ),
      children: [
        AuthField(
          label: '邮箱',
          child: TextField(
            key: const Key('register_email'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14),
            decoration: authInputDecoration(
              hintText: 'name@company.com',
              icon: Icons.mail_outline,
            ),
          ),
        ),
        const SizedBox(height: 16),
        AuthField(
          label: '密码',
          hint: '至少10位，需包含大小写字母和数字',
          child: TextField(
            key: const Key('register_password'),
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14),
            decoration: authInputDecoration(
              hintText: '设置登录密码',
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
          ),
        ),
        const SizedBox(height: 16),
        AuthField(
          label: '确认密码',
          child: TextField(
            key: const Key('register_confirm_password'),
            controller: _confirmController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14),
            decoration: authInputDecoration(
              hintText: '再次输入密码',
              icon: Icons.lock_reset_outlined,
            ),
          ),
        ),
        const SizedBox(height: 16),
        AuthField(
          label: '邮箱验证码',
          trailing: SizedBox(
            width: 104,
            height: 44,
            child: OutlinedButton(
              key: const Key('register_send_code'),
              onPressed: (_sendingCode || _cooldownSeconds > 0)
                  ? null
                  : _sendCode,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: _sendingCode
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_sendCodeLabel),
            ),
          ),
          child: TextField(
            key: const Key('register_verification_code'),
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(fontSize: 14, letterSpacing: 2),
            onSubmitted: (_) => _submit(),
            decoration: authInputDecoration(
              hintText: '6位数字',
              icon: Icons.mark_email_read_outlined,
            ),
          ),
        ),
        if (_notice != null) ...[
          const SizedBox(height: 16),
          AuthMessage(text: _notice!, isError: false),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          AuthMessage(text: _error!, isError: true),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 44,
          child: FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('注册'),
          ),
        ),
      ],
    );
  }
}
