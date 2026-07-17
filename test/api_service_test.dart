import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhitian_app/constants/toolbox_formats.dart';
import 'package:zhitian_app/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mode in ['fast', 'expert']) {
    test('chat stream serializes $mode mode in the request body', () async {
      final client = _CapturingClient();

      SharedPreferences.setMockInitialValues({
        ApiService.backendUrlKey: 'http://localhost:8000',
        ApiService.authTokenKey: 'test-token',
      });

      await ApiService(clientFactory: () => client)
          .chatStream(sessionId: 'mode-test', message: 'hello', mode: mode)
          .toList();

      expect(client.requestBody['mode'], mode);
      expect(client.requestBody['session_id'], 'mode-test');
      expect(client.requestBody['message'], 'hello');
      expect(client.requestBody['attachment_ids'], isEmpty);
    });
  }

  test('toolbox conversion formats match backend supported extensions', () {
    expect(toolboxConvertibleExtensions, [
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
    ]);
    expect(toolboxPdfExtensions, ['pdf']);
  });

  test(
    'chat stream parses reasoning without affecting chunks or done',
    () async {
      final client = _CapturingClient(
        responseBody:
            'data: {"chunk":"","reasoning":"需要检索企业资料"}\n\n'
            'data: {"chunk":"正文"}\n\n'
            'data: {"chunk":"[DONE]"}\n\n',
      );
      SharedPreferences.setMockInitialValues({
        ApiService.backendUrlKey: 'http://localhost:8000',
        ApiService.authTokenKey: 'test-token',
      });

      final events = await ApiService(clientFactory: () => client)
          .chatStream(
            sessionId: 'reasoning-test',
            message: 'hello',
            mode: 'expert',
          )
          .toList();

      expect(events, hasLength(3));
      expect(events[0].reasoning, '需要检索企业资料');
      expect(events[1].chunk, '正文');
      expect(events[2].isDone, isTrue);
    },
  );

  test(
    'tool conversion upload and download use authenticated endpoints',
    () async {
      final client = _ConversionClient();
      final tempDir = await Directory.systemTemp.createTemp(
        'zhitian_tool_test_',
      );
      final input = File('${tempDir.path}${Platform.pathSeparator}sample.xlsx');
      await input.writeAsBytes([1, 2, 3]);
      SharedPreferences.setMockInitialValues({
        ApiService.backendUrlKey: 'http://localhost:8000',
        ApiService.authTokenKey: 'test-token',
      });

      try {
        final service = ApiService(clientFactory: () => client);
        final result = await service.convertFile(
          input.path,
          targetFormat: 'pdf',
        );
        final download = await service.downloadConversion(
          result.fileId,
          fallbackFilename: result.downloadFilename,
        );

        expect(result.success, isTrue);
        expect(result.fileId, 'file-123');
        expect(result.convertedToFormat, 'pdf');
        expect(download.filename, 'sample.pdf');
        expect(download.bytes, [9, 8, 7]);
        expect(client.paths, ['/tools/convert', '/files/file-123']);
        expect(client.authorizationHeaders, [
          'Bearer test-token',
          'Bearer test-token',
        ]);
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );

  test('PDF merge and split serialize multipart files', () async {
    final client = _PdfToolsClient();
    final tempDir = await Directory.systemTemp.createTemp('zhitian_pdf_test_');
    final first = File('${tempDir.path}${Platform.pathSeparator}first.pdf');
    final second = File('${tempDir.path}${Platform.pathSeparator}second.pdf');
    await first.writeAsBytes([37, 80, 68, 70]);
    await second.writeAsBytes([37, 80, 68, 70]);
    SharedPreferences.setMockInitialValues({
      ApiService.backendUrlKey: 'http://localhost:8000',
      ApiService.authTokenKey: 'test-token',
    });

    try {
      final service = ApiService(clientFactory: () => client);
      final merged = await service.mergePdfFiles([first.path, second.path]);
      final split = await service.splitPdfFile(first.path);

      expect(merged.file.downloadFilename, 'merged_first.pdf');
      expect(merged.pageCount, 2);
      expect(split.files.map((item) => item.downloadFilename), [
        'first_page1.pdf',
        'first_page2.pdf',
      ]);
      expect(client.paths, ['/tools/pdf/merge', '/tools/pdf/split']);
      expect(client.fileFields[0], ['files', 'files']);
      expect(client.fileFields[1], ['file']);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('file library lists and deletes authenticated user files', () async {
    final client = _FilesClient();
    SharedPreferences.setMockInitialValues({
      ApiService.backendUrlKey: 'http://localhost:8000',
      ApiService.authTokenKey: 'test-token',
    });
    final service = ApiService(clientFactory: () => client);

    final files = await service.listFiles();
    final preview = await service.previewFile(files.single.fileId);
    await service.deleteFile(files.single.fileId);

    expect(files.single.originalFilename, 'report.pdf');
    expect(files.single.sourceType, 'generated');
    expect(preview.content, 'preview text');
    expect(preview.truncated, isTrue);
    expect(client.requests, [
      'GET /files',
      'GET /files/file-456/preview',
      'DELETE /files/file-456',
    ]);
    expect(client.authorizationHeaders, [
      'Bearer test-token',
      'Bearer test-token',
      'Bearer test-token',
    ]);
  });

  test('chat attachment upload and stream send authenticated ids', () async {
    final client = _AttachmentClient();
    final tempDir = await Directory.systemTemp.createTemp('chat_attachment_');
    final input = File('${tempDir.path}${Platform.pathSeparator}notes.txt');
    await input.writeAsString('attachment');
    SharedPreferences.setMockInitialValues({
      ApiService.backendUrlKey: 'http://localhost:8000',
      ApiService.authTokenKey: 'test-token',
    });

    try {
      final service = ApiService(clientFactory: () => client);
      final upload = await service.uploadChatAttachment('session-1', input);
      await service
          .chatStream(
            sessionId: 'session-1',
            message: 'summarize',
            mode: 'fast',
            attachmentIds: [upload.attachmentId],
          )
          .toList();

      expect(upload.attachmentId, 'attachment-123');
      expect(upload.filename, 'notes.txt');
      expect(client.uploadSessionId, 'session-1');
      expect(client.streamBody['attachment_ids'], ['attachment-123']);
      expect(client.authorizationHeaders, [
        'Bearer test-token',
        'Bearer test-token',
      ]);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'session rename and delete use authenticated management endpoints',
    () async {
      final client = _SessionManagementClient();
      SharedPreferences.setMockInitialValues({
        ApiService.backendUrlKey: 'http://localhost:8000',
        ApiService.authTokenKey: 'test-token',
      });
      final service = ApiService(clientFactory: () => client);

      final renamed = await service.renameSession('session-1', '项目讨论');
      final deleted = await service.deleteSession('session-1');

      expect(renamed, '项目讨论');
      expect(deleted, isTrue);
      expect(client.requests, [
        'PATCH /memory/sessions/session-1',
        'DELETE /memory/sessions/session-1',
      ]);
      expect(client.renameBody, {'display_name': '项目讨论'});
      expect(client.authorizationHeaders, [
        'Bearer test-token',
        'Bearer test-token',
      ]);
    },
  );
}

class _CapturingClient extends http.BaseClient {
  _CapturingClient({this.responseBody = 'data: {"chunk":"[DONE]"}\n\n'});

  final String responseBody;
  Map<String, dynamic> requestBody = {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestBody =
        jsonDecode(await request.finalize().bytesToString())
            as Map<String, dynamic>;
    return http.StreamedResponse(
      Stream.value(utf8.encode(responseBody)),
      200,
      headers: {'content-type': 'text/event-stream; charset=utf-8'},
    );
  }
}

class _ConversionClient extends http.BaseClient {
  final List<String> paths = [];
  final List<String?> authorizationHeaders = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    paths.add(request.url.path);
    authorizationHeaders.add(request.headers['Authorization']);
    if (request.method == 'POST') {
      expect(request, isA<http.MultipartRequest>());
      final multipart = request as http.MultipartRequest;
      expect(multipart.files.single.field, 'file');
      expect(multipart.fields['target_format'], 'pdf');
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'success': true,
              'file_id': 'file-123',
              'download_filename': 'sample.pdf',
              'converted_from_format': 'xlsx',
              'converted_to_format': 'pdf',
              'error_type': '',
            }),
          ),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(
      Stream.value([9, 8, 7]),
      200,
      headers: {
        'content-disposition': "attachment; filename*=utf-8''sample.pdf",
      },
    );
  }
}

class _PdfToolsClient extends http.BaseClient {
  final List<String> paths = [];
  final List<List<String>> fileFields = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    paths.add(request.url.path);
    final multipart = request as http.MultipartRequest;
    fileFields.add(multipart.files.map((file) => file.field).toList());
    final body = request.url.path.endsWith('/merge')
        ? {
            'success': true,
            'file_id': 'merged-id',
            'download_filename': 'merged_first.pdf',
            'download_url': '/files/merged-id',
            'page_count': 2,
          }
        : {
            'success': true,
            'files': [
              {
                'file_id': 'page-1',
                'download_filename': 'first_page1.pdf',
                'download_url': '/files/page-1',
              },
              {
                'file_id': 'page-2',
                'download_filename': 'first_page2.pdf',
                'download_url': '/files/page-2',
              },
            ],
            'page_count': 2,
          };
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
    );
  }
}

class _FilesClient extends http.BaseClient {
  final List<String> requests = [];
  final List<String?> authorizationHeaders = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add('${request.method} ${request.url.path}');
    authorizationHeaders.add(request.headers['Authorization']);
    if (request.method == 'GET') {
      if (request.url.path.endsWith('/preview')) {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'file_id': 'file-456',
                'filename': 'report.pdf',
                'format': 'pdf',
                'content': 'preview text',
                'truncated': true,
              }),
            ),
          ),
          200,
        );
      }
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode([
              {
                'file_id': 'file-456',
                'original_filename': 'report.pdf',
                'format': 'pdf',
                'source_type': 'generated',
                'size_bytes': 2048,
                'created_at': '2026-07-15T12:00:00+08:00',
              },
            ]),
          ),
        ),
        200,
      );
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  }
}

