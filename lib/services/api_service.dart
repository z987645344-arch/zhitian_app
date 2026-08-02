import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/message.dart';
import '../models/file_preview.dart';
import '../models/chat_session.dart';
import '../models/pending_attachment.dart';
import '../models/tool_conversion.dart';
import '../models/user_file.dart';

abstract class ChatStreamingService {
  Stream<ChatStreamEvent> chatStream({
    required String sessionId,
    required String message,
    required String mode,
    List<String> attachmentIds = const [],
  });

  Future<ChatAttachmentUpload> uploadChatAttachment(
    String sessionId,
    File file,
  ) => throw UnimplementedError();
}

abstract class MemoryService {
  Future<List<ChatSessionSummary>> getSessions();
  Future<List<Map>> getHistory(String sessionId);
  Future<bool> clearHistory(String sessionId);
  Future<String?> renameSession(String sessionId, String? displayName);
  Future<bool> deleteSession(String sessionId);
}

abstract class ConversionService {
  Future<ToolConversionResult> convertFile(
    String filePath, {
    String? targetFormat,
  });
  Future<PdfMergeResult> mergePdfFiles(List<String> filePaths);
  Future<PdfSplitResult> splitPdfFile(String filePath);
  Future<ToolConversionDownload> downloadConversion(
    String fileId, {
    required String fallbackFilename,
  });
}

abstract class FileLibraryService {
  Future<List<UserFile>> listFiles();
  Future<FilePreview> previewFile(String fileId);
  Future<ToolConversionDownload> downloadFile(
    String fileId, {
    required String fallbackFilename,
  });
  Future<void> deleteFile(String fileId);
}

