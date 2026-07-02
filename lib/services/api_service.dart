import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

abstract class ChatStreamingService {
  Stream<String> chatStream({
    required String sessionId,
    required String message,
  });
}

abstract class MemoryService {
  Future<List<Map>> getHistory(String sessionId);
  Future<bool> clearHistory(String sessionId);
}

class ApiService implements ChatStreamingService, MemoryService {
  static const String backendUrlKey = 'backend_url';
  static const String authTokenKey = 'auth_token';
  static const String userRoleKey = 'user_role';
  static const String defaultBackendUrl = 'http://localhost:8000';
  static const String connectionErrorMessage = '⚠️ 无法连接到后端，请检查服务是否启动';
  static const String timeoutErrorMessage = '⚠️ 请求超时，请稍后重试';

  Future<String> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(backendUrlKey)?.trim();
    if (saved == null || saved.isEmpty) return defaultBackendUrl;
    return _stripTrailingSlash(saved);
  }

  Future<void> saveBackendUrl(String backendUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      backendUrlKey,
      _stripTrailingSlash(backendUrl.trim()),
    );
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final backendUrl = await getBackendUrl();
    final uri = Uri.parse('$backendUrl/auth/login');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_loginErrorMessage(response));
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw Exception('登录响应格式错误');
    }
    final token = body['token'];
    final role = body['role'];
    if (token is! String || token.isEmpty || role is! String || role.isEmpty) {
      throw Exception('登录响应缺少token');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(authTokenKey, token);
    await prefs.setString(userRoleKey, role);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(authTokenKey);
    await prefs.remove(userRoleKey);
  }

  Future<String> checkHealth() async {
    try {
      final backendUrl = await getBackendUrl();
      final uri = Uri.parse('$backendUrl/health');
      final response = await http
          .get(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 'error';
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final status = body is Map<String, dynamic> ? body['status'] : null;
      if (status == 'ok' || status == 'degraded' || status == 'error') {
        return status as String;
      }
      return 'error';
    } catch (_) {
      return 'error';
    }
  }

  @override
  Future<List<Map>> getHistory(String sessionId) async {
    try {
      final backendUrl = await getBackendUrl();
      final uri = Uri.parse(
        '$backendUrl/memory/${Uri.encodeComponent(sessionId)}',
      );
      final response = await http
          .get(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return [];
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) return [];
      final history = body['history'];
      if (history is! List) return [];
      return history.whereType<Map>().toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> clearHistory(String sessionId) async {
    try {
      final backendUrl = await getBackendUrl();
      final uri = Uri.parse(
        '$backendUrl/memory/${Uri.encodeComponent(sessionId)}',
      );
      final response = await http
          .delete(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) return false;
      return body['status'] == 'cleared';
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<String> chatStream({
    required String sessionId,
    required String message,
  }) async* {
    final client = http.Client();
    try {
      final backendUrl = await getBackendUrl();
      final request = http.Request('POST', Uri.parse('$backendUrl/chat/stream'))
        ..headers.addAll(await _authHeaders(contentType: 'application/json'))
        ..body = jsonEncode({
          'session_id': sessionId,
          'message': message,
          'mode': 'chat',
        });

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        yield '⚠️ 发生错误：HTTP ${response.statusCode}';
        return;
      }

      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(const Duration(seconds: 30))) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;

        final rawData = trimmed.substring(6).trim();
        if (rawData.isEmpty) continue;

        try {
          final event = jsonDecode(rawData);
          if (event is! Map<String, dynamic>) continue;

          final error = event['error'];
          if (error is String && error.isNotEmpty) {
            yield error;
            return;
          }

          final chunk = event['chunk'];
          if (chunk is! String) continue;
          if (chunk == '[DONE]') return;
          yield chunk;
        } catch (_) {
          continue;
        }
      }
    } on SocketException {
      yield connectionErrorMessage;
    } on TimeoutException {
      yield timeoutErrorMessage;
    } catch (e) {
      yield '⚠️ 发生错误：${_briefError(e)}';
    } finally {
      client.close();
    }
  }

  Future<Map<String, String>> _authHeaders({String? contentType}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(authTokenKey)?.trim();
    final headers = <String, String>{};
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  String _loginErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        final detail = body['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
      }
    } catch (_) {
      // Ignore malformed error body and fall through to HTTP code.
    }
    return '登录失败：HTTP ${response.statusCode}';
  }

  String _stripTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  String _briefError(Object error) {
    final text = error.toString().replaceAll('\n', ' ');
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }
}
