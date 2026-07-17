class UserFile {
  const UserFile({
    required this.fileId,
    required this.originalFilename,
    required this.format,
    required this.sourceType,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String fileId;
  final String originalFilename;
  final String format;
  final String sourceType;
  final int sizeBytes;
  final DateTime? createdAt;

  factory UserFile.fromJson(Map<String, dynamic> json) {
    return UserFile(
      fileId: (json['file_id'] ?? '').toString(),
      originalFilename: (json['original_filename'] ?? '').toString(),
      format: (json['format'] ?? '').toString(),
      sourceType: (json['source_type'] ?? '').toString(),
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }
}