class ApiService
    implements
        ChatStreamingService,
        MemoryService,
        ConversionService,
        FileLibraryService {
  ApiService({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;

  static const String backendUrlKey = 'backend_url';
  static const String authTokenKey = 'auth_token';
  static const String userRoleKey = 'user_role';
  static const String usernameKey = 'username';
  static const String chatSessionIdKey = 'chat_session_id';
  static const String chatModeKey = 'chat_mode';
  static const String defaultBackendUrl = 'http://localhost:8000';
  static const String connectionErrorMessage = '⚠️ 无法连接服务器，请检查地址和网络连接';
  static const String certificateErrorMessage =
      '⚠️ 证书验证失败，请确认服务地址使用有效的 HTTPS 证书';
  static const String timeoutErrorMessage = '⚠️ 请求超时，请稍后重试';

  static String normalizeBackendUrl(String value) {
    var candidate = value.trim();
    if (candidate.isEmpty) {
      throw const FormatException('请输入后端服务地址');
    }
    if (!candidate.contains('://')) {
      final lower = candidate.toLowerCase();
      final isLoopback =
          lower == 'localhost' ||
          lower.startsWith('localhost:') ||
          lower == '127.0.0.1' ||
          lower.startsWith('127.0.0.1:') ||
          lower == '[::1]' ||
          lower.startsWith('[::1]:');
      candidate = '${isLoopback ? 'http' : 'https'}://$candidate';
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const FormatException('地址格式无效，请填写完整的 HTTP 或 HTTPS 地址');
    }
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      throw const FormatException('地址不能包含账号密码、查询参数或片段');
    }
    final host = uri.host.toLowerCase();
    final isLoopback =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    if (uri.scheme == 'http' && !isLoopback) {
      throw const FormatException('远程服务必须使用 HTTPS；HTTP 仅允许本机地址');
    }
    return _stripTrailingSlash(uri.toString());
  }

  static bool isValidBackendUrl(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    try {
      normalizeBackendUrl(value);
      return true;
    } on FormatException {
      return false;
    }
  }

  static String userMessageFor(Object error) {
    final lower = error.toString().toLowerCase();
    if (error is HandshakeException ||
        lower.contains('certificate_verify_failed') ||
        lower.contains('handshake')) {
      return certificateErrorMessage;
    }
    if (error is SocketException ||
        error is http.ClientException ||
        lower.contains('connection refused')) {
      return connectionErrorMessage;
    }
    if (error is TimeoutException) return timeoutErrorMessage;
    if (error is FormatException) return error.message;
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }

  Future<String> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(backendUrlKey)?.trim();
    if (saved == null || saved.isEmpty) return defaultBackendUrl;
    return normalizeBackendUrl(saved);
  }

  Future<bool> saveBackendUrl(String backendUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = normalizeBackendUrl(backendUrl);
    final saved = prefs.getString(backendUrlKey)?.trim();
    final previous = isValidBackendUrl(saved)
        ? normalizeBackendUrl(saved!)
        : null;
    final changed = previous != normalized;
    await prefs.setString(backendUrlKey, normalized);
    if (changed) {
      await prefs.remove(authTokenKey);
      await prefs.remove(userRoleKey);
      await prefs.remove(usernameKey);
      await prefs.remove(chatSessionIdKey);
    }
    return changed;
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final backendUrl = await getBackendUrl();
    final uri = Uri.parse('$backendUrl/auth/login');
    final response = await _postJson(uri, {
      'username': username,
      'password': password,
      'role': 'customer',
    });

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
    await prefs.setString(usernameKey, username);
  }

  /// 发送customer自助注册验证码；customer场景不需要企业密码。
  Future<void> sendCustomerRegisterCode({required String email}) async {
    final backendUrl = await getBackendUrl();
    final response = await _postJson(
      Uri.parse('$backendUrl/auth/send-verification-code'),
      {'email': email, 'purpose': 'customer_register'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_responseDetail(response, '验证码发送失败，请稍后重试'));
    }
  }

  Future<void> registerCustomer({
    required String email,
    required String password,
    required String verificationCode,
  }) async {
    final backendUrl = await getBackendUrl();
    final response = await _postJson(Uri.parse('$backendUrl/auth/register'), {
      'username': email,
      'password': password,
      'role': 'customer',
      'verification_code': verificationCode,
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_responseDetail(response, '注册失败，请稍后重试'));
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(authTokenKey);
    await prefs.remove(userRoleKey);
    await prefs.remove(usernameKey);
    await prefs.remove(chatSessionIdKey);
  }

  Future<http.Response> _postJson(Uri uri, Map<String, dynamic> body) async {
    final client = _clientFactory();
    try {
      return await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
    } finally {
      client.close();
    }
  }

  Future<BackendConnectionResult> checkBackendUrl(String backendUrl) async {
    final client = _clientFactory();
    try {
      final normalized = normalizeBackendUrl(backendUrl);
      final uri = Uri.parse('$normalized/health');
      final response = await client
          .get(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return BackendConnectionResult.error(
          '服务器已响应，但健康检查返回 HTTP ${response.statusCode}',
        );
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final status = body is Map<String, dynamic> ? body['status'] : null;
      if (status == 'ok') {
        return const BackendConnectionResult(
          status: 'ok',
          message: '连接成功，服务运行正常',
        );
      }
      if (status == 'degraded') {
        return const BackendConnectionResult(
          status: 'degraded',
          message: '已连接，但服务处于降级状态',
        );
      }
      return const BackendConnectionResult(
        status: 'error',
        message: '服务器已响应，但健康状态异常',
      );
    } catch (error) {
      final lower = error.toString().toLowerCase();
      final status =
          error is HandshakeException ||
              lower.contains('certificate_verify_failed') ||
              lower.contains('handshake')
          ? 'certificate_error'
          : 'error';
      return BackendConnectionResult(
        status: status,
        message: userMessageFor(error).replaceFirst('⚠️ ', ''),
      );
    } finally {
      client.close();
    }
  }

  Future<String> checkHealth() async {
    final backendUrl = await getBackendUrl();
    return (await checkBackendUrl(backendUrl)).status;
  }

  @override
  Future<ToolConversionResult> convertFile(
    String filePath, {
    String? targetFormat,
  }) async {
    final client = _clientFactory();
    try {
      final backendUrl = await getBackendUrl();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendUrl/tools/convert'),
      );
      request.headers.addAll(await _authHeaders());
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      if (targetFormat != null && targetFormat.isNotEmpty) {
        request.fields['target_format'] = targetFormat;
      }
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final bytes = await response.stream.toBytes();
      if (response.statusCode == 401) {
        await logout();
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw Exception('转换响应格式错误');
      }
      return ToolConversionResult.fromJson(decoded);
    } finally {
      client.close();
    }
  }

  @override
  Future<PdfMergeResult> mergePdfFiles(List<String> filePaths) async {
    final client = _clientFactory();
    try {
      final backendUrl = await getBackendUrl();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendUrl/tools/pdf/merge'),
      )..headers.addAll(await _authHeaders());
      for (final filePath in filePaths) {
        request.files.add(await http.MultipartFile.fromPath('files', filePath));
      }
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final decoded = _decodeToolResponse(await response.stream.toBytes());
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception((decoded['detail'] ?? 'PDF合并失败').toString());
      }
      return PdfMergeResult.fromJson(decoded);
    } finally {
      client.close();
    }
  }

  @override
  Future<PdfSplitResult> splitPdfFile(String filePath) async {
    final client = _clientFactory();
    try {
      final backendUrl = await getBackendUrl();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendUrl/tools/pdf/split'),
      )..headers.addAll(await _authHeaders());
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final decoded = _decodeToolResponse(await response.stream.toBytes());
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception((decoded['detail'] ?? 'PDF拆分失败').toString());
      }
      return PdfSplitResult.fromJson(decoded);
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> _decodeToolResponse(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('工具箱响应格式错误');
    }
    return decoded;
  }

  @override
  Future<ToolConversionDownload> downloadConversion(
    String fileId, {
    required String fallbackFilename,
  }) async {
    return downloadFile(fileId, fallbackFilename: fallbackFilename);
  }

  @override
  Future<List<UserFile>> listFiles() async {
    final client = _clientFactory();
    try {
      final backendUrl = await getBackendUrl();
      final response = await client
          .get(Uri.parse('$backendUrl/files'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('加载文件列表失败：HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) throw Exception('文件列表响应格式错误');
      return decoded
          .whereType<Map>()
          .map((item) => UserFile.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } finally {
      client.close();
    }
  }

  @override
  Future<FilePreview> previewFile(String fileId) async {
    final client = _clientFactory();
    try {
      final backendUrl = await getBackendUrl();
      final uri = Uri.parse(
        '$backendUrl/files/${Uri.encodeComponent(fileId)}/preview',
      );
      final response = await client
          .get(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 35));
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = body is Map<String, dynamic>
            ? (body['detail'] ?? '文件预览失败').toString()
            : '文件预览失败';
        throw Exception(detail);
      }
      if (body is! Map<String, dynamic>) {
        throw Exception('文件预览响应格式错误');
      }
      return FilePreview.fromJson(body);
    } finally {
      client.close();
    }
  }

  @override
  Future<ToolConversionDownload> downloadFile(
    String fileId, {
    required String fallbackFilename,
  }) async {
    final client = _clientFactory();
    try {
      final backendUrl = await getBackendUrl();
      final request = http.Request(
        'GET',
        Uri.parse('$backendUrl/files/${Uri.encodeComponent(fileId)}'),
      )..headers.addAll(await _authHeaders());
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('下载失败：HTTP ${response.statusCode}');
      }
      return ToolConversionDownload(
        filename: _downloadFilename(
          response.headers['content-disposition'],
          fallbackFilename,
        ),
        bytes: Uint8List.fromList(await response.stream.toBytes()),
      );
    } finally {
      client.close();
    }
  }

  @override
  Future<void> deleteFile(String fileId) async {
    final client = _clientFactory();
    try {
      final backendUrl = await getBackendUrl();
      final request = http.Request(
        'DELETE',
        Uri.parse('$backendUrl/files/${Uri.encodeComponent(fileId)}'),
      )..headers.addAll(await _authHeaders());
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('删除文件失败：HTTP ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<List<ChatSessionSummary>> getSessions() async {
    try {
      final backendUrl = await getBackendUrl();
      final response = await http
          .get(
            Uri.parse('$backendUrl/memory/sessions'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return [];
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic> || body['sessions'] is! List) return [];
      return (body['sessions'] as List)
          .whereType<Map>()
          .map(
            (item) =>
                ChatSessionSummary.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.sessionId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
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
  Future<String?> renameSession(String sessionId, String? displayName) async {
    final backendUrl = await getBackendUrl();
    final uri = Uri.parse(
      '$backendUrl/memory/sessions/${Uri.encodeComponent(sessionId)}',
    );
    final client = _clientFactory();
    try {
      final response = await client
          .patch(
            uri,
            headers: await _authHeaders(contentType: 'application/json'),
            body: jsonEncode({'display_name': displayName}),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('重命名会话失败：HTTP ${response.statusCode}');
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) return displayName;
      return body['display_name']?.toString();
    } finally {
      client.close();
    }
  }

  @override
  Future<bool> deleteSession(String sessionId) async {
    final backendUrl = await getBackendUrl();
    final uri = Uri.parse(
      '$backendUrl/memory/sessions/${Uri.encodeComponent(sessionId)}',
    );
    final client = _clientFactory();
    try {
      final response = await client
          .delete(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body is Map<String, dynamic> && body['deleted'] == true;
    } finally {
      client.close();
    }
  }

  @override
  Stream<ChatStreamEvent> chatStream({
    required String sessionId,
    required String message,
    required String mode,
    List<String> attachmentIds = const [],
  }) async* {
    final client = _clientFactory();
    try {
      final backendUrl = await getBackendUrl();
      final request = http.Request('POST', Uri.parse('$backendUrl/chat/stream'))
        ..headers.addAll(await _authHeaders(contentType: 'application/json'))
        ..body = jsonEncode({
          'session_id': sessionId,
          'message': message,
          'mode': mode,
          'attachment_ids': attachmentIds,
        });

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 90));
      if (response.statusCode == 401) {
        await logout();
        yield ChatStreamEvent.chunk('⚠️ 登录已过期，请重新登录');
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        yield ChatStreamEvent.chunk('⚠️ 发生错误：HTTP ${response.statusCode}');
        return;
      }

      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(const Duration(seconds: 90))) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;

        final rawData = trimmed.substring(6).trim();
        if (rawData.isEmpty) continue;

        try {
          final event = jsonDecode(rawData);
          if (event is! Map<String, dynamic>) continue;

          final error = event['error'];
          if (error is String && error.isNotEmpty) {
            yield ChatStreamEvent.chunk(error);
            return;
          }

          if (event['type'] == 'citations') {
            yield ChatStreamEvent.citations(parseCitations(event['citations']));
            continue;
          }

          final reasoning = event['reasoning'];
          if (reasoning is String && reasoning.trim().isNotEmpty) {
            yield ChatStreamEvent.reasoning(reasoning.trim());
            continue;
          }

          final chunk = event['chunk'];
          if (chunk is! String) continue;
          if (chunk == '[DONE]') {
            yield ChatStreamEvent.done();
            return;
          }
          yield ChatStreamEvent.chunk(chunk);
        } catch (_) {
          continue;
        }
      }
    } on HandshakeException catch (error) {
      yield ChatStreamEvent.chunk(userMessageFor(error));
    } on SocketException catch (error) {
      yield ChatStreamEvent.chunk(userMessageFor(error));
    } on TimeoutException catch (error) {
      yield ChatStreamEvent.chunk(userMessageFor(error));
    } catch (e) {
      yield ChatStreamEvent.chunk(userMessageFor(e));
    } finally {
      client.close();
    }
  }

  @override
  Future<ChatAttachmentUpload> uploadChatAttachment(
    String sessionId,
    File file,
  ) async {
    final client = _clientFactory();
    try {
      final backendUrl = await getBackendUrl();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendUrl/chat/attachments'),
      );
      request.headers.addAll(await _authHeaders());
      request.fields['session_id'] = sessionId;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final bytes = await response.stream.toBytes();
      if (response.statusCode == 401) await logout();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('附件上传失败：HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw Exception('附件上传响应格式错误');
      }
      final attachmentId = decoded['attachment_id']?.toString() ?? '';
      final filename =
          decoded['original_filename']?.toString() ??
          file.uri.pathSegments.last;
      if (attachmentId.isEmpty) throw Exception('附件上传响应缺少attachment_id');
      return ChatAttachmentUpload(
        attachmentId: attachmentId,
        filename: filename,
      );
    } on HandshakeException catch (error) {
      throw Exception(userMessageFor(error));
    } on SocketException catch (error) {
      throw Exception(userMessageFor(error));
    } on TimeoutException catch (error) {
      throw Exception(userMessageFor(error));
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
    return _responseDetail(response, '登录失败：HTTP ${response.statusCode}');
  }

  String _responseDetail(http.Response response, String fallback) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        final detail = body['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
      }
    } catch (_) {
      // Ignore malformed error body and fall through to HTTP code.
    }
    return fallback;
  }

  String _downloadFilename(String? contentDisposition, String fallback) {
    final encoded = RegExp(
      r"filename\*=utf-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(contentDisposition ?? '')?.group(1);
    if (encoded != null && encoded.isNotEmpty) {
      return Uri.decodeComponent(encoded);
    }
    final quoted = RegExp(
      r'filename="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(contentDisposition ?? '')?.group(1);
    return quoted?.trim().isNotEmpty == true ? quoted!.trim() : fallback;
  }

  static String _stripTrailingSlash(String value) {
    var result = value;
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}

class BackendConnectionResult {
  const BackendConnectionResult({required this.status, required this.message});

  const BackendConnectionResult.error(String message)
    : this(status: 'error', message: message);

  final String status;
  final String message;

  bool get isHealthy => status == 'ok' || status == 'degraded';
}
