class FilePreview {
  const FilePreview({
    required this.fileId,
    required this.filename,
    required this.format,
    required this.content,
    required this.truncated,
  });

  final String fileId;
  final String filename;
  final String format;
  final String content;
  final bool truncated;

  factory FilePreview.fromJson(Map<String, dynamic> json) {
    return FilePreview(
      fileId: (json['file_id'] ?? '').toString(),
      filename: (json['filename'] ?? '').toString(),
      format: (json['format'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      truncated: json['truncated'] == true,
    );
  }
}
