import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/user_file.dart';
import 'file_preview_page.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key, FileLibraryService? apiService})
    : _apiService = apiService;

  final FileLibraryService? _apiService;

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  late final FileLibraryService _apiService;
  List<UserFile> _files = const [];
  bool _loading = true;
  String? _busyFileId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiService = widget._apiService ?? ApiService();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await _apiService.listFiles();
      if (mounted) setState(() => _files = files);
    } catch (_) {
      if (mounted) setState(() => _error = '文件列表加载失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download(UserFile file) async {
    if (_busyFileId != null) return;
    setState(() => _busyFileId = file.fileId);
    try {
      final download = await _apiService.downloadFile(
        file.fileId,
        fallbackFilename: file.originalFilename,
      );
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存文件',
        fileName: download.filename,
      );
      if (outputPath != null) {
        await File(outputPath).writeAsBytes(download.bytes, flush: true);
      }
    } catch (_) {
      if (mounted) setState(() => _error = '文件下载失败');
    } finally {
      if (mounted) setState(() => _busyFileId = null);
    }
  }

  void _preview(UserFile file) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FilePreviewPage(file: file, apiService: _apiService),
      ),
    );
  }

  Future<void> _confirmDelete(UserFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定删除“${file.originalFilename}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busyFileId != null) return;
    setState(() => _busyFileId = file.fileId);
    try {
      await _apiService.deleteFile(file.fileId);
      if (mounted) {
        setState(
          () => _files = _files
              .where((item) => item.fileId != file.fileId)
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = '文件删除失败');
    } finally {
      if (mounted) setState(() => _busyFileId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('我的文件'),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _loadFiles,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: RefreshIndicator(
                  onRefresh: _loadFiles,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFB3261E)),
                          ),
                        ),
                      if (_files.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('暂无文件')),
                        ),
                      for (final file in _files)
                        _FileRow(
                          file: file,
                          busy: _busyFileId == file.fileId,
                          onPreview: () => _preview(file),
                          onDownload: () => _download(file),
                          onDelete: () => _confirmDelete(file),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.busy,
    required this.onDownload,
    required this.onPreview,
    required this.onDelete,
  });

  final UserFile file;
  final bool busy;
  final VoidCallback onDownload;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.originalFilename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${_sourceLabel(file.sourceType)} · ${_sizeLabel(file.sizeBytes)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            if (_previewableFormats.contains(file.format.toLowerCase()))
              IconButton(
                tooltip: '预览',
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined),
              ),
            IconButton(
              tooltip: '下载',
              onPressed: onDownload,
              icon: const Icon(Icons.download_outlined),
            ),
            IconButton(
              tooltip: '删除',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ],
      ),
    );
  }

  static String _sourceLabel(String sourceType) {
    return switch (sourceType) {
      'attachment' => '聊天附件',
      'generated' => '生成文件',
      'converted' => '转换文件',
      _ => sourceType,
    };
  }

  static const Set<String> _previewableFormats = {'txt', 'md', 'pdf', 'docx'};

  static String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
