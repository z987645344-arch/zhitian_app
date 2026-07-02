import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'chat_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText;

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
      _showError(_briefError(e));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorText = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text(
                    '知天',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1A73E8),
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '企业知识助手',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF666666), fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 15),
                    decoration: _inputDecoration(
                      label: '用户名',
                      icon: Icons.person_outline,
                    ),
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(fontSize: 15),
                    decoration: _inputDecoration(
                      label: '密码',
                      icon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 14),
                  if (_errorText != null)
                    Text(
                      _errorText!,
                      style: const TextStyle(color: Color(0xFFD32F2F)),
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : _login,
                      icon: _isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.login),
                      label: const Text('登录'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF666666)),
      prefixIcon: Icon(icon, color: const Color(0xFF666666)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _briefError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }
}
