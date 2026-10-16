/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../design/td_design.dart';
import '../../services/aufgaben_anhang_service.dart';

/// Auswahl „Foto aufnehmen / Aus Fotos / Datei“ für Anhänge.
Future<AttachmentSource?> showAttachmentSourceSheet(
  BuildContext context, {
  required bool canUseCamera,
  bool allowFiles = true,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showTdSheet<AttachmentSource>(
    context,
    title: l10n.attachmentAdd,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canUseCamera)
          _Option(
            key: const ValueKey('attachment-option-camera'),
            icon: Icons.photo_camera_outlined,
            label: l10n.attachmentTakePhoto,
            onTap: () => Navigator.of(ctx).pop(AttachmentSource.camera),
          ),
        _Option(
          key: const ValueKey('attachment-option-gallery'),
          icon: Icons.photo_library_outlined,
          label: l10n.attachmentChooseFromPhotos,
          onTap: () => Navigator.of(ctx).pop(AttachmentSource.gallery),
        ),
        if (allowFiles)
          _Option(
            key: const ValueKey('attachment-option-file'),
            icon: Icons.picture_as_pdf_outlined,
            label: l10n.attachmentChooseFile,
            onTap: () => Navigator.of(ctx).pop(AttachmentSource.file),
          ),
      ],
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TdSpace.sm),
      child: TdCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: TdSpace.lg,
          vertical: TdSpace.md,
        ),
        child: Row(
          children: [
            Icon(icon, color: context.colors.primary),
            const SizedBox(width: TdSpace.md),
            Expanded(child: Text(label, style: context.text.bodyLarge)),
            Icon(Icons.chevron_right_rounded, color: context.td.muted),
          ],
        ),
      ),
    );
  }
}

/// Wählt einen Anhang aus und meldet Fehler als Toast. `null` = abgebrochen
/// oder fehlgeschlagen.
Future<PickedAttachment?> pickAttachmentWithFeedback(
  BuildContext context,
  AttachmentService service, {
  bool allowFiles = true,
}) async {
  final canUseCamera = await service.canUseCamera();
  if (!context.mounted) return null;
  final source = await showAttachmentSourceSheet(
    context,
    canUseCamera: canUseCamera,
    allowFiles: allowFiles,
  );
  if (source == null || !context.mounted) return null;
  final result = await service.pick(source);
  if (!context.mounted) return null;
  final l10n = AppLocalizations.of(context)!;
  switch (result.status) {
    case AttachmentPickStatus.picked:
      return result.file;
    case AttachmentPickStatus.cancelled:
      return null;
    case AttachmentPickStatus.permissionDenied:
      TdToast.show(
        context,
        l10n.attachmentPermissionMessage,
        variant: TdToastVariant.warning,
      );
    case AttachmentPickStatus.tooLarge:
      TdToast.show(context, l10n.attachmentTooLarge, variant: TdToastVariant.warning);
    case AttachmentPickStatus.unsupported:
      TdToast.show(
        context,
        l10n.attachmentUnsupported,
        variant: TdToastVariant.warning,
      );
    case AttachmentPickStatus.unavailable:
      TdToast.show(
        context,
        l10n.attachmentUploadFailed,
        variant: TdToastVariant.error,
      );
  }
  return null;
}
