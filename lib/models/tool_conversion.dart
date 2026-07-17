import 'dart:typed_data';

class ToolConversionResult {
  const ToolConversionResult({
    required this.success,
    required this.fileId,
    required this.downloadFilename,
    required this.convertedFromFormat,
    required this.convertedToFormat,
    required this.errorType,
  });

  final bool success;
  final String fileId;
  final String downloadFilename;
  final String convertedFromFormat;
  final String convertedToFormat;
  final String errorType;

  factory ToolConversionResult.fromJson(Map<String, dynamic> json) {
    return ToolConversionResult(
      success: json['success'] == true,
      fileId: (json['file_id'] ?? '').toString(),
      downloadFilename: (json['download_filename'] ?? '').toString(),
      convertedFromFormat: (json['converted_from_format'] ?? '').toString(),
      convertedToFormat: (json['converted_to_format'] ?? '').toString(),
      errorType: (json['error_type'] ?? '').toString(),
    );
  }
}

class ToolConversionDownload {
  const ToolConversionDownload({required this.filename, required this.bytes});

  final String filename;
  final Uint8List bytes;
}

class PdfToolFile {
  const PdfToolFile({required this.fileId, required this.downloadFilename});

  final String fileId;
  final String downloadFilename;

  factory PdfToolFile.fromJson(Map<String, dynamic> json) => PdfToolFile(
    fileId: (json['file_id'] ?? '').toString(),
    downloadFilename: (json['download_filename'] ?? '').toString(),
  );
}

class PdfMergeResult {
  const PdfMergeResult({
    required this.success,
    required this.file,
    required this.pageCount,
  });

  final bool success;
  final PdfToolFile file;
  final int pageCount;

  factory PdfMergeResult.fromJson(Map<String, dynamic> json) => PdfMergeResult(
    success: json['success'] == true,
    file: PdfToolFile.fromJson(json),
    pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
  );
}

class PdfSplitResult {
  const PdfSplitResult({
    required this.success,
    required this.files,
    required this.pageCount,
  });

  final bool success;
  final List<PdfToolFile> files;
  final int pageCount;

  factory PdfSplitResult.fromJson(Map<String, dynamic> json) => PdfSplitResult(
    success: json['success'] == true,
    files: (json['files'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => PdfToolFile.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
  );
}
