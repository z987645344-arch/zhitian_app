import 'dart:async';

import 'package:flutter/material.dart';

import '../models/file_preview.dart';
import '../models/user_file.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class FilePreviewPage extends StatefulWidget {
  const FilePreviewPage({
    super.key,
    required this.file,
    FileLibraryService? apiService,
  }) : _apiService = apiService;

  final UserFile file;
  final FileLibraryService? _apiService;

  @override
  State<FilePreviewPage> createState() => _FilePreviewPageState();
}

class _FilePreviewPageState extends State<FilePreviewPage> {
  late final FileLibraryService _apiService;
  FilePreview? _preview;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _apiService = widget._apiService ?? ApiService();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preview = await _apiService.previewFile(widget.file.fileId);
      if (mounted) setState(() => _preview = preview);
    } on TimeoutException {
      if (mounted) setState(() => _error = '预览请求超时，请稍后重试');
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        setState(() => _error = message.isEmpty ? '文件预览失败' : message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.file.originalFilename),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        actions: [
          IconButton(
            tooltip: '重新加载',
            onPressed: _loading ? null : _loadPreview,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: SelectableText(
                              _preview?.content ?? '',
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 15,
                                height: 1.7,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_preview?.truncated == true)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFFFFF4CE),
                    child: const Text(
                      '内容较长，已截断显示',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
    );
  }
}
