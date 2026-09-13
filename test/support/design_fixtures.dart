import 'package:zhitian_app/services/api_service.dart';
import 'package:zhitian_app/models/chat_session.dart';
import 'package:zhitian_app/models/user_file.dart';
import 'package:zhitian_app/models/file_preview.dart';

// In-memory presentation fixtures; no requests, accounts or credentials.
class DesignService extends ApiService {
  static const sampleFile = UserFile(
    fileId: 'design-document',
    originalFilename: '项目资料整理说明.md',
    format: 'md',
    sourceType: 'generated',
    sizeBytes: 2048,
    createdAt: null,
  );
  @override
  Future<String> getBackendUrl() async => '由管理员提供的服务地址';
  @override
  Future<List<ChatSessionSummary>> getSessions() async => const [
    ChatSessionSummary(
      sessionId: 'design-session',
      title: '整理项目资料与会议记录',
      lastActive: '2026-09-13 09:00',
      messageCount: 6,
    ),
  ];
  @override
  Future<List<UserFile>> listFiles() async => const [sampleFile];
  @override
  Future<List<Map>> getHistory(String sessionId) async => [];
  @override
  Future<FilePreview> previewFile(String fileId) async => FilePreview.fromJson({
    'file_id': fileId,
    'format': 'md',
    'content': '项目资料整理说明\n\n先核对来源，再整理关键结论。资料中的时间、范围和版本需要保留，方便后续回查。',
    'truncated': false,
  });
}
