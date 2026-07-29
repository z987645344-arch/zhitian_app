import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/pending_attachment.dart';
import '../theme/app_theme.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.isSending,
    required this.pendingAttachments,
    required this.hasUploadingAttachments,
    required this.hasSuccessfulAttachments,
    required this.onAddAttachment,
    required this.onRemoveAttachment,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final List<PendingAttachment> pendingAttachments;
  final bool hasUploadingAttachments;
  final bool hasSuccessfulAttachments;
  final Future<void> Function(File file) onAddAttachment;
  final ValueChanged<String> onRemoveAttachment;
  final VoidCallback onSend;

  Future<void> _pickAttachments() async {
    if (isSending) return;
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'txt',
        'md',
        'pdf',
        'docx',
        'doc',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
      ],
    );
    if (picked == null) return;
    await Future.wait(
      picked.files
          .where((item) => item.path != null)
          .map((item) => onAddAttachment(File(item.path!))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D252A2E),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pendingAttachments.isNotEmpty)
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pendingAttachments.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final attachment = pendingAttachments[index];
                      final icon = switch (attachment.status) {
                        AttachmentUploadStatus.uploading => Icons.sync,
                        AttachmentUploadStatus.success => Icons.check_circle,
                        AttachmentUploadStatus.failed => Icons.error_outline,
                      };
                      return InputChip(
                        avatar: Icon(icon, size: 16),
                        label: Text(
                          attachment.filename,
                          overflow: TextOverflow.ellipsis,
                        ),
                        tooltip: attachment.errorMessage,
                        onDeleted: () =>
                            onRemoveAttachment(attachment.attachmentId),
                      );
                    },
                  ),
                ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final canSend =
                      !isSending &&
                      !hasUploadingAttachments &&
                      (value.text.trim().isNotEmpty ||
                          hasSuccessfulAttachments);
                  return Row(
                    children: [
                      IconButton(
                        tooltip: '添加附件',
                        onPressed: isSending ? null : _pickAttachments,
                        icon: const Icon(
                          Icons.attach_file,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: controller,
                            enabled: !isSending,
                            minLines: 1,
                            maxLines: 4,
                            style: const TextStyle(fontSize: 15),
                            textInputAction: TextInputAction.send,
                            decoration: const InputDecoration(
                              hintText: '输入问题；可添加文件作为本轮参考',
                              hintStyle: TextStyle(color: AppColors.textMuted),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (_) {
                              if (canSend) onSend();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Opacity(
                        opacity: canSend ? 1 : 0.4,
                        child: SizedBox.square(
                          dimension: 44,
                          child: IconButton.filled(
                            tooltip: '发送',
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: canSend ? onSend : null,
                            icon: isSending
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
