import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
    });
  }
}

class _CapturingClient extends http.BaseClient {
  Map<String, dynamic> requestBody = {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestBody =
        jsonDecode(await request.finalize().bytesToString())
            as Map<String, dynamic>;
    return http.StreamedResponse(
      Stream.value(utf8.encode('data: {"chunk":"[DONE]"}\n\n')),
      200,
      headers: {'content-type': 'text/event-stream; charset=utf-8'},
    );
  }
}
