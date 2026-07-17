enum AttachmentUploadStatus { uploading, success, failed }

class PendingAttachment {
  const PendingAttachment({
    required this.attachmentId,
    required this.filename,
    required this.status,
    this.errorMessage,
  });

  final String attachmentId;
  final String filename;
  final AttachmentUploadStatus status;
  final String? errorMessage;

  PendingAttachment copyWith({
    String? attachmentId,
    AttachmentUploadStatus? status,
    String? errorMessage,
  }) {
    return PendingAttachment(
      attachmentId: attachmentId ?? this.attachmentId,
      filename: filename,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

class ChatAttachmentUpload {
  const ChatAttachmentUpload({
    required this.attachmentId,
    required this.filename,
  });

  final String attachmentId;
  final String filename;
}