class _AttachmentClient extends http.BaseClient {
  String? uploadSessionId;
  Map<String, dynamic> streamBody = {};
  final List<String?> authorizationHeaders = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    authorizationHeaders.add(request.headers['Authorization']);
    if (request is http.MultipartRequest) {
      uploadSessionId = request.fields['session_id'];
      expect(request.files.single.field, 'file');
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'success': true,
              'attachment_id': 'attachment-123',
              'original_filename': 'notes.txt',
              'char_count': 10,
            }),
          ),
        ),
        200,
      );
    }
    streamBody =
        jsonDecode(await request.finalize().bytesToString())
            as Map<String, dynamic>;
    return http.StreamedResponse(
      Stream.value(utf8.encode('data: {"chunk":"[DONE]"}\n\n')),
      200,
    );
  }
}

class _SessionManagementClient extends http.BaseClient {
  final List<String> requests = [];
  final List<String?> authorizationHeaders = [];
  Map<String, dynamic> renameBody = {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add('${request.method} ${request.url.path}');
    authorizationHeaders.add(request.headers['Authorization']);
    if (request.method == 'PATCH') {
      renameBody =
          jsonDecode(await request.finalize().bytesToString())
              as Map<String, dynamic>;
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({'session_id': 'session-1', 'display_name': '项目讨论'}),
          ),
        ),
        200,
      );
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'deleted': true}))),
      200,
    );
  }
}
