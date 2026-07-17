import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhitian_app/models/message.dart';
import 'package:zhitian_app/models/pending_attachment.dart';
import 'package:zhitian_app/providers/chat_provider.dart';
import 'package:zhitian_app/services/api_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('multiple attachments upload and successful send clears them', () async {
    final service = _AttachmentService();
    final provider = ChatProvider(apiService: service);
    final files = await _createFiles(['one.txt', 'two.pdf']);
    addTearDown(() => files.first.parent.delete(recursive: true));

    await Future.wait(files.map(provider.addAttachment));

    expect(provider.pendingAttachments, hasLength(2));
    expect(
      provider.pendingAttachments.every(
        (item) => item.status == AttachmentUploadStatus.success,
      ),
      isTrue,
    );

    await provider.sendMessage('总结附件');

    expect(
      service.sentAttachmentIds,
      containsAll(['attachment-1', 'attachment-2']),
    );
    expect(service.sentAttachmentIds, hasLength(2));
    expect(provider.pendingAttachments, isEmpty);
  });

  test('failed send preserves successful attachments', () async {
    final service = _AttachmentService(failStream: true);
    final provider = ChatProvider(apiService: service);
    final files = await _createFiles(['keep.txt']);
    addTearDown(() => files.first.parent.delete(recursive: true));

    await provider.addAttachment(files.single);
    await provider.sendMessage('发送失败');

    expect(provider.pendingAttachments, hasLength(1));
    expect(
      provider.pendingAttachments.single.status,
      AttachmentUploadStatus.success,
    );
  });

  test('successful attachment allows an empty text message', () async {
    final service = _AttachmentService();
    final provider = ChatProvider(apiService: service);
    final files = await _createFiles(['only.txt']);
    addTearDown(() => files.first.parent.delete(recursive: true));

    await provider.addAttachment(files.single);
    expect(provider.canSend(''), isTrue);
    await provider.sendMessage('');

    expect(service.sentMessages, ['']);
    expect(service.sentAttachmentIds, ['attachment-1']);
    expect(provider.messages.first.attachmentFilenames, ['only.txt']);
  });

  test('new chat appends a session instead of replacing existing entries', () {
    final provider = ChatProvider(apiService: _AttachmentService());
    provider.newChat();
    final firstNewSession = provider.sessionId;
    provider.newChat();

    expect(
      provider.sessions.map((item) => item.sessionId),
      contains(firstNewSession),
    );
    expect(provider.sessions, hasLength(2));
  });

  test('upload state can be removed and new chat clears attachments', () async {
    final completer = Completer<ChatAttachmentUpload>();
    final service = _AttachmentService(uploadCompleter: completer);
    final provider = ChatProvider(apiService: service);
    final files = await _createFiles(['pending.txt']);
    addTearDown(() => files.first.parent.delete(recursive: true));

    final upload = provider.addAttachment(files.single);
    await Future<void>.delayed(Duration.zero);
    expect(provider.hasUploadingAttachments, isTrue);
    final localId = provider.pendingAttachments.single.attachmentId;
    provider.removeAttachment(localId);
    expect(provider.pendingAttachments, isEmpty);
    completer.complete(
      const ChatAttachmentUpload(
        attachmentId: 'late-id',
        filename: 'pending.txt',
      ),
    );
    await upload;

    await provider.addAttachment(files.single);
    provider.newChat();
    expect(provider.pendingAttachments, isEmpty);
  });
}

Future<List<File>> _createFiles(List<String> names) async {
  final directory = await Directory.systemTemp.createTemp(
    'attachment_provider_',
  );
  final files = <File>[];
  for (final name in names) {
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    await file.writeAsString('test');
    files.add(file);
  }
  return files;
}

class _AttachmentService implements ChatStreamingService {
  _AttachmentService({this.failStream = false, this.uploadCompleter});

  final bool failStream;
  final Completer<ChatAttachmentUpload>? uploadCompleter;
  final List<String> sentAttachmentIds = [];
  final List<String> sentMessages = [];
  int _uploadCount = 0;

  @override
  Future<ChatAttachmentUpload> uploadChatAttachment(
    String sessionId,
    File file,
  ) async {
    if (uploadCompleter != null) return uploadCompleter!.future;
    _uploadCount += 1;
    return ChatAttachmentUpload(
      attachmentId: 'attachment-$_uploadCount',
      filename: file.uri.pathSegments.last,
    );
  }

  @override
  Stream<ChatStreamEvent> chatStream({
    required String sessionId,
    required String message,
    required String mode,
    List<String> attachmentIds = const [],
  }) async* {
    sentMessages.add(message);
    sentAttachmentIds.addAll(attachmentIds);
    if (failStream) throw const SocketException('offline');
    yield ChatStreamEvent.chunk('ok');
    yield ChatStreamEvent.done();
  }
}
