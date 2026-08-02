import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../constants/toolbox_formats.dart';
import '../models/tool_conversion.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

enum _ToolMode { convert, merge, split }

class ToolboxPage extends StatefulWidget {
  const ToolboxPage({super.key, ConversionService? apiService})
    : _apiService = apiService;

  final ConversionService? _apiService;

  @override
  State<ToolboxPage> createState() => _ToolboxPageState();
}

class _ToolboxPageState extends State<ToolboxPage> {
  late final ConversionService _apiService;
  _ToolMode _mode = _ToolMode.convert;
  ToolboxConversionOption _conversionOption = toolboxConversionOptions.first;
  List<String> _selectedPaths = [];
  List<String> _selectedNames = [];
  ToolConversionResult? _conversionResult;
  PdfMergeResult? _mergeResult;
  PdfSplitResult? _splitResult;
  bool _isProcessing = false;
  bool _isDownloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiService = widget._apiService ?? ApiService();
  }

  List<String> get _allowedExtensions => _mode == _ToolMode.convert
      ? _conversionOption.extensions
      : toolboxPdfExtensions;

  Future<void> _pickFiles() async {
    if (_isProcessing) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: _mode == _ToolMode.merge,
    );
    if (picked == null || !mounted) return;
    final selected = picked.files.where((item) => item.path != null).toList();
    await _useFiles(
      selected.map((item) => item.path!).toList(),
      selected.map((item) => item.name).toList(),
      append: _mode == _ToolMode.merge,
    );
  }

  Future<void> _useFiles(
    List<String> paths,
    List<String> names, {
    bool append = false,
  }) async {
    if (_isProcessing || paths.isEmpty || paths.length != names.length) return;
    if (_mode != _ToolMode.merge && paths.length != 1) {
      setState(() => _error = '当前操作只能选择一个文件');
      return;
    }
    final nextPaths = append ? [..._selectedPaths, ...paths] : paths;
    final nextNames = append ? [..._selectedNames, ...names] : names;
    if (_mode == _ToolMode.merge && nextPaths.length > 10) {
      setState(() => _error = 'PDF合并最多选择10个文件');
      return;
    }
    for (var index = 0; index < paths.length; index++) {
      final extension = names[index].split('.').last.toLowerCase();
      if (!_allowedExtensions.contains(extension)) {
        setState(() => _error = '不支持该文件格式');
        return;
      }
      if (File(paths[index]).lengthSync() > 20 * 1024 * 1024) {
        setState(() => _error = '文件超过20MB限制');
        return;
      }
    }
    setState(() {
      _selectedPaths = nextPaths;
      _selectedNames = nextNames;
      _clearResults();
    });
    if (_mode != _ToolMode.merge) await _process();
  }

  void _removeSelectedFile(int index) {
    if (_isProcessing || index < 0 || index >= _selectedPaths.length) return;
    setState(() {
      _selectedPaths = [..._selectedPaths]..removeAt(index);
      _selectedNames = [..._selectedNames]..removeAt(index);
      _clearResults();
    });
  }

  void _clearResults() {
    _conversionResult = null;
    _mergeResult = null;
    _splitResult = null;
    _error = null;
  }

  Future<void> _process() async {
    if (_selectedPaths.isEmpty || _isProcessing) return;
    setState(() {
      _isProcessing = true;
      _clearResults();
    });
    try {
      switch (_mode) {
        case _ToolMode.convert:
          final result = await _apiService.convertFile(
            _selectedPaths.single,
            targetFormat: _conversionOption.targetFormat,
          );
          if (mounted) {
            setState(() {
              _conversionResult = result.success ? result : null;
              _error = result.success ? null : _errorMessage(result.errorType);
            });
          }
          break;
        case _ToolMode.merge:
          final result = await _apiService.mergePdfFiles(_selectedPaths);
          if (mounted) setState(() => _mergeResult = result);
          break;
        case _ToolMode.split:
          final result = await _apiService.splitPdfFile(_selectedPaths.single);
          if (mounted) setState(() => _splitResult = result);
          break;
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = ApiService.userMessageFor(error));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _download(PdfToolFile file) async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _error = null;
    });
    try {
      final download = await _apiService.downloadConversion(
        file.fileId,
        fallbackFilename: file.downloadFilename,
      );
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存文件',
        fileName: download.filename,
      );
      if (outputPath != null) {
        await File(outputPath).writeAsBytes(download.bytes, flush: true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = ApiService.userMessageFor(error));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  PdfToolFile? get _singleResult {
    if (_conversionResult != null) {
      return PdfToolFile(
        fileId: _conversionResult!.fileId,
        downloadFilename: _conversionResult!.downloadFilename,
      );
    }
    return _mergeResult?.file;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('工具箱'),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            children: [
              const Text(
                '文件处理',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '转换 Office 与 PDF，或合并、拆分 PDF 文件',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 22),
              SegmentedButton<_ToolMode>(
                segments: const [
                  ButtonSegment(value: _ToolMode.convert, label: Text('格式转换')),
                  ButtonSegment(value: _ToolMode.merge, label: Text('PDF合并')),
                  ButtonSegment(value: _ToolMode.split, label: Text('PDF拆分')),
                ],
                selected: {_mode},
                onSelectionChanged: _isProcessing
                    ? null
                    : (selection) => setState(() {
                        _mode = selection.single;
                        _selectedPaths = [];
                        _selectedNames = [];
                        _clearResults();
                      }),
              ),
              const SizedBox(height: 20),
              if (_mode == _ToolMode.convert) ...[
                DropdownButtonFormField<ToolboxConversionOption>(
                  initialValue: _conversionOption,
                  decoration: const InputDecoration(
                    labelText: '转换类型',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final option in toolboxConversionOptions)
                      DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: _isProcessing
                      ? null
                      : (option) {
                          if (option == null) return;
                          setState(() {
                            _conversionOption = option;
                            _selectedPaths = [];
                            _selectedNames = [];
                            _clearResults();
                          });
                        },
                ),
                const SizedBox(height: 16),
              ],
              DropTarget(
                onDragDone: (details) async {
                  if (details.files.isEmpty || _isProcessing) return;
                  final files = _mode == _ToolMode.merge
                      ? details.files
                      : details.files.take(1).toList();
                  await _useFiles(
                    files.map((item) => item.path).toList(),
                    files.map((item) => item.name).toList(),
                    append: _mode == _ToolMode.merge,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: _isProcessing ? null : _pickFiles,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.file_upload_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _selectionLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '支持点击选择或拖拽文件',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_mode == _ToolMode.merge &&
                          _selectedNames.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (
                          var index = 0;
                          index < _selectedNames.length;
                          index++
                        )
                          ListTile(
                            key: ValueKey('merge-file-$index'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Text('${index + 1}'),
                            title: Text(
                              _selectedNames[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: '移除',
                              onPressed: _isProcessing
                                  ? null
                                  : () => _removeSelectedFile(index),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: !_canProcess || _isProcessing
                            ? null
                            : _process,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(_isProcessing ? '处理中' : _actionLabel),
                      ),
                      if (_singleResult != null) ...[
                        const SizedBox(height: 12),
                        Text('处理成功：${_singleResult!.downloadFilename}'),
                        const SizedBox(height: 8),
                        _downloadButton(_singleResult!),
                      ],
                      if (_splitResult != null) ...[
                        const SizedBox(height: 12),
                        Text('拆分成功：${_splitResult!.pageCount}个文件'),
                        const SizedBox(height: 8),
                        for (final file in _splitResult!.files)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _downloadButton(file),
                          ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _downloadButton(PdfToolFile file) => OutlinedButton.icon(
    onPressed: _isDownloading ? null : () => _download(file),
    icon: _isDownloading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.download_outlined),
    label: Text(file.downloadFilename),
  );

  String get _actionLabel => switch (_mode) {
    _ToolMode.convert => '开始转换',
    _ToolMode.merge => '开始合并',
    _ToolMode.split => '开始拆分',
  };

  bool get _canProcess => switch (_mode) {
    _ToolMode.convert || _ToolMode.split => _selectedPaths.length == 1,
    _ToolMode.merge => _selectedPaths.length >= 2,
  };

  String get _selectionLabel {
    if (_selectedNames.isEmpty) return '点击选择文件，或拖拽文件到此处';
    if (_mode == _ToolMode.merge) {
      return '已选择${_selectedNames.length}个PDF，点击可继续添加';
    }
    return _selectedNames.single;
  }

  String _errorMessage(String errorType) => switch (errorType) {
    'unsupported_format' => '不支持该文件格式',
    'file_too_large' => '文件超过大小限制',
    'timeout' => '转换超时，请稍后重试',
    _ => '转换失败',
  };
}
